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
// Authors:        Matthias Baer - baermatt@student.ethz.ch                   //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Robert Balas - balasr@iis.ee.ethz.ch                       //
//                 Andrea Bettati - andrea.bettati@studenti.unipr.it          //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Description:    RTL assertions for the controller module                   //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_controller_fsm_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
  #(  parameter bit X_EXT     = 1'b0,
      parameter bit DEBUG     = 1'b0,
      parameter bit CLIC      = 1'b0
  )
(
  input logic           clk,
  input logic           rst_n,
  input logic           debug_mode_q,
  input ctrl_fsm_t      ctrl_fsm_o,
  input ctrl_byp_t      ctrl_byp_i,
  input logic           jump_taken_id,
  input logic           branch_taken_ex,
  input logic           branch_decision_ex_i,
  input ctrl_state_e    ctrl_fsm_cs,
  input ctrl_state_e    ctrl_fsm_ns,
  input logic [1:0]     lsu_outstanding_cnt,
  input mpu_status_e    mpu_status_wb_i,
  input logic           if_valid_i,
  input if_id_pipe_t    if_id_pipe_i,
  input id_ex_pipe_t    id_ex_pipe_i,
  input ex_wb_pipe_t    ex_wb_pipe_i,
  input logic           ex_valid_i,
  input logic           wb_ready_i,
  input logic           mret_in_wb,
  input logic           exception_in_wb,
  input logic [10:0]    exception_cause_wb,
  input logic           rf_we_wb_i,
  input logic           csr_we_i,
  input logic           csr_illegal_i,
  input logic           pending_single_step,
  input logic           trigger_match_in_wb,
  input logic [1:0]     lsu_err_wb_i,
  input logic           wb_valid_i,
  input logic           fencei_in_wb,
  input logic           fencei_flush_req_o,
  input logic           fencei_flush_ack_i,
  input logic           fencei_req_and_ack_q,
  input logic           pending_async_debug,
  input logic           pending_sync_debug,
  input logic           async_debug_allowed,
  input logic           sync_debug_allowed,
  input logic           pending_interrupt,
  input logic           interrupt_allowed,
  input logic           pending_nmi,
  input logic           nmi_allowed,
  input logic           lsu_busy_i,
  input logic           xif_commit_kill,
  input logic           xif_commit_valid,
  input logic           nmi_is_store_q,
  input logic           nmi_pending_q,
  input dcsr_t          dcsr_i,
  input logic           irq_clic_shv_i,
  input logic           last_op_wb_i,
  input logic           abort_op_wb_i,
  input logic           csr_wr_in_wb_flush_i,
  input logic [2:0]     debug_cause_q,
  input logic           id_valid_i,
  input logic           first_op_if_i,
  input logic           first_op_id_i,
  input logic           first_op_ex_i,
  input logic           last_op_id_i,
  input logic           ex_ready_i,
  input logic           sequence_interruptible,
  input logic           id_stage_haltable,
  input logic           prefetch_valid_if_i,
  input logic           prefetch_is_tbljmp_ptr_if_i,
  input logic           prefetch_is_mret_ptr_if_i,
  input logic           abort_op_id_i,
  input mcause_t        mcause_i,
  input logic           lsu_trans_valid_i,
  input logic           irq_wu_ctrl_i,
  input logic           wu_wfe_i,
  input logic           sys_en_id_i,
  input logic           sys_mret_id_i,
  input logic           mret_ptr_in_wb,
  input logic           clic_ptr_in_wb,
  input logic           csr_en_id_i,
  input logic           clic_ptr_in_progress_id_set,
  input logic           clic_ptr_in_progress_id,
  input pipe_pc_mux_e   pipe_pc_mux_ctrl,
  input logic           ptr_in_if_i,
  input logic           etrigger_in_wb,
  input logic           wpt_match_wb_i,
  input logic           debug_req_i,
  input logic           fetch_enable_i,
  input logic           instr_req_o,
  input logic           instr_dbg_o,
  input logic           wfe_in_wb,
  input mstatus_t       mstatus_i,
  input logic           woke_to_interrupt_q,
  input logic           woke_to_debug_q,
  input logic           ebreak_in_wb,
  input mintstatus_t    mintstatus_i,
  input logic           exception_allowed,
  input logic           wfi_in_wb,
  input logic           fence_in_wb,
  input logic           dret_in_wb,
  input logic           csr_flush_ack_q,
  input logic           clic_ptr_in_id,
  input logic           mret_ptr_in_id
);


  // Back-to-back branch should not be possible due to kill of IF/ID stages after branch
  a_no_back_to_back_branch :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_BRANCH)) |=>
                    !(ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_BRANCH)))
      else `uvm_error("controller", "Two branches back-to-back are taken")


  // Helper signal
  logic jump_taken;
  assign jump_taken = (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_JUMP)) ||
                      (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_MRET));

  // Back-to-back jump should not be possible due to kill of IF stage after branch
  a_no_back_to_back_jump :
    assert property (@(posedge clk) disable iff (!rst_n)
                     jump_taken |=> !jump_taken)
      else `uvm_error("controller", "Two jumps back-to-back are taken")

/* todo: fix
  // Check that a jump is taken only when ID is not killed
  a_valid_jump :
    assert property (@(posedge clk)
                     jump_taken |-> if_id_pipe_i.instr_valid && !ctrl_fsm_o.kill_id)
      else `uvm_error("controller", "Jump taken while ID is halted or killed")
*/

// Check that xret does not coincide with CSR write (to avoid using wrong return address)
  // This check is more strict than really needed; a CSR instruction would be allowed in EX as long
  // as its write action happens before the xret CSR usage
  property p_xret_csr;
    @(posedge clk) disable iff (!rst_n)
      (ctrl_fsm_o.pc_set && ((ctrl_fsm_o.pc_mux == PC_MRET) || (ctrl_fsm_o.pc_mux == PC_DRET))) |->
                                (!(ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.csr_en && csr_we_i));
  endproperty

  a_xret_csr : assert property(p_xret_csr) else `uvm_error("controller", "Assertion a_xret_csr failed")

  // Ensure that debug state outputs are one-hot
  a_debug_state_onehot :
    assert property (@(posedge clk) disable iff (!rst_n)
                     $onehot({ctrl_fsm_o.debug_havereset, ctrl_fsm_o.debug_running, ctrl_fsm_o.debug_halted}))
      else `uvm_error("controller", "Assertion a_debug_state_onehot failed")

  // Ensure that debug_halted_o equals debug_mode_q
  a_debug_halted_equals_debug_mode :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (1'b1) |-> (debug_mode_q == ctrl_fsm_o.debug_halted))
      else `uvm_error("controller", "Assertion a_debug_halted_equals_debug_mode failed")

  // Ensure no interrupt is taken if LSU has outstanding transactions
  a_no_irq_on_outstanding_obi :
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_o.irq_ack) |-> (lsu_outstanding_cnt == 2'b00) )
      else `uvm_error("controller", "Interrupt taken while oustanding transactions are pending")

  // Ensure <stage>.instr_valid is zero following a kill_<prev_stage>
 /* TODO:OK:low Failing when bubble is inserted in ID (id_ready_o==0) when WFI is in EX.
            Will investigate how to solve. Agreed that this assertion is maybe too strict. We only need to guarantee that if a stage is killed, that the instruction in that stage never reaches the following stage with instr_valid = 1 (it doesn't need instr_valid of the next stage 0 in the following cycle.
  a_kill_if :
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_o.kill_if) |=> (if_id_pipe_i.instr_valid == 1'b0) )
    else `uvm_error("controller", "if_id_pipe.instr_valid not zero after kill_if")
*/
/* TODO:OK:low Failing when a DIV instruction is being executed
           Causes ex_ready to be 0. Will be fixed then divider is interruptable
  a_kill_id :
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_o.kill_id) |=> (id_ex_pipe_i.instr_valid == 1'b0) )
    else `uvm_error("controller", "id_ex_pipe.instr_valid not zero after kill_id")
*/
  a_kill_ex :
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_o.kill_ex && !ctrl_fsm_o.halt_wb) |=> (ex_wb_pipe_i.instr_valid == 1'b0) )
    else `uvm_error("controller", "ex_wb_pipe.instr_valid not zero after kill_ex")

  a_kill_wb_rf :
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_o.kill_wb) |-> (rf_we_wb_i == 1'b0) )
    else `uvm_error("controller", "regfile written when kill_wb is asserted")

  a_kill_wb_csr :
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_o.kill_wb) |-> (!csr_we_i) )
    else `uvm_error("controller", "csr written while kill_wb is asserted")

  // Check that no stages have valid instructions using RESET
  a_reset_if_csr :
    assert property (@(posedge clk) disable iff (!rst_n)
            ((ctrl_fsm_cs == RESET)) |-> (!if_valid_i && !if_id_pipe_i.instr_valid && !id_ex_pipe_i.instr_valid && !ex_wb_pipe_i.instr_valid) )
      else `uvm_error("controller", "Instruction valid during RESET")

  // Check that no LSU insn can be in EX when there is a WFI or WFE in WB
  a_wfi_wfe_lsu_csr :
  assert property (@(posedge clk) disable iff (!rst_n)
          (ex_wb_pipe_i.sys_en && (ex_wb_pipe_i.sys_wfi_insn || ex_wb_pipe_i.sys_wfe_insn) && ex_wb_pipe_i.instr_valid) |-> !(id_ex_pipe_i.lsu_en) )
    else `uvm_error("controller", "LSU instruction follows WFI or WFE")


  // Check that lsu_err_wb_i can only be active when an LSU instruction is valid in WB
  // Not using wb_valid, as that is only active for the second half of misaligned.
  // bus error may also be active on the first half, thus checking only for active LSU in WB.
  // Todo: Modify to account for response filter (bufferable writes)
  //a_lsu_err_wb :
  //  assert property (@(posedge clk) disable iff (!rst_n)
  //          lsu_err_wb_i[0] |-> ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.lsu_en)
  //    else `uvm_error("controller", "lsu_error in WB with no valid LSU instruction")

  // Check that fencei handshake is only exersiced when there's a fencei in the writeback stage
  a_fencei_hndshk_fencei_wb :
    assert property (@(posedge clk) disable iff (!rst_n)
           fencei_flush_req_o |-> fencei_in_wb)
      else `uvm_error("controller", "Fencei request when no fencei in writeback")

  // Assert that the fencei request is set the cycle after fencei instruction enters WB (if lsu_busy_i=0 and there are no higher priority events)
  // Only check when no higher priority event is pending (nmi, async debug or interrupts) and WB stage is not killed
  a_fencei_hndshk_req_when_fencei_wb :
    assert property (@(posedge clk) disable iff (!rst_n)
           $rose(fencei_in_wb && !lsu_busy_i) && !ctrl_fsm_o.kill_wb && !(pending_nmi || (pending_async_debug && async_debug_allowed) || (pending_interrupt && interrupt_allowed))
                     |=> $rose(fencei_flush_req_o))
      else `uvm_error("controller", "Fencei in WB did not result in fencei_flush_req_o")

  // Only clear fencei request when acknowledged
  //  ##1 is added to prevent $fell from triggering in cycle 1
  a_fencei_hndshk_ack_b4_req_clear :
    assert property (@(posedge clk) disable iff (!rst_n)
           ##1 $fell(fencei_flush_req_o) |-> $past(fencei_flush_ack_i))
      else `uvm_error("controller", "Fencei request cleared before ack")

  // Clearing of fencei_flush_req_o is always followed by wb_valid (meaning that the fence.i fully completed)
  //  ##1 is added to prevent $fell from triggering in cycle 1
  a_fencei_wb_valid :
    assert property (@(posedge clk) disable iff (!rst_n)
           ##1 $fell(fencei_flush_req_o) |-> wb_valid_i)
      else `uvm_error("controller", "Fencei handshake completion not followed by wb_valid")

  // assert that fencei_flush_req_o goes low the cycle after req&&ack
  a_fencei_clear_req :
    assert property (@(posedge clk) disable iff (!rst_n)
                     fencei_flush_req_o && fencei_flush_ack_i |=> !fencei_flush_req_o)
      else `uvm_error("controller", "fencei_flush_req_o not cleared after req&&ack")

  // assert no lingering fencei handshake when a fencei instruction enters WB.
  a_fencei_lingering_req :
    assert property (@(posedge clk) disable iff (!rst_n)
                     $rose(fencei_in_wb) |-> !(fencei_flush_req_o || fencei_req_and_ack_q))
      else `uvm_error("controller", "Fencei handshake not idle when fencei instruction entered writeback")

  // assert that the lsu_busy_i signal (i.e. write buffer empty) is always cleared when fencei handshake is active
  a_fencei_lsu_busy :
    assert property (@(posedge clk) disable iff (!rst_n)
                     fencei_flush_req_o |-> !lsu_busy_i)
      else `uvm_error("controller", "Fencei handshake active while lsu_busy_o = 1")

  // assert that NMI's are not reported on irq_ack
  // Exception for the case where the core wakes from SLEEP due to an interrupt
  //   - in that case the interrupt is honored while there may be a pending nmi.
  a_irq_ack_no_nmi :
    assert property (@(posedge clk) disable iff (!rst_n)
                     ctrl_fsm_o.irq_ack |-> !(pending_nmi && !woke_to_interrupt_q))
      else `uvm_error("controller", "irq_ack set while there's a pending NMI")

  // Assert that intr_taken is always single cycle. I.e. no double counting
  a_mhpevent_intr_taken_single_cycle:
    assert property (@(posedge clk) disable iff (!rst_n)
                     ctrl_fsm_o.mhpmevent.intr_taken |=> !ctrl_fsm_o.mhpmevent.intr_taken)
      else `uvm_error("controller", "mhpmevent.intr_taken not single cycle")

  // Assert that id_ld_stall is always single cycle. I.e. no double counting
  a_mhpevent_id_ld_stall_single_cycle:
    assert property (@(posedge clk) disable iff (!rst_n)
                     ctrl_fsm_o.mhpmevent.id_ld_stall |=> !ctrl_fsm_o.mhpmevent.id_ld_stall)
      else `uvm_error("controller", "mhpmevent.id_ld_stall not single cycle")

  // Assert that id_jalr_stall is a subset of id_invalid
  a_mhpevent_id_jalr_stall_subset:
    assert property (@(posedge clk) disable iff (!rst_n)
                     ctrl_fsm_o.mhpmevent.id_jalr_stall |-> ctrl_fsm_o.mhpmevent.id_invalid)
      else `uvm_error("controller", "mhpmevent.id_jalr_stall not a subset of mhpmevent.id_invalid")

  // Assert that id_ld_stall is a subset of id_invalid
  a_mhpevent_id_ld_stall_subset:
    assert property (@(posedge clk) disable iff (!rst_n)
                     ctrl_fsm_o.mhpmevent.id_ld_stall |-> ctrl_fsm_o.mhpmevent.id_invalid)
      else `uvm_error("controller", "mhpmevent.id_ld_stall not a subset of mhpmevent.id_invalid")

  // Assert that wb_data_stall is a subset of wb_invalid
  a_mhpevent_wb_data_stall_subset:
    assert property (@(posedge clk) disable iff (!rst_n)
                     ctrl_fsm_o.mhpmevent.wb_data_stall |-> ctrl_fsm_o.mhpmevent.wb_invalid)
      else `uvm_error("controller", "mhpmevent.wb_data_stall not a subset of mhpmevent.wb_invalid")

  // Assert that interrupts are not allowed when WB stage has an LSU
  // instruction (cnt_q != 0)
  a_block_interrupts:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.lsu_en) |-> !interrupt_allowed)
      else `uvm_error("controller", "interrupt_allowed high while LSU is in WB")

// Only include following assertions if X_EXT=1
generate;
  if (X_EXT) begin

    // Assert that a CSR instruction that is accepted by both eXtension interface and pipeline is
    // flagged as killed on the eXtension interface
    a_duplicate_csr_kill:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (id_ex_pipe_i.xif_en && id_ex_pipe_i.xif_meta.accepted) && id_ex_pipe_i.csr_en && !csr_illegal_i &&
                    (id_ex_pipe_i.instr_valid && !ctrl_fsm_o.halt_ex && !ctrl_fsm_o.kill_ex)
                    |-> xif_commit_kill)
      else `uvm_error("controller", "Duplicate CSR instruction not killed")

    // Assert that a CSR instruction that is accepted by both eXtension interface and pipeline
    // causes an illegal instruction
    // TODO: The checks for mpu_status and bus_resp.err below can be removed once the
    //       xif offload is fully implemented (no offload if mpu or bus error occured in IF)
    a_duplicate_csr_illegal:
      assert property (@(posedge clk) disable iff (!rst_n)
                      ex_valid_i && wb_ready_i && (id_ex_pipe_i.xif_en && id_ex_pipe_i.xif_meta.accepted) && id_ex_pipe_i.csr_en && !csr_illegal_i &&
                      !((id_ex_pipe_i.instr.mpu_status != MPU_OK) || (id_ex_pipe_i.instr.bus_resp.err))
                      |=> exception_in_wb && (exception_cause_wb == EXC_CAUSE_ILLEGAL_INSN))
        else `uvm_error("controller", "Duplicate CSR instruction not mardked as illegal")

    // Never kill offloaded instructions in WB (received commit_kill=0 in EX)
    a_offload_kill_wb:
      assert property (@(posedge clk) disable iff (!rst_n)
                        (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.xif_en) |-> !ctrl_fsm_o.kill_wb)
        else `uvm_error("controller", "Offloaded instruction killed in WB")

    // xif_commit_if.commit_valid one cycle per offloaded instruction
    a_single_commit_valid:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (xif_commit_valid && ex_valid_i && !wb_ready_i) |=> !xif_commit_valid until_with (ex_valid_i && wb_ready_i))
        else `uvm_error("controller", "Multiple xif.commit_valid for one instruction")

    // Do not kill commited offloaded instructions if they stay in EX for multiple cycles
    a_nokill_commited_xif:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (xif_commit_valid && ex_valid_i && !wb_ready_i) |=> !ctrl_fsm_o.kill_ex until_with (ex_valid_i && wb_ready_i))
        else `uvm_error("controller", "Committed xif instruction was killed in EX")

    // EX shall be halted if offloaded instruction in WB can cause an exception
    a_halt_ex_xif_exception:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.xif_en && ex_wb_pipe_i.xif_meta.exception)
                      |-> ctrl_fsm_o.halt_ex)
        else `uvm_error("controller", "EX not halted while offloaded instruction in WB can cause an exception")

    // Helper logic to check that all offloaded instructions recive commit_valid
    logic commit_valid_flag;
    logic commit_kill_flag;
    always_ff @(posedge clk, negedge rst_n) begin
      if (rst_n == 1'b0) begin
        commit_valid_flag <= 1'b0;
        commit_kill_flag  <= 1'b0;
      end else begin
        // Clear flag if EX is killed or instruction goes to WB
        if (ctrl_fsm_o.kill_ex || (ex_valid_i && wb_ready_i)) begin
          commit_valid_flag <= 1'b0;
          commit_kill_flag  <= 1'b0;
        // Set flag when commit_valid goes high
        end else if (xif_commit_valid) begin
          commit_valid_flag <= 1'b1;
          commit_kill_flag  <= xif_commit_kill;
        end
      end
    end

    // When WB is ready, and EX contains an offloaded instructon,
    // commit_valid must be 1, or must have been one while the instruction
    // was in the EX stage.
    a_offload_commit_valid:
      assert property (@(posedge clk) disable iff (!rst_n)
                      // Xif instruction is in EX, and it either gets killed or goes to WB
                      ((id_ex_pipe_i.instr_valid && id_ex_pipe_i.xif_en && !ctrl_fsm_o.halt_ex) &&
                        (ctrl_fsm_o.kill_ex || wb_ready_i))
                      // Must receive commit_valid, or commit_valid has already been recieved
                      |-> (xif_commit_valid || commit_valid_flag))
        else `uvm_error("controller", "Offloaded instruction did not receive commit_valid")

    // When WB is ready, and EX contains an offloaded instructon that was rejected,
    // commit_kill must be 1, or must have been one while the instruction
    // was in the EX stage.
    a_offload_commit_kill_rejected:
      assert property (@(posedge clk) disable iff (!rst_n)
                      // Rejected Xif instruction is in EX, must be killed
                      ((id_ex_pipe_i.instr_valid && id_ex_pipe_i.xif_en && !id_ex_pipe_i.xif_meta.accepted && !ctrl_fsm_o.halt_ex) &&
                        (ctrl_fsm_o.kill_ex || wb_ready_i))
                      // Must receive commit_kill, or commit_kill has already been recieved
                      |-> (xif_commit_kill || commit_kill_flag))
        else `uvm_error("controller", "Rejected offloaded instruction did not receive commit_kill")

    // Any offloaded instruction that reaches WB must have been accepted by the eXtension interface
    a_offload_in_wb_was_accepted:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.xif_en)
                      |-> ex_wb_pipe_i.xif_meta.accepted)
        else `uvm_error("controller", "Offloaded instruction in WB was not preciously accepted by the eXtension interface")

  end
endgenerate

  // Assert that debug is not allowed when WB stage has an LSU
  // instruction (cnt_q != 0) with no watchpoint match attached to it.

  a_block_debug:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.lsu_en) && (ctrl_fsm_cs == FUNCTIONAL)
                     |->
                     !async_debug_allowed)
      else `uvm_error("controller", "debug_allowed high while LSU is in WB")


  // Ensure bubble in EX while in SLEEP mode.
  // WFI or WFE instruction will be in WB
  // Bubble is needed to avoid any LSU instructions to go on the bus while handling the WFI, as this
  // could cause the pipeline not to be interruptible when we wake up to an interrupt that should be taken.
  a_wfi_wfe_bubbles:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == SLEEP)
                      |->
                      !(id_ex_pipe_i.instr_valid) && ((ex_wb_pipe_i.sys_en && ex_wb_pipe_i.instr_valid && (ex_wb_pipe_i.sys_wfi_insn || ex_wb_pipe_i.sys_wfe_insn))))
      else `uvm_error("controller", "EX stage not empty while in SLEEP state")

  // When halt_limited_wb is asserted, there can only be WFI instruction in WB
  a_halt_limited_wfi:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_o.halt_limited_wb) |-> (ex_wb_pipe_i.sys_en && (ex_wb_pipe_i.sys_wfi_insn || ex_wb_pipe_i.sys_wfe_insn) && ex_wb_pipe_i.instr_valid))
      else `uvm_error("controller", "No WFI or WFE in WB while halt_limited_wb is asserted")

  // Check that the pipeline is interruptible when we wake up from SLEEP
  a_wakeup_interruptible:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == SLEEP) && (ctrl_fsm_ns == FUNCTIONAL)
                      |=>
                      interrupt_allowed)
      else `uvm_error("controller", "Pipeline not interruptible after waking from SLEEP")

  // When entering or in SLEEP mode, no LSU should perform a request.
  a_enter_sleep_no_lsu:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == SLEEP) || (ctrl_fsm_ns == SLEEP)
                      |=>
                      !lsu_trans_valid_i)
      else `uvm_error("controller", "LSU trans_valid high when entering or in SLEEP")


  // WFI cannot wake up to wu_wfe_i pin
  // Disregarding debug related reasons to wake up
  a_no_wfi_wakeup_on_wfe:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_cs == SLEEP) && ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_wfi_insn &&
                    !(irq_wu_ctrl_i || pending_nmi) && wu_wfe_i && !pending_async_debug
                    |=>
                    (ctrl_fsm_cs == SLEEP))
    else `uvm_error("controller", "WFI instruction woke up to wu_wfe_i")

  // WFE wakes up to either interrupts (including NMI) or wu_wfe_i
  // Disregarding debug related reasons to wake up
  a_wfe_wakeup:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_cs == SLEEP) && ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_wfe_insn &&
                    (irq_wu_ctrl_i || wu_wfe_i || pending_nmi) && !pending_async_debug
                    |->
                    (ctrl_fsm_ns == FUNCTIONAL))
    else `uvm_error("controller", "WFE must wake up to interuppts or wu_wfe_i")

  // Assert correct exception cause for mpu load faults (checks default of cause mux)
  a_mpu_re_cause_mux:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (mpu_status_wb_i == MPU_RE_FAULT) |-> (exception_cause_wb == EXC_CAUSE_LOAD_FAULT))
      else `uvm_error("controller", "Wrong exception cause for MPU read fault")


  // Helper logic to track first occuring bus error
  // Note: Supports max two outstanding transactions
  logic [1:0] outstanding_type;
  logic [1:0] outstanding_count;
  logic bus_error_is_write;
  logic bus_error_latched;
  logic retire_at_error; // 1 if wb_valid_i is high when the bus error is active
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      outstanding_type <= 2'b00;
      outstanding_count <= 2'b00;
      bus_error_latched <= 1'b0;
      bus_error_is_write <= 1'b0;
      retire_at_error <= 1'b0;
    end else begin
      // Req, no rvalid
      if (m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt && !m_c_obi_data_if.s_rvalid.rvalid) begin
        // Increase outstanding counter
        outstanding_count <= outstanding_count + 2'b01;

        if (outstanding_count == 2'b00) begin
          // No outstanding, assign first entry
          outstanding_type[0] <= m_c_obi_data_if.req_payload.we;
        end else begin
          // One outstanding, shift and assign first entry
          outstanding_type[1] <= outstanding_type[0];
          outstanding_type[0] <= m_c_obi_data_if.req_payload.we;
        end

      // rvalid, no req
      end else if (!(m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt) && m_c_obi_data_if.s_rvalid.rvalid) begin
        // Decrease outstanding counter
        outstanding_count <= outstanding_count - 2'b01;

      // req and rvalid
      end else if ((m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt) && m_c_obi_data_if.s_rvalid.rvalid) begin
        if (outstanding_count == 2'b10) begin
          // Two outstanding, shift and replace index 0
          outstanding_type[1] <= outstanding_type[0];
          outstanding_type[0] <= m_c_obi_data_if.req_payload.we;
        end else begin
          // One outstanding, replate index 0
          outstanding_type[0] <= m_c_obi_data_if.req_payload.we;
        end
      end


      if (m_c_obi_data_if.s_rvalid.rvalid && m_c_obi_data_if.resp_payload.err && !bus_error_latched) begin
        bus_error_is_write <= outstanding_count == 2'b01 ? outstanding_type[0] : outstanding_type[1];
        bus_error_latched <= 1'b1;
        retire_at_error <= wb_valid_i;
      end else begin
        if (ctrl_fsm_o.pc_set && ctrl_fsm_o.pc_mux == PC_TRAP_NMI) begin
          bus_error_latched <= 1'b0;
        end
      end
    end
  end

  // Check that controller latches correct type for bus error
  a_latched_bus_error:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (m_c_obi_data_if.s_rvalid.rvalid && m_c_obi_data_if.resp_payload.err && !bus_error_latched)
                      |=> (nmi_is_store_q == bus_error_is_write) &&
                          (nmi_pending_q == bus_error_latched) && bus_error_latched)
      else `uvm_error("controller", "Wrong type for LSU bus error")



  // Helper logic. Counting number of retired instructions while an NMI is pending outside of debug mode or single stepping.
  logic [1:0] valid_cnt;
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      valid_cnt <= '0;
    end else begin
      if (bus_error_latched) begin
        if (wb_valid_i && (last_op_wb_i || abort_op_wb_i) && !ctrl_fsm_o.debug_mode && !(dcsr_i.step && !dcsr_i.stepie)) begin
          valid_cnt <= valid_cnt + 1'b1;
        end
      end else begin
        valid_cnt <= '0;
      end
    end
  end

  // valid_cnt will start counting one cycle after the LSU bus error has
  // become visible to the core. If an instruction was retired (wb_valid=1)
  // when the bus error arrived, we will allow one more instruction to retire
  // before the NMI is taken (counter < 2). If we didn't retire at the same time as the bus
  // error, we allow two instructions to retire (counter < 3). In any case, max two
  // instructions will retire after the bus error has become visible to the
  // core.
  a_nmi_handler_max_retire:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (valid_cnt < (retire_at_error ? 2'b10 : 2'b11)))
    else `uvm_error("controller", "NMI handler not taken within two instruction retirements")

if (CLIC) begin

  // After a pc_set to PC_TRAP_CLICV, only the following jump targets are allowed:
  // PC_POINTER : Normal execution, the pointer target is being fetched
  // PC_TRAP_EXC: The pointer fetch has a synchronous exception
  // PC_TRAP_NMI: A buffered write may receive a data_err_i long after the instruction has left WB.
  a_clicv_next_pc_set:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_CLICV))
                  |=> !ctrl_fsm_o.pc_set until (ctrl_fsm_o.pc_set && ((ctrl_fsm_o.pc_mux == PC_POINTER)        ||
                                                                      (ctrl_fsm_o.pc_mux == PC_TRAP_EXC)       ||
                                                                      (ctrl_fsm_o.pc_mux == PC_TRAP_NMI))))
    else `uvm_error("controller", "Illegal pc_mux after pointer fetch")


  a_clic_ptr_functional_only:
  assert property (@(posedge clk) disable iff (!rst_n)
                  ((ctrl_fsm_cs != FUNCTIONAL)
                  |->
                  !(mret_ptr_in_wb || clic_ptr_in_wb)))
    else `uvm_error("controller", "clic_ptr_in_wb or mret_ptr_in_wb while not in FUNCTIONAL state.")

  // Killing the ID stage should never happen if the ID stage is waiting for a CLIC pointer
  a_clic_ptr_in_progress_no_kill:
  assert property (@(posedge clk) disable iff (!rst_n)
                  clic_ptr_in_progress_id
                  |->
                  !ctrl_fsm_o.kill_id)
    else `uvm_error("controller", "ID stage killed while clic_ptr_in_progress_id is high")

  a_nmi_irq_level_stable:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_NMI))
                  |=>
                  $stable(mintstatus_i))
    else `uvm_error("controller", "mintstatus changed after taking an NMI")

  // The only possible cause for a instruction misaligned exception is an mret pointer.
  a_mret_ptr_exception:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (exception_cause_wb == EXC_CAUSE_INSTR_MISALIGNED) &&
                  exception_in_wb
                  |->
                  mret_ptr_in_wb)

    else `uvm_error("controller", "Instruction address misaligned exception without mret pointer.")

end else begin // CLIC
  // Check that CLIC related signals are inactive when CLIC is not configured.
  a_clic_inactive:
  assert property (@(posedge clk) disable iff (!rst_n)
                  1'b1
                  |->
                  (clic_ptr_in_progress_id_set != 1'b1)     &&
                  !ctrl_fsm_o.csr_cause.minhv       &&
                  !ctrl_fsm_o.csr_clear_minhv       &&
                  !mcause_i.minhv                   &&
                  !if_id_pipe_i.instr_meta.clic_ptr &&
                  !id_ex_pipe_i.instr_meta.clic_ptr &&
                  !ex_wb_pipe_i.instr_meta.clic_ptr &&
                  !if_id_pipe_i.instr_meta.mret_ptr &&
                  !id_ex_pipe_i.instr_meta.mret_ptr &&
                  !ex_wb_pipe_i.instr_meta.mret_ptr &&
                  !ctrl_fsm_o.pc_set_clicv          &&
                  !(|ctrl_fsm_o.irq_level)          &&
                  !ctrl_fsm_o.irq_shv               &&
                  !(|ctrl_fsm_o.irq_priv) )
    else `uvm_error("controller", "CLIC signals active when CLIC is not configured.")
end



  // Detect if we are in the middle of a multi operation sequence
  // Basically check if the oldest instruction in the pipeline is a 'first_op'
  // - if not, we have an unfinished sequence and cannot interrupt it.
  // Used to determine if we are allowed to take debug or interrupts
  logic sequence_interruptible_alt;
  always_comb begin
    // Excluding the case of the current state being DEBUG_TAKEN. In this state, we may have a
    // lsu instruction in WB with !first_op if this instruction caused a watchpoint trigger.
    // The controller will reset the flop based flag when this is detected and the code below
    // would not match if not detecting the same case.
    if (ex_wb_pipe_i.instr_valid && (ctrl_fsm_cs == DEBUG_TAKEN)) begin
      sequence_interruptible_alt = 1'b1;
    end else if (ex_wb_pipe_i.instr_valid) begin
      sequence_interruptible_alt = ex_wb_pipe_i.first_op;
    end else if (id_ex_pipe_i.instr_valid) begin
      sequence_interruptible_alt = first_op_ex_i;
    end else if (if_id_pipe_i.instr_valid) begin
      sequence_interruptible_alt = first_op_id_i;
    end else if (prefetch_valid_if_i) begin
      sequence_interruptible_alt = first_op_if_i;
    end else begin
      // If no instruction is ready in the whole pipeline (including IF), then there are nothing in progress
      // and we should safely be able to interrupt unless the IF stage is waiting for a table jump pointer or
      // a CLIC pointer that is a side effect of an mret.
      sequence_interruptible_alt = !(prefetch_is_tbljmp_ptr_if_i || prefetch_is_mret_ptr_if_i);
    end
  end

  // Check if we are allowed to halt the ID stage.
  // If ID stage contains a non-first operation, we cannot halt ID as that
  // could cause a deadlock because a sequence cannot finish through ID.
  // If ID stage does not contain a valid instruction, the same check is performed
  // for the IF stage (although this is likely not needed).
  // todo: This logic currently does not match the RTL version when not gating instruction in IF due to exceptions.
  //       Assertions checking SVA vs RTL commented out.
  logic id_stage_haltable_alt;
  always_comb begin
    if (if_id_pipe_i.instr_valid) begin
      id_stage_haltable_alt = first_op_id_i;
    end else if (prefetch_valid_if_i) begin
      id_stage_haltable_alt = first_op_if_i;
    end else begin
      // If no instruction is ready in the whole pipeline (including IF), then there are nothing in progress
      // and we should safely be able to halt ID unless the IF stage is waiting for a table jump pointer or
      // a CLIC pointer that is a side effect of an mret
      id_stage_haltable_alt = !(prefetch_is_tbljmp_ptr_if_i || prefetch_is_mret_ptr_if_i);
    end
  end

  a_no_sequence_interrupt:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (!sequence_interruptible |-> !ctrl_fsm_o.irq_ack))
    else `uvm_error("controller", "Sequence broken by interrupt")

  a_interruptible_equivalency:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (sequence_interruptible_alt == sequence_interruptible))
    else `uvm_error("controller", "first_op_done_wb not matching !sequence_interruptible")

  a_no_sequence_nmi:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (!sequence_interruptible |-> !(ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_NMI))))
    else `uvm_error("controller", "Sequence broken by NMI")

  a_no_sequence_ext_debug:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (!sequence_interruptible |-> !(ctrl_fsm_o.dbg_ack && (debug_cause_q == DBG_CAUSE_HALTREQ)))) // todo: timing of (debug_cause_q == DBG_CAUSE_HALTREQ) seems wrong (and whole calsuse should not be needed)
    else `uvm_error("controller", "Sequence broken by external debug")

  a_no_sequence_wb_kill:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (!sequence_interruptible |-> !ctrl_fsm_o.kill_wb))
    else `uvm_error("controller", "Sequence broken by external debug")

/* todo: Bring back in if id_stage_haltable_alt can be correctly calculated.
  // Check that we do not allow ID stage to be halted for pending interrupts/debug if a sequence is not done
  // in the ID stage.
  a_id_stage_haltable:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (id_stage_haltable_alt == id_stage_haltable))
    else `uvm_error("controller", "id_stage_haltable not correct")
*/
  // Assert that we have no pc_set in the same cycle as a CSR write in WB requires flushing of the pipeline
  a_csr_wr_in_wb_no_fetch:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (csr_wr_in_wb_flush_i && !ctrl_fsm_o.kill_wb) |-> (!ctrl_fsm_o.pc_set))
    else `uvm_error("controller", "Fetching new instruction before CSR values are updated")

  // Check that id stage is haltable after passing through an operation with abort_op=1
  a_id_halt_abort:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (id_valid_i && ex_ready_i && abort_op_id_i)
                    |=>
                    id_stage_haltable)
    else `uvm_error("controller", "ID stage not haltable after a deasserted operation")

  // Check that wb stage is interruptible after passing through an operation with exception_in_wb
  a_wb_interruptible_abort:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (wb_valid_i && abort_op_wb_i)
                    |=>
                    sequence_interruptible)
    else `uvm_error("controller", "sequence_interruptible should be 1 after an exception has been taken.")


  // Check that id stage is haltable after passing through an operation with abort_op=1
  a_id_halt_last:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (id_valid_i && ex_ready_i && last_op_id_i)
                    |=>
                    id_stage_haltable)
    else `uvm_error("controller", "ID stage not haltable after a deasserted operation")

  // Check that wb stage is interruptible after passing through an operation with exception_in_wb
  a_wb_interruptible_last:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (wb_valid_i && last_op_wb_i)
                    |=>
                    sequence_interruptible)
    else `uvm_error("controller", "sequence_interruptible should be 1 after an exception has been taken.")

  // No new exception may occur in WB unless wb was ready the cycle before
  a_wb_ready_exception:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (!wb_ready_i)
                    |=>
                    $stable(exception_in_wb))
    else `uvm_error("controller", "New exception in WB without WB being ready.")


  // MRET in WB always results in cst_restore_mret being set
  a_mret_in_wb_csr_restore_mret:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (mret_in_wb && wb_valid_i) |-> ctrl_fsm_o.csr_restore_mret)
    else `uvm_error("controller", "MRET in WB did not result in csr_restore_mret.")


  // No CSR should be updated during sleep, and hence no irq_enable_stall should be active.
  a_no_irq_write_during_sleep:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_cs == SLEEP) |-> !ctrl_byp_i.irq_enable_stall)
    else `uvm_error("controller", "irq_enable_stall while SLEEPING should not happen.")

  // Handling of mret in ID requires mcause.minhv to be stable
  // This assertion checks that both operations of secure mrets in ID see the same mcause.minhv.
  a_mret_id_ex_minhv_stable:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (id_valid_i && ex_ready_i && sys_en_id_i && sys_mret_id_i)
                    |=>
                    $stable(mcause_i.minhv))
    else `uvm_error("controller", "mcause.minhv not stable when mret goes from ID to EX")


  a_mret_ex_wb_minhv_stable:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ex_valid_i && wb_ready_i && id_ex_pipe_i.sys_en && id_ex_pipe_i.sys_mret_insn)
                    |=>
                    $stable(mcause_i.minhv))
    else `uvm_error("controller", "mcause.minhv not stable when mret goes from EX to WB")


  //  mret CSR restores are done in parallell with other events in the controller except for nmi/interrupt/debug entries.
  // Check that CSR restores for mret cannot happen while the WB stage is halted.
  a_mret_restore_halt:
  assert property (@(posedge clk) disable iff (!rst_n)
                  ctrl_fsm_o.csr_restore_mret
                  |->
                  !ctrl_fsm_o.halt_wb)
  else `uvm_error("controller", "csr_restore_mret when WB is halted")

  if (CLIC) begin
    // CSR instructions should be stalled in ID if there is a CLIC or mret pointer in EX or WB (RAW hazard)
    a_csr_stall_on_ptr:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (csr_en_id_i && if_id_pipe_i.instr_valid) &&
                    (((id_ex_pipe_i.instr_meta.clic_ptr || id_ex_pipe_i.instr_meta.mret_ptr) && id_ex_pipe_i.instr_valid) ||
                    ((ex_wb_pipe_i.instr_meta.clic_ptr || ex_wb_pipe_i.instr_meta.mret_ptr) && ex_wb_pipe_i.instr_valid))
                    |->
                    !id_valid_i)
    else `uvm_error("controller", "CSR* not stalled in ID when CLIC pointer is in EX or WB")
  end


  // When interrupts or debug is taken, the PC stored to dpc or mepc cannot come from a pointer
  a_no_context_from_pointer:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_o.dbg_ack || ctrl_fsm_o.irq_ack || (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_NMI)))
                  |->
                  !(((pipe_pc_mux_ctrl == PC_WB) && (ex_wb_pipe_i.instr_meta.clic_ptr || ex_wb_pipe_i.instr_meta.mret_ptr || (ex_wb_pipe_i.instr_meta.tbljmp && ex_wb_pipe_i.last_op))) ||
                    ((pipe_pc_mux_ctrl == PC_EX) && (id_ex_pipe_i.instr_meta.clic_ptr || id_ex_pipe_i.instr_meta.mret_ptr || (id_ex_pipe_i.instr_meta.tbljmp && id_ex_pipe_i.last_op))) ||
                    ((pipe_pc_mux_ctrl == PC_ID) && (if_id_pipe_i.instr_meta.clic_ptr || if_id_pipe_i.instr_meta.mret_ptr || (if_id_pipe_i.instr_meta.tbljmp && last_op_id_i))) ||
                    ((pipe_pc_mux_ctrl == PC_IF) && ptr_in_if_i)))
  else `uvm_error("controller", "Pointer used for context storage")


  // Ensure interrupt is taken if woken up by an interrupt (unless a higher priority NMI or debug request woke up the core)
  a_sleep_to_irq:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_cs == SLEEP) &&
                  (ctrl_fsm_ns == FUNCTIONAL) &&
                  irq_wu_ctrl_i &&
                  !(pending_nmi || debug_req_i) &&
                  mstatus_i.mie
                  |=>
                  (ctrl_fsm_o.pc_mux == PC_TRAP_IRQ) || (ctrl_fsm_o.pc_mux == PC_TRAP_CLICV))
    else `uvm_error("controller", "Woke from sleep due to irq but irq not taken")

  // Ensure NMI is taken if woken up by an NMI
  a_sleep_to_nmi:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_cs == SLEEP) &&
                  (ctrl_fsm_ns == FUNCTIONAL) &&
                  pending_nmi
                  |=>
                  (ctrl_fsm_o.pc_mux == PC_TRAP_NMI))
    else `uvm_error("controller", "Woke from sleep due to NMI but NMI not taken")

  // woke_to_interrupt_q shall only be high for a single cycle
  a_woke_to_interrupt_single_cycle:
  assert property (@(posedge clk) disable iff (!rst_n)
                  woke_to_interrupt_q
                  |=>
                  !woke_to_interrupt_q)
    else `uvm_error("controller", "woke_to_interrupt_q asserted for more than one cycle")

  // Make sure no synchronous events are missed during RESET state
  a_no_event_during_reset:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_cs == RESET)
                  |->
                  !((pending_sync_debug && sync_debug_allowed)                  ||
                    (exception_in_wb && exception_allowed)                      ||
                    (wfi_in_wb || wfe_in_wb)                                    ||
                    (fence_in_wb || fencei_in_wb)                               ||
                    (dret_in_wb)                                                ||
                    (csr_wr_in_wb_flush_i)                                      ||
                    (csr_flush_ack_q)                                           ||
                    (branch_taken_ex)                                           ||
                    (jump_taken_id)                                             ||
                    (clic_ptr_in_id || mret_ptr_in_id)                          ||
                    (mret_in_wb || mret_ptr_in_wb)                              ||
                    (clic_ptr_in_wb)                                            ||
                    (pending_single_step || etrigger_in_wb)                     ||
                    (clic_ptr_in_id && id_valid_i && ex_ready_i)                ||
                    (mret_in_wb && !ctrl_fsm_o.kill_wb)                         ||
                    (mret_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb) ||
                    (clic_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb)))
    else `uvm_error("controller", "Synchronous event during RESET")

  // Make sure no synchronous events are missed during SLEEP state
  // During SLEEP, either a WFE of WFI instruction must be in WB
  // jump_taken_id is excluded below on purpose. This event may be true
  // while in sleep (condition was true at the time of WFI/WFE in WB and will be kept true
  // until SLEEP is exited).
  a_no_event_during_sleep:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_cs == SLEEP)
                  |->
                  (wfi_in_wb || wfe_in_wb) &&
                  !((pending_sync_debug && sync_debug_allowed)                  ||
                    (exception_in_wb && exception_allowed)                      ||
                    (fence_in_wb || fencei_in_wb)                               ||
                    (dret_in_wb)                                                ||
                    (csr_wr_in_wb_flush_i)                                      ||
                    (csr_flush_ack_q)                                           ||
                    (branch_taken_ex)                                           ||
                  //(jump_taken_id)                                             || // Left in on purpose, see a_stable_id_sleep
                    (clic_ptr_in_id || mret_ptr_in_id)                          ||
                    (mret_in_wb || mret_ptr_in_wb)                              ||
                    (clic_ptr_in_wb)                                            ||
                    (pending_single_step || etrigger_in_wb)                     ||
                    (clic_ptr_in_id && id_valid_i && ex_ready_i)                ||
                    (mret_in_wb && !ctrl_fsm_o.kill_wb)                         ||
                    (mret_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb) ||
                    (clic_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb)))
    else `uvm_error("controller", "Synchronous event during SLEEP")

  // Check that the if_id_pipe and jump_taken_id are stable when the FSM
  // is in the SLEEP state, just went from FUNCTIONAL to SLEEP or just went from
  // SLEEP to FUNCTIONAL.
  a_stable_id_sleep:
  assert property (@(posedge clk) disable iff (!rst_n)
                  ((ctrl_fsm_cs == SLEEP) ||
                   ((ctrl_fsm_cs == SLEEP) && ($past(ctrl_fsm_cs) == FUNCTIONAL)) ||
                   ((ctrl_fsm_cs == FUNCTIONAL) && ($past(ctrl_fsm_cs) == SLEEP)))
                   |->
                   $stable(if_id_pipe_i) && $stable(jump_taken_id))
    else `uvm_error("controller", "if_id_pipe or jump_taken_id not stable during SLEEP or transition to/from SLEEP")



  // Make sure no synchronous events are missed during DEBUG_TAKEN state caused by non-single-step
  // The following events may be active, and must be killed during DEBUG_TAKEN
  //   - Exceptions will be killed, unless they raised an ETRIGGER (RVFI needs the rvfi_valid)
  //   - WFI/WFE will be killed
  //   - fence[i] will be killed
  //   - CSR instructions requiring pipeline flush will be killed
  //   - Branches in EX will be killed
  //   - Jumps in ID will be killed
  //   - mret pointers in ID will be killed (unless the mret instruction itself finished in WB, then debug will not be allowed at all.)
  //   - mret instructions in WB will be killed.

  // The following events cannot be active during DEBUG_TAKEN:
  //   - dret instructions cannot be in WB while in DEBUG_TAKEN (will be an illegal instruction exception instead)
  //   - csr_flush_ack_q - Handshake flag one cycle after csr_wr_in_wb_flush_i.
  //   - CLIC pointer in ID: When a CLIC pointer is in the pipeline, debug is not allowed
  //   - mret or CLIC pointers in WB, debug is not allowed when these events are active.

  // pending_single step may be true for the following conditions, but will not affect the debug cause (debug cause was decided during the previous cycle)
  //   - An NMI occured (may happen at any time, and may assert pending_single_step even though we're currently handling another debug entry)
  //   - WB is not killed during DEBUG_TAKEN. This will only happen for entries due to trigger match or ebreak

  // pending_sync_debug and etrigger may be active as they may be the cause of debug entry and kept stable due to halting when going into DEBUG_TAKEN.
  a_no_event_during_debug_taken_nonstep:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_cs == DEBUG_TAKEN) &&
                  (debug_cause_q != DBG_CAUSE_STEP)
                  |->
                  !(//(pending_sync_debug && sync_debug_allowed)                    || // Left in on purpose, see comment above
                    (exception_in_wb && exception_allowed && !ctrl_fsm_o.kill_wb &&
                     (debug_cause_q != DBG_CAUSE_TRIGGER))                          ||
                    ((wfi_in_wb || wfe_in_wb) && !ctrl_fsm_o.kill_wb)               ||
                    ((fence_in_wb || fencei_in_wb) && !ctrl_fsm_o.kill_wb)          ||
                    (dret_in_wb)                                                    ||
                    (csr_wr_in_wb_flush_i && !ctrl_fsm_o.kill_wb)                   ||
                    (csr_flush_ack_q)                                               ||
                    (branch_taken_ex && !ctrl_fsm_o.kill_ex)                        ||
                    (jump_taken_id && !ctrl_fsm_o.kill_id)                          ||
                    (clic_ptr_in_id)                                                ||
                    (mret_ptr_in_id && !ctrl_fsm_o.kill_id)                         ||
                    (mret_in_wb && !ctrl_fsm_o.kill_wb)                             ||
                    (mret_ptr_in_wb)                                                ||
                    (clic_ptr_in_wb)                                                ||
                    (pending_single_step && !pending_nmi && !(debug_cause_q == DBG_CAUSE_TRIGGER) && !(debug_cause_q == DBG_CAUSE_EBREAK)) // NMI can come at any time
                    /*(etrigger_in_wb)*/                                            || // Left in on purpose, see comment above
                    (clic_ptr_in_id && id_valid_i && ex_ready_i)                    ||
                    (mret_in_wb && !ctrl_fsm_o.kill_wb)                             ||
                    (mret_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb)     ||
                    (clic_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb)))
    else `uvm_error("controller", "Synchronous event during DEBUG_TAKEN(not single step)")


    // Make sure no synchronous events are missed during DEBUG_TAKEN state caused by single stepping
    // If the stepped instruction was a CSR write requiring pipeline flushing, the event
    // csr_flush_ack_q (flush due to CSR can be done) will be active during DEBUG_TAKEN due to completing the instruction requiring flushing.
    // In single step mode, there are no other instructions in the pipeline once an instruction completes, and
    // execution is redirected to the debug module. This is effectively the same as a pipeline flush, and thus
    // ignoring csr_flush_ack_q is ok.
    a_no_event_during_debug_taken_step:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_cs == DEBUG_TAKEN) &&
                    (debug_cause_q == DBG_CAUSE_STEP)
                    |->
                    !((pending_sync_debug && sync_debug_allowed)                  ||
                      (exception_in_wb && exception_allowed)                      ||
                      ((wfi_in_wb || wfe_in_wb))                                  ||
                      ((fence_in_wb || fencei_in_wb))                             ||
                      (dret_in_wb)                                                ||
                      (csr_wr_in_wb_flush_i)                                      ||
                      //(csr_flush_ack_q)                                         || // Left in on purpose, see coment above
                      (branch_taken_ex)                                           ||
                      (jump_taken_id)                                             ||
                      (clic_ptr_in_id)                                            ||
                      (mret_ptr_in_id)                                            ||
                      (mret_in_wb)                                                ||
                      (mret_ptr_in_wb)                                            ||
                      (clic_ptr_in_wb)                                            ||
                      (pending_single_step && !pending_nmi)                       ||
                      (etrigger_in_wb)                                            ||
                      (clic_ptr_in_id && id_valid_i && ex_ready_i)                ||
                      (mret_in_wb && !ctrl_fsm_o.kill_wb)                         ||
                      (mret_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb) ||
                      (clic_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb)))
      else `uvm_error("controller", "Synchronous event during DEBUG_TAKEN(single stepping)")

generate
  if (DEBUG) begin
    // Check that no new instructions (first_op=1) are valid in ID or EX when a single step is taken
    // In case of interrupt (including NMI) during step, the instruction being stepped could be in any stage, and will get killed.
    // Aborted instructions may cause early termination of sequences. Either we jump to the exception handler before debug entry,
    // or straight to debug in case of a trigger match.
    a_single_step_pipecheck :
      assert property (@(posedge clk) disable iff (!rst_n)
              (pending_single_step && (ctrl_fsm_ns == DEBUG_TAKEN)
              |-> ((!(id_ex_pipe_i.instr_valid && first_op_ex_i) && !(if_id_pipe_i.instr_valid && if_id_pipe_i.first_op))) ||
                  ((ctrl_fsm_o.irq_ack || (pending_nmi && nmi_allowed)) && ctrl_fsm_o.kill_if && ctrl_fsm_o.kill_id && ctrl_fsm_o.kill_ex && ctrl_fsm_o.kill_wb)))

        else `uvm_error("controller", "ID and EX not empty when when single step is taken")

     // Check trigger match never happens during debug_mode
    a_trigger_match_in_debug :
      assert property (@(posedge clk) disable iff (!rst_n)
              ctrl_fsm_o.debug_mode |-> !trigger_match_in_wb)
        else `uvm_error("controller", "Trigger match during debug mode")

    a_lsu_wp_debug:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == DEBUG_TAKEN) && (ex_wb_pipe_i.lsu_en && ex_wb_pipe_i.instr_valid)
                      |->
                      $past(wpt_match_wb_i))
        else `uvm_error("conroller", "LSU active in WB during DEBUG_TAKEN with no preceeding watchpoint trigger")

    // MRET in WB shall not update CSRs if WB stage is halted (debug entry)
    a_mret_in_wb_halt_csr_restore_mret:
      assert property (@(posedge clk) disable iff (!rst_n)
                        (mret_in_wb && ctrl_fsm_o.halt_wb) |-> !ctrl_fsm_o.csr_restore_mret)
        else `uvm_error("controller", "MRET in WB restored CSRs when WB was halted.")

    // etrigger_in_wb shall only be set when there is an exception in wb
    a_etrig_exception:
      assert property (@(posedge clk) disable iff (!rst_n)
                        etrigger_in_wb |-> exception_in_wb)
        else `uvm_error("controller", "etrigger_in_wb when there is no exception in WB")

     // Only halt LSU instruction in WB for watchpoint trigger matches
    a_halt_lsu_wb:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.lsu_en) && ctrl_fsm_o.halt_wb
                      |->
                      wpt_match_wb_i)
        else `uvm_error("controller", "LSU in WB halted without watchpoint trigger match")
    // Check that debug is always taken when a watchpoint trigger is arrives in WB
    // The watchpoint is halted during its first cycle in WB, thus checking during FUNCTIONAL state only,
    // as the watchpoint will also be valid during DEBUG_TAKEN, but then the decision already has been made and
    // the controller will go back to FUNCTIONAL.
    a_wpt_debug_entry:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ex_wb_pipe_i.instr_valid && wpt_match_wb_i) && (ctrl_fsm_cs == FUNCTIONAL)
                      |->
                      (abort_op_wb_i && (ctrl_fsm_ns == DEBUG_TAKEN)))
        else `uvm_error("controller", "Debug not entered on a WPT match")

    // Ensure debug mode is entered if woken up by a debug request (unless a higher priority NMI woke up the core)
    a_sleep_to_debug:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == SLEEP) &&
                      (ctrl_fsm_ns == FUNCTIONAL) &&
                      debug_req_i &&
                      !pending_nmi
                      |=>
                      (ctrl_fsm_ns == DEBUG_TAKEN))
        else `uvm_error("controller", "Woke from sleep due to debug_req but debug mode not entered")

    // woke_to_debug_q shall only be high for a single cycle
    a_woke_to_debug_single_cycle:
      assert property (@(posedge clk) disable iff (!rst_n)
                      woke_to_debug_q
                      |=>
                      !woke_to_debug_q)
        else `uvm_error("controller", "woke_to_debug_q asserted for more than one cycle")

    // The register file shall never be written during DEBUG_TAKEN state
    // Instructions in WB are generally killed during this state, with the exception of
    // ebreak and triggers. Ebreak and triggers shall never write to the RF anyway.
    a_debug_taken_rf_write:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == DEBUG_TAKEN)
                      |->
                      !rf_we_wb_i)
      else `uvm_error("controller", "Register file written during DEBUG_TAKEN state")

    // Debug cause shall be set to 'step' if an interrupt is taken during stepping
    // Interrupt will kill any potential synchronous debug cause that is present in the WB stage.
    a_irq_step_noetrig_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == FUNCTIONAL) &&
                      dcsr_i.step &&               // single stepping enabled in dcsr
                      !ctrl_fsm_o.debug_mode &&    // Not in debug mode
                      pending_single_step    &&    // Single step is pending
                      !etrigger_in_wb        &&    // No exception trigger (would get higher priority cause 'trigger')
                      ((ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_IRQ)) ||      // Step caused by taking a non-SHV interrupt
                      (clic_ptr_in_wb && ex_wb_pipe_i.instr_valid))                     // or step caused by a CLIC pointer finishing taking a CLIC interrupt
                      |=>
                      (ctrl_fsm_cs == DEBUG_TAKEN) &&
                      (debug_cause_q == DBG_CAUSE_STEP))
        else `uvm_error("controller", "Wrong debug cause when taking an interrupt during single stepping")

if (CLIC) begin
    // While single stepping, debug cause shall be set to 'trigger' if a pointer for a SHV CLIC interrupt arrives in WB
    // with an exception and an exception trigger that matches the exception has been configured. (trigger > step)
    a_irq_step_etrig_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == FUNCTIONAL) &&
                      dcsr_i.step &&               // single stepping enabled in dcsr
                      !ctrl_fsm_o.debug_mode &&    // Not in debug mode
                      pending_single_step    &&    // Single step is pending
                      etrigger_in_wb         &&    // Exception trigger in CLIC pointer fetch
                      (clic_ptr_in_wb && ex_wb_pipe_i.instr_valid)  // Step caused by an excepted CLIC pointer finishing taking a CLIC interrupt
                      |=>
                      (ctrl_fsm_cs == DEBUG_TAKEN) &&
                      (debug_cause_q == DBG_CAUSE_TRIGGER))
        else `uvm_error("controller", "Wrong debug cause when taking a SHV interrupt with exception trigger on the pointer fetch")
end

    // Debug cause shall be set to 'step' if an NMI is taken during stepping
    // Taking an NMI has priority above async debug, so in case of a debug_req_i at the same cycle debug_cause should be 'step' and not 'haltreq'.
    a_nmi_step_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == FUNCTIONAL) &&
                      dcsr_i.step &&               // single stepping enabled in dcsr
                      !ctrl_fsm_o.debug_mode &&    // Not in debug mode
                      pending_single_step    &&    // Single step is pending
                      (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_NMI))  // Step caused by taking an NMI
                      |=>
                      (ctrl_fsm_cs == DEBUG_TAKEN) &&
                      (debug_cause_q == DBG_CAUSE_STEP))
        else `uvm_error("controller", "Wrong debug cause when taking an NMI during single stepping")

    // Single stepping an ebreak (that is not killed) with dcsr.ebreakm==0 shall result in either debug cause being step or
    // trigger, depending on if an exception trigger was configured or not.
    a_irq_step_ebreak_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == FUNCTIONAL) &&
                      dcsr_i.step &&                      // single stepping enabled in dcsr
                      !ctrl_fsm_o.debug_mode &&           // Not in debug mode
                      pending_single_step    &&           // Single step is pending
                      ebreak_in_wb && !dcsr_i.ebreakm &&  // Ebreak exception in WB
                      !ctrl_fsm_o.kill_wb                 // Ebreak instruction not killed (by NMI or interrupt)
                      |=>
                      (ctrl_fsm_cs == DEBUG_TAKEN) &&
                      (debug_cause_q == ($past(etrigger_in_wb) ? DBG_CAUSE_TRIGGER : DBG_CAUSE_STEP)))
        else `uvm_error("controller", "Wrong debug cause when single stepping an ebreak without dcsr.ebreakm set")

    // Any synchronous debug entry cause has priority over single step
    // If a pending_sync_debug is allowed to be taken at the same time as a pending_single_step, it must be because an interupt or NMI
    // caused the step, and thus wb_valid must not be 1.
    a_step_vs_sync_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (pending_sync_debug && sync_debug_allowed) &&
                      (ctrl_fsm_cs == FUNCTIONAL)
                      |->
                      !(pending_single_step && wb_valid_i))
        else `uvm_error("controller", "Flagging single step pending while there is a pending synchronous debug reason")

    // Any asynchronous debug entry cause has priority over single step
    // If a pending_async_debug is allowed to be taken at the same time as a pending_single_step, it must be because an interupt or NMI
    // caused the step, and thus wb_valid must not be 1.
    a_step_vs_async_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (pending_async_debug && async_debug_allowed) &&
                      (ctrl_fsm_cs == FUNCTIONAL)
                      |->
                      !(pending_single_step && wb_valid_i))
        else `uvm_error("controller", "Flagging single step pending while there is a pending asynchronous debug reason")


  end // DEBUG
endgenerate



endmodule

