// Copyright 2023 Silicon Labs, Inc.
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
// Description:    debug_triggers assertions                                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_debug_triggers_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
#(
    parameter int     DBG_NUM_TRIGGERS = 1,
    parameter a_ext_e A_EXT = A_NONE
  )

  (
   input logic        clk,
   input logic        rst_n,
   input csr_opcode_e csr_op,       // from cs_registers
   input logic [31:0] csr_wdata,    // from cs_registers
   input csr_num_e    csr_waddr,    // from cs_registers
   input ex_wb_pipe_t ex_wb_pipe_i,
   input ctrl_fsm_t   ctrl_fsm_i,
   input logic [31:0] tselect_q,
   input logic [31:0] tdata1_q[DBG_NUM_TRIGGERS],
   input logic [31:0] tdata2_q[DBG_NUM_TRIGGERS],
   input logic [DBG_NUM_TRIGGERS-1 : 0] lsu_addr_match_en,
   input privlvl_t    priv_lvl_ex_i,
   input lsu_atomic_e lsu_atomic_ex_i,
   input logic        lsu_valid_ex_i
  );



  /////////////////////////////////////////////////////////////////////////////////////////
  // Asserts to check that the CSR flops remain unchanged if a set/clear has all_zero rs1
  /////////////////////////////////////////////////////////////////////////////////////////
  a_set_clear_tselect_q:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (csr_waddr == CSR_TSELECT) &&
                  ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                  !(|csr_wdata) &&
                  ex_wb_pipe_i.csr_en &&
                  !ctrl_fsm_i.kill_wb
                  |=>
                  $stable(tselect_q))
    else `uvm_error("debug_triggers", "tselect_q changed after set/clear with rs1==0")

  a_set_clear_tdata1_q:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (csr_waddr == CSR_TDATA1) &&
                  ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                  !(|csr_wdata) &&
                  ex_wb_pipe_i.csr_en &&
                  !ctrl_fsm_i.kill_wb
                  |=>
                  $stable(tdata1_q)) // Checking stability of ALL tdata1, not just the one selected
    else `uvm_error("debug_triggers", "tdata1_q changed after set/clear with rs1==0")

  a_set_clear_tdata2_q:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (csr_waddr == CSR_TDATA2) &&
                  ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                  !(|csr_wdata) &&
                  ex_wb_pipe_i.csr_en &&
                  !ctrl_fsm_i.kill_wb
                  |=>
                  $stable(tdata2_q)) // Checking stability of ALL tdata2, not just the one selected
    else `uvm_error("debug_triggers", "tdata2_q changed after set/clear with rs1==0")

generate
  if (A_EXT == A) begin : gen_amo_trigger_assert
    for (genvar idx=0; idx<DBG_NUM_TRIGGERS; idx++) begin
      // Since AMOs perform both a read and a write, it must be possible to get a trigger match on its address
      // when any of the tdata1.LOAD or tdata1.STORE bits are set.
      a_amo_enable_trig_on_load:
        assert property (@(posedge clk) disable iff (!rst_n)
                        (tdata1_q[idx][MCONTROL2_6_LOAD] || tdata1_q[idx][MCONTROL2_6_STORE]) &&  // Trig on loads or stores enabled
                        (tdata1_q[idx][MCONTROL2_6_M] && (priv_lvl_ex_i == PRIV_LVL_M)) && // Matches privilege level
                        (lsu_atomic_ex_i == AT_AMO)  && // An Atomic AMO instruction is in EX
                        lsu_valid_ex_i
                        |->
                        lsu_addr_match_en[idx])    // Address matching must be enabled on the trigger
          else `uvm_error("debug_triggers", "Address matching not enabled on an AMO instruction when trig on loads are configured")
    end
  end
endgenerate

endmodule

