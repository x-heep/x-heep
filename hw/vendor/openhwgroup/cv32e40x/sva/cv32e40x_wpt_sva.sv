// Copyright 2022 Silicon Labs, Inc.
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
// Authors:        Oystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Description:    WPT assertions                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_wpt_sva import cv32e40x_pkg::*; import uvm_pkg::*;
  (
   input logic        clk,
   input logic        rst_n,

   input wpt_state_e  state_q,
   input mpu_state_e  mpu_state

   );

  // WPT and MPU cannot both wait for a response at the sime time
  // If they could both wait for a response, then they would need separate counters for the
  // "one-transaction-left" inputs - otherwise they may share the counter.
  a_wpt_mpu_cnt_share:
  assert property (@(posedge clk) disable iff (!rst_n)
                  ((state_q == WPT_MATCH_WAIT) || (mpu_state == MPU_RE_ERR_WAIT) || (mpu_state == MPU_WR_ERR_WAIT))
                  |->
                  (state_q == WPT_MATCH_WAIT) != ((mpu_state == MPU_RE_ERR_WAIT) || (mpu_state == MPU_WR_ERR_WAIT)))
    else `uvm_error("load_store_unit", "WPT and MPU both wait for responses")
endmodule

