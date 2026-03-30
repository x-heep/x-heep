// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

module quadrilatero_register_lsu_controller #(
    parameter N_SLOTS = 3
) (
    input logic clk_i,
    input logic rst_ni,

    output logic issue_queue_full_o,
    input logic dispatch_i,
    input quadrilatero_pkg::lsu_instr_t dispatched_instr_i,
    input quadrilatero_pkg::lsu_conf_t csr_config_i,  // csr matrix configuration 

    // To Register Loader
    input logic busy_i,  // Load Unit busy
    output logic start_o,  // WL will start executing new instruction
    output quadrilatero_pkg::lsu_instr_t issued_instr_o,  // issued instruction
    output quadrilatero_pkg::lsu_conf_t issued_instr_conf_o  // issued instruction configuration
);

  localparam int unsigned USAGE = N_SLOTS > 1 ? $clog2(N_SLOTS)-1 : 0;
  logic issue_queue_empty;
  logic start_load;
  logic issue_queue_almost_full;
  logic issue_queue_full;
  logic[USAGE:0] issue_queue_usage;

  quadrilatero_pkg::lsu_instr_t issued_instr_ff;  // issued instruction
  quadrilatero_pkg::lsu_instr_t fifo_data_out;
  quadrilatero_pkg::lsu_conf_t issued_instr_conf_ff;  // issued instruction configuration

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      issued_instr_ff <= '0;
      issued_instr_conf_ff <= '0;
      start_o <= '0;
    end else begin
      start_o <= '0;
      if (start_load) begin
        issued_instr_ff <= fifo_data_out;
        issued_instr_conf_ff <= csr_config_i;
        start_o <= '1;
      end
    end

  end

  assign issued_instr_conf_o = issued_instr_conf_ff;
  assign issued_instr_o = issued_instr_ff;

  logic pop_instr;
  assign pop_instr  = !busy_i && !issue_queue_empty && !start_o;

  assign start_load = pop_instr;

  assign issue_queue_almost_full = (issue_queue_usage == N_SLOTS-1);
  assign issue_queue_full_o = issue_queue_full | issue_queue_almost_full;

  fifo_v3 #(
      .FALL_THROUGH(0),
      .DATA_WIDTH  (32),
      .DEPTH       (N_SLOTS),
      .dtype       (quadrilatero_pkg::lsu_instr_t)
  ) issue_queue_inst (
      .clk_i,
      .rst_ni,

      .flush_i   (1'b0),
      .testmode_i(1'b0),

      .usage_o(issue_queue_usage),
      .full_o (issue_queue_full),
      .empty_o(issue_queue_empty),

      .data_i(dispatched_instr_i),  // data to push into the queue
      .push_i(dispatch_i),          // data is valid and can be pushed to the queue
      .data_o(fifo_data_out),       // output data
      .pop_i (pop_instr)            // pop head from queue
  );


endmodule
