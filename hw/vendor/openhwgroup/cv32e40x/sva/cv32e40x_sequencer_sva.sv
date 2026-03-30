// Copyright 2022 Silicon Labs, Inc.
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
// Authors:        Oystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Description:    RTL assertions for the sequencer module                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_sequencer_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
(
  input  logic           clk,
  input  logic           rst_n,

  input  logic           valid_i,
  input  logic           kill_i,
  input  logic           halt_i,
  input  logic           valid_o,
  input  logic           ready_i,
  input  logic           ready_o,
  input  seq_t           instr_cnt_q,
  input  seq_state_e     seq_state_q,
  input  logic           seq_last_o,
  input  seq_instr_e     seq_instr,
  input  logic           instr_is_tbljmp_ptr_i,
  input  logic           instr_is_clic_ptr_i,
  input  logic           instr_is_mret_ptr_i,
  input  logic           seq_tbljmp_o
);

  // After kill, all state must be reset.
  a_kill_state:
  assert property (@(posedge clk) disable iff (!rst_n)
                    kill_i |=> ((instr_cnt_q == '0) && (seq_state_q == S_IDLE)))
      else `uvm_error("sequencer", "Sequencer state not reset after kill_i.")

  // After sequence is done, all state must be reset.
  a_done_state:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (valid_o && seq_last_o && ready_i) |=> ((instr_cnt_q == '0) && (seq_state_q == S_IDLE)))
      else `uvm_error("sequencer", "Sequencer state not reset after finishing sequence")

  // Kill implies ready and not valid
  a_seq_kill:
  assert property (@(posedge clk) disable iff (!rst_n)
                    kill_i |-> (ready_o && !valid_o))
      else `uvm_error("sequencer", "Kill should imply ready and not valid.")


  // Halt implies not ready and not valid
  a_seq_halt :
    assert property (@(posedge clk) disable iff (!rst_n)
                      (halt_i && !kill_i)
                      |-> (!ready_o && !valid_o))
      else `uvm_error("sequencer", "Halt should imply not ready and not valid")

  // State should not update while halted and not killed
  a_seq_halt_state_stable :
    assert property (@(posedge clk) disable iff (!rst_n)
                      (halt_i && !kill_i)
                      |=> ($stable(instr_cnt_q) && $stable(seq_state_q)))
      else `uvm_error("sequencer", "Counter or state not stable while halted")

  // todo: add assertion to check that atomic part cannot be killed -- how? Depends on when operations are done in WB


  // Check max sequence length
  // POPRETZ with rlist ra, s0-s11
  // 13 register loads
  // 1 stack pointer update
  // 1 clearing of a0
  // 1 return
  // Total sequence length = 16 -> must signal seq_last_o on counter value 'd15
  a_max_seq_len_popretz:
  assert property (@(posedge clk) disable iff (!rst_n)
                  valid_i && (seq_instr == POPRETZ) && (instr_cnt_q == 'd15)
                  |->
                  seq_last_o)
      else `uvm_error("sequencer", "popretz sequence too long")

  // Check max sequence length
  // POPRET with rlist ra, s0-s11
  // 13 register loads
  // 1 stack pointer update
  // 1 return
  // Total sequence length = 15
  a_max_seq_len_popret:
    assert property (@(posedge clk) disable iff (!rst_n)
                    valid_i && (seq_instr == POPRET)
                    |->
                    (instr_cnt_q < 'd15))
        else `uvm_error("sequencer", "popret sequence too long")


  // Check max sequence length
  // POP with rlist ra, s0-s11
  // 13 register loads
  // 1 stack pointer update
  // Total sequence length = 14
  a_max_seq_len_pop:
    assert property (@(posedge clk) disable iff (!rst_n)
                    valid_i && (seq_instr == POP)
                    |->
                    (instr_cnt_q < 'd14))
        else `uvm_error("sequencer", "pop sequence too long")

  // Check max sequence length
  // PUSH with rlist ra, s0-s11
  // 13 register stores
  // 1 stack pointer update
  // Total sequence length = 14
  a_max_seq_len_push:
    assert property (@(posedge clk) disable iff (!rst_n)
                    valid_i && (seq_instr == PUSH)
                    |->
                    (instr_cnt_q < 'd14))
        else `uvm_error("sequencer", "push sequence too long")

  // Check max sequence length
  // MVA01S
  // 2 register moves
  a_max_seq_len_mva01s:
  assert property (@(posedge clk) disable iff (!rst_n)
                  valid_i && (seq_instr == MVA01S)
                  |->
                  (instr_cnt_q < 'd2))
      else `uvm_error("sequencer", "mva01s sequence too long")

  // Check max sequence length
  // MVSA01
  // 2 register moves
  a_max_seq_len_mvsa01:
    assert property (@(posedge clk) disable iff (!rst_n)
                    valid_i && (seq_instr == MVSA01)
                    |->
                    (instr_cnt_q < 'd2))
        else `uvm_error("sequencer", "mva01s sequence too long")

  // Check that the sequencer does not decode any instructions from pointers
  a_ptr_illegal:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (instr_is_tbljmp_ptr_i || instr_is_clic_ptr_i || instr_is_mret_ptr_i)
                    |->
                    (seq_instr == INVALID_INST))
        else `uvm_error("sequencer", "Instruction should not be decoded from a pointer")

  // Check that the sequence counter does not count for tablejumps or tablejump pointers
  a_tbljmp_cnt:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (valid_o && ready_i && (seq_tbljmp_o || instr_is_tbljmp_ptr_i))
                    |=>
                    (instr_cnt_q == '0))
        else `uvm_error("sequencer", "Should not count when handling table jumps")
endmodule

