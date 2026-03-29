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
// Authors:        Arjan Bink - arjan.bink@silabs.com                         //
//                                                                            //
// Description:    RTL assertions for the wb_stage module                     //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_wb_stage_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
  #(
    parameter bit DEBUG  = 1
  )
(
  input logic           clk,
  input logic           rst_n,

  input logic           wb_ready_o,
  input logic           wb_valid,
  input ctrl_fsm_t      ctrl_fsm_i,
  input ex_wb_pipe_t    ex_wb_pipe_i,
  input mpu_status_e    lsu_mpu_status_i,
  input mpu_status_e    lsu_mpu_status_q,
  input logic           lsu_wpt_match_i,
  input logic           rf_we_wb_o,
  input logic           lsu_valid_q,
  input logic           lsu_wpt_match_q,
  input logic           lsu_valid_i
);

  // LSU instructions should not get killed once in WB (as they commit already in EX).
  a_lsu_no_kill :
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ex_wb_pipe_i.lsu_en && ex_wb_pipe_i.instr_valid)
                      |-> (!ctrl_fsm_i.kill_wb))
      else `uvm_error("wb_stage", "LSU instruction killed in WB")

  // Halt implies not ready and not valid
  a_halt :
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_i.halt_wb && !ctrl_fsm_i.kill_wb)
                      |-> (!wb_ready_o && !wb_valid))
      else `uvm_error("wb_stage", "Halt should imply not ready and not valid")

  // Kill implies ready and not valid
  a_kill :
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_i.kill_wb)
                      |-> (wb_ready_o && !wb_valid))
      else `uvm_error("wb_stage", "Kill should imply ready and not valid")


  // MPU should never signal error on non-LSU instructions
  a_nonlsu_error:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (!ex_wb_pipe_i.lsu_en)
                      |-> (lsu_mpu_status_i == MPU_OK))
      else `uvm_error("wb_stage", "MPU error on non LSU instruction")

  // Register file shall not be written when WB is halted or killed
  a_rf_halt_kill:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_i.kill_wb || ctrl_fsm_i.halt_wb)
                    |-> !rf_we_wb_o)
      else `uvm_error("wb_stage", "Register file written while WB is halted or killed")


  // The WB stage will make the mpu_status sticky if wb_walid is not asserted the first cycle in WB.
  // In practice this should never happen as the controller will not allow any halt or kill on a LSU in WB.
  // The only exception to this is the watchpoints which are asserted separately.
  a_no_sticky_mpu_error:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (lsu_mpu_status_q == MPU_OK))
      else `uvm_error("wb_stage", "lsu_mpu_status_q should never see an error")


  // Any load or store without an MPU error or watchpoint trigger must signal wb_valid when rvalid arrives.
  // This chekcs that there is no need for sticky rdata_q bits in the wb_stage similar to the mpu_status and wpt bits.
  a_lsu_wb_valid:
    assert property (@(posedge clk) disable iff (!rst_n)
                    lsu_valid_i &&
                    !(lsu_wpt_match_i || (lsu_mpu_status_i != MPU_OK))
                    |->
                    wb_valid)
      else `uvm_error("wb_stage", "wb_valid not signaled immediately upon rvalid for LSU without WPT or MPU error")

generate
  if (DEBUG) begin
    // The only cause for a sticky lsu_valid is a watchpoint trigger.
    a_only_wpt_lsu_valid_sticky:
    assert property (@(posedge clk) disable iff (!rst_n)
                    lsu_valid_q
                    |->
                    lsu_wpt_match_q &&
                    $past(lsu_wpt_match_i))
      else `uvm_error("wb_stage", "LSU signal sticky for non-watchpoint cause")

    // A watchpoint trigger will be halted during its first cycle in WB, giving !wb_valid.
    // During the next cycle the controller will kill the pipeline but let wb_valid==1'b1 to let RVFI
    // know the core hit a watchpoint.
    a_wpt_wb_halt:
    assert property (@(posedge clk) disable iff (!rst_n)
                    lsu_wpt_match_i
                    |->
                    !wb_valid && ctrl_fsm_i.halt_wb)
      else `uvm_error("wb_stage", "WB stage not halted on a WPT match")

  a_wpt_wb_valid:
    assert property (@(posedge clk) disable iff (!rst_n)
                    lsu_wpt_match_i
                    |=>
                    wb_valid)
      else `uvm_error("wb_stage", "WB stage not setting wb_valid on a WPT")

  end else begin
    // Without debug support, sticky lsu_valid shall never be set
    a_never_lsu_valid_sticky:
    assert property (@(posedge clk) disable iff (!rst_n)
                    !lsu_valid_q)
      else `uvm_error("wb_stage", "LSU signal sticky when debug support is not enabled.")
  end
endgenerate
endmodule // cv32e40x_wb_stage_sva
