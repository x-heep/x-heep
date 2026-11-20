// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Clean X-HEEP-facing wrapper around an HLS-generated 'dot_product' core.
// Hides all AXI<->OBI protocol adaptation so the testbench only ever sees
// plain X-HEEP OBI ports:
//   - ctrl_obi_*  : OBI slave  -> dot_product's AXI4-Lite CTRL port
//                   (addr_a, addr_b, size, result, ap_start/ap_done/...)
//   - gmem_a_obi_*, gmem_b_obi_* : OBI masters <- dot_product's own two
//                   AXI4 read masters (it fetches its own vector data).
//
// This wrapper is shared by every HLS flow (Vitis HLS, Bambu HLS, ...): all
// it knows about the core is the tool-independent contract of
// 'dot_product_hls_adapter', which each flow provides in its own directory
// (hw/fpga/hls/<tool>/dot_product/rtl/) with identical ports:
//   - one AXI4-Lite slave  (the CTRL register file, see
//     sw/applications/example_dot_product_hls/main.c for the register map)
//   - two AXI4 read masters (gmem_a / gmem_b)
// All of them are expressed with PULP AXI structs, so a flow only has to map
// whatever flat ports (and port names) its HLS tool emits onto them.
// FuseSoC picks which adapter gets built (see epfl:ip:dot_product).

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
  // The adapter only looks at the low bits of the address (the in-region
  // offset), which is right as long as DOT_PRODUCT_CTRL_START_ADDRESS
  // (testharness_pkg.sv) is aligned to the size of the CTRL register file
  // (64 bytes) -- it is (0x...20000).
  // ---------------------------------------------------------------------
  localparam int unsigned CtrlAddrWidth = 32;
  localparam int unsigned CtrlDataWidth = 32;

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
  // gmem_a / gmem_b: full AXI4 master ports (only the read channel is
  // actually driven -- 'a'/'b' are read-only C pointers).
  // The struct address is 64 bits wide (the widest an HLS tool emits: Vitis
  // HLS derives the m_axi pointer width from the host's native 64-bit
  // pointers; Bambu's 32-bit-target flow zero-extends its 32-bit addresses);
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
  // HLS-generated dot-product core, seen through the flow-specific
  // adapter (Vitis HLS, Bambu HLS or Dynamatic -- whichever
  // epfl:ip:dot_product pulled in).
  // ---------------------------------------------------------------------
  dot_product_hls_adapter #(
      .ctrl_axi_req_t(ctrl_axi_req_t),
      .ctrl_axi_rsp_t(ctrl_axi_rsp_t),
      .gmem_axi_req_t(gmem_axi_req_t),
      .gmem_axi_rsp_t(gmem_axi_rsp_t)
  ) dot_product_adapter_i (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .ctrl_axi_req_i(ctrl_axi_req),
      .ctrl_axi_rsp_o(ctrl_axi_rsp),

      .gmem_a_axi_req_o(gmem_a_axi_req),
      .gmem_a_axi_rsp_i(gmem_a_axi_rsp),

      .gmem_b_axi_req_o(gmem_b_axi_req),
      .gmem_b_axi_rsp_i(gmem_b_axi_rsp)
  );

endmodule : dot_product_xheep_wrapper
