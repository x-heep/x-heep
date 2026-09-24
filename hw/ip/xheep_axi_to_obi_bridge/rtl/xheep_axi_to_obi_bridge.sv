// Copyright (C) 2026 EPFL.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: xheep_axi_to_obi_bridge.sv
// Description: Wraps PULP's AXI-to-OBI bridge for X-HEEP's flat OBI external
// interface. Mirror image of xheep_obi_to_axi_bridge: here the AXI side is
// the master driving a memory-mapped read/write region, and the OBI side is
// what plugs into one of core_v_mini_mcu's ext_xbar_master ports.

module xheep_axi_to_obi_bridge #(
    // X-HEEP's external OBI bus is flat 32-bit; the AXI side is typically
    // wider (e.g. a 64-bit HLS-generated m_axi master port).
    parameter int unsigned ObiIdWidth = 1,

    parameter int unsigned AxiAddrWidth = 64,
    parameter int unsigned AxiDataWidth = 32,
    parameter int unsigned AxiIdWidth   = 1,
    parameter int unsigned AxiUserWidth = 1,
    parameter int unsigned MaxTrans     = 2,

    // AXI request/response structs are parameterized so the caller can pass
    // the exact type matching its generated AXI master port.
    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic,

    // OBI request/response structs, defaulting to X-HEEP's flat OBI type.
    parameter type obi_req_t = xheep_obi_pkg::xheep_obi_req_t,
    parameter type obi_rsp_t = xheep_obi_pkg::xheep_obi_rsp_t
) (
    input logic clk_i,
    input logic rst_ni,

    input  axi_req_t axi_req_i,
    output axi_rsp_t axi_rsp_o,

    output obi_req_t obi_req_o,
    input  obi_rsp_t obi_rsp_i
);

  localparam int unsigned ObiAddrWidth = 32;
  localparam int unsigned ObiDataWidth = 32;

  typedef logic [ObiAddrWidth-1:0] pulp_obi_addr_t;
  typedef logic [ObiDataWidth-1:0] pulp_obi_data_t;
  typedef logic [ObiDataWidth/8-1:0] pulp_obi_be_t;
  typedef logic [ObiIdWidth-1:0] pulp_obi_id_t;

  // Optional fields are present in the type so it matches the shape expected
  // by axi_to_obi. The configuration below disables their protocol use.
  typedef struct packed {
    obi_pkg::prot_t    prot;
    obi_pkg::atop_t    atop;
    obi_pkg::memtype_t memtype;
  } pulp_obi_a_optional_t;

  typedef struct packed {logic exokay;} pulp_obi_r_optional_t;

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

  localparam obi_pkg::obi_optional_cfg_t ObiOptCfg = '{
      UseAtop: 1'b0,
      UseMemtype: 1'b0,
      UseProt: 1'b0,
      UseDbg: 1'b0,
      AUserWidth: 0,
      WUserWidth: 0,
      RUserWidth: 0,
      MidWidth: 0,
      AChkWidth: 0,
      RChkWidth: 0
  };

  localparam obi_pkg::obi_cfg_t ObiCfg = '{
      UseRReady: 1'b0,
      CombGnt: 1'b0,
      AddrWidth: ObiAddrWidth,
      DataWidth: ObiDataWidth,
      IdWidth: ObiIdWidth,
      Integrity: 1'b0,
      BeFull: 1'b1,
      OptionalCfg: ObiOptCfg
  };

  pulp_obi_req_t pulp_obi_req;
  pulp_obi_rsp_t pulp_obi_rsp;

  axi_to_obi #(
      .ObiCfg      (ObiCfg),
      .obi_req_t   (pulp_obi_req_t),
      .obi_rsp_t   (pulp_obi_rsp_t),
      .obi_a_chan_t(pulp_obi_a_chan_t),
      .obi_r_chan_t(pulp_obi_r_chan_t),
      .AxiAddrWidth(AxiAddrWidth),
      .AxiDataWidth(AxiDataWidth),
      .AxiIdWidth  (AxiIdWidth),
      .AxiUserWidth(AxiUserWidth),
      .MaxTrans    (MaxTrans),
      .axi_req_t   (axi_req_t),
      .axi_rsp_t   (axi_rsp_t)
  ) axi_to_obi_i (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .testmode_i('0),

      .axi_req_i(axi_req_i),
      .axi_rsp_o(axi_rsp_o),

      .obi_req_o(pulp_obi_req),
      .obi_rsp_i(pulp_obi_rsp),

      .req_aw_id_o  (),
      .req_aw_user_o(),
      .req_w_user_o (),

      .req_write_aid_i  ('0),
      .req_write_auser_i('0),
      .req_write_wuser_i('0),

      .req_ar_id_o  (),
      .req_ar_user_o(),

      .req_read_aid_i  ('0),
      .req_read_auser_i('0),

      .rsp_write_aw_user_o  (),
      .rsp_write_w_user_o   (),
      .rsp_write_bank_strb_o(),
      .rsp_write_rid_o      (),
      .rsp_write_ruser_o    (),
      .rsp_write_last_o     (),
      .rsp_write_hs_o       (),
      .rsp_b_user_i         ('0),

      .rsp_read_ar_user_o    (),
      .rsp_read_size_enable_o(),
      .rsp_read_rid_o        (),
      .rsp_read_ruser_o      (),
      .rsp_r_user_i          ('0)
  );

  // Nested PULP a/r-channel struct -> X-HEEP's flat OBI struct.
  assign obi_req_o.req             = pulp_obi_req.req;
  assign obi_req_o.we              = pulp_obi_req.a.we;
  assign obi_req_o.be              = pulp_obi_req.a.be;
  assign obi_req_o.addr            = 32'(pulp_obi_req.a.addr);
  assign obi_req_o.wdata           = pulp_obi_req.a.wdata;

  assign pulp_obi_rsp.gnt          = obi_rsp_i.gnt;
  assign pulp_obi_rsp.rvalid       = obi_rsp_i.rvalid;
  assign pulp_obi_rsp.r.rdata      = pulp_obi_data_t'(obi_rsp_i.rdata);
  assign pulp_obi_rsp.r.rid        = '0;
  assign pulp_obi_rsp.r.err        = 1'b0;
  assign pulp_obi_rsp.r.r_optional = '0;

  // pragma translate_off
`ifndef SYNTHESIS
  initial begin : gen_parameter_assertions
    assert (AxiDataWidth == ObiDataWidth)
    else
      $fatal(
          1, "xheep_axi_to_obi_bridge expects matching AXI/OBI data widths (no bank splitting)."
      );
  end
`endif
  // pragma translate_on

endmodule : xheep_axi_to_obi_bridge
