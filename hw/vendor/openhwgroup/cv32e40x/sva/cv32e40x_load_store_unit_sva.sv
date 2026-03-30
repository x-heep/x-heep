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
// Authors:        Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                                                                            //
// Description:    RTL assertions for the load_store_unit module              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_load_store_unit_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
  #(
    parameter bit          X_EXT = 0,
    parameter int unsigned DEPTH = 0,
    parameter bit          DEBUG = 1,
    parameter a_ext_e      A_EXT = A_NONE
  )
  (input logic       clk,
   input logic       rst_n,
   input logic [1:0] cnt_q,
   input logic       busy_o,
   input logic       count_up,
   input logic       count_down,
   input ctrl_fsm_t  ctrl_fsm_i,
   input ctrl_state_e ctrl_fsm_ns,
   input ctrl_state_e ctrl_fsm_cs,
   input logic       trans_valid,
   input logic       lsu_split_0_o,
   input write_buffer_state_e write_buffer_state_i,
   input logic       split_q,
   input mpu_status_e lsu_mpu_status_1_o, // WB mpu status
   input align_status_e lsu_align_status_1_o,
   input ex_wb_pipe_t ex_wb_pipe_i,
   if_c_obi.monitor  m_c_obi_data_if,
   input logic       xif_req,
   input logic       xif_res_q,
   input logic       id_valid,
   input logic       ex_ready,
   input logic       lsu_en_id,
   input logic       lsu_first_op_0_o,
   input logic       valid_0_i,
   input logic       ready_0_i,
   input logic       trigger_match_0_i,
   input logic       lsu_wpt_match_1_o,
   input trans_req_t trans,
   input logic       bus_trans_valid,
   input logic       mpu_err_i,
   input logic       align_err_i
  );

  // Check that outstanding transaction count will not overflow DEPTH
  property p_no_transaction_count_overflow_0;
    @(posedge clk) (1'b1) |-> (cnt_q <= DEPTH);
  endproperty

  a_no_transaction_count_overflow_0 :
    assert property(p_no_transaction_count_overflow_0)
      else `uvm_error("load_store_unit", "Assertion a_no_transaction_count_overflow_0 failed")

  property p_no_transaction_count_overflow_1;
        @(posedge clk) (cnt_q == DEPTH) |-> (!count_up || count_down);
  endproperty

  a_no_transaction_count_overflow_1 :
    assert property(p_no_transaction_count_overflow_1)
      else `uvm_error("load_store_unit", "Assertion a_no_transaction_count_overflow_1 failed")

  a_no_cnt_underflow :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (cnt_q == 0) |=> (cnt_q == 0) || (cnt_q == 1))
      else `uvm_error("load_store_unit", "Transfer counter underflow");

  a_busy_when_lsu_outststanding :
   assert property (@(posedge clk) disable iff (!rst_n)
                    (cnt_q != 0) |-> busy_o )
      else `uvm_error("load_store_unit", "Outstanding transfers but LSU busy signal not set")

    // Outstanding Transactions on OBI interface

    int outstanding_cnt;
    int outstanding_cnt_q;
    always_comb begin
      outstanding_cnt = outstanding_cnt_q;
      if (m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt)
        outstanding_cnt++;
      if (m_c_obi_data_if.s_rvalid.rvalid)
        outstanding_cnt--;
    end

    always_ff @(posedge clk, negedge rst_n) begin
      if (rst_n == 1'b0) begin
        outstanding_cnt_q <= 0;
      end else begin
        outstanding_cnt_q <= outstanding_cnt;
      end
    end

  a_data_obi_max_2_outstanding_transactions :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (outstanding_cnt_q <= 2))
      else `uvm_error("core", "More than two outstanding transactions")

  // Check that an rvalid only occurs when there are outstanding transaction(s)
  property p_no_spurious_rvalid;
        @(posedge clk) (m_c_obi_data_if.s_rvalid.rvalid == 1'b1) |-> (outstanding_cnt_q > 0);
  endproperty

  a_no_spurious_rvalid :
    assert property(p_no_spurious_rvalid) else `uvm_error("load_store_unit", "Assertion a_no_spurious_rvalid failed")

  // No transaction allowd if EX is halted or killed
  a_lsu_halt_kill:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_i.kill_ex || ctrl_fsm_i.halt_ex)
                    |-> !trans_valid)
      else `uvm_error("load_store_unit", "Transaction happened while WB is halted or killed")

  // Second half of a split transaction should never get killed while in EX
  // Exception: Second half of a split transaction may be killed if the first half
  //            gets blocked by the PMA or alignment checker.
  a_lsu_no_kill_second_half_ex:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (split_q && (lsu_mpu_status_1_o == MPU_OK) && (lsu_align_status_1_o == ALIGN_OK)) |-> !ctrl_fsm_i.kill_ex)
    else `uvm_error("load_store_unit", "Second half of split transaction was killed")

  // cnt_q == 2'b00 shall be the same as !(ex_wb_pipe.lsu_en && ex_wb_pipe_i.instr_valid)
  // With a watchpoint match, the LSU counter may clear while WB is halted for synchronous debug entry, leaving cnt=0 while lsu_en in WB is true.
  a_cnt_zero:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (cnt_q == 2'b00) && !(ctrl_fsm_cs == DEBUG_TAKEN) |-> !(ex_wb_pipe_i.lsu_en && ex_wb_pipe_i.instr_valid))
      else `uvm_error("load_store_unit", "cnt_q is zero when WB contains a valid LSU instruction")

    // Check that no XIF request or result are produced if X_EXT is disabled
  a_lsu_no_xif_req_if_xext_disabled:
  assert property (@(posedge clk) disable iff (!rst_n)
                  !X_EXT |-> !xif_req)
    else `uvm_error("load_store_unit", "XIF transaction request despite X_EXT being disabled")
  a_lsu_no_xif_res_if_xext_disabled:
  assert property (@(posedge clk) disable iff (!rst_n)
                  !X_EXT |-> !xif_res_q)
    else `uvm_error("load_store_unit", "XIF transaction result despite X_EXT being disabled")


  // split_q must be 0 when a new LSU instruction enters the LSU
  a_clear_splitq:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (id_valid && ex_ready && lsu_en_id)
                  |=>
                  !split_q && lsu_first_op_0_o)
    else `uvm_error("load_store_unit", "split_q not zero for a new LSU instruction")

  // trigger_match_0_i must remain stable while the instruction is in EX
  a_stable_tmatch:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (valid_0_i && !ready_0_i)
                  |=>
                  $stable(trigger_match_0_i) until_with(ready_0_i))
    else `uvm_error("load_store_unit", "trigger_match_0_i changed before ready_0_i became 1")


  // Helper logic to remember OBI prot for the previous transfer
  // Also keep track of remainig parts of a split transfer
  logic [2:0] trans_prot_prev;
  logic [1:0] split_rem_cnt;
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      trans_prot_prev <= '0;
      split_rem_cnt <= '0;
    end
    else begin
      if(m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt) begin
        // Keep track of prot for the previous transfer
        trans_prot_prev <= m_c_obi_data_if.req_payload.prot;
      end

      // Keep track of remaining parts of split transfers
      if(ctrl_fsm_i.kill_ex) begin
        // EX was killed, clear counter
        split_rem_cnt <= 2'h0;
      end
      else if (lsu_split_0_o && !(|split_rem_cnt)) begin
        // New split transfer
        // lsu_split_0_o has the same timing as the transfer going into the write buffer,
        // but if the write buffer is full, it will not have the same timing as the OBI transfer.

        // Determine number of expected OBI transfers to be accepted before the last part of the split transfer
        if(m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt) begin
          // OBI transfer was accepted in this cycle.
          // If the write buffer is full, the accepted transfer is not part of the split transfer
          // If the write buffer is not full, the accepted transfer is the first part of the split transfer
          split_rem_cnt <= (write_buffer_state_i == WBUF_FULL) ? 2'h2 : 2'h1;
        end
        else begin
          // OBI transfer was not accepted in this cycle
          // If the write buffer is full, the buffered transfer must be accepted before the split transfer can go on the OBI bus
          // If the write buffer is not full, the next accepted OBI transfer will be the first part of the split transfer
          split_rem_cnt <= (write_buffer_state_i == WBUF_FULL) ? 2'h3 : 2'h2;
        end
      end
      else if (m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt) begin
        // Transfer accepted, decrement counter
        split_rem_cnt <= (split_rem_cnt > 2'h0) ? split_rem_cnt - 2'h1 : 2'h0;
      end
    end
  end

  // Assert that OBI prot is equal for both parts of a split transfer
  a_lsu_split_prot:
    assert property (@(posedge clk) disable iff (!rst_n)
                     ((split_rem_cnt == 2'h1) && (m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt)) |->
                     (m_c_obi_data_if.req_payload.prot == trans_prot_prev))
      else `uvm_error("load_store_unit", "OBI prot not equal for both parts of a split transfer")


if (DEBUG) begin
  // The only cause of (cnt_q==0) with a valid LSU instruction in WB is a watchpoint trigger.
  // Assertions checks that this is the case and that a debug entry is taking place.
  a_lsu_cnt_nonzero_wpt:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (cnt_q == 2'b00) && (ex_wb_pipe_i.lsu_en && ex_wb_pipe_i.instr_valid)
                  |->
                  $past(lsu_wpt_match_1_o) && (ctrl_fsm_cs == DEBUG_TAKEN))
      else `uvm_error("load_store_unit", "Illegal cause of cnt_q=0 while a valid LSU instruction is in WB")

  // MPU errors and watchpoint triggers cannot happen at the same time
  a_mpuerr_wpt_unique:
  assert property (@(posedge clk) disable iff (!rst_n)
                  lsu_wpt_match_1_o
                  |->
                  !(lsu_mpu_status_1_o != MPU_OK))
      else `uvm_error("load_store_unit", "MPU error and watchpoint trigger not unique")
end

if (A_EXT != A_NONE) begin
  // Check that misaligned atomics never reach the bus but get blocked by the alignment checker
  a_misaligned_atomic_err:
  assert property (@(posedge clk) disable iff (!rst_n)
                  trans_valid &&                                    // Active transfer
                  (trans.atop[5] && (trans.addr[1:0] != 2'b00)) &&  // Misaligned atomic
                  !mpu_err_i                                        // Not blocked by MPU
                  |->
                  lsu_split_0_o &&
                  align_err_i && !bus_trans_valid)
      else `uvm_error("load_store_unit", "Misaligned atomic not blocked by alignment checker")
end

endmodule // cv32e40x_load_store_unit_sva
