// Copyright (C) 2026 EPFL.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: xheep_obi_to_axi_bridge.sv
// Author: Mohammad Hossein Nikkhah
// Description: Wraps PULP's OBI-to-AXI bridge for X-HEEP's flat OBI external interface.


module xheep_obi_to_axi_bridge
  import xheep_obi_to_axi_bridge_pkg::*;
#(
    // X-HEEP's external OBI data bus is currently 32-bit. The bridge address
    // width is usually wider than X-HEEP's flat 32-bit address because the VPK180
    // DDR NoC lives in a 64-bit physical address map.
    parameter int unsigned ObiAddrWidth = VPK180_DDR_AXI_ADDR_WIDTH,
    parameter int unsigned ObiDataWidth = 32,
    parameter int unsigned ObiIdWidth = 1,
    parameter int unsigned ObiRspUserWidth = 1,

    parameter bit AxiLite = 1'b0,
    parameter int unsigned AxiAddrWidth = VPK180_DDR_AXI_ADDR_WIDTH,
    parameter int unsigned AxiDataWidth = VPK180_DDR_AXI_DATA_WIDTH,
    parameter int unsigned AxiUserWidth = VPK180_DDR_AXI_USER_WIDTH,
    parameter int unsigned AxiBurstType = axi_pkg::BURST_INCR,
    parameter int unsigned MaxRequests = 2,

    // AXI request/response structs are parameterized so the top-level wrapper
    // can pass the exact type matching the PS wizard exported AXI port.
    parameter type axi_req_t = vpk180_ddr_axi_req_t,
    parameter type axi_rsp_t = vpk180_ddr_axi_rsp_t
) (
    input logic clk_i,
    input logic rst_ni,

    input  xheep_obi_pkg::xheep_obi_req_t obi_req_i,
    output xheep_obi_pkg::xheep_obi_rsp_t obi_resp_o,

    output axi_req_t axi_req_o,
    input  axi_rsp_t axi_rsp_i
);

  typedef logic [ObiAddrWidth-1:0] pulp_obi_addr_t;
  typedef logic [ObiDataWidth-1:0] pulp_obi_data_t;
  typedef logic [ObiDataWidth/8-1:0] pulp_obi_be_t;
  typedef logic [ObiIdWidth-1:0] pulp_obi_id_t;
  typedef logic [ObiRspUserWidth-1:0] pulp_obi_ruser_t;

  // Optional fields are present in the type so it matches the shape expected by
  // obi_to_axi. The configuration below disables their protocol use.
  typedef struct packed {
    obi_pkg::prot_t    prot;
    obi_pkg::atop_t    atop;
    obi_pkg::memtype_t memtype;
  } pulp_obi_a_optional_t;

  typedef struct packed {
    logic            exokay;
    pulp_obi_ruser_t ruser;
  } pulp_obi_r_optional_t;

  typedef struct packed {
    pulp_obi_addr_t       addr;
    logic                 we;
    pulp_obi_be_t         be;
    pulp_obi_data_t       wdata;
    pulp_obi_id_t         aid;
    pulp_obi_a_optional_t a_optional;
  } pulp_obi_a_chan_t;

  typedef struct packed {
    pulp_obi_data_t       rdata;
    pulp_obi_id_t         rid;
    logic                 err;
    pulp_obi_r_optional_t r_optional;
  } pulp_obi_r_chan_t;

  typedef struct packed {
    pulp_obi_a_chan_t a;
    logic             req;
  } pulp_obi_req_t;

  typedef struct packed {
    pulp_obi_r_chan_t r;
    logic             gnt;
    logic             rvalid;
  } pulp_obi_rsp_t;

  localparam obi_pkg::obi_optional_cfg_t ObiToAxiOptionalCfg = '{
      UseAtop: 1'b0,
      UseMemtype: 1'b0,
      UseProt: 1'b0,
      UseDbg: 1'b0,
      AUserWidth: 0,
      WUserWidth: 0,
      RUserWidth: ObiRspUserWidth,
      MidWidth: 0,
      AChkWidth: 0,
      RChkWidth: 0
  };

  localparam obi_pkg::obi_cfg_t ObiToAxiCfg = '{
      UseRReady: 1'b0,
      CombGnt: 1'b0,
      AddrWidth: ObiAddrWidth,
      DataWidth: ObiDataWidth,
      IdWidth: ObiIdWidth,
      Integrity: 1'b0,
      BeFull: 1'b1,
      OptionalCfg: ObiToAxiOptionalCfg
  };

  pulp_obi_req_t pulp_obi_req;
  pulp_obi_rsp_t pulp_obi_rsp;

  logic [AxiUserWidth-1:0] axi_user;

  assign axi_user = '0;

  always_comb begin
    pulp_obi_req              = '0;

    pulp_obi_req.req          = obi_req_i.req;
    pulp_obi_req.a.addr       = pulp_obi_addr_t'(obi_req_i.addr);
    pulp_obi_req.a.we         = obi_req_i.we;
    pulp_obi_req.a.be         = pulp_obi_be_t'(obi_req_i.be);
    pulp_obi_req.a.wdata      = pulp_obi_data_t'(obi_req_i.wdata);
    pulp_obi_req.a.aid        = '0;

    pulp_obi_req.a.a_optional = '0;
  end

  assign obi_resp_o.gnt    = pulp_obi_rsp.gnt;
  assign obi_resp_o.rvalid = pulp_obi_rsp.rvalid;
  assign obi_resp_o.rdata  = pulp_obi_rsp.r.rdata[31:0];

  obi_to_axi #(
      .ObiCfg      (ObiToAxiCfg),
      .obi_req_t   (pulp_obi_req_t),
      .obi_rsp_t   (pulp_obi_rsp_t),
      .AxiLite     (AxiLite),
      .AxiAddrWidth(AxiAddrWidth),
      .AxiDataWidth(AxiDataWidth),
      .AxiUserWidth(AxiUserWidth),
      .AxiBurstType(AxiBurstType),
      .axi_req_t   (axi_req_t),
      .axi_rsp_t   (axi_rsp_t),
      .MaxRequests (MaxRequests)
  ) obi_to_axi_i (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .obi_req_i(pulp_obi_req),
      .obi_rsp_o(pulp_obi_rsp),
      .user_i   (axi_user),

      .axi_req_o(axi_req_o),
      .axi_rsp_i(axi_rsp_i),

      .axi_rsp_channel_sel(),
      .axi_rsp_b_user_o   (),
      .axi_rsp_r_user_o   (),
      .obi_rsp_user_i     ('0)
  );

  // pragma translate_off
`ifndef SYNTHESIS
  initial begin : gen_parameter_assertions
    assert (ObiDataWidth == 32)
    else $fatal(1, "xheep_obi_to_axi_bridge expects the current flat X-HEEP OBI data width.");

    assert (ObiAddrWidth <= AxiAddrWidth)
    else $fatal(1, "OBI address width must not exceed AXI address width.");

    assert (AxiDataWidth >= ObiDataWidth && AxiDataWidth % ObiDataWidth == 0)
    else $fatal(1, "AXI data width must be an integer multiple of OBI data width.");
  end
`endif
  // pragma translate_on

endmodule : xheep_obi_to_axi_bridge
