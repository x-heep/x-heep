// Copyright (C) 2026 EPFL.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: xheep_obi_to_axi_bridge_pkg.sv
// Author: Mohammad Hossein Nikkhah
// Description: Defines the default VPK180 DDR AXI widths and typedefs used by the bridge.

package xheep_obi_to_axi_bridge_pkg;

  `include "axi/typedef.svh"

  // Default VPK180 AXI type view. Override the wrapper type parameters if the
  // exported PS/NoC AXI port uses different widths.
  localparam int unsigned VPK180_DDR_AXI_ADDR_WIDTH = 64;
  localparam int unsigned VPK180_DDR_AXI_DATA_WIDTH = 128;
  localparam int unsigned VPK180_DDR_AXI_ID_WIDTH = 1;
  localparam int unsigned VPK180_DDR_AXI_USER_WIDTH = 1;

  typedef logic [VPK180_DDR_AXI_ADDR_WIDTH-1:0] vpk180_ddr_axi_addr_t;
  typedef logic [VPK180_DDR_AXI_DATA_WIDTH-1:0] vpk180_ddr_axi_data_t;
  typedef logic [VPK180_DDR_AXI_DATA_WIDTH/8-1:0] vpk180_ddr_axi_strb_t;
  typedef logic [VPK180_DDR_AXI_ID_WIDTH-1:0] vpk180_ddr_axi_id_t;
  typedef logic [VPK180_DDR_AXI_USER_WIDTH-1:0] vpk180_ddr_axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(vpk180_ddr_axi_aw_t, vpk180_ddr_axi_addr_t, vpk180_ddr_axi_id_t,
                         vpk180_ddr_axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T(vpk180_ddr_axi_w_t, vpk180_ddr_axi_data_t, vpk180_ddr_axi_strb_t,
                        vpk180_ddr_axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(vpk180_ddr_axi_b_t, vpk180_ddr_axi_id_t, vpk180_ddr_axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(vpk180_ddr_axi_ar_t, vpk180_ddr_axi_addr_t, vpk180_ddr_axi_id_t,
                         vpk180_ddr_axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(vpk180_ddr_axi_r_t, vpk180_ddr_axi_data_t, vpk180_ddr_axi_id_t,
                        vpk180_ddr_axi_user_t)

  `AXI_TYPEDEF_REQ_T(vpk180_ddr_axi_req_t, vpk180_ddr_axi_aw_t, vpk180_ddr_axi_w_t,
                     vpk180_ddr_axi_ar_t)
  `AXI_TYPEDEF_RESP_T(vpk180_ddr_axi_rsp_t, vpk180_ddr_axi_b_t, vpk180_ddr_axi_r_t)

endpackage : xheep_obi_to_axi_bridge_pkg
