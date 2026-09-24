// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Clean X-HEEP-facing wrapper around the Vitis HLS-generated 'dot_product'
// core. Hides all AXI<->OBI protocol adaptation so the testbench only ever
// sees plain X-HEEP OBI ports:
//   - ctrl_obi_*  : OBI slave  -> dot_product's AXI4-Lite CTRL port
//                   (addr_a, addr_b, size, result, ap_start/ap_done/...)
//   - gmem_a_obi_*, gmem_b_obi_* : OBI masters <- dot_product's own two
//                   AXI4 read masters (it fetches its own vector data).

module dot_product_xheep_wrapper #(
    // OBI request/response structs, defaulting to X-HEEP's flat OBI type.
    parameter type obi_req_t = xheep_obi_pkg::xheep_obi_req_t,
    parameter type obi_rsp_t = xheep_obi_pkg::xheep_obi_rsp_t
) (
    input logic clk_i,
    input logic rst_ni,

    input  obi_req_t ctrl_obi_req_i,
    output obi_rsp_t ctrl_obi_rsp_o,

    output obi_req_t gmem_a_obi_req_o,
    input  obi_rsp_t gmem_a_obi_rsp_i,

    output obi_req_t gmem_b_obi_req_o,
    input  obi_rsp_t gmem_b_obi_rsp_i
);

  `include "axi/typedef.svh"

  // ---------------------------------------------------------------------
  // CTRL: AXI4-Lite. xheep_obi_to_axi_bridge requires ObiAddrWidth <=
  // AxiAddrWidth (it was built for the OBI side being the narrow one, AXI
  // the wide one, e.g. VPK180's 64-bit DDR) -- so the bridge itself stays
  // a same-width 32-bit passthrough, matching X-HEEP's native OBI address.
  // dot_product's actual s_axi_CTRL port is only 6 bits wide
  // (C_S_AXI_CTRL_ADDR_WIDTH=6); the low 6 bits are sliced off below at
  // the connection to dot_product, which is exactly the in-region offset
  // as long as DOT_PRODUCT_CTRL_START_ADDRESS (testharness_pkg.sv) is
  // 64-byte aligned -- it is (0x...20000).
  // ---------------------------------------------------------------------
  localparam int unsigned CtrlAddrWidth = 32;
  localparam int unsigned CtrlDataWidth = 32;
  localparam int unsigned CtrlHlsAddrWidth = 6;  // dot_product's actual s_axi_CTRL_*ADDR width

  typedef logic [CtrlAddrWidth-1:0] ctrl_addr_t;
  typedef logic [CtrlDataWidth-1:0] ctrl_data_t;
  typedef logic [CtrlDataWidth/8-1:0] ctrl_strb_t;
  typedef logic [0:0] ctrl_id_t;
  typedef logic [0:0] ctrl_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(ctrl_aw_t, ctrl_addr_t, ctrl_id_t, ctrl_user_t)
  `AXI_TYPEDEF_W_CHAN_T(ctrl_w_t, ctrl_data_t, ctrl_strb_t, ctrl_user_t)
  `AXI_TYPEDEF_B_CHAN_T(ctrl_b_t, ctrl_id_t, ctrl_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ctrl_ar_t, ctrl_addr_t, ctrl_id_t, ctrl_user_t)
  `AXI_TYPEDEF_R_CHAN_T(ctrl_r_t, ctrl_data_t, ctrl_id_t, ctrl_user_t)
  `AXI_TYPEDEF_REQ_T(ctrl_axi_req_t, ctrl_aw_t, ctrl_w_t, ctrl_ar_t)
  `AXI_TYPEDEF_RESP_T(ctrl_axi_rsp_t, ctrl_b_t, ctrl_r_t)

  ctrl_axi_req_t ctrl_axi_req;
  ctrl_axi_rsp_t ctrl_axi_rsp;

  xheep_obi_to_axi_bridge #(
      .ObiAddrWidth   (32),
      .ObiDataWidth   (32),
      .ObiIdWidth     (1),
      .ObiRspUserWidth(1),
      .AxiLite        (1'b1),
      .AxiAddrWidth   (CtrlAddrWidth),
      .AxiDataWidth   (CtrlDataWidth),
      .AxiUserWidth   (1),
      .axi_req_t      (ctrl_axi_req_t),
      .axi_rsp_t      (ctrl_axi_rsp_t)
  ) ctrl_obi_to_axi_i (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .obi_req_i (ctrl_obi_req_i),
      .obi_resp_o(ctrl_obi_rsp_o),
      .axi_req_o (ctrl_axi_req),
      .axi_rsp_i (ctrl_axi_rsp)
  );

  // ---------------------------------------------------------------------
  // gmem_a / gmem_b: full AXI4 master ports as emitted by HLS (only the
  // read channel is actually driven -- 'a'/'b' are read-only C pointers).
  // Address width matches HLS's host-pointer-sized m_axi port (64 bits);
  // the bridge truncates down to X-HEEP's native 32-bit OBI address, so
  // software must keep the upper pointer word at zero.
  // ---------------------------------------------------------------------
  localparam int unsigned GmemAddrWidth = 64;
  localparam int unsigned GmemDataWidth = 32;
  localparam int unsigned GmemIdWidth = 1;
  localparam int unsigned GmemUserWidth = 1;

  typedef logic [GmemAddrWidth-1:0] gmem_addr_t;
  typedef logic [GmemDataWidth-1:0] gmem_data_t;
  typedef logic [GmemDataWidth/8-1:0] gmem_strb_t;
  typedef logic [GmemIdWidth-1:0] gmem_id_t;
  typedef logic [GmemUserWidth-1:0] gmem_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(gmem_aw_t, gmem_addr_t, gmem_id_t, gmem_user_t)
  `AXI_TYPEDEF_W_CHAN_T(gmem_w_t, gmem_data_t, gmem_strb_t, gmem_user_t)
  `AXI_TYPEDEF_B_CHAN_T(gmem_b_t, gmem_id_t, gmem_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(gmem_ar_t, gmem_addr_t, gmem_id_t, gmem_user_t)
  `AXI_TYPEDEF_R_CHAN_T(gmem_r_t, gmem_data_t, gmem_id_t, gmem_user_t)
  `AXI_TYPEDEF_REQ_T(gmem_axi_req_t, gmem_aw_t, gmem_w_t, gmem_ar_t)
  `AXI_TYPEDEF_RESP_T(gmem_axi_rsp_t, gmem_b_t, gmem_r_t)

  gmem_axi_req_t gmem_a_axi_req, gmem_b_axi_req;
  gmem_axi_rsp_t gmem_a_axi_rsp, gmem_b_axi_rsp;

  // dot_product never drives AWATOP (not a Xilinx AXI4 signal at all) --
  // tie it off explicitly since PULP's AXI struct carries the field.
  assign gmem_a_axi_req.aw.atop = '0;
  assign gmem_b_axi_req.aw.atop = '0;

  // dot_product's AWLOCK/ARLOCK are legacy 2-bit AXI3-style ports; PULP's
  // struct only carries a 1-bit 'lock' (true AXI4 shape), so they're left
  // unconnected above and tied off here instead of driving a 1-bit field
  // from a 2-bit pin.
  assign gmem_a_axi_req.aw.lock = '0;
  assign gmem_a_axi_req.ar.lock = '0;
  assign gmem_b_axi_req.aw.lock = '0;
  assign gmem_b_axi_req.ar.lock = '0;

  xheep_axi_to_obi_bridge #(
      .ObiIdWidth  (1),
      .AxiAddrWidth(GmemAddrWidth),
      .AxiDataWidth(GmemDataWidth),
      .AxiIdWidth  (GmemIdWidth),
      .AxiUserWidth(GmemUserWidth),
      .MaxTrans    (2),
      .axi_req_t   (gmem_axi_req_t),
      .axi_rsp_t   (gmem_axi_rsp_t),
      .obi_req_t   (obi_req_t),
      .obi_rsp_t   (obi_rsp_t)
  ) gmem_a_axi_to_obi_i (
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),
      .axi_req_i(gmem_a_axi_req),
      .axi_rsp_o(gmem_a_axi_rsp),
      .obi_req_o(gmem_a_obi_req_o),
      .obi_rsp_i(gmem_a_obi_rsp_i)
  );

  xheep_axi_to_obi_bridge #(
      .ObiIdWidth  (1),
      .AxiAddrWidth(GmemAddrWidth),
      .AxiDataWidth(GmemDataWidth),
      .AxiIdWidth  (GmemIdWidth),
      .AxiUserWidth(GmemUserWidth),
      .MaxTrans    (2),
      .axi_req_t   (gmem_axi_req_t),
      .axi_rsp_t   (gmem_axi_rsp_t),
      .obi_req_t   (obi_req_t),
      .obi_rsp_t   (obi_rsp_t)
  ) gmem_b_axi_to_obi_i (
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),
      .axi_req_i(gmem_b_axi_req),
      .axi_rsp_o(gmem_b_axi_rsp),
      .obi_req_o(gmem_b_obi_req_o),
      .obi_rsp_i(gmem_b_obi_rsp_i)
  );

  // ---------------------------------------------------------------------
  // HLS-generated dot-product core. Every AXI struct field is wired
  // directly to its matching flat Xilinx signal -- the same style used
  // to hook PULP AXI structs into a Vivado-generated PS wrapper.
  // ---------------------------------------------------------------------
  dot_product dot_product_i (
      .ap_clk  (clk_i),
      .ap_rst_n(rst_ni),

      // gmem_a
      .m_axi_gmem_a_AWVALID (gmem_a_axi_req.aw_valid),
      .m_axi_gmem_a_AWREADY (gmem_a_axi_rsp.aw_ready),
      .m_axi_gmem_a_AWADDR  (gmem_a_axi_req.aw.addr),
      .m_axi_gmem_a_AWID    (gmem_a_axi_req.aw.id),
      .m_axi_gmem_a_AWLEN   (gmem_a_axi_req.aw.len),
      .m_axi_gmem_a_AWSIZE  (gmem_a_axi_req.aw.size),
      .m_axi_gmem_a_AWBURST (gmem_a_axi_req.aw.burst),
      .m_axi_gmem_a_AWLOCK  (),
      .m_axi_gmem_a_AWCACHE (gmem_a_axi_req.aw.cache),
      .m_axi_gmem_a_AWPROT  (gmem_a_axi_req.aw.prot),
      .m_axi_gmem_a_AWQOS   (gmem_a_axi_req.aw.qos),
      .m_axi_gmem_a_AWREGION(gmem_a_axi_req.aw.region),
      .m_axi_gmem_a_AWUSER  (gmem_a_axi_req.aw.user),
      .m_axi_gmem_a_WVALID  (gmem_a_axi_req.w_valid),
      .m_axi_gmem_a_WREADY  (gmem_a_axi_rsp.w_ready),
      .m_axi_gmem_a_WDATA   (gmem_a_axi_req.w.data),
      .m_axi_gmem_a_WSTRB   (gmem_a_axi_req.w.strb),
      .m_axi_gmem_a_WLAST   (gmem_a_axi_req.w.last),
      .m_axi_gmem_a_WID     (),
      .m_axi_gmem_a_WUSER   (gmem_a_axi_req.w.user),
      .m_axi_gmem_a_ARVALID (gmem_a_axi_req.ar_valid),
      .m_axi_gmem_a_ARREADY (gmem_a_axi_rsp.ar_ready),
      .m_axi_gmem_a_ARADDR  (gmem_a_axi_req.ar.addr),
      .m_axi_gmem_a_ARID    (gmem_a_axi_req.ar.id),
      .m_axi_gmem_a_ARLEN   (gmem_a_axi_req.ar.len),
      .m_axi_gmem_a_ARSIZE  (gmem_a_axi_req.ar.size),
      .m_axi_gmem_a_ARBURST (gmem_a_axi_req.ar.burst),
      .m_axi_gmem_a_ARLOCK  (),
      .m_axi_gmem_a_ARCACHE (gmem_a_axi_req.ar.cache),
      .m_axi_gmem_a_ARPROT  (gmem_a_axi_req.ar.prot),
      .m_axi_gmem_a_ARQOS   (gmem_a_axi_req.ar.qos),
      .m_axi_gmem_a_ARREGION(gmem_a_axi_req.ar.region),
      .m_axi_gmem_a_ARUSER  (gmem_a_axi_req.ar.user),
      .m_axi_gmem_a_RVALID  (gmem_a_axi_rsp.r_valid),
      .m_axi_gmem_a_RREADY  (gmem_a_axi_req.r_ready),
      .m_axi_gmem_a_RDATA   (gmem_a_axi_rsp.r.data),
      .m_axi_gmem_a_RLAST   (gmem_a_axi_rsp.r.last),
      .m_axi_gmem_a_RID     (gmem_a_axi_rsp.r.id),
      .m_axi_gmem_a_RUSER   (gmem_a_axi_rsp.r.user),
      .m_axi_gmem_a_RRESP   (gmem_a_axi_rsp.r.resp),
      .m_axi_gmem_a_BVALID  (gmem_a_axi_rsp.b_valid),
      .m_axi_gmem_a_BREADY  (gmem_a_axi_req.b_ready),
      .m_axi_gmem_a_BRESP   (gmem_a_axi_rsp.b.resp),
      .m_axi_gmem_a_BID     (gmem_a_axi_rsp.b.id),
      .m_axi_gmem_a_BUSER   (gmem_a_axi_rsp.b.user),

      // gmem_b
      .m_axi_gmem_b_AWVALID (gmem_b_axi_req.aw_valid),
      .m_axi_gmem_b_AWREADY (gmem_b_axi_rsp.aw_ready),
      .m_axi_gmem_b_AWADDR  (gmem_b_axi_req.aw.addr),
      .m_axi_gmem_b_AWID    (gmem_b_axi_req.aw.id),
      .m_axi_gmem_b_AWLEN   (gmem_b_axi_req.aw.len),
      .m_axi_gmem_b_AWSIZE  (gmem_b_axi_req.aw.size),
      .m_axi_gmem_b_AWBURST (gmem_b_axi_req.aw.burst),
      .m_axi_gmem_b_AWLOCK  (),
      .m_axi_gmem_b_AWCACHE (gmem_b_axi_req.aw.cache),
      .m_axi_gmem_b_AWPROT  (gmem_b_axi_req.aw.prot),
      .m_axi_gmem_b_AWQOS   (gmem_b_axi_req.aw.qos),
      .m_axi_gmem_b_AWREGION(gmem_b_axi_req.aw.region),
      .m_axi_gmem_b_AWUSER  (gmem_b_axi_req.aw.user),
      .m_axi_gmem_b_WVALID  (gmem_b_axi_req.w_valid),
      .m_axi_gmem_b_WREADY  (gmem_b_axi_rsp.w_ready),
      .m_axi_gmem_b_WDATA   (gmem_b_axi_req.w.data),
      .m_axi_gmem_b_WSTRB   (gmem_b_axi_req.w.strb),
      .m_axi_gmem_b_WLAST   (gmem_b_axi_req.w.last),
      .m_axi_gmem_b_WID     (),
      .m_axi_gmem_b_WUSER   (gmem_b_axi_req.w.user),
      .m_axi_gmem_b_ARVALID (gmem_b_axi_req.ar_valid),
      .m_axi_gmem_b_ARREADY (gmem_b_axi_rsp.ar_ready),
      .m_axi_gmem_b_ARADDR  (gmem_b_axi_req.ar.addr),
      .m_axi_gmem_b_ARID    (gmem_b_axi_req.ar.id),
      .m_axi_gmem_b_ARLEN   (gmem_b_axi_req.ar.len),
      .m_axi_gmem_b_ARSIZE  (gmem_b_axi_req.ar.size),
      .m_axi_gmem_b_ARBURST (gmem_b_axi_req.ar.burst),
      .m_axi_gmem_b_ARLOCK  (),
      .m_axi_gmem_b_ARCACHE (gmem_b_axi_req.ar.cache),
      .m_axi_gmem_b_ARPROT  (gmem_b_axi_req.ar.prot),
      .m_axi_gmem_b_ARQOS   (gmem_b_axi_req.ar.qos),
      .m_axi_gmem_b_ARREGION(gmem_b_axi_req.ar.region),
      .m_axi_gmem_b_ARUSER  (gmem_b_axi_req.ar.user),
      .m_axi_gmem_b_RVALID  (gmem_b_axi_rsp.r_valid),
      .m_axi_gmem_b_RREADY  (gmem_b_axi_req.r_ready),
      .m_axi_gmem_b_RDATA   (gmem_b_axi_rsp.r.data),
      .m_axi_gmem_b_RLAST   (gmem_b_axi_rsp.r.last),
      .m_axi_gmem_b_RID     (gmem_b_axi_rsp.r.id),
      .m_axi_gmem_b_RUSER   (gmem_b_axi_rsp.r.user),
      .m_axi_gmem_b_RRESP   (gmem_b_axi_rsp.r.resp),
      .m_axi_gmem_b_BVALID  (gmem_b_axi_rsp.b_valid),
      .m_axi_gmem_b_BREADY  (gmem_b_axi_req.b_ready),
      .m_axi_gmem_b_BRESP   (gmem_b_axi_rsp.b.resp),
      .m_axi_gmem_b_BID     (gmem_b_axi_rsp.b.id),
      .m_axi_gmem_b_BUSER   (gmem_b_axi_rsp.b.user),

      // CTRL
      .s_axi_CTRL_AWVALID(ctrl_axi_req.aw_valid),
      .s_axi_CTRL_AWREADY(ctrl_axi_rsp.aw_ready),
      .s_axi_CTRL_AWADDR (ctrl_axi_req.aw.addr[CtrlHlsAddrWidth-1:0]),
      .s_axi_CTRL_WVALID (ctrl_axi_req.w_valid),
      .s_axi_CTRL_WREADY (ctrl_axi_rsp.w_ready),
      .s_axi_CTRL_WDATA  (ctrl_axi_req.w.data),
      .s_axi_CTRL_WSTRB  (ctrl_axi_req.w.strb),
      .s_axi_CTRL_ARVALID(ctrl_axi_req.ar_valid),
      .s_axi_CTRL_ARREADY(ctrl_axi_rsp.ar_ready),
      .s_axi_CTRL_ARADDR (ctrl_axi_req.ar.addr[CtrlHlsAddrWidth-1:0]),
      .s_axi_CTRL_RVALID (ctrl_axi_rsp.r_valid),
      .s_axi_CTRL_RREADY (ctrl_axi_req.r_ready),
      .s_axi_CTRL_RDATA  (ctrl_axi_rsp.r.data),
      .s_axi_CTRL_RRESP  (ctrl_axi_rsp.r.resp),
      .s_axi_CTRL_BVALID (ctrl_axi_rsp.b_valid),
      .s_axi_CTRL_BREADY (ctrl_axi_req.b_ready),
      .s_axi_CTRL_BRESP  (ctrl_axi_rsp.b.resp),

      .interrupt()
  );

endmodule : dot_product_xheep_wrapper
