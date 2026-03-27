// Copyright 2021 Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License").
//
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
//
// You may obtain a copy of the License at:
//
//     https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof distributed under the License
// is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
//
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Halfdan Bechmann  -  halfdan.bechmann@silabs.com           //
//                                                                            //
// Design Name:    Response Filter                                            //
// Project Name:   CV32E40X                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Response filter for the LSU. Used to return rvalid early   //
//                 for bufferable transfers.                                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_lsu_response_filter
  import cv32e40x_pkg::*;
  #(parameter int unsigned DEPTH = 2)
  (
   // clock and reset
   input logic            clk,
   input logic            rst_n,

   // inputs
   input  logic           valid_i,
   input  obi_data_req_t  trans_i,
   input  logic           ready_i,

   input  logic           resp_valid_i,
   input  obi_data_resp_t resp_i,

   // outputs
   output logic           valid_o,
   output obi_data_req_t  trans_o,
   output logic           ready_o,

   output logic           busy_o,
   output logic           bus_busy_o,      // There are outstanding transactions on the bus side.
   output logic           resp_valid_o,
   output obi_data_resp_t resp_o, // Todo: This also carries the obi error field. Could replace by data_resp_t

   // Todo: This error signal could be merged with mpu_status_e, and be signaled via the resp_o above (if replaced by data_resp_t).
   //       This would make the error flow all the way through the MPU and not bypass the MPU as it does now.
   output logic [1:0]     err_o  // bit0: flag for error, bit1: type (1 for store, 0 for load)
   );

  localparam CNT_WIDTH = $clog2(DEPTH+1);

  // Core side transfer counter
  logic [CNT_WIDTH-1:0]  bus_cnt_q;
  logic [CNT_WIDTH-1:0]  bus_next_cnt;
  logic                  bus_count_up;
  logic                  bus_count_down;

  // Bus side transfer counter
  logic [CNT_WIDTH-1:0]  core_cnt_q;
  logic [CNT_WIDTH-1:0]  core_next_cnt;
  logic                  core_count_up;
  logic                  core_count_down;

  logic                  core_trans_accepted;
  logic                  bus_trans_accepted;

  logic                  bus_resp_is_bufferable;
  logic                  core_resp_is_bufferable;

  // Shift register containing bufferable cofiguration of outstanding transfers
  outstanding_t [DEPTH:0]        outstanding_q; // Using 1-DEPTH entries for outstanding xfers, index 0 is tied low
  outstanding_t [DEPTH:0]        outstanding_next;

  assign busy_o              = ( bus_cnt_q != '0) || valid_i;
  assign bus_busy_o          = ( bus_cnt_q != '0);

  // The two trans valid signals will always have the same value as they are gated with the same condition
  assign core_trans_accepted = ready_o && valid_i; // Transfer accepted on the core side of the response filter
  assign bus_trans_accepted  = ready_i && valid_o; // Transfer accepted on the bus side of the response filter

  // Bufferable configuration of the oldest outstanding transfer
  assign bus_resp_is_bufferable = outstanding_q[bus_cnt_q].bufferable;

  // Bufferable configuration of the oldest outstanding transfer seen from the LSU control logic
  assign core_resp_is_bufferable = outstanding_q[core_cnt_q].bufferable;

  always_comb begin
    outstanding_next = outstanding_q;

    if (bus_trans_accepted) begin
      // Shift in bufferable bit and type of accepted transfer
      outstanding_next[DEPTH:1]    = outstanding_q[DEPTH-1:0];
      outstanding_next[1]          = outstanding_t'{bufferable: trans_i.memtype[0], store: trans_i.we};
      outstanding_next[0]          = '0; // Tie off unused index
    end

  end

  ///////////////////////////////////////////
  // Counter
  ///////////////////////////////////////////

  assign core_count_up   = core_trans_accepted;
  assign core_count_down = resp_valid_o;

  assign bus_count_up    = bus_trans_accepted;
  assign bus_count_down  = resp_valid_i;

  always_comb begin
    core_next_cnt = core_cnt_q;
    if (core_count_up) begin
      core_next_cnt++;
    end
    if (core_count_down) begin
      core_next_cnt--;
    end

    bus_next_cnt = bus_cnt_q;
    if (bus_count_up) begin
      bus_next_cnt++;
    end
    if (bus_count_down) begin
      bus_next_cnt--;
    end
  end

  ///////////////////////////////////////////
  // Registers
  ///////////////////////////////////////////

  always_ff @(posedge clk, negedge rst_n) begin
    if(rst_n == 1'b0)  begin
      bus_cnt_q                <= '0;
      core_cnt_q               <= '0;
      outstanding_q <= '0;
    end else begin
      bus_cnt_q                <= bus_next_cnt;
      core_cnt_q               <= core_next_cnt;
      outstanding_q <= outstanding_next;
    end
  end

  ///////////////////////////////////////////
  // Filtering
  ///////////////////////////////////////////

  // Blocking transfers when outstanding queue is full to avoid bus_cnt_q overflow
  assign ready_o      = ready_i && (bus_cnt_q < DEPTH);
  assign valid_o      = valid_i && (bus_cnt_q < DEPTH);

  // Response Mux
  // If the oldest outstanding transaction on the bus side is bufferable,
  // response valid will be signalled if the oldest outstanding transaction on the core side is bufferable.
  // If the oldest outstanding transfer is non-bufferable the valid response from the bus will be passed through.
  assign resp_valid_o = (bus_resp_is_bufferable) ? core_resp_is_bufferable : resp_valid_i;
  assign trans_o      = trans_i;

  assign err_o[0] = resp_valid_i && resp_i.err;
  assign err_o[1] = outstanding_q[bus_cnt_q].store;

  // bus_resp goes straight through
  assign resp_o = resp_i;

endmodule
