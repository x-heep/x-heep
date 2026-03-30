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
//                                                                            //
// Authors:        Arjan Bink       - arjan.bink@silabs.com                   //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                                                                            //
// Description:    RTL assertions for the sleep_unit module                   //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_sleep_unit_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
  (
   input logic clk_ungated_i,
   input logic rst_n,
   input logic clock_en,
   input logic core_busy_d,
   input logic core_busy_q,
   input logic core_sleep_o,
   input logic fetch_enable_d,
   input logic fetch_enable_q,
   input       ctrl_state_e ctrl_fsm_cs,
   input       ctrl_state_e ctrl_fsm_ns
   );

  // Clock gate is disabled during RESET state of the controller
  property p_clock_en_0;
    @(posedge clk_ungated_i) disable iff (!rst_n)
      ((ctrl_fsm_cs == RESET) && (ctrl_fsm_ns == RESET)) |->  (clock_en == 1'b0);
  endproperty

  a_clock_en_0 : assert property(p_clock_en_0) else `uvm_error("sleep_unit", "Assertion a_clock_en_0 failed")

  // Clock gate is enabled when exit from RESET state is required
  property p_clock_en_1;
    @(posedge clk_ungated_i) disable iff (!rst_n)
      ((ctrl_fsm_cs == RESET) && (ctrl_fsm_ns != RESET)) |-> (clock_en == 1'b1);
  endproperty

  a_clock_en_1 : assert property(p_clock_en_1) else `uvm_error("sleep_unit", "Assertion a_clock_en_1 failed")

  // Clock gate is not enabled before receiving fetch_enable_i pulse
  property p_clock_en_2;
   @(posedge clk_ungated_i) disable iff (!rst_n) (fetch_enable_q == 1'b0) |-> (clock_en == 1'b0);
  endproperty

  a_clock_en_2 : assert property(p_clock_en_2) else `uvm_error("sleep_unit", "Assertion a_clock_en_2 failed")



  // Clock gate is only possibly disabled in RESET or SLEEP
  property p_clock_en_4;
    @(posedge clk_ungated_i) disable iff (!rst_n)
      (clock_en == 1'b0) -> ((ctrl_fsm_cs == RESET) || (ctrl_fsm_ns == SLEEP));
  endproperty

  a_clock_en_4 : assert property(p_clock_en_4) else `uvm_error("sleep_unit", "Assertion a_clock_en_4 failed")

  // Clock gate is enabled when exit from SLEEP state is required
  property p_clock_en_5;
    @(posedge clk_ungated_i) disable iff (!rst_n)
      ((ctrl_fsm_cs == SLEEP) && (ctrl_fsm_ns != SLEEP)) |-> (clock_en == 1'b1);
  endproperty

  a_clock_en_5 : assert property(p_clock_en_5) else `uvm_error("sleep_unit", "Assertion a_clock_en_5 failed")

  // Core sleep is only signaled in SLEEP state
  property p_core_sleep;
    @(posedge clk_ungated_i) disable iff (!rst_n)
      (core_sleep_o == 1'b1) -> ((ctrl_fsm_cs == cv32e40x_pkg::SLEEP));
  endproperty

  a_core_sleep : assert property(p_core_sleep) else `uvm_error("sleep_unit", "Assertion a_core_sleep failed")

  // Core can only become non-busy due to SLEEP entry
  property p_non_busy;
    @(posedge clk_ungated_i) disable iff (!rst_n)
      (core_busy_d == 1'b0) |-> /*(ctrl_fsm_cs == WAIT_SLEEP) ||*/ (ctrl_fsm_cs == SLEEP);
  endproperty

  a_non_busy : assert property(p_non_busy) else `uvm_error("sleep_unit", "Assertion a_non_busy failed")

  // During sleep it should be allowed to externally gate clk_i
  property p_gate_clk_i;
    @(posedge clk_ungated_i) disable iff (!rst_n)
      (core_sleep_o == 1'b1) |-> (core_busy_q == core_busy_d) && (fetch_enable_q == fetch_enable_d);
  endproperty

  a_gate_clk_i : assert property(p_gate_clk_i) else `uvm_error("sleep_unit", "Assertion a_gate_clk_i failed")

  // During sleep the internal clock is gated
  property p_gate_clock_during_sleep;
    @(posedge clk_ungated_i) disable iff (!rst_n)
      (core_sleep_o == 1'b1) |-> (clock_en == 1'b0);
  endproperty

  a_gate_clock_during_sleep : assert property(p_gate_clock_during_sleep)
    else `uvm_error("sleep_unit", "Assertion a_gate_clock_during_sleep failed")

  // Sleep mode can only be entered in response to a WFI or WFE instruction
  property p_only_sleep_for_wfi_wfe;
      @(posedge clk_ungated_i) disable iff (!rst_n)
        (core_sleep_o == 1'b1) |-> (wb_stage_i.ex_wb_pipe_i.instr.bus_resp.rdata == { 12'b000100000101, 13'b0, OPCODE_SYSTEM } ||
                                   (wb_stage_i.ex_wb_pipe_i.instr.bus_resp.rdata == { 6'b100011, 11'b00000000000, 3'b000, 5'b00000, OPCODE_SYSTEM }));
    endproperty

  a_only_sleep_for_wfi_wfe : assert property(p_only_sleep_for_wfi_wfe)
    else `uvm_error("sleep_unit", "Assertion a_only_sleep_for_wfi_wfe failed")

  // In sleep mode the core will not be busy (e.g. no ongoing/outstanding instruction or data transactions)
  property p_not_busy_during_sleep;
      @(posedge clk_ungated_i) disable iff (!rst_n) (core_sleep_o == 1'b1) |-> ((core_busy_q == 1'b0) && (core_busy_d == 1'b0));
    endproperty

  a_not_busy_during_sleep : assert property(p_not_busy_during_sleep)
    else `uvm_error("sleep_unit", "Assertion a_not_busy_during_sleep failed")

endmodule // cv32e40x_sleep_unit_sva

