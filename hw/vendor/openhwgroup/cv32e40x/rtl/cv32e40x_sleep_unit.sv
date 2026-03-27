// Copyright 2020 Silicon Labs, Inc.
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
// Engineer:       Arjan Bink - arjan.bink@silabs.com                         //
//                                                                            //
// Design Name:    Sleep Unit                                                 //
// Project Name:   CV32E40P                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Sleep unit containing the instantiated clock gate which    //
//                 provides the gated clock (clk_gated_o) for the rest        //
//                 of the design.                                             //
//                                                                            //
//                 The clock is gated for the following scenarios:            //
//                                                                            //
//                 - While waiting for fetch to become enabled                //
//                 - While blocked on a WFI                                   //
//                                                                            //
//                 Sleep is signaled via core_sleep_o:                        //
//                                                                            //
//                 - During a WFI (except in debug)                           //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_sleep_unit import cv32e40x_pkg::*;
#(
  parameter LIB = 0
)
(
  // Clock, reset interface
  input  logic        clk_ungated_i,            // Free running clock
  input  logic        rst_n,
  output logic        clk_gated_o,              // Gated clock
  input  logic        scan_cg_en_i,             // Enable all clock gates for testing

  // Core sleep
  output logic        core_sleep_o,

  // Fetch enable
  input  logic        fetch_enable_i,
  output logic        fetch_enable_o,

  // Core status
  input  logic        if_busy_i,
  input  logic        lsu_busy_i,

  input  ctrl_fsm_t   ctrl_fsm_i
);

  logic              fetch_enable_q;            // Sticky version of fetch_enable_i
  logic              fetch_enable_d;
  logic              core_busy_q;               // Is core still busy (and requires a clock) with what needs to finish before entering sleep?
  logic              core_busy_d;
  logic              clock_en;                  // Final clock enable

  //////////////////////////////////////////////////////////////////////////////
  // Sleep FSM
  //////////////////////////////////////////////////////////////////////////////

  // Make sticky version of fetch_enable_i
  assign fetch_enable_d = fetch_enable_i ? 1'b1 : fetch_enable_q;

  // Busy when any of the sub units is busy (typically wait for the instruction buffer to fill up)
  assign core_busy_d = if_busy_i || ctrl_fsm_i.ctrl_busy || lsu_busy_i;

  // Enable the clock only after the initial fetch enable while busy or waking up to become busy
  assign clock_en = fetch_enable_q && (ctrl_fsm_i.wake_from_sleep || core_busy_q);

  // Sleep only in response to WFI which leads to clock disable. The controller determines the
  // scenarios for which WFI can(not) cause sleep. WFI suppression is performed in the i_decoder
  // based on the debug_wfi_no_sleep signal from the controller.
  assign core_sleep_o = fetch_enable_q && !clock_en;

  always_ff @(posedge clk_ungated_i, negedge rst_n)
  begin
    if (rst_n == 1'b0) begin
      core_busy_q    <= 1'b0;
      fetch_enable_q <= 1'b0;
    end else begin
      core_busy_q    <= core_busy_d;
      fetch_enable_q <= fetch_enable_d;
    end
  end

  // Fetch enable for Controller
  assign fetch_enable_o = fetch_enable_q;

  // Main clock gate of CV32E40P
  cv32e40x_clock_gate
    #(.LIB (LIB))
  core_clock_gate_i
  (
    .clk_i        ( clk_ungated_i   ),
    .en_i         ( clock_en        ),
    .scan_cg_en_i ( scan_cg_en_i    ),
    .clk_o        ( clk_gated_o     )
  );

endmodule
