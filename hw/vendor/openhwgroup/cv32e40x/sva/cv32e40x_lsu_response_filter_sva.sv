// Copyright 2021 Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License");
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Authors:        Halfdan Bechmann - Halfdan Bechmann@silabs.com             //
//                                                                            //
// Description:    Response Filter Assertions                                 //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_lsu_response_filter_sva
  import cv32e40x_pkg::*;
  import uvm_pkg::*;
  #(parameter int unsigned DEPTH = 2)
  (input logic                       clk,
   input logic                       rst_n,

   input logic                       valid_i,

   input logic                       busy_o,
   input logic                       core_trans_accepted,
   input logic                       bus_trans_accepted,
   input logic [1:0]                 core_cnt_q,
   input logic [$clog2(DEPTH+1)-1:0] bus_cnt_q
   );

  a_no_lost_transfers :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (1'b1) |-> (core_cnt_q <= bus_cnt_q))
      else `uvm_error("Response Filter", "Lost transfer(s): More outstanding transfers on the core side than on the bus side.");

  a_busy_when_outstanding :
    assert property (@(posedge clk) disable iff (!rst_n)
                     ((core_cnt_q != 0) || (bus_cnt_q != 0) || valid_i) |-> busy_o)
      else `uvm_error("Response Filter", "Has outstanding (or pending) transfer(s) but busy_o is not set.");

  a_no_core_cnt_overflow :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (1'b1) |-> (core_cnt_q <= DEPTH))
      else `uvm_error("Response Filter", "Core side outstanding transfers counter overflow");

  a_no_bus_cnt_overflow :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (1'b1) |-> (bus_cnt_q <= DEPTH))
      else `uvm_error("Response Filter", "Bus side outstanding transfers counter overflow");

  a_no_bus_cnt_underflow :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (bus_cnt_q == 0) |=> (bus_cnt_q == 0) || (bus_cnt_q == 1))
      else `uvm_error("Response Filter", "Bus side transfer counter underflow");

  a_no_core_cnt_underflow :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (core_cnt_q == 0) |=> (core_cnt_q == 0) || (core_cnt_q == 1))
      else `uvm_error("Response Filter", "Core side transfer counter underflow");

  a_transfers_accepted_at_the_same_time :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (1'b1) |-> (core_trans_accepted == bus_trans_accepted))
      else `uvm_error("Response Filter", "Mismatch between accepted transfers on core side and bus side");

endmodule : cv32e40x_lsu_response_filter_sva

