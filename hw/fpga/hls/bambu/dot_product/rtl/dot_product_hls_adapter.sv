// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Bambu HLS flavour of 'dot_product_hls_adapter': hooks the Bambu-generated
// 'dot_product' core onto the PULP AXI structs used by the tool-independent
// hw/fpga/hls/common/dot_product/dot_product_xheep_wrapper.sv.
//
// Compared to the Vitis HLS flow (hw/fpga/hls/vitis/dot_product/rtl/), the
// Bambu core has two differences that this adapter absorbs:
//
//  1. No AXI4-Lite control port. The core exposes clock/reset/start_port/
//     done_port plus plain 'a', 'b', 'size' input ports and 'result' /
//     'result_vld' output ports, so the CTRL register file -- same register
//     map as Vitis' -- is instantiated here (dot_product_ctrl_regs).
//  2. Different flat AXI port names and widths: lower-case names
//     (m_axi_gmem_a_arvalid vs m_axi_gmem_a_ARVALID), 32-bit addresses
//     (Bambu targets a 32-bit address space, which is also X-HEEP's), 6-bit
//     ids and a real 1-bit lock. Ids are truncated/zero-extended and the
//     address is zero-extended to the wrapper's struct widths (64-bit
//     address, 1-bit id). The wrapper's struct widths are part of the
//     adapter contract, so a change there fails loudly here (width lint)
//     rather than silently.
//
// Bambu's AXI master issues single-beat, in-order transactions (ARLEN = 0);
// only the read channels ever fire (a/b are const pointers).

module dot_product_hls_adapter #(
    parameter type ctrl_axi_req_t = logic,
    parameter type ctrl_axi_rsp_t = logic,
    parameter type gmem_axi_req_t = logic,
    parameter type gmem_axi_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // CTRL: AXI4-Lite slave (register file: start/done, a, b, size, result)
    input  ctrl_axi_req_t ctrl_axi_req_i,
    output ctrl_axi_rsp_t ctrl_axi_rsp_o,

    // gmem_a / gmem_b: the core's two AXI4 read masters
    output gmem_axi_req_t gmem_a_axi_req_o,
    input  gmem_axi_rsp_t gmem_a_axi_rsp_i,
    output gmem_axi_req_t gmem_b_axi_req_o,
    input  gmem_axi_rsp_t gmem_b_axi_rsp_i
);

  // ---------------------------------------------------------------------
  // CTRL register file <-> core control/data ports
  // ---------------------------------------------------------------------
  logic        core_start;
  logic        core_done;
  logic [31:0] core_a;
  logic [31:0] core_b;
  logic [31:0] core_size;
  logic [63:0] core_result;
  logic        core_result_vld;

  dot_product_ctrl_regs #(
      .axi_req_t(ctrl_axi_req_t),
      .axi_rsp_t(ctrl_axi_rsp_t)
  ) ctrl_regs_i (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .axi_req_i   (ctrl_axi_req_i),
      .axi_rsp_o   (ctrl_axi_rsp_o),
      .start_o     (core_start),
      .done_i      (core_done),
      .a_o         (core_a),
      .b_o         (core_b),
      .size_o      (core_size),
      .result_i    (core_result),
      .result_vld_i(core_result_vld),
      .interrupt_o ()                  // like the Vitis flow, the core's interrupt is not used
  );

  // ---------------------------------------------------------------------
  // Core-side AXI signals whose width differs from the wrapper's structs
  // ---------------------------------------------------------------------
  // Only bit 0 of the core's 6-bit request ids reaches the wrapper's 1-bit
  // struct ids, so the upper bits of these four are unused by design.
  // verilator lint_off UNUSEDSIGNAL
  logic [ 5:0] a_awid;
  logic [ 5:0] a_arid;
  logic [ 5:0] b_awid;
  logic [ 5:0] b_arid;
  // verilator lint_on UNUSEDSIGNAL
  logic [ 5:0] a_bid;
  logic [ 5:0] a_rid;
  logic [31:0] a_awaddr;
  logic [31:0] a_araddr;
  logic [ 5:0] b_bid;
  logic [ 5:0] b_rid;
  logic [31:0] b_awaddr;
  logic [31:0] b_araddr;

  // ids: core 6 bits <-> struct 1 bit
  assign gmem_a_axi_req_o.aw.id = a_awid[0];
  assign gmem_a_axi_req_o.ar.id = a_arid[0];
  assign gmem_b_axi_req_o.aw.id = b_awid[0];
  assign gmem_b_axi_req_o.ar.id = b_arid[0];
  assign a_bid = {5'b0, gmem_a_axi_rsp_i.b.id};
  assign a_rid = {5'b0, gmem_a_axi_rsp_i.r.id};
  assign b_bid = {5'b0, gmem_b_axi_rsp_i.b.id};
  assign b_rid = {5'b0, gmem_b_axi_rsp_i.r.id};

  // addresses: core 32 bits -> struct 64 bits (zero-extended)
  assign gmem_a_axi_req_o.aw.addr = {32'b0, a_awaddr};
  assign gmem_a_axi_req_o.ar.addr = {32'b0, a_araddr};
  assign gmem_b_axi_req_o.aw.addr = {32'b0, b_awaddr};
  assign gmem_b_axi_req_o.ar.addr = {32'b0, b_araddr};

  // AWATOP is not an AXI4 (Bambu) signal at all -- tie it off explicitly
  // since PULP's AXI struct carries the field.
  assign gmem_a_axi_req_o.aw.atop = '0;
  assign gmem_b_axi_req_o.aw.atop = '0;

  // ---------------------------------------------------------------------
  // Bambu-generated dot-product core. Flat lower-case AXI ports are wired
  // to the matching struct fields.
  //  - cache_reset: only used by the optional '#pragma HLS cache' logic
  //    (reset_cache = reset && !cache_reset); there is no cache here, so
  //    it stays inactive.
  //  - reset is active low.
  // ---------------------------------------------------------------------
  dot_product dot_product_i (
      .clock      (clk_i),
      .reset      (rst_ni),
      .start_port (core_start),
      .done_port  (core_done),
      .a          (core_a),
      .b          (core_b),
      .size       (core_size),
      .result     (core_result),
      .result_vld (core_result_vld),
      .cache_reset(1'b0),

      // gmem_a
      .m_axi_gmem_a_awid    (a_awid),
      .m_axi_gmem_a_awaddr  (a_awaddr),
      .m_axi_gmem_a_awlen   (gmem_a_axi_req_o.aw.len),
      .m_axi_gmem_a_awsize  (gmem_a_axi_req_o.aw.size),
      .m_axi_gmem_a_awburst (gmem_a_axi_req_o.aw.burst),
      .m_axi_gmem_a_awlock  (gmem_a_axi_req_o.aw.lock),
      .m_axi_gmem_a_awcache (gmem_a_axi_req_o.aw.cache),
      .m_axi_gmem_a_awprot  (gmem_a_axi_req_o.aw.prot),
      .m_axi_gmem_a_awqos   (gmem_a_axi_req_o.aw.qos),
      .m_axi_gmem_a_awregion(gmem_a_axi_req_o.aw.region),
      .m_axi_gmem_a_awuser  (gmem_a_axi_req_o.aw.user),
      .m_axi_gmem_a_awvalid (gmem_a_axi_req_o.aw_valid),
      .m_axi_gmem_a_wdata   (gmem_a_axi_req_o.w.data),
      .m_axi_gmem_a_wstrb   (gmem_a_axi_req_o.w.strb),
      .m_axi_gmem_a_wlast   (gmem_a_axi_req_o.w.last),
      .m_axi_gmem_a_wuser   (gmem_a_axi_req_o.w.user),
      .m_axi_gmem_a_wvalid  (gmem_a_axi_req_o.w_valid),
      .m_axi_gmem_a_bready  (gmem_a_axi_req_o.b_ready),
      .m_axi_gmem_a_arid    (a_arid),
      .m_axi_gmem_a_araddr  (a_araddr),
      .m_axi_gmem_a_arlen   (gmem_a_axi_req_o.ar.len),
      .m_axi_gmem_a_arsize  (gmem_a_axi_req_o.ar.size),
      .m_axi_gmem_a_arburst (gmem_a_axi_req_o.ar.burst),
      .m_axi_gmem_a_arlock  (gmem_a_axi_req_o.ar.lock),
      .m_axi_gmem_a_arcache (gmem_a_axi_req_o.ar.cache),
      .m_axi_gmem_a_arprot  (gmem_a_axi_req_o.ar.prot),
      .m_axi_gmem_a_arqos   (gmem_a_axi_req_o.ar.qos),
      .m_axi_gmem_a_arregion(gmem_a_axi_req_o.ar.region),
      .m_axi_gmem_a_aruser  (gmem_a_axi_req_o.ar.user),
      .m_axi_gmem_a_arvalid (gmem_a_axi_req_o.ar_valid),
      .m_axi_gmem_a_rready  (gmem_a_axi_req_o.r_ready),
      .m_axi_gmem_a_awready (gmem_a_axi_rsp_i.aw_ready),
      .m_axi_gmem_a_wready  (gmem_a_axi_rsp_i.w_ready),
      .m_axi_gmem_a_bid     (a_bid),
      .m_axi_gmem_a_bresp   (gmem_a_axi_rsp_i.b.resp),
      .m_axi_gmem_a_buser   (gmem_a_axi_rsp_i.b.user),
      .m_axi_gmem_a_bvalid  (gmem_a_axi_rsp_i.b_valid),
      .m_axi_gmem_a_arready (gmem_a_axi_rsp_i.ar_ready),
      .m_axi_gmem_a_rid     (a_rid),
      .m_axi_gmem_a_rdata   (gmem_a_axi_rsp_i.r.data),
      .m_axi_gmem_a_rresp   (gmem_a_axi_rsp_i.r.resp),
      .m_axi_gmem_a_rlast   (gmem_a_axi_rsp_i.r.last),
      .m_axi_gmem_a_ruser   (gmem_a_axi_rsp_i.r.user),
      .m_axi_gmem_a_rvalid  (gmem_a_axi_rsp_i.r_valid),

      // gmem_b
      .m_axi_gmem_b_awid    (b_awid),
      .m_axi_gmem_b_awaddr  (b_awaddr),
      .m_axi_gmem_b_awlen   (gmem_b_axi_req_o.aw.len),
      .m_axi_gmem_b_awsize  (gmem_b_axi_req_o.aw.size),
      .m_axi_gmem_b_awburst (gmem_b_axi_req_o.aw.burst),
      .m_axi_gmem_b_awlock  (gmem_b_axi_req_o.aw.lock),
      .m_axi_gmem_b_awcache (gmem_b_axi_req_o.aw.cache),
      .m_axi_gmem_b_awprot  (gmem_b_axi_req_o.aw.prot),
      .m_axi_gmem_b_awqos   (gmem_b_axi_req_o.aw.qos),
      .m_axi_gmem_b_awregion(gmem_b_axi_req_o.aw.region),
      .m_axi_gmem_b_awuser  (gmem_b_axi_req_o.aw.user),
      .m_axi_gmem_b_awvalid (gmem_b_axi_req_o.aw_valid),
      .m_axi_gmem_b_wdata   (gmem_b_axi_req_o.w.data),
      .m_axi_gmem_b_wstrb   (gmem_b_axi_req_o.w.strb),
      .m_axi_gmem_b_wlast   (gmem_b_axi_req_o.w.last),
      .m_axi_gmem_b_wuser   (gmem_b_axi_req_o.w.user),
      .m_axi_gmem_b_wvalid  (gmem_b_axi_req_o.w_valid),
      .m_axi_gmem_b_bready  (gmem_b_axi_req_o.b_ready),
      .m_axi_gmem_b_arid    (b_arid),
      .m_axi_gmem_b_araddr  (b_araddr),
      .m_axi_gmem_b_arlen   (gmem_b_axi_req_o.ar.len),
      .m_axi_gmem_b_arsize  (gmem_b_axi_req_o.ar.size),
      .m_axi_gmem_b_arburst (gmem_b_axi_req_o.ar.burst),
      .m_axi_gmem_b_arlock  (gmem_b_axi_req_o.ar.lock),
      .m_axi_gmem_b_arcache (gmem_b_axi_req_o.ar.cache),
      .m_axi_gmem_b_arprot  (gmem_b_axi_req_o.ar.prot),
      .m_axi_gmem_b_arqos   (gmem_b_axi_req_o.ar.qos),
      .m_axi_gmem_b_arregion(gmem_b_axi_req_o.ar.region),
      .m_axi_gmem_b_aruser  (gmem_b_axi_req_o.ar.user),
      .m_axi_gmem_b_arvalid (gmem_b_axi_req_o.ar_valid),
      .m_axi_gmem_b_rready  (gmem_b_axi_req_o.r_ready),
      .m_axi_gmem_b_awready (gmem_b_axi_rsp_i.aw_ready),
      .m_axi_gmem_b_wready  (gmem_b_axi_rsp_i.w_ready),
      .m_axi_gmem_b_bid     (b_bid),
      .m_axi_gmem_b_bresp   (gmem_b_axi_rsp_i.b.resp),
      .m_axi_gmem_b_buser   (gmem_b_axi_rsp_i.b.user),
      .m_axi_gmem_b_bvalid  (gmem_b_axi_rsp_i.b_valid),
      .m_axi_gmem_b_arready (gmem_b_axi_rsp_i.ar_ready),
      .m_axi_gmem_b_rid     (b_rid),
      .m_axi_gmem_b_rdata   (gmem_b_axi_rsp_i.r.data),
      .m_axi_gmem_b_rresp   (gmem_b_axi_rsp_i.r.resp),
      .m_axi_gmem_b_rlast   (gmem_b_axi_rsp_i.r.last),
      .m_axi_gmem_b_ruser   (gmem_b_axi_rsp_i.r.user),
      .m_axi_gmem_b_rvalid  (gmem_b_axi_rsp_i.r_valid)
  );

endmodule : dot_product_hls_adapter
