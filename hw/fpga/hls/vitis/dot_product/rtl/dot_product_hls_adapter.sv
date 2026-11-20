// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Vitis HLS flavour of 'dot_product_hls_adapter': hooks the Vitis
// HLS-generated 'dot_product' core (flat Xilinx-style AXI ports, plus an
// AXI4-Lite 's_axi_CTRL' slave that already contains the ap_ctrl_hs register
// file) onto the PULP AXI structs used by the tool-independent
// hw/fpga/hls/common/dot_product/dot_product_xheep_wrapper.sv.
//
// The Bambu HLS flow provides a module with the very same name and ports in
// hw/fpga/hls/bambu/dot_product/rtl/; FuseSoC only ever pulls in one of them
// (see epfl:ip:dot_product).

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

  // dot_product's actual s_axi_CTRL port is only 6 bits wide
  // (C_S_AXI_CTRL_ADDR_WIDTH=6); the low 6 bits of the (32-bit, same-width
  // bridge) CTRL address are sliced off at the connection below, which is
  // exactly the in-region offset as long as DOT_PRODUCT_CTRL_START_ADDRESS
  // (testharness_pkg.sv) is 64-byte aligned -- it is (0x...20000).
  localparam int unsigned CtrlHlsAddrWidth = 6;

  // dot_product never drives AWATOP (not a Xilinx AXI4 signal at all) --
  // tie it off explicitly since PULP's AXI struct carries the field.
  assign gmem_a_axi_req_o.aw.atop = '0;
  assign gmem_b_axi_req_o.aw.atop = '0;

  // dot_product's AWLOCK/ARLOCK are legacy 2-bit AXI3-style ports; PULP's
  // struct only carries a 1-bit 'lock' (true AXI4 shape), so they're left
  // unconnected below and tied off here instead of driving a 1-bit field
  // from a 2-bit pin.
  assign gmem_a_axi_req_o.aw.lock = '0;
  assign gmem_a_axi_req_o.ar.lock = '0;
  assign gmem_b_axi_req_o.aw.lock = '0;
  assign gmem_b_axi_req_o.ar.lock = '0;

  // ---------------------------------------------------------------------
  // HLS-generated dot-product core. Every AXI struct field is wired
  // directly to its matching flat Xilinx signal -- the same style used
  // to hook PULP AXI structs into a Vivado-generated PS wrapper.
  // ---------------------------------------------------------------------
  dot_product dot_product_i (
      .ap_clk  (clk_i),
      .ap_rst_n(rst_ni),

      // gmem_a
      .m_axi_gmem_a_AWVALID (gmem_a_axi_req_o.aw_valid),
      .m_axi_gmem_a_AWREADY (gmem_a_axi_rsp_i.aw_ready),
      .m_axi_gmem_a_AWADDR  (gmem_a_axi_req_o.aw.addr),
      .m_axi_gmem_a_AWID    (gmem_a_axi_req_o.aw.id),
      .m_axi_gmem_a_AWLEN   (gmem_a_axi_req_o.aw.len),
      .m_axi_gmem_a_AWSIZE  (gmem_a_axi_req_o.aw.size),
      .m_axi_gmem_a_AWBURST (gmem_a_axi_req_o.aw.burst),
      .m_axi_gmem_a_AWLOCK  (),
      .m_axi_gmem_a_AWCACHE (gmem_a_axi_req_o.aw.cache),
      .m_axi_gmem_a_AWPROT  (gmem_a_axi_req_o.aw.prot),
      .m_axi_gmem_a_AWQOS   (gmem_a_axi_req_o.aw.qos),
      .m_axi_gmem_a_AWREGION(gmem_a_axi_req_o.aw.region),
      .m_axi_gmem_a_AWUSER  (gmem_a_axi_req_o.aw.user),
      .m_axi_gmem_a_WVALID  (gmem_a_axi_req_o.w_valid),
      .m_axi_gmem_a_WREADY  (gmem_a_axi_rsp_i.w_ready),
      .m_axi_gmem_a_WDATA   (gmem_a_axi_req_o.w.data),
      .m_axi_gmem_a_WSTRB   (gmem_a_axi_req_o.w.strb),
      .m_axi_gmem_a_WLAST   (gmem_a_axi_req_o.w.last),
      .m_axi_gmem_a_WID     (),
      .m_axi_gmem_a_WUSER   (gmem_a_axi_req_o.w.user),
      .m_axi_gmem_a_ARVALID (gmem_a_axi_req_o.ar_valid),
      .m_axi_gmem_a_ARREADY (gmem_a_axi_rsp_i.ar_ready),
      .m_axi_gmem_a_ARADDR  (gmem_a_axi_req_o.ar.addr),
      .m_axi_gmem_a_ARID    (gmem_a_axi_req_o.ar.id),
      .m_axi_gmem_a_ARLEN   (gmem_a_axi_req_o.ar.len),
      .m_axi_gmem_a_ARSIZE  (gmem_a_axi_req_o.ar.size),
      .m_axi_gmem_a_ARBURST (gmem_a_axi_req_o.ar.burst),
      .m_axi_gmem_a_ARLOCK  (),
      .m_axi_gmem_a_ARCACHE (gmem_a_axi_req_o.ar.cache),
      .m_axi_gmem_a_ARPROT  (gmem_a_axi_req_o.ar.prot),
      .m_axi_gmem_a_ARQOS   (gmem_a_axi_req_o.ar.qos),
      .m_axi_gmem_a_ARREGION(gmem_a_axi_req_o.ar.region),
      .m_axi_gmem_a_ARUSER  (gmem_a_axi_req_o.ar.user),
      .m_axi_gmem_a_RVALID  (gmem_a_axi_rsp_i.r_valid),
      .m_axi_gmem_a_RREADY  (gmem_a_axi_req_o.r_ready),
      .m_axi_gmem_a_RDATA   (gmem_a_axi_rsp_i.r.data),
      .m_axi_gmem_a_RLAST   (gmem_a_axi_rsp_i.r.last),
      .m_axi_gmem_a_RID     (gmem_a_axi_rsp_i.r.id),
      .m_axi_gmem_a_RUSER   (gmem_a_axi_rsp_i.r.user),
      .m_axi_gmem_a_RRESP   (gmem_a_axi_rsp_i.r.resp),
      .m_axi_gmem_a_BVALID  (gmem_a_axi_rsp_i.b_valid),
      .m_axi_gmem_a_BREADY  (gmem_a_axi_req_o.b_ready),
      .m_axi_gmem_a_BRESP   (gmem_a_axi_rsp_i.b.resp),
      .m_axi_gmem_a_BID     (gmem_a_axi_rsp_i.b.id),
      .m_axi_gmem_a_BUSER   (gmem_a_axi_rsp_i.b.user),

      // gmem_b
      .m_axi_gmem_b_AWVALID (gmem_b_axi_req_o.aw_valid),
      .m_axi_gmem_b_AWREADY (gmem_b_axi_rsp_i.aw_ready),
      .m_axi_gmem_b_AWADDR  (gmem_b_axi_req_o.aw.addr),
      .m_axi_gmem_b_AWID    (gmem_b_axi_req_o.aw.id),
      .m_axi_gmem_b_AWLEN   (gmem_b_axi_req_o.aw.len),
      .m_axi_gmem_b_AWSIZE  (gmem_b_axi_req_o.aw.size),
      .m_axi_gmem_b_AWBURST (gmem_b_axi_req_o.aw.burst),
      .m_axi_gmem_b_AWLOCK  (),
      .m_axi_gmem_b_AWCACHE (gmem_b_axi_req_o.aw.cache),
      .m_axi_gmem_b_AWPROT  (gmem_b_axi_req_o.aw.prot),
      .m_axi_gmem_b_AWQOS   (gmem_b_axi_req_o.aw.qos),
      .m_axi_gmem_b_AWREGION(gmem_b_axi_req_o.aw.region),
      .m_axi_gmem_b_AWUSER  (gmem_b_axi_req_o.aw.user),
      .m_axi_gmem_b_WVALID  (gmem_b_axi_req_o.w_valid),
      .m_axi_gmem_b_WREADY  (gmem_b_axi_rsp_i.w_ready),
      .m_axi_gmem_b_WDATA   (gmem_b_axi_req_o.w.data),
      .m_axi_gmem_b_WSTRB   (gmem_b_axi_req_o.w.strb),
      .m_axi_gmem_b_WLAST   (gmem_b_axi_req_o.w.last),
      .m_axi_gmem_b_WID     (),
      .m_axi_gmem_b_WUSER   (gmem_b_axi_req_o.w.user),
      .m_axi_gmem_b_ARVALID (gmem_b_axi_req_o.ar_valid),
      .m_axi_gmem_b_ARREADY (gmem_b_axi_rsp_i.ar_ready),
      .m_axi_gmem_b_ARADDR  (gmem_b_axi_req_o.ar.addr),
      .m_axi_gmem_b_ARID    (gmem_b_axi_req_o.ar.id),
      .m_axi_gmem_b_ARLEN   (gmem_b_axi_req_o.ar.len),
      .m_axi_gmem_b_ARSIZE  (gmem_b_axi_req_o.ar.size),
      .m_axi_gmem_b_ARBURST (gmem_b_axi_req_o.ar.burst),
      .m_axi_gmem_b_ARLOCK  (),
      .m_axi_gmem_b_ARCACHE (gmem_b_axi_req_o.ar.cache),
      .m_axi_gmem_b_ARPROT  (gmem_b_axi_req_o.ar.prot),
      .m_axi_gmem_b_ARQOS   (gmem_b_axi_req_o.ar.qos),
      .m_axi_gmem_b_ARREGION(gmem_b_axi_req_o.ar.region),
      .m_axi_gmem_b_ARUSER  (gmem_b_axi_req_o.ar.user),
      .m_axi_gmem_b_RVALID  (gmem_b_axi_rsp_i.r_valid),
      .m_axi_gmem_b_RREADY  (gmem_b_axi_req_o.r_ready),
      .m_axi_gmem_b_RDATA   (gmem_b_axi_rsp_i.r.data),
      .m_axi_gmem_b_RLAST   (gmem_b_axi_rsp_i.r.last),
      .m_axi_gmem_b_RID     (gmem_b_axi_rsp_i.r.id),
      .m_axi_gmem_b_RUSER   (gmem_b_axi_rsp_i.r.user),
      .m_axi_gmem_b_RRESP   (gmem_b_axi_rsp_i.r.resp),
      .m_axi_gmem_b_BVALID  (gmem_b_axi_rsp_i.b_valid),
      .m_axi_gmem_b_BREADY  (gmem_b_axi_req_o.b_ready),
      .m_axi_gmem_b_BRESP   (gmem_b_axi_rsp_i.b.resp),
      .m_axi_gmem_b_BID     (gmem_b_axi_rsp_i.b.id),
      .m_axi_gmem_b_BUSER   (gmem_b_axi_rsp_i.b.user),

      // CTRL
      .s_axi_CTRL_AWVALID(ctrl_axi_req_i.aw_valid),
      .s_axi_CTRL_AWREADY(ctrl_axi_rsp_o.aw_ready),
      .s_axi_CTRL_AWADDR (ctrl_axi_req_i.aw.addr[CtrlHlsAddrWidth-1:0]),
      .s_axi_CTRL_WVALID (ctrl_axi_req_i.w_valid),
      .s_axi_CTRL_WREADY (ctrl_axi_rsp_o.w_ready),
      .s_axi_CTRL_WDATA  (ctrl_axi_req_i.w.data),
      .s_axi_CTRL_WSTRB  (ctrl_axi_req_i.w.strb),
      .s_axi_CTRL_ARVALID(ctrl_axi_req_i.ar_valid),
      .s_axi_CTRL_ARREADY(ctrl_axi_rsp_o.ar_ready),
      .s_axi_CTRL_ARADDR (ctrl_axi_req_i.ar.addr[CtrlHlsAddrWidth-1:0]),
      .s_axi_CTRL_RVALID (ctrl_axi_rsp_o.r_valid),
      .s_axi_CTRL_RREADY (ctrl_axi_req_i.r_ready),
      .s_axi_CTRL_RDATA  (ctrl_axi_rsp_o.r.data),
      .s_axi_CTRL_RRESP  (ctrl_axi_rsp_o.r.resp),
      .s_axi_CTRL_BVALID (ctrl_axi_rsp_o.b_valid),
      .s_axi_CTRL_BREADY (ctrl_axi_req_i.b_ready),
      .s_axi_CTRL_BRESP  (ctrl_axi_rsp_o.b.resp),

      .interrupt()
  );

endmodule : dot_product_hls_adapter
