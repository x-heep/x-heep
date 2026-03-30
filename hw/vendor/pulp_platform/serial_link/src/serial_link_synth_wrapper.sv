// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Tim Fischer <fischeti@iis.ee.ethz.ch>
//  - Roman Marquart <maroman@iis.ee.ethz.ch>

`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/assign.svh"
`include "register_interface/typedef.svh"

module serial_link_synth_wrapper #(
  parameter type axi_req_t  = logic,
  parameter type axi_rsp_t  = logic,
  parameter type aw_chan_t  = logic,
  parameter type ar_chan_t  = logic,
  parameter type r_chan_t   = logic,
  parameter type w_chan_t   = logic,
  parameter type b_chan_t   = logic,
  parameter type cfg_req_t  = logic,
  parameter type cfg_rsp_t  = logic,
  parameter int NumChannels = 1,
  parameter int NumLanes = 8,
  parameter int MaxClkDiv = 1024
) (
  input  logic                      clk_i,
  input  logic                      rst_ni,
  input  logic                      clk_reg_i,
  input  logic                      rst_reg_ni,
  input  logic                      testmode_i,
  input  axi_req_t                  axi_in_req_i,
  output axi_rsp_t                  axi_in_rsp_o,
  output axi_req_t                  axi_out_req_o,
  input  axi_rsp_t                  axi_out_rsp_i,
  input  cfg_req_t                  cfg_req_i,
  output cfg_rsp_t                  cfg_rsp_o,
  input  logic [NumChannels-1:0]    ddr_rcv_clk_i,
  output logic [NumChannels-1:0]    ddr_rcv_clk_o,
  input  logic [NumChannels-1:0][NumLanes-1:0] ddr_i,
  output logic [NumChannels-1:0][NumLanes-1:0] ddr_o
);

  if (NumChannels > 1) begin : gen_multi_channel_serial_link
    serial_link #(
      .axi_req_t        ( axi_req_t   ),
      .axi_rsp_t        ( axi_rsp_t   ),
      .aw_chan_t        ( aw_chan_t   ),
      .w_chan_t         ( w_chan_t    ),
      .b_chan_t         ( b_chan_t    ),
      .ar_chan_t        ( ar_chan_t   ),
      .r_chan_t         ( r_chan_t    ),
      .cfg_req_t        ( cfg_req_t   ),
      .cfg_rsp_t        ( cfg_rsp_t   ),
      .hw2reg_t         ( serial_link_reg_pkg::serial_link_hw2reg_t ),
      .reg2hw_t         ( serial_link_reg_pkg::serial_link_reg2hw_t ),
      .NumChannels      ( NumChannels ),
      .NumLanes         ( NumLanes    ),
      .MaxClkDiv        ( MaxClkDiv   )
    ) i_serial_link (
      .clk_i          ( clk_i             ),
      .rst_ni         ( rst_ni            ),
      .clk_sl_i       ( clk_i             ),
      .rst_sl_ni      ( rst_ni            ),
      .clk_reg_i      ( clk_reg_i         ),
      .rst_reg_ni     ( rst_reg_ni        ),
      .testmode_i     ( testmode_i        ),
      .axi_in_req_i   ( axi_in_req_i      ),
      .axi_in_rsp_o   ( axi_in_rsp_o      ),
      .axi_out_req_o  ( axi_out_req_o     ),
      .axi_out_rsp_i  ( axi_out_rsp_i     ),
      .cfg_req_i      ( cfg_req_i         ),
      .cfg_rsp_o      ( cfg_rsp_o         ),
      .ddr_rcv_clk_i  ( ddr_rcv_clk_i     ),
      .ddr_rcv_clk_o  ( ddr_rcv_clk_o     ),
      .ddr_i          ( ddr_i             ),
      .ddr_o          ( ddr_o             ),
      .isolated_i     ( '0                ),
      .isolate_o      (                   ),
      .clk_ena_o      (                   ),
      .reset_no       (                   )
    );
  end else begin : gen_single_channel_serial_link
    serial_link #(
      .axi_req_t        ( axi_req_t   ),
      .axi_rsp_t        ( axi_rsp_t   ),
      .aw_chan_t        ( aw_chan_t   ),
      .w_chan_t         ( w_chan_t    ),
      .b_chan_t         ( b_chan_t    ),
      .ar_chan_t        ( ar_chan_t   ),
      .r_chan_t         ( r_chan_t    ),
      .cfg_req_t        ( cfg_req_t   ),
      .cfg_rsp_t        ( cfg_rsp_t   ),
      .hw2reg_t         ( serial_link_single_channel_reg_pkg::serial_link_single_channel_hw2reg_t ),
      .reg2hw_t         ( serial_link_single_channel_reg_pkg::serial_link_single_channel_reg2hw_t ),
      .NumChannels      ( NumChannels ),
      .NumLanes         ( NumLanes    ),
      .MaxClkDiv        ( MaxClkDiv   )
    ) i_serial_link (
      .clk_i          ( clk_i             ),
      .rst_ni         ( rst_ni            ),
      .clk_sl_i       ( clk_i             ),
      .rst_sl_ni      ( rst_ni            ),
      .clk_reg_i      ( clk_reg_i         ),
      .rst_reg_ni     ( rst_reg_ni        ),
      .testmode_i     ( testmode_i        ),
      .axi_in_req_i   ( axi_in_req_i      ),
      .axi_in_rsp_o   ( axi_in_rsp_o      ),
      .axi_out_req_o  ( axi_out_req_o     ),
      .axi_out_rsp_i  ( axi_out_rsp_i     ),
      .cfg_req_i      ( cfg_req_i         ),
      .cfg_rsp_o      ( cfg_rsp_o         ),
      .ddr_rcv_clk_i  ( ddr_rcv_clk_i     ),
      .ddr_rcv_clk_o  ( ddr_rcv_clk_o     ),
      .ddr_i          ( ddr_i             ),
      .ddr_o          ( ddr_o             ),
      .isolated_i     ( '0                ),
      .isolate_o      (                   ),
      .clk_ena_o      (                   ),
      .reset_no       (                   )
    );
  end

endmodule


module serial_link_synth_wrapper_intf #(
  //AXI parameters
  parameter int unsigned AxiAddrWidth = 32,
  parameter int unsigned AxiDataWidth = 64,
  parameter int unsigned AxiIdWidth   = 8,
  parameter int unsigned AxiUserWidth = 8,
  // Regbus parameters
  parameter int unsigned RegAddrWidth = 32,
  parameter int unsigned RegDataWidth = 32,
  // Serial link configuration
  parameter int unsigned NumChannels  = 1,
  parameter int unsigned NumLanes     = 8,
  parameter int unsigned MaxClkDiv    = 1024
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              clk_reg_i,
  input  logic              rst_reg_ni,
  input  logic              testmode_i,
  // axi in
  AXI_BUS.Slave axi_slv_in,
  // axi out
  AXI_BUS.Master axi_mst_out,
  // cfg reg
  REG_BUS.in cfg_reg,
  // link
  output logic [NumChannels*NumLanes-1:0] ddr_o,
  input  logic [NumChannels*NumLanes-1:0] ddr_i,
  output logic [NumChannels-1:0] ddr_rcv_clk_o,
  input  logic [NumChannels-1:0] ddr_rcv_clk_i
);

  localparam int unsigned AxiStrbWidth = AxiDataWidth / 8;
  localparam int unsigned RegStrbWidth = RegDataWidth / 8;

  typedef logic [AxiAddrWidth-1:0]  axi_addr_t;
  typedef logic [AxiIdWidth-1:0]    axi_id_t;
  typedef logic [AxiDataWidth-1:0]  axi_data_t;
  typedef logic [AxiStrbWidth-1:0]  axi_strb_t;
  typedef logic [AxiUserWidth-1:0]  axi_user_t;

  `AXI_TYPEDEF_ALL(axi, axi_addr_t, axi_id_t, axi_data_t, axi_strb_t, axi_user_t)
  axi_req_t  axi_in_req_i,  axi_out_req_o;
  axi_resp_t axi_in_rsp_o, axi_out_rsp_i;

  `AXI_ASSIGN_TO_REQ(axi_in_req_i, axi_slv_in)
  `AXI_ASSIGN_FROM_RESP(axi_slv_in, axi_in_rsp_o)

  `AXI_ASSIGN_FROM_REQ(axi_mst_out, axi_out_req_o)
  `AXI_ASSIGN_TO_RESP(axi_out_rsp_i, axi_mst_out)

  typedef logic [RegAddrWidth-1:0] cfg_addr_t;
  typedef logic [RegDataWidth-1:0] cfg_data_t;
  typedef logic [RegStrbWidth-1:0] cfg_strb_t;

  // Regbus Types
  `REG_BUS_TYPEDEF_ALL(cfg, cfg_addr_t, cfg_data_t, cfg_strb_t)
  cfg_req_t cfg_req_i;
  cfg_rsp_t cfg_rsp_o;

  `REG_BUS_ASSIGN_TO_REQ(cfg_req_i, cfg_reg)
  `REG_BUS_ASSIGN_FROM_RSP(cfg_reg, cfg_rsp_o)

  serial_link_synth_wrapper #(
    .axi_req_t(axi_req_t),
    .axi_rsp_t(axi_resp_t),
    .aw_chan_t(axi_aw_chan_t),
    .ar_chan_t(axi_ar_chan_t),
    .r_chan_t (axi_r_chan_t),
    .w_chan_t (axi_w_chan_t),
    .b_chan_t (axi_b_chan_t),
    .cfg_req_t(cfg_req_t),
    .cfg_rsp_t(cfg_rsp_t),
    .NumChannels(NumChannels),
    .NumLanes   (NumLanes),
    .MaxClkDiv  (MaxClkDiv)
  ) i_serial_link_synth_wrapper (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .clk_reg_i(clk_reg_i),
    .rst_reg_ni(rst_reg_ni),
    .testmode_i(testmode_i),
    .axi_in_req_i(axi_in_req_i),
    .axi_in_rsp_o(axi_in_rsp_o),
    .axi_out_req_o(axi_out_req_o),
    .axi_out_rsp_i(axi_out_rsp_i),
    .cfg_req_i(cfg_req_i),
    .cfg_rsp_o(cfg_rsp_o),
    .ddr_o(ddr_o),
    .ddr_i(ddr_i),
    .ddr_rcv_clk_o(ddr_rcv_clk_o),
    .ddr_rcv_clk_i(ddr_rcv_clk_i)
);

endmodule
