// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Author:         Matthias Baer - baermatt@student.ethz.ch                   //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                                                                            //
// Description:    RTL assertions for the mult module                         //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_mult_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
  (// Module boundary signals
   input logic        clk,
   input logic        rst_n,
   input logic [31:0] op_a_i,
   input logic [31:0] op_b_i,
   input logic        ready_o,
   input logic        valid_i,
   input logic [31:0] result_o,
   input logic        valid_o,
   input logic        ready_i,
   input logic [ 1:0] signed_mode_i,
   input mul_opcode_e operator_i,
   // Internal signals
   input logic [32:0] mulh_acc,
   input mul_state_e  mulh_state,
   input logic [16:0] mulh_al,
   input logic [16:0] mulh_bl,
   input logic [16:0] mulh_ah,
   input logic [16:0] mulh_bh,
   input logic [33:0] int_result);

  ////////////////////////////////////////
  ////  Assertions on module boundary ////
  ////////////////////////////////////////

  // Check result for MUL
  logic [31:0] mul_result;
  assign mul_result = $signed(op_a_i) * $signed(op_b_i);
  a_mul_result : // check multiplication result for MUL
    assert property (@(posedge clk) disable iff (!rst_n)
                     (valid_i && (operator_i == MUL_M32)) |-> (result_o == mul_result))
      else `uvm_error("mult", "MUL result check failed")
  a_mul_valid : // check that MUL result is immediately qualified by valid_o
    assert property (@(posedge clk) disable iff (!rst_n)
                     (valid_i && (operator_i == MUL_M32)) |-> valid_o)
      else `uvm_error("mult", "MUL result wasn't immediately valid")


  // Check result for all MULH flavors 
  logic               mulh_result_valid;
  assign mulh_result_valid = ((operator_i == MUL_H) && valid_i) && valid_o;

  logic [31:0] mulh_result;
  assign mulh_result = ($signed({{32{op_a_i[31]}}, op_a_i}) * $signed({{32{op_b_i[31]}}, op_b_i})) >>> 32;
  a_mulh_result : // check multiplication result for MULH
    assert property (@(posedge clk) disable iff (!rst_n)
                     (mulh_result_valid && (signed_mode_i == 2'b11)) |->
                     (result_o == mulh_result))
      else `uvm_error("mult", "MULH result check failed")

  logic [31:0] mulhsu_result;
  assign mulhsu_result = ($signed({{32{op_a_i[31]}}, op_a_i}) * {32'b0, op_b_i}) >> 32;
  a_mulhsu_result : // check multiplication result for MULHSU
    assert property (@(posedge clk) disable iff (!rst_n)
                     (mulh_result_valid && (signed_mode_i == 2'b01)) |->
                     (result_o == mulhsu_result))
      else `uvm_error("mult", "MULHSU result check failed")

  logic [31:0] mulhu_result;
  assign mulhu_result = ({32'b0, op_a_i} * {32'b0, op_b_i}) >> 32;
  a_mulhu_result : // check multiplication result for MULHU
    assert property (@(posedge clk) disable iff (!rst_n)
                     (mulh_result_valid && (signed_mode_i == 2'b00)) |->
                     (result_o == mulhu_result))
      else `uvm_error("mult", "MULHU result check failed")


  // Check signal stability
  sequence s_insistent_valid;
    @(posedge clk)
    (valid_i && !ready_o) ##1 valid_i;
  endsequence

  a_operator_constant_when_mulh_active:
    assert property (@(posedge clk) disable iff (!rst_n)
                     s_insistent_valid |-> $stable(operator_i))
      else `uvm_error("mult", "Operator changed when MULH active")

  a_sign_constant_when_mulh_active:
    assert property (@(posedge clk) disable iff (!rst_n)
                     s_insistent_valid |-> $stable(signed_mode_i))
      else `uvm_error("mult", "Sign changed when MULH active")

  a_operand_a_constant_when_mulh_active:
    assert property (@(posedge clk) disable iff (!rst_n)
                     s_insistent_valid |-> $stable(op_a_i))
      else `uvm_error("mult", "Operand A changed when MULH active")

  a_operand_b_constant_when_mulh_active:
    assert property (@(posedge clk) disable iff (!rst_n)
                     s_insistent_valid |-> $stable(op_b_i))
      else `uvm_error("mult", "Operand B changed when MULH active")

  a_check_result_constant: // Check that the result is kept stable until receiver is ready
    assert property (@(posedge clk) disable iff (!rst_n)
                     (valid_o && !ready_i) ##1 valid_o |-> $stable(result_o))
      else `uvm_error("mult", "Completed result changed while receiving end was not ready")


  // Check handshake properties

  a_outputs_are_input_qualified:
    assert property (@(posedge clk) disable iff (!rst_n)
                     valid_o |-> valid_i)
      else `uvm_error("mult", "Outputs valid while inputs where unknown")

  a_can_receive_expediently:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (valid_o && ready_i) |-> ready_o)
      else `uvm_error("mult", "Outputs where consumed but didn't get ready for new inputs")


  //////////////////////////////
  ////  Internal assertions ////
  //////////////////////////////

  // Check initial value of accumulate register
  a_check_acc_init_zero:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (mulh_state == MUL_ALBL) |-> (mulh_acc == '0))
      else `uvm_error("mult", "Accumulate register not 0 when starting MULH calculation")

  // Check that accumulate register is 0 for MUL
  a_check_acc_mul_value_zero:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (operator_i == MUL_M32) && valid_i |-> (mulh_acc == '0))
      else `uvm_error("mult", "Accumulate register not 0 for MUL instruction")


  // Check result for intermediary stages of the 4-step shift-and-add algorithm

  //Here are checks for the `int_result` of the 4 steps.
  //There are also checks for `mulh_acc` for the 3 last steps.
  //At the final step, `int_result + mulh_acc` represents the final `result_o`.

  logic [33:0] shift_result_ll;
  logic [33:0] shift_result_lh;
  logic [33:0] shift_result_hl;
  logic [33:0] shift_result_hh;
  logic [33:0] shift_result_ll_shift;
  logic [32:0] shift_result_ll_lh;
  logic [33:0] shift_result_ll_lh_hl;
  logic [32:0] shift_result_ll_lh_hl_shift;
  logic unused;

  assign shift_result_ll = $signed({{16{mulh_al[16]}}, mulh_al[15:0]}) * $signed({{16{mulh_bl[16]}}, mulh_bl[15:0]});
  a_shift_result_ll : // Given MUL_H, first calculation is "al * bl"
    assert property (@(posedge clk) disable iff (!rst_n)
                     ((mulh_state == MUL_ALBL) && valid_i && (operator_i == MUL_H)) |->
                     (int_result == shift_result_ll))
      else `uvm_error("mult", "MUL_H step 1/4 got wrong int_result")

  assign shift_result_lh = $signed({{16{mulh_al[16]}}, mulh_al[15:0]}) * $signed({{16{mulh_bh[16]}}, mulh_bh[15:0]});
  a_shift_result_lh : // Second calculation is "al * bh"
    assert property (@(posedge clk) disable iff (!rst_n)
                     (mulh_state == MUL_ALBH) && valid_i |->
                     (int_result == shift_result_lh))
      else `uvm_error("mult", "MUL_H step 2/4 got wrong int_result")

  assign shift_result_hl = $signed({{16{mulh_ah[16]}}, mulh_ah[15:0]}) * $signed({{16{mulh_bl[16]}}, mulh_bl[15:0]});
  a_shift_result_hl : // Third calculation is "ah * bl"
    assert property (@(posedge clk) disable iff (!rst_n)
                     (mulh_state == MUL_AHBL) && valid_i |->
                     (int_result == shift_result_hl))
      else `uvm_error("mult", "MUL_H step 3/4 got wrong int_result")

  assign shift_result_hh = $signed({{16{mulh_ah[16]}}, mulh_ah[15:0]}) * $signed({{16{mulh_bh[16]}}, mulh_bh[15:0]});
  a_shift_result_hh : // Fourth and final multiplication is "ah * bh"
    assert property (@(posedge clk) disable iff (!rst_n)
                     (mulh_state == MUL_AHBH) && valid_i |->
                     (int_result == shift_result_hh))
      else `uvm_error("mult", "MUL_H step 4/4 got wrong int_result")

  assign shift_result_ll_shift = (shift_result_ll) >> 16;
  a_shift_result_ll_shift : // In step 2, accumulate the shifted result of "al * bl"
    assert property (@(posedge clk) disable iff (!rst_n)
                     (mulh_state == MUL_ALBH) && valid_i |->
                     (mulh_acc == shift_result_ll_shift))
      else `uvm_error("mult", "MUL_H accumulated 'al x bl' wrong")

  assign {unused, shift_result_ll_lh} = $signed(shift_result_ll_shift) + $signed(shift_result_lh);
  a_shift_result_ll_lh : // In step 3, accumulate also result of "al * bh"
    assert property (@(posedge clk) disable iff (!rst_n)
                     (mulh_state == MUL_AHBL) && valid_i |->
                     (mulh_acc == shift_result_ll_lh))
      else `uvm_error("mult", "MUL_H accumulated 'al x bh' wrong")

  assign shift_result_ll_lh_hl = $signed(shift_result_ll_lh) + $signed(shift_result_hl);
  assign shift_result_ll_lh_hl_shift = $signed(shift_result_ll_lh_hl) >>> 16;
  a_shift_result_ll_lh_hl_shift : // In step 4, accumulate also "ah * bl" and store the shifted result
    assert property (@(posedge clk) disable iff (!rst_n)
                     (mulh_state == MUL_AHBH) && valid_i |->
                     (mulh_acc == shift_result_ll_lh_hl_shift))
      else `uvm_error("mult", "MUL_H accumulated 'ah x bl' wrong")

endmodule // cv32e40x_mult
