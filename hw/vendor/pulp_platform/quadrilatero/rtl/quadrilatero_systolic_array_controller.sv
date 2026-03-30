// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

module quadrilatero_systolic_array_controller #(
    parameter N_SLOTS = 3,
    parameter DATA_WIDTH = 32
) (
    input logic clk_i,
    input logic rst_ni,

    output logic issue_queue_full_o,
    input logic dispatch_i,
    input quadrilatero_pkg::sa_instr_t dispatched_instr_i,

    // To Systolic Array
    input logic wl_ready_i,  // WL stage is ready for new instruction
    output logic start_o,  // WL will start executing new instruction
    output quadrilatero_pkg::sa_instr_t issued_instr_o  // issued instruction
);
  localparam int unsigned USAGE_DEPTH = (N_SLOTS > 1) ? $clog2(N_SLOTS) : 1;
  logic issue_queue_empty;
  logic issue_queue_full;
  logic issue_queue_almost_full;
  logic pop_instr;
  logic [USAGE_DEPTH-1:0] issue_queue_inst_usage;
  assign pop_instr = wl_ready_i & !issue_queue_empty;

  assign start_o   = pop_instr;


  assign issue_queue_almost_full = issue_queue_inst_usage == (N_SLOTS[USAGE_DEPTH:0] - 1);
  assign issue_queue_full_o = issue_queue_almost_full | issue_queue_full;
  
  fifo_v3 #(
      .FALL_THROUGH(0),
      .DATA_WIDTH  (DATA_WIDTH),
      .DEPTH       (N_SLOTS),
      .dtype       (quadrilatero_pkg::sa_instr_t)
  ) issue_queue_inst (
      .clk_i,
      .rst_ni,

      .flush_i   (1'b0),
      .testmode_i(1'b0),

      .usage_o(issue_queue_inst_usage),
      .full_o (issue_queue_full),
      .empty_o(issue_queue_empty),

      .data_i(dispatched_instr_i),  // data to push into the queue
      .push_i(dispatch_i),          // data is valid and can be pushed to the queue
      .data_o(issued_instr_o),      // output data
      .pop_i (pop_instr)            // pop head from queue
  );


endmodule
