// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Noah Huetter <huettern@iis.ee.ethz.ch>

/// An AXI4 stream interface.
interface AXIS_BUS #(
    parameter int unsigned AXIS_DATA_WIDTH = 0,
    parameter int unsigned AXIS_ID_WIDTH = 0,
    parameter int unsigned AXIS_DEST_WIDTH = 0,
    parameter int unsigned AXIS_USER_WIDTH = 0,
    parameter int unsigned AXIS_READY_WIDTH = 0,
    parameter int unsigned AXIS_LAST_WIDTH = 0
);
  localparam int unsigned AXIS_STRB_WIDTH = AXIS_DATA_WIDTH / 8;
  localparam int unsigned AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH / 8;

  typedef logic [AXIS_DATA_WIDTH-1:0] tdata_t;
  typedef logic [AXIS_STRB_WIDTH-1:0] tstrb_t;
  typedef logic [AXIS_KEEP_WIDTH-1:0] tkeep_t;
  typedef logic [AXIS_ID_WIDTH-1:0] tid_t;
  typedef logic [AXIS_DEST_WIDTH-1:0] tdest_t;
  typedef logic [AXIS_USER_WIDTH-1:0] tuser_t;
  typedef logic [AXIS_READY_WIDTH-1:0] tready_t;
  typedef logic [AXIS_LAST_WIDTH-1:0] tlast_t;

  // Signal list
  logic    tvalid;
  tready_t tready;
  tdata_t  tdata;
  tstrb_t  tstrb;
  tkeep_t  tkeep;
  tlast_t  tlast;
  tid_t    tid;
  tdest_t  tdest;
  tuser_t  tuser;

  // Module ports
  modport Master(output tvalid, tdata, tstrb, tkeep, tlast, tid, tdest, tuser, input tready);
  modport Slave(input tvalid, tdata, tstrb, tkeep, tlast, tid, tdest, tuser, output tready);

endinterface

/// A clocked AXI4 stream interface for use in design verification.
interface AXIS_BUS_DV #(
    parameter int unsigned AXIS_DATA_WIDTH = 0,
    parameter int unsigned AXIS_ID_WIDTH = 0,
    parameter int unsigned AXIS_DEST_WIDTH = 0,
    parameter int unsigned AXIS_USER_WIDTH = 0,
    parameter int unsigned AXIS_READY_WIDTH = 0,
    parameter int unsigned AXIS_LAST_WIDTH = 0
) (
    input logic clk_i
);
  localparam int unsigned AXIS_STRB_WIDTH = AXIS_DATA_WIDTH / 8;
  localparam int unsigned AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH / 8;

  typedef logic [AXIS_DATA_WIDTH-1:0] tdata_t;
  typedef logic [AXIS_STRB_WIDTH-1:0] tstrb_t;
  typedef logic [AXIS_KEEP_WIDTH-1:0] tkeep_t;
  typedef logic [AXIS_ID_WIDTH-1:0] tid_t;
  typedef logic [AXIS_DEST_WIDTH-1:0] tdest_t;
  typedef logic [AXIS_USER_WIDTH-1:0] tuser_t;
  typedef logic [AXIS_READY_WIDTH-1:0] tready_t;
  typedef logic [AXIS_LAST_WIDTH-1:0] tlast_t;

  // Signal list
  logic    tvalid;
  tready_t tready;
  tdata_t  tdata;
  tstrb_t  tstrb;
  tkeep_t  tkeep;
  tlast_t  tlast;
  tid_t    tid;
  tdest_t  tdest;
  tuser_t  tuser;

  // Module ports
  modport Master(output tvalid, tdata, tstrb, tkeep, tlast, tid, tdest, tuser, input tready);
  modport Slave(input tvalid, tdata, tstrb, tkeep, tlast, tid, tdest, tuser, output tready);
  modport Monitor(input tvalid, tready, tdata, tstrb, tkeep, tlast, tid, tdest, tuser);

  // pragma translate_off
`ifndef VERILATOR
  // Single-Channel Assertions: Signals including valid must not change between valid and handshake.
  assert property (@(posedge clk_i) (tvalid && !tready |=> $stable(tdata)));
  assert property (@(posedge clk_i) (tvalid && !tready |=> $stable(tstrb)));
  assert property (@(posedge clk_i) (tvalid && !tready |=> $stable(tkeep)));
  assert property (@(posedge clk_i) (tvalid && !tready |=> $stable(tlast)));
  assert property (@(posedge clk_i) (tvalid && !tready |=> $stable(tid)));
  assert property (@(posedge clk_i) (tvalid && !tready |=> $stable(tdest)));
  assert property (@(posedge clk_i) (tvalid && !tready |=> $stable(tuser)));
  assert property (@(posedge clk_i) (tvalid && !tready |=> tvalid));
`endif
  // pragma translate_on

endinterface
