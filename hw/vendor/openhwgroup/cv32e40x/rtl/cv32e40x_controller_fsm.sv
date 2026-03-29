// Copyright 202[x] Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License");
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
// You may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
// See the License for the specific language governing permissions and
// limitations under the License.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Øystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Additional contributions by:                                               //
//                                                                            //
// Design Name:    cv32e40x_controller_fsm                                 //
// Project Name:   CV32E40X                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    FSM of the pipeline controller                             //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_controller_fsm import cv32e40x_pkg::*;
#(
  parameter bit          X_EXT         = 0,
  parameter bit          DEBUG         = 1,
  parameter bit          CLIC          = 0,
  parameter int unsigned CLIC_ID_WIDTH = 5
)
(
  // Clocks and reset
  input  logic        clk,                        // Gated clock
  input  logic        rst_n,

  input  logic        fetch_enable_i,             // Start executing

  // From bypass logic
  input  ctrl_byp_t   ctrl_byp_i,

  // From IF stage
  input  logic [31:0] pc_if_i,
  input  logic        last_op_if_i,               // IF stage is handling the last operation of a sequence.
  input  logic        abort_op_if_i,              // IF stage contains an operation that will be aborted (bus error or MPU exception)

  // From ID stage
  input  if_id_pipe_t if_id_pipe_i,
  input  logic        alu_jmp_id_i,               // Jump in ID
  input  logic        sys_mret_id_i,              // mret in ID
  input  logic        alu_en_id_i,                // alu_en qualifier for jumps
  input  logic        sys_en_id_i,                // sys_en qualifier for mret
  input  logic        first_op_id_i,              // ID stage is handling the first operation of a sequence
  input  logic        last_op_id_i,               // ID stage is handling the last operation of a sequence
  input  logic        abort_op_id_i,              // ID stage contains an (to be) aborted instruction or sequence

  // From EX stage
  input  id_ex_pipe_t id_ex_pipe_i,
  input  logic        branch_decision_ex_i,       // branch decision signal from EX ALU
  input  logic        last_op_ex_i,               // EX stage contains the last operation of an instruction

  // From WB stage
  input  ex_wb_pipe_t   ex_wb_pipe_i,
  input  logic [1:0]    lsu_err_wb_i,               // LSU caused bus_error in WB stage, gated with data_rvalid_i inside load_store_unit
  input  logic          last_op_wb_i,               // WB stage contains the last operation of an instruction
  input  logic          abort_op_wb_i,              // WB stage contains an (to be) aborted instruction or sequence
  input  mpu_status_e   mpu_status_wb_i,            // MPU status (WB timing)
  input  align_status_e align_status_wb_i,          // Aligned status (atomics) in WB
  input  logic          wpt_match_wb_i,             // LSU watchpoint trigger (WB)


  // From LSU (WB)
  input  logic        data_stall_wb_i,            // WB stalled by LSU
  input  logic        lsu_valid_wb_i,             // LSU instruction in WB is valid

  input  logic        lsu_busy_i,                 // LSU is busy with outstanding transfers
  input  logic        lsu_interruptible_i,        // LSU can be interrupted

  // Interrupt Controller Signals
  input  logic        irq_wu_ctrl_i,              // Irq wakeup control
  input  logic        irq_req_ctrl_i,             // Irq request
  input  logic [9:0]  irq_id_ctrl_i,              // Irq id
  input  logic        irq_clic_shv_i,             // CLIC mode selective hardware vectoring
  input  logic [7:0]  irq_clic_level_i,           // CLIC mode current interrupt level
  input  logic [1:0]  irq_clic_priv_i,            // CLIC mode current interrupt privilege

  // Wakeup signal for WFE (from toplevel input)
  input  logic        wu_wfe_i,

  // From cs_registers
  input  logic  [1:0] mtvec_mode_i,
  input  dcsr_t       dcsr_i,
  input  mcause_t     mcause_i,
  input  mintstatus_t mintstatus_i,

  // Trigger module
  input  logic        etrigger_wb_i,              // Trigger module detected match in WB (etrigger)

  // Toplevel input
  input  logic        debug_req_i,                // External debug request

  // All controller FSM outputs
  output ctrl_fsm_t   ctrl_fsm_o,

  // CSR write strobes
  input  logic        csr_wr_in_wb_flush_i,

  // Stage valid/ready signals
  input  logic        if_valid_i,       // IF stage has valid (non-bubble) data for next stage
  input  logic        id_ready_i,       // ID stage is ready for new data
  input  logic        id_valid_i,       // ID stage has valid (non-bubble) data for next stage
  input  logic        ex_ready_i,       // EX stage is ready for new data
  input  logic        ex_valid_i,       // EX stage has valid (non-bubble) data for next stage
  input  logic        wb_ready_i,       // WB stage is ready for new data,
  input  logic        wb_valid_i,       // WB stage ha valid (non-bubble) data

  // Fencei flush handshake
  output logic        fencei_flush_req_o,
  input logic         fencei_flush_ack_i,

  // Data OBI interface monitor
  if_c_obi.monitor     m_c_obi_data_if,

  // eXtension interface
  if_xif.cpu_commit    xif_commit_if,
  input                xif_csr_error_i
);

   // FSM state encoding
  ctrl_state_e ctrl_fsm_cs, ctrl_fsm_ns;

  // Debug state
  debug_state_e debug_fsm_cs, debug_fsm_ns;

  // Sticky version of lsu_err_wb_i
  logic nmi_pending_q;
  logic nmi_is_store_q; // 1 for store, 0 for load

  // Debug mode
  logic debug_mode_n;
  logic debug_mode_q;

  // Signals used for halting IF after first instruction
  // during single step
  logic single_step_halt_if_n;
  logic single_step_halt_if_q; // Halting IF after issuing one insn in single step mode

  // ID signals
  logic sys_mret_id;             // MRET in ID
  logic jmp_id;                  // JAL, JALR in ID
  logic jump_in_id;
  logic jump_taken_id;
  logic clic_ptr_in_id; // CLIC pointer in ID
  logic mret_ptr_in_id; // mret pointer in ID

  // EX signals
  logic branch_in_ex;
  logic branch_taken_ex;

  logic branch_taken_n;
  logic branch_taken_q;

  // WB signals
  logic exception_in_wb;
  logic [10:0] exception_cause_wb;
  logic wfi_in_wb;
  logic wfe_in_wb;
  logic fencei_in_wb;
  logic fence_in_wb;
  logic mret_in_wb;
  logic mret_ptr_in_wb; // CLIC pointer caused by mret is in WB
  logic dret_in_wb;
  logic ebreak_in_wb;
  logic trigger_match_in_wb;   // mcontrol6 trigger in WB
  logic etrigger_in_wb;        // exception trigger in WB
  logic xif_in_wb;
  logic clic_ptr_in_wb;   // CLIC pointer caused by directly acking an SHV is in WB (no mret)

  logic pending_nmi;
  logic pending_nmi_early;
  logic pending_async_debug;
  logic pending_sync_debug;
  logic pending_single_step;
  logic pending_interrupt;


  // Flags for allowing interrupt and debug
  logic exception_allowed;
  logic interrupt_allowed;
  logic nmi_allowed;
  logic async_debug_allowed;
  logic sync_debug_allowed;
  logic single_step_allowed;

  // Flag for blocking interrupts due to debug conditions
  logic debug_interruptible;

  // Flag indicating there is a 'live' CLIC pointer in the pipeline
  // Used to block debug and interrupts until pointer fetch is done and the final ISR instruction PC is available.
  logic clic_ptr_in_pipeline;

  // Internal irq_ack for use when a (clic) pointer reaches ID stage and
  // we have single stepping enabled.
  logic non_shv_irq_ack;

  // Flops for debug cause
  logic [2:0] debug_cause_n;
  logic [2:0] debug_cause_q;

  // Cause of synchronous debug entry
  logic [2:0] sync_debug_cause;

  // Flop for remembering causes of wakeup
  logic       woke_to_debug_q;
  logic       woke_to_interrupt_q;

  logic [10:0] exc_cause; // id of taken interrupt. Max width, unused bits are tied off.

  logic       fence_req_set;
  logic       fence_req_clr;
  logic       fence_req_q;
  logic       fencei_req_and_ack_q;
  logic       fencei_ongoing;

  // Pipeline PC mux control
  pipe_pc_mux_e pipe_pc_mux_ctrl;

  // Flag for signalling that a new instruction arrived in WB.
  // Used for performance counters. High for one cycle, unless WB is halted
  // (for fence.i for example), then it will remain high until un-halted.
  logic       wb_counter_event;

  // Gated version of wb_counter_event
  // Do not count if halted or killed
  logic       wb_counter_event_gated;

  // Flop for acking flush requests due to CSR writes
  logic       csr_flush_ack_n;
  logic       csr_flush_ack_q;

  // Flag for checking if multi op instructions are in an interruptible state
  logic       sequence_in_progress_wb;
  logic       sequence_interruptible;

  // Flag for checking if ID stage can be halted
  // Used to not halt sequences in the middle, potentially causing deadlocks
  logic       sequence_in_progress_id;
  logic       id_stage_haltable;

  // Flag that is high during the cycle after an LSU instruction finishes in WB
  logic       interrupt_blanking_q;

  // Flop for tracking when a pointer fetch is in progress
  logic       clic_ptr_in_progress_id;
  logic       clic_ptr_in_progress_id_set;
  logic       clic_ptr_in_progress_id_clear;

  assign sequence_interruptible = !sequence_in_progress_wb;

  assign id_stage_haltable = !(sequence_in_progress_id || clic_ptr_in_progress_id);

  // Once the fencei handshake is initiated, it must complete and the instruction must retire.
  // The instruction retires when fencei_req_and_ack_q = 1
  assign fencei_ongoing = fencei_flush_req_o || fencei_req_and_ack_q;

  // Mux selector for vectored IRQ PC
  // Used for both basic mode and CLIC when shv == 0.
  assign ctrl_fsm_o.mtvec_pc_mux = ((mtvec_mode_i == 2'b0) || ((mtvec_mode_i == 2'b11) && !irq_clic_shv_i)) ? 5'h0 : exc_cause[4:0];

  // CLIC mode vectored PC mux is always the same as exc_cause.
  assign ctrl_fsm_o.mtvt_pc_mux = exc_cause[9:0];

  // Set which mtvec index to jump to when an NMI is taken
  // index 0 for non-vectored CLINT mode and CLIC mode, 0xF for vectored CLINT mode
  assign ctrl_fsm_o.nmi_mtvec_index = (mtvec_mode_i == 2'b01) ? 5'hF : 5'h0;



  ////////////////////////////////////////////////////////////////////
  // ID stage

  // A jump is taken in ID for jump instructions, and also for mret instructions
  // Checking validity of jump/mret instruction with if_id_pipe_i.instr_valid and the respective alu_en/sys_en.
  // Using the ID stage local instr_valid would bring halt_id and kill_id into the equation
  // causing a path from data_rvalid to instr_addr_o/instr_req_o/instr_memtype_o via pc_set.



  assign sys_mret_id = sys_en_id_i && sys_mret_id_i && if_id_pipe_i.instr_valid;
  assign jmp_id      = alu_en_id_i && alu_jmp_id_i  && if_id_pipe_i.instr_valid;

  // Detect that a jump is in the ID stage.
  // This will also be true for table jumps, as they are encoded as JAL instructions.
  //   An extra table jump flag is used in the logic for taken jumps to disinguish between
  //   regular jumps and table jumps.
  // Table jumps do an implicit read of the JVT CSR, so csr_stall must be accounted for.
  assign jump_in_id = (jmp_id && !if_id_pipe_i.instr_meta.tbljmp && !ctrl_byp_i.jalr_stall) ||
                      (jmp_id &&  if_id_pipe_i.instr_meta.tbljmp && !ctrl_byp_i.csr_stall ) ||
                      (sys_mret_id && !ctrl_byp_i.csr_stall);

  // Blocking on branch_taken_q, as a jump has already been taken
  assign jump_taken_id = jump_in_id && !branch_taken_q;

  // Detect clic pointers in ID
  assign clic_ptr_in_id = if_id_pipe_i.instr_valid && if_id_pipe_i.instr_meta.clic_ptr;

  // Detect mret pointers in ID
  assign mret_ptr_in_id = if_id_pipe_i.instr_valid && if_id_pipe_i.instr_meta.mret_ptr;

  // Note: RVFI does not use jump_taken_id (which is not in itself an issue). An assertion in id_stage_sva checks that the jump target remains stable.

  // EX stage
  // Branch taken for valid branch instructions in EX with valid decision

  assign branch_in_ex = id_ex_pipe_i.alu_bch && id_ex_pipe_i.alu_en && id_ex_pipe_i.instr_valid && branch_decision_ex_i;

  // Blocking on branch_taken_q, as a branch ha already been taken
  assign branch_taken_ex = branch_in_ex && !branch_taken_q;

  // Exception in WB if the following evaluates to 1
  // Not checking for ex_wb_pipe_i.last_op to enable exceptions to be taken as soon as possible for
  // split load/stores or Zc sequences.
  //
  // For ebreak instructions, the following scenarios are possible. Only one scenario could cause an exception:
  // priv_lvl | ebreakm | debug_mode | action
  //----------|---------|------------|-----------------------------------------
  //   M      |   0     |      0     | Exception
  //   M      |   0     |      1     | Debug entry (restart from dm_halt_addr_i)
  //   M      |   1     |      0     | Debug entry
  //   M      |   1     |      1     | Debug entry (restart from dm_halt_addr_i)
  //
  assign exception_in_wb = ((ex_wb_pipe_i.instr.mpu_status != MPU_OK)                                                      ||
                            (ex_wb_pipe_i.instr.align_status != ALIGN_OK)                                                  ||
                             ex_wb_pipe_i.instr.bus_resp.err                                                               ||
                             ex_wb_pipe_i.illegal_insn                                                                     ||
                            (ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_ecall_insn)                                           ||
                            (ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_ebrk_insn && (ex_wb_pipe_i.priv_lvl == PRIV_LVL_M) &&
                              !dcsr_i.ebreakm && !debug_mode_q) ||
                            (mpu_status_wb_i != MPU_OK) ||
                            (align_status_wb_i != ALIGN_OK)) && ex_wb_pipe_i.instr_valid;

  assign ctrl_fsm_o.exception_in_wb = exception_in_wb;

  // Set exception cause
  assign exception_cause_wb = (ex_wb_pipe_i.instr.mpu_status != MPU_OK)                                                      ? EXC_CAUSE_INSTR_FAULT      :
                              (ex_wb_pipe_i.instr.align_status != ALIGN_OK)                                                  ? EXC_CAUSE_INSTR_MISALIGNED :
                              ex_wb_pipe_i.instr.bus_resp.err                                                                ? EXC_CAUSE_INSTR_BUS_FAULT  :
                              ex_wb_pipe_i.illegal_insn                                                                      ? EXC_CAUSE_ILLEGAL_INSN     :
                              (ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_ecall_insn)                                           ? EXC_CAUSE_ECALL_MMODE      :
                              (ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_ebrk_insn && (ex_wb_pipe_i.priv_lvl == PRIV_LVL_M) &&
                                !dcsr_i.ebreakm && !debug_mode_q)                                                            ? EXC_CAUSE_BREAKPOINT       :
                              (mpu_status_wb_i == MPU_WR_FAULT)                                                              ? EXC_CAUSE_STORE_FAULT      :
                              (mpu_status_wb_i == MPU_RE_FAULT)                                                              ? EXC_CAUSE_LOAD_FAULT       :
                              (align_status_wb_i == ALIGN_WR_ERR)                                                            ? EXC_CAUSE_STORE_MISALIGNED :
                                                                                                                               EXC_CAUSE_LOAD_MISALIGNED;

  assign ctrl_fsm_o.exception_cause_wb = exception_cause_wb;

  // For now we are always allowed to take exceptions once they arrive in WB.
  // For a misaligned load/store with MPU error on the first half, the second half
  // will arrive in EX when the first half (with error) arrives in WB. The exception will
  // be taken and the bus transaction of the second half will be suppressed by the ctrl_fsm_o.kill_ex signal.
  // The only higher priority events are  NMI, debug and interrupts, and none of them are allowed if there is
  // a load/store in WB.
  assign exception_allowed = 1'b1;

  // wfi in wb
  assign wfi_in_wb = ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_wfi_insn && ex_wb_pipe_i.instr_valid;

  // wfe in wb
  assign wfe_in_wb = ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_wfe_insn && ex_wb_pipe_i.instr_valid;

  // fencei in wb
  assign fencei_in_wb = ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_fencei_insn && ex_wb_pipe_i.instr_valid;

  // fence in wb
  assign fence_in_wb  = ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_fence_insn && ex_wb_pipe_i.instr_valid;

  // mret in wb - only valid when last_op_wb_i == 1 (which means only mret that did not cause a CLIC pointer fetch)
  // Restricts CSR updates due to mret to not happen if the mret caused a CLIC pointer fetch, such CSR updates
  // should only happen once the instruction fully completes (pointer arrives in WB).
  assign mret_in_wb = ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_mret_insn && ex_wb_pipe_i.instr_valid && last_op_wb_i;

  // CLIC pointer (caused by mret) in WB.
  assign mret_ptr_in_wb = ex_wb_pipe_i.instr_meta.mret_ptr && ex_wb_pipe_i.instr_valid;

  // dret in wb
  assign dret_in_wb = ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_dret_insn && ex_wb_pipe_i.instr_valid;

  // ebreak in wb
  assign ebreak_in_wb = ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_ebrk_insn && ex_wb_pipe_i.instr_valid;

  // Trigger match in wb
  // Trigger_match during debug mode is masked in the trigger logic inside cs_registers.sv
  assign trigger_match_in_wb = ((ex_wb_pipe_i.trigger_match || wpt_match_wb_i) && ex_wb_pipe_i.instr_valid);

  // Only set the etrigger_in_wb flag when wb_valid is true (WB is not halted or killed).
  // If a higher priority event than taking an exception (NMI, external debug or interrupts) are present, wb_valid_i will be
  // suppressed by either halt_wb followed by kill_wb (debug), or kill_wb (NMI/interrupt).
  assign etrigger_in_wb = etrigger_wb_i && wb_valid_i;

  // An offloaded instruction is in WB
  assign xif_in_wb = (ex_wb_pipe_i.xif_en && ex_wb_pipe_i.instr_valid);

  // Regular CLIC pointer in WB (not caused by mret)
  assign clic_ptr_in_wb = ex_wb_pipe_i.instr_meta.clic_ptr && ex_wb_pipe_i.instr_valid;

  // Pending NMI
  // Using flopped version to avoid paths from data_err_i/data_rvalid_i to instr_* outputs
  assign pending_nmi = nmi_pending_q;

  // Early version of the pending_nmi signal, using the unflopped lsu_err_wb_i[0]
  // This signal is used for halting the ID stage in the same cycle as the bus error arrives.
  // This ensures that any instruction in the ID stage that may depend on the result of the faulted load
  // will not propagate to the EX stage. For cycles after lsu_err_wb_i[0] is
  // high, ID stage will be halted due to pending_nmi and !nmi_allowed.
  assign pending_nmi_early =  lsu_err_wb_i[0];

  // dcsr.nmip will always see a pending nmi if nmi_pending_q is set.
  // This CSR bit shall not be gated by debug mode or step without stepie
  assign ctrl_fsm_o.pending_nmi = nmi_pending_q;

  // Debug //

  // Single step will need to finish insn in WB, including LSU
  // LSU will now set valid_1_o only for second part of misaligned instructions.
  // We can always allow single step when checking for wb_valid_i in 'pending_single_step'
  // - no other instructions should be in the pipeline.
  assign single_step_allowed = 1'b1;

  /*
  Debug spec 1.0.0 (unratified as of Aug 9th '21)
  "If control is transferred to a trap handler while executing the instruction, then Debug Mode is
  re-entered immediately after the PC is changed to the trap handler, and the appropriate tval and
  cause registers are updated. In this case none of the trap handler is executed, and if the cause was
  a pending interrupt no instructions might be executed at all."

  Hence, a pending_single_step is asserted if we take an interrupt when we should be stepping.
  For any interruptible instructions (non-LSU), at any stage, we would kill the instruction and jump
  to debug mode without executing any instructions. Interrupt handler's first instruction will be in dpc.

  For LSU instructions that may not be killed (if they reach WB or stay in EX for >1 cycles),
  we are not allowed to take interrupts, and we will re-enter debug mode after finishing the LSU.
  Interrupt will then be taken when we enter the next step.
  */

  assign non_shv_irq_ack = ctrl_fsm_o.irq_ack && !irq_clic_shv_i;

  // single step becomes pending when the last operation of an instruction is done in WB (including CLIC pointers), or we ack a non-shv interrupt (including NMI).
  // If a CLIC SHV interrupt is taken during single step, a pointer that reaches WB will trigger the debug entry.
  //   - For un-faulted pointer fetches, the second fetch of the CLIC vectoring took place in ID, and the final SHV handler target address will be available from IF.
  //   - A faulted pointer fetch does not perform the second fetch. Instead the exception handler fetch will occur before entering debug due to stepping.
  // todo: Likely flop the wb_valid/last_op/abort_op to be able to evaluate all debug reasons (debug_req when pointer is in WB is not allowed, while single step is allowed)
  // todo: can this be merged with pending_sync_debug in the future?
  assign pending_single_step = (!debug_mode_q && dcsr_i.step && ((wb_valid_i && (last_op_wb_i || abort_op_wb_i)) || non_shv_irq_ack || (pending_nmi && nmi_allowed)));


  // Detect if there is a live CLIC pointer in the pipeline
  // This should block debug and interrupts
  generate
    if (CLIC) begin : gen_clic_pointer_flag
      // A CLIC pointer may be in the pipeline from the moment we start fetching (clic_ptr_in_progress_id == 1)
      // or while a pointer is in the EX or WB stages.
      assign clic_ptr_in_pipeline = (id_ex_pipe_i.instr_valid && id_ex_pipe_i.instr_meta.clic_ptr) ||
                                    (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.instr_meta.clic_ptr) ||
                                    clic_ptr_in_progress_id;
    end else begin : gen_basic_pointer_flag
      assign clic_ptr_in_pipeline = 1'b0;
    end
  endgenerate
  // External debug will kill insn in WB, do not allow if LSU is not interruptible, a fence.i handshake is taking place
  // or if an offloaded instruction is in WB.
  // LSU will not be interruptible if the outstanding counter != 0, or
  // a trans_valid has been clocked without ex_valid && wb_ready handshake.
  // When a fencei is present in WB and the LSU has completed all tranfers, the fencei handshake will be initiated. This must complete and the fencei instruction must retire before allowing external debug.
  // Any multi operation instruction (table jumps, push/pop and double moves) may not be interrupted once the first operation has completed its operation in WB.
  //   - This is guarded with using the sequence_interruptible, which tracks sequence progress through the WB stage.
  // When a CLIC pointer is in the pipeline stages EX or WB, we must block debug.
  //   - Debug would otherwise kill the pointer and use the address of the pointer for dpc. A following dret would then return to the mtvt table, losing program progress.
  //
  // Debug entry because of haltreq is disallowed when the LSU is busy and therefore
  // haltreq can only cause debug entry on the instruction following a load or store that
  // keep the LSU busy. If such load or store however is being single stepped or has an
  // associated breakpoint or watchpoint, then debug will be entered because of that
  // lower priority reason even though haltreq is asserted. This is okay because if instruction
  // timing is considered haltreq should be considered only asserted on the following
  // instruction (i.e. the asynchronous haltreq signal is considered asserted too late to
  // impact the current instruction in the pipeline).
  // If the core woke up from sleep due to interrupts, the wakeup reason will be honored
  // by not allowing async debug the cycle after wakeup.
  assign async_debug_allowed = lsu_interruptible_i && !fencei_ongoing && !xif_in_wb && !clic_ptr_in_pipeline && sequence_interruptible &&
                               !woke_to_interrupt_q && !(ctrl_fsm_cs == SLEEP);

  // synchronous debug entry have far fewer restrictions than asynchronous entries. In principle synchronous debug entry should have the same
  // 'allowed' signal as exceptions - that is it should always be possible.
  // todo: When XIF is being finished, debug entry vs xif must be reevaluated.
  assign sync_debug_allowed = !xif_in_wb && !(ctrl_fsm_cs == SLEEP);

  // Debug pending for any other synchronous reason than single step
  // Note that the WB stage may be killed for interrupts and NMIs, thus invalidating the instruction causing the sync debug entry.
  // Exception triggers do not set pending_sync_debug, as they need to take the single step path through the FSM.
  assign pending_sync_debug = (trigger_match_in_wb) ||
                              (ebreak_in_wb && dcsr_i.ebreakm && (ex_wb_pipe_i.priv_lvl == PRIV_LVL_M) && !debug_mode_q) || // Ebreak with dcsr.ebreakm==1  during machine mode
                              (ebreak_in_wb && debug_mode_q); // Ebreak during debug_mode restarts execution from dm_halt_addr, as a regular debug entry without CSR updates.

  // Debug pending for external debug request, only if not already in debug mode
  // Ideally the !debug_mode_q below should be factored into async_debug_allowed, but
  // that can currently cause a deadlock if debug_req_i gets asserted while in debug mode, as
  // a pending but not allowed async debug will cause the ID stage to halt forever while trying
  // to get to an interruptible state.
  // When the core wakes up from sleep due to debug_req_i, woke_to_debug_q will be set for exactly one cycle
  // to allow the core to enter debug one cycle after waking up, even though debug_req_i may have been deasserted.
  assign pending_async_debug = (debug_req_i || woke_to_debug_q) && !debug_mode_q;

  // Determine cause of debug. Set for all causes of debug entry.
  // In case of ebreak during debug mode, the entry code in DEBUG_TAKEN will
  // make sure not to update any CSRs.
  // The flopped version of this is checked during DEBUG_TAKEN state (one cycle delay)
  // For this core, the three top priorities are covered by pending_async_debug.
  // 1: resethaltreq (0x5)
  // 2: halt group (0x6)
  // 3: haltreq (0x3)
  // 4: trigger match (0x2)
  // 5: ebreak (0x1)
  // 6: single step (0x4)

  // The synchronous causes are determined here, while the priority between haltreq, sync_debug_cause and single step is determined within the FSM.
  assign sync_debug_cause = (trigger_match_in_wb)                                                                      ? DBG_CAUSE_TRIGGER :    // Etrigger will enter DEBUG_TAKEN as a single step (no halting), but kill pipeline as non-stepping entries.
                            (ebreak_in_wb && dcsr_i.ebreakm && (ex_wb_pipe_i.priv_lvl == PRIV_LVL_M) && !debug_mode_q) ? DBG_CAUSE_EBREAK  :    // Ebreak during machine mode
                            (ebreak_in_wb && debug_mode_q)                                                             ? DBG_CAUSE_EBREAK  :    // Ebreak during debug mode
                                                                                                                         DBG_CAUSE_NONE;

  // Debug cause to CSR from flopped version (valid during DEBUG_TAKEN)
  assign ctrl_fsm_o.debug_cause = debug_cause_q;

  // interrupt pending comes directly from the interrupt controller
  assign pending_interrupt = irq_req_ctrl_i;

  // Allow interrupts to be taken only if there is no data request in WB,
  // and no trans_valid has been clocked from EX to environment.
  // Not allowing interrupts when the core cannot take interrupts due to debug conditions.
  // Offloaded instructions in WB also block, as they cannot be killed after commit_kill=0 (EX stage)
  // LSU instructions which were suppressed due to previous exceptions or trigger match
  // will be interruptable as they were converted to NOP in ID stage.
  // When a fencei is present in WB and the LSU has completed all tranfers, the fencei handshake will be initiated. This must complete and the fencei instruction must retire before allowing interrupts.
  // Any multi operation instruction (table jumps, push/pop and double moves) may not be interrupted once the first operation has completed its operation in WB.
  //   - This is guarded with using the sequence_interruptible, which tracks sequence progress through the WB stage.
  // When a CLIC pointer is in the pipeline stages EX or WB, we must block interrupts.
  //   - Interrupt would otherwise kill the pointer and use the address of the pointer for mepc. A following mret would then return to the mtvt table, losing program progress.
  assign interrupt_allowed = lsu_interruptible_i && debug_interruptible && !fencei_ongoing && !xif_in_wb && !clic_ptr_in_pipeline &&
                             sequence_interruptible && !interrupt_blanking_q && !(ctrl_fsm_cs == SLEEP);

  // Allowing NMI's follow the same rule as regular interrupts, except we don't need to regard blanking of NMIs after a load/store.
  // If the core woke up from sleep due to either debug or regular interrupts, the wakeup reason is honored by not allowing NMIs in the cycle after
  // waking up to such an event.
  assign nmi_allowed = lsu_interruptible_i && debug_interruptible && !fencei_ongoing && !xif_in_wb && !clic_ptr_in_pipeline &&
                       sequence_interruptible && !(woke_to_debug_q || woke_to_interrupt_q) && !(ctrl_fsm_cs == SLEEP);

  // Do not allow interrupts if in debug mode, or single stepping without dcsr.stepie set.
  assign debug_interruptible = !(debug_mode_q || (dcsr_i.step && !dcsr_i.stepie));

  // Do not count if we have an exception in WB, ebreak in WB, trigger match in WB (we do not execute the instruction at trigger address),
  // or WB stage is killed or halted.
  // When WB is halted, we do not know (yet) if the instruction will retire or get killed.
  // Halted WB due to debug will result in WB getting killed
  // Halted WB due to fence.i will result in fence.i retire after handshake is done and we count when WB is un-halted
  // ctrl_fsm_o.halt_limited_wb will only be set during SLEEP, and only affect the WB stage (not cs_registers)
  //  In terms of counter events, no event should be counted while either of the WB related halts are asserted.
  assign wb_counter_event_gated = wb_counter_event && !exception_in_wb && !ebreak_in_wb && !trigger_match_in_wb &&
                                  !ctrl_fsm_o.kill_wb && !ctrl_fsm_o.halt_wb && !ctrl_fsm_o.halt_limited_wb;

  // Performance counter events
  assign ctrl_fsm_o.mhpmevent.minstret      = wb_counter_event_gated;
  assign ctrl_fsm_o.mhpmevent.compressed    = wb_counter_event_gated && ex_wb_pipe_i.instr_meta.compressed;
  assign ctrl_fsm_o.mhpmevent.jump          = wb_counter_event_gated && ex_wb_pipe_i.alu_jmp_qual;
  assign ctrl_fsm_o.mhpmevent.branch        = wb_counter_event_gated && ex_wb_pipe_i.alu_bch_qual;
  assign ctrl_fsm_o.mhpmevent.branch_taken  = wb_counter_event_gated && ex_wb_pipe_i.alu_bch_taken_qual;
  assign ctrl_fsm_o.mhpmevent.intr_taken    = ctrl_fsm_o.irq_ack;
  assign ctrl_fsm_o.mhpmevent.data_read     = m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt && !m_c_obi_data_if.req_payload.we;
  assign ctrl_fsm_o.mhpmevent.data_write    = m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt && m_c_obi_data_if.req_payload.we;
  assign ctrl_fsm_o.mhpmevent.if_invalid    = !if_valid_i && id_ready_i;
  assign ctrl_fsm_o.mhpmevent.id_invalid    = !id_valid_i && ex_ready_i;
  assign ctrl_fsm_o.mhpmevent.ex_invalid    = !ex_valid_i && wb_ready_i;
  assign ctrl_fsm_o.mhpmevent.wb_invalid    = !wb_valid_i;
  assign ctrl_fsm_o.mhpmevent.id_jalr_stall = ctrl_byp_i.jalr_stall && !id_valid_i && ex_ready_i;
  assign ctrl_fsm_o.mhpmevent.id_ld_stall   = ctrl_byp_i.load_stall && !id_valid_i && ex_ready_i;
  assign ctrl_fsm_o.mhpmevent.wb_data_stall = data_stall_wb_i;



  // Mux used to select PC from the different pipeline stages
  always_comb begin

    ctrl_fsm_o.pipe_pc = PC_WB;

    unique case (pipe_pc_mux_ctrl)
      PC_WB: ctrl_fsm_o.pipe_pc = ex_wb_pipe_i.pc;
      PC_EX: ctrl_fsm_o.pipe_pc = id_ex_pipe_i.pc;
      PC_ID: ctrl_fsm_o.pipe_pc = if_id_pipe_i.pc;
      PC_IF: ctrl_fsm_o.pipe_pc = pc_if_i;
      default:;
    endcase
  end

  //////////////
  // FSM comb //
  //////////////
  always_comb begin
    // Default values
    ctrl_fsm_ns                 = ctrl_fsm_cs;
    ctrl_fsm_o.ctrl_busy        = 1'b1;
    ctrl_fsm_o.instr_req        = 1'b1;

    ctrl_fsm_o.pc_mux           = PC_BOOT;
    ctrl_fsm_o.pc_set           = 1'b0;

    ctrl_fsm_o.irq_ack          = 1'b0;
    ctrl_fsm_o.irq_id           = '0;
    ctrl_fsm_o.irq_priv         = '0;
    ctrl_fsm_o.irq_shv          = '0;
    ctrl_fsm_o.irq_level        = 8'h00;

    ctrl_fsm_o.dbg_ack          = 1'b0;

    // IF stage is halted if an instruction has been issued during single step
    // to avoid more than one instructions passing down the pipe.
    ctrl_fsm_o.halt_if          = single_step_halt_if_q;

    // ID stage is halted when hazards are present (i.e. stalls for which the instruction currently in ID is not ready to be issued yet).
    //
    // In addition the ID stage may be halted to enable interrupts or debug to be taken.
    //   - If an interrupt (including NMI) is present it is not guaranteed that the pipeline
    //     can take the interrupt immediately. A LSU instruction could for instance be outstanding, causing the interrupt not to be taken.
    //     The controller uses (pending_interrupt && interrupt_allowed) to check for these conditions.
    //     When an interrupt (or NMI) is pending, the ID stage is halted to guarantee that an interruptible bubble eventually will
    //     occur in the WB stage.
    //   -- The ID stage is only halted iff debug_interruptible==1, indicating that we are not in debug mode or single step mode with interrupts disabled.
    //   --- If halting for interrupts while in debug mode (debug_interruptible == 0), the core would deadlock waiting for interrupt_allowed, but the core
    //       would never exit debug mode because the dret instruction could be blocked by the halted ID stage.
    //   -- The ID stage is only halted iff also the ID stage is haltable (meaning ID stage is not currently in the middle of a sequence or waiting for a CLIC pointer)
    //
    //   - The ID stage is halted when any async or sync debug is pending for the same reasons as for interrupts.
    //
    //   - If not checking for id_stage_haltable for interrupts and debug, the core could end up in a situation where it tries to create a bubble
    //     by halting ID, but the condition disallowing interrupt or debug will not disappear until the sequence currently handled by the ID stage
    //     is done. This would create an unrecoverable deadlock.
    ctrl_fsm_o.halt_id          = (ctrl_byp_i.jalr_stall || ctrl_byp_i.load_stall || ctrl_byp_i.csr_stall || ctrl_byp_i.wfi_wfe_stall || ctrl_byp_i.mnxti_id_stall) ||
                                  ((pending_interrupt || pending_nmi || pending_nmi_early) && debug_interruptible && id_stage_haltable)                             ||
                                  ((pending_async_debug || pending_sync_debug) && id_stage_haltable);


    // Halting EX if minstret_stall occurs. Otherwise we would read the wrong minstret value
    // Also halting EX if an offloaded instruction in WB may cause an exception, such that a following offloaded
    // instruction can correctly receive commit_kill.
    // Halting EX when an instruction in WB may cause an interrupt to become pending.
    // Halting while handling atomics for the following two scenarios to avoid mix of atomics and non-atomics outstanding at the same time:
    //   - An atomic is in EX while there is an LSU instruction in WB (including atomics)
    //   - Any LSU instruction is in EX while there is an outstanding atomic in WB
    ctrl_fsm_o.halt_ex          = ctrl_byp_i.minstret_stall || ctrl_byp_i.xif_exception_stall || ctrl_byp_i.irq_enable_stall || ctrl_byp_i.mnxti_ex_stall || ctrl_byp_i.atomic_stall;
    ctrl_fsm_o.halt_wb          = 1'b0;
    ctrl_fsm_o.halt_limited_wb  = 1'b0;

    // By default no stages are killed
    ctrl_fsm_o.kill_if          = 1'b0;
    ctrl_fsm_o.kill_id          = 1'b0;
    ctrl_fsm_o.kill_ex          = 1'b0;
    ctrl_fsm_o.kill_wb          = 1'b0;

    ctrl_fsm_o.csr_restore_mret = 1'b0;
    ctrl_fsm_o.csr_restore_mret_ptr = 1'b0;
    ctrl_fsm_o.csr_restore_dret = 1'b0;

    ctrl_fsm_o.csr_save_cause   = 1'b0;
    ctrl_fsm_o.csr_cause        = 32'h0;

    ctrl_fsm_o.csr_clear_minhv  = 1'b0;

    pipe_pc_mux_ctrl            = PC_WB;

    exc_cause                   = 11'b0;

    debug_cause_n               = DBG_CAUSE_NONE;
    debug_mode_n                = debug_mode_q;
    ctrl_fsm_o.debug_csr_save   = 1'b0;
    ctrl_fsm_o.block_data_addr  = 1'b0;

    // Single step halting of IF
    single_step_halt_if_n       = single_step_halt_if_q;

    // Ensure jumps and branches are taken only once
    branch_taken_n              = branch_taken_q;

    fence_req_set               = 1'b0;
    fence_req_clr               = 1'b1;

    ctrl_fsm_o.pc_set_clicv     = 1'b0;
    ctrl_fsm_o.pc_set_tbljmp    = 1'b0;

    csr_flush_ack_n             = 1'b0;

    clic_ptr_in_progress_id_set   = 1'b0;
    clic_ptr_in_progress_id_clear = 1'b0;

    unique case (ctrl_fsm_cs)
      RESET: begin
        ctrl_fsm_o.instr_req = 1'b0;
        if (fetch_enable_i) begin
          if (debug_req_i) begin
            // Not raising instr_req to prevent fetching until we are in debug mode
            ctrl_fsm_o.instr_req = 1'b0;
            ctrl_fsm_o.pc_mux    = PC_BOOT;
            ctrl_fsm_o.pc_set    = 1'b1; // pc_set is required for propagating boot address to dpc (from IF stage)
            ctrl_fsm_ns          = DEBUG_TAKEN;
            debug_cause_n        = DBG_CAUSE_HALTREQ;
          end else begin
            ctrl_fsm_o.instr_req = 1'b1;
            ctrl_fsm_o.pc_mux    = PC_BOOT;
            ctrl_fsm_o.pc_set    = 1'b1;
            ctrl_fsm_ns          = FUNCTIONAL;
          end
        end
      end
      FUNCTIONAL: begin
        // NMI
        if (pending_nmi && nmi_allowed) begin
          ctrl_fsm_o.kill_if = 1'b1;
          ctrl_fsm_o.kill_id = 1'b1;
          ctrl_fsm_o.kill_ex = 1'b1;
          ctrl_fsm_o.kill_wb = 1'b1;

          ctrl_fsm_o.pc_set = 1'b1;
          ctrl_fsm_o.pc_mux = PC_TRAP_NMI;

          ctrl_fsm_o.csr_save_cause  = 1'b1;
          ctrl_fsm_o.csr_cause.irq = 1'b1;
          ctrl_fsm_o.csr_cause.exception_code = nmi_is_store_q ? INT_CAUSE_LSU_STORE_FAULT : INT_CAUSE_LSU_LOAD_FAULT;

          // Keep mcause.minhv when taking exceptions and interrupts, only cleared on successful pointer fetches or CSR writes.
          ctrl_fsm_o.csr_cause.minhv  = mcause_i.minhv;

          if (CLIC) begin
            // Keep current interrupt level when taking NMIs
            ctrl_fsm_o.irq_level = mintstatus_i.mil;
          end


          // Save pc from oldest valid instruction
          if (ex_wb_pipe_i.instr_valid) begin
            pipe_pc_mux_ctrl = PC_WB;
          end else if (id_ex_pipe_i.instr_valid) begin
            pipe_pc_mux_ctrl = PC_EX;
          end else if (if_id_pipe_i.instr_valid) begin
            pipe_pc_mux_ctrl = PC_ID;
          end else begin
            // IF PC will always be valid as it points to the next
            // instruction to be issued from IF to ID.
            pipe_pc_mux_ctrl = PC_IF;
          end

        // External debug entry (async)
        end else if (pending_async_debug && async_debug_allowed) begin
          // Halt the whole pipeline
          // Halting makes sure instructions stay in the pipeline stage without propagating to the next.
          //  This is needed by the debug entry code in the DEBUG_STAKEN state to pick the correct PC for storing in dpc.
          ctrl_fsm_o.halt_if = 1'b1;
          ctrl_fsm_o.halt_id = 1'b1;
          ctrl_fsm_o.halt_ex = 1'b1;
          ctrl_fsm_o.halt_wb = 1'b1;

          ctrl_fsm_ns = DEBUG_TAKEN;
          debug_cause_n = DBG_CAUSE_HALTREQ;
        // IRQ
        end else if (pending_interrupt && interrupt_allowed) begin
          ctrl_fsm_o.kill_if = 1'b1;
          ctrl_fsm_o.kill_id = 1'b1;
          ctrl_fsm_o.kill_ex = 1'b1;
          ctrl_fsm_o.kill_wb = 1'b1;

          ctrl_fsm_o.pc_set = 1'b1;

          exc_cause = {1'b0, irq_id_ctrl_i};

          ctrl_fsm_o.irq_ack = 1'b1;
          ctrl_fsm_o.irq_id  = irq_id_ctrl_i;

          ctrl_fsm_o.csr_save_cause  = 1'b1;
          ctrl_fsm_o.csr_cause.irq = 1'b1;

          // Default to keeping mcause.minhv. It will only be set to 1 when taking a CLIC SHV interrupt (or by a CSR write).
          // For all other cases it keeps its value.
          ctrl_fsm_o.csr_cause.minhv  = mcause_i.minhv;


          if (CLIC) begin
            ctrl_fsm_o.csr_cause.exception_code = {1'b0, irq_id_ctrl_i};
            ctrl_fsm_o.irq_level = irq_clic_level_i;
            ctrl_fsm_o.irq_priv = irq_clic_priv_i;
            ctrl_fsm_o.irq_shv = irq_clic_shv_i;
            if (irq_clic_shv_i) begin
              ctrl_fsm_o.pc_mux = PC_TRAP_CLICV;
              clic_ptr_in_progress_id_set = 1'b1;
              ctrl_fsm_o.pc_set_clicv = 1'b1;
              // When taking an SHV interrupt, always set minhv.
              // Mcause.minhv will only be cleared when a successful pointer fetch is done, or when it is cleared by a CSR write.
              ctrl_fsm_o.csr_cause.minhv = 1'b1;
            end else begin
              ctrl_fsm_o.pc_mux = PC_TRAP_IRQ;
            end
          end else begin
            ctrl_fsm_o.pc_mux = PC_TRAP_IRQ;
            ctrl_fsm_o.csr_cause.exception_code = {1'b0, irq_id_ctrl_i};
          end

          // Save pc from oldest valid instruction
          if (ex_wb_pipe_i.instr_valid) begin
            pipe_pc_mux_ctrl = PC_WB;
          end else if (id_ex_pipe_i.instr_valid) begin
            pipe_pc_mux_ctrl = PC_EX;
          end else if (if_id_pipe_i.instr_valid) begin
            pipe_pc_mux_ctrl = PC_ID;
          end else begin
            // IF PC will always be valid as it points to the next
            // instruction to be issued from IF to ID.
            pipe_pc_mux_ctrl = PC_IF;
          end
        // Synchronous debug entry (ebreak, trigger match)
        end else if (pending_sync_debug && sync_debug_allowed) begin
          // Halt the whole pipeline
          // Halting makes sure instructions stay in the pipeline stage without propagating to the next.
          //  This is needed by the debug entry code in the DEBUG_STAKEN state to pick the correct PC for storing in dpc.
          ctrl_fsm_o.halt_if = 1'b1;
          ctrl_fsm_o.halt_id = 1'b1;
          ctrl_fsm_o.halt_ex = 1'b1;
          ctrl_fsm_o.halt_wb = 1'b1;

          ctrl_fsm_ns = DEBUG_TAKEN;
          debug_cause_n = sync_debug_cause;
        end else begin
          if (exception_in_wb && exception_allowed) begin
            // Kill all stages
            ctrl_fsm_o.kill_if = 1'b1;
            ctrl_fsm_o.kill_id = 1'b1;
            ctrl_fsm_o.kill_ex = 1'b1;
            ctrl_fsm_o.kill_wb = 1'b0; // All write enables are suppressed, no need to kill WB.

            // Set pc to exception handler
            ctrl_fsm_o.pc_set = 1'b1;
            ctrl_fsm_o.pc_mux = debug_mode_q ? PC_TRAP_DBE : PC_TRAP_EXC;

            // Save CSR from WB
            pipe_pc_mux_ctrl = PC_WB;
            ctrl_fsm_o.csr_save_cause = !debug_mode_q; // Do not update CSRs if in debug mode
            ctrl_fsm_o.csr_cause.exception_code = exception_cause_wb;

            // Keep mcause.minhv when taking exceptions and interrupts, only cleared on successful pointer fetches or CSR writes.
            ctrl_fsm_o.csr_cause.minhv  = mcause_i.minhv;

          // Special insn
          end else if (wfi_in_wb || wfe_in_wb) begin
            // Halt the entire pipeline
            // WFI/WFE will stay in WB until we exit sleep mode
            ctrl_fsm_o.halt_wb = 1'b1;
            ctrl_fsm_o.instr_req = 1'b0;
            ctrl_fsm_ns = SLEEP;

          end else if (fencei_in_wb || fence_in_wb) begin

            // fence.i behavior:
            //
            // - Can be killed due to interrupts and debug at any time before fencei_flush_req_o is asserted (so even after initial cycle in WB).
            // - Initially halt entire pipeline, making sure that possibly following loads/stores do not initiate transactions.
            // - Wait until the LSU is ready (i.e. write buffer must also be empty and possible NMIs will have been raised).
            // - Once the LSU is ready take the NMI if present or otherwise continue fence.i handling by initiating the fencei_flush_req_o handshake.
            // - Once the fencei_flush_req_o handshake is complete flush the entire pipeline (branch to next instruction) and retire the fence.i.

            // fence behavior:
            //
            // - Can be killed due to interrupts and debug at any time (so even after initial cycle in WB).
            // - Initially halt entire pipeline, making sure that possibly following loads/stores do not initiate transactions.
            // - Wait until the LSU is ready (i.e. write buffer must also be empty and possible NMIs will have been raised).
            // - Once the LSU is ready take the NMI if present or otherwise continue fence handling.
            // - Flush the entire pipeline (branch to next instruction) and retire the fence.

            // Halt the pipeline
            ctrl_fsm_o.halt_if = 1'b1;
            ctrl_fsm_o.halt_id = 1'b1;
            ctrl_fsm_o.halt_ex = 1'b1;
            ctrl_fsm_o.halt_wb = 1'b1;

            // Set fence_req_q when the LSU is no longer busy
            fence_req_set = !lsu_busy_i;
            fence_req_clr = 1'b0;

            if (fencei_in_wb ? fencei_req_and_ack_q : fence_req_q) begin

              // Unhalt wb, kill if,id,ex
              ctrl_fsm_o.kill_if   = 1'b1;
              ctrl_fsm_o.kill_id   = 1'b1;
              ctrl_fsm_o.kill_ex   = 1'b1;
              ctrl_fsm_o.halt_wb   = 1'b0;

              // Jump to PC from oldest valid instruction, excluding WB stage
              if (id_ex_pipe_i.instr_valid) begin
                pipe_pc_mux_ctrl = PC_EX;
              end else if (if_id_pipe_i.instr_valid) begin
                pipe_pc_mux_ctrl = PC_ID;
              end else begin
                pipe_pc_mux_ctrl = PC_IF;
              end

              ctrl_fsm_o.pc_set    = 1'b1;
              ctrl_fsm_o.pc_mux    = PC_WB_PLUS4;

              // Clear fence_req_q
              fence_req_set = 1'b0;
              fence_req_clr = 1'b1;
            end
          end else if (dret_in_wb) begin
            // dret takes jump from WB stage
            // Kill previous stages and jump to pc in dpc
            ctrl_fsm_o.kill_if = 1'b1;
            ctrl_fsm_o.kill_id = 1'b1;
            ctrl_fsm_o.kill_ex = 1'b1;

            ctrl_fsm_o.pc_mux  = PC_DRET;
            ctrl_fsm_o.pc_set  = 1'b1;

            ctrl_fsm_o.csr_restore_dret  = 1'b1;

            single_step_halt_if_n = 1'b0;
            debug_mode_n  = 1'b0;
          end else if (csr_wr_in_wb_flush_i) begin
            // CSR write in WB requires pipeline flush, halt all stages except WB
            // EX could contain a load/store, need to avoid its address phase going onto the bus
            ctrl_fsm_o.halt_if = 1'b1;
            ctrl_fsm_o.halt_id = 1'b1;
            ctrl_fsm_o.halt_ex = 1'b1;

            // Set flop input to get ack in the next cycle when the write is done.
            csr_flush_ack_n    = 1'b1;
          end else if (csr_flush_ack_q) begin
            // Flush pipeline because of CSR update in the previous cycle
            ctrl_fsm_o.kill_if   = 1'b1;
            ctrl_fsm_o.kill_id   = 1'b1;
            ctrl_fsm_o.kill_ex   = 1'b1;

            // Jump to PC from oldest valid instruction, excluding WB stage
            if (id_ex_pipe_i.instr_valid) begin
              pipe_pc_mux_ctrl = PC_EX;
            end else if (if_id_pipe_i.instr_valid) begin
              pipe_pc_mux_ctrl = PC_ID;
            end else begin
              pipe_pc_mux_ctrl = PC_IF;
            end

            ctrl_fsm_o.pc_set    = 1'b1;
            ctrl_fsm_o.pc_mux    = PC_WB_PLUS4;


          end else if (branch_taken_ex) begin
            ctrl_fsm_o.kill_if = 1'b1;
            ctrl_fsm_o.kill_id = 1'b1;

            ctrl_fsm_o.pc_mux  = PC_BRANCH;
            ctrl_fsm_o.pc_set  = 1'b1;

            // Set flag to avoid further branches to the same target
            // if we are stalled
            branch_taken_n     = 1'b1;

          end else if (jump_taken_id) begin
            // Jumps in ID (JAL, JALR, mret)

            // kill_if
            ctrl_fsm_o.kill_if = 1'b1;

            if (sys_mret_id) begin
              // If the xcause.minhv bit is set for the previous privilege level (mcause.mpp) when an mret is in ID,
              // the mret should restart the CLIC pointer fetch using mepc as a pointer to the pointer instead of jumping to
              // the address in mepc. If mpp==PRIV_LVL_U, the (not existing) ucause.uinhv bit is assumed to be 0.
              // This is done below by signalling pc_set_clicv along with pc_mux=PC_MRET. This will
              // treat the mepc as an address to a CLIC pointer. The minhv flag will only be cleared
              // when a pointer reaches the WB stage with no faults from fetching.
              // ID stage is halted while it contains an mret and at the same time there are CSR writes (including CLIC pointers) EX or WB, hence it is safe to use mcause here.
              if (mcause_i.minhv && (mcause_i.mpp == PRIV_LVL_M)) begin
                // mcause.minhv set, exception occured during last pointer fetch (or SW wrote it)
                // Do another pointer fetch from the address stored in mepc.
                ctrl_fsm_o.pc_set = 1'b1;
                ctrl_fsm_o.pc_set_clicv = 1'b1; // Treat mepc as a pointer fetch
                ctrl_fsm_o.pc_mux = PC_MRET;

                // Set flag to avoid further jumps to the same target
                // if we are stalled
                branch_taken_n = 1'b1;

                // Clear flag for halting IF in case of single stepping
                // For the single step to complete, both the mret and the pointer must reach WB.
                // If no unhalt is done here, the pointer will never reach WB.
                single_step_halt_if_n = 1'b0;
              end else begin
                // xcause.xinhv not set for the previous privilege level, do regular mret
                ctrl_fsm_o.pc_mux = PC_MRET;
                ctrl_fsm_o.pc_set = 1'b1;

                // Set flag to avoid further jumps to the same target
                // if we are stalled
                branch_taken_n = 1'b1;
              end

            end else begin
              // For table jumps we have two different jumps
              // - First part does a pointer fetch from (jvt + (index<<2))
              // - Second part jumps to the fetched pointer
              // Regular jumps use the regular jump to the target calculated in the ID stage.
              ctrl_fsm_o.pc_mux        = if_id_pipe_i.instr_meta.tbljmp && !if_id_pipe_i.last_op ? PC_TBLJUMP :
                                         if_id_pipe_i.instr_meta.tbljmp && if_id_pipe_i.last_op  ? PC_POINTER : PC_JUMP;
              ctrl_fsm_o.pc_set        = 1'b1;
              ctrl_fsm_o.pc_set_tbljmp = if_id_pipe_i.instr_meta.tbljmp && !if_id_pipe_i.last_op;

              // Set flag to avoid further jumps to the same target
              // if we are stalled
              branch_taken_n = 1'b1;
            end
          end else if (clic_ptr_in_id || mret_ptr_in_id) begin
            if (!(if_id_pipe_i.instr.bus_resp.err || (if_id_pipe_i.instr.mpu_status != MPU_OK) || (if_id_pipe_i.instr.align_status != ALIGN_OK))) begin
              if (!branch_taken_q) begin
                ctrl_fsm_o.pc_set = 1'b1;
                ctrl_fsm_o.pc_mux = PC_POINTER;
                ctrl_fsm_o.kill_if = 1'b1;
                branch_taken_n = 1'b1;
              end
            end
          end

          // The following if statements are in parallel with the main decision tree.
          // If any of these would be part of the decision tree, they could mask jumps and branches
          // from being taken.
          // CLIC pointer in ID clears pointer fetch flag
          if (clic_ptr_in_id && id_valid_i && ex_ready_i) begin
            clic_ptr_in_progress_id_clear = 1'b1;
          end

          // Regular mret in WB restores CSR regs
          if (mret_in_wb && !ctrl_fsm_o.kill_wb && !ctrl_fsm_o.halt_wb) begin
            ctrl_fsm_o.csr_restore_mret  = !debug_mode_q;
          end

          // For mret that caused a CLIC pointer fetch, CSR updates will happen once the pointer reaches WB.
          // If the pointer has associated exceptions, the csr_restore_mret_ptr will not happen
          if (mret_ptr_in_wb && !ctrl_fsm_o.kill_wb && !ctrl_fsm_o.halt_wb && !exception_in_wb) begin
            ctrl_fsm_o.csr_restore_mret_ptr  = !debug_mode_q;
          end

          // CLIC pointer in WB
          if (clic_ptr_in_wb && !ctrl_fsm_o.kill_wb && !ctrl_fsm_o.halt_wb && !exception_in_wb) begin
            // Clear minhv if no exceptions are associated with the pointer
            ctrl_fsm_o.csr_clear_minhv = 1'b1;
          end
        end // !debug or interrupts

        // Single step debug entry or etrigger debug entry
        // Need to be after (in parallell with) exception/interrupt handling
        // to ensure mepc and if_pc are set correctly for use in dpc,
        // and to ensure only one instruction can retire during single step
        // Triggers other than exception trigger do not cause any state change before debug entry.
        // Exception triggers do all the side effects off taking an exception (mcause, mepc etc) but without
        // executing the first handler instruction before debug entry. If an exception trigger factored into
        // 'pending_sync_debug' instead og the single step logic, then these side effects of taking the exception would not occur, since exceptions
        // are prioritized below all debug entries in the FSM.
        if (pending_single_step || etrigger_in_wb) begin
          if (single_step_allowed) begin
            ctrl_fsm_ns = DEBUG_TAKEN;
            // etrigger has higher priority than step.
            // Any other higher priority cause of debug would not be pending is this context
            //   Async and sync debug entries will halt WB, causing !wb_valid which in turn pulls pending_single_step and etrigger_in_wb low.
            //   Any taken interrupt or NMI kills WB, also pulling wb_valid low. Pending_single_step will still be high, but any other debug entry
            //   reason as seen from WB will be deasserted.
            if (etrigger_in_wb) begin
              debug_cause_n = DBG_CAUSE_TRIGGER;
            end else begin
              debug_cause_n = DBG_CAUSE_STEP;
            end
          end
        end
      end
      SLEEP: begin
        // There should be a bubble in EX in this state (checked by assertion)
        // We are avoiding that a load/store starts its bus transaction
        ctrl_fsm_o.ctrl_busy         = 1'b0;
        ctrl_fsm_o.instr_req         = 1'b0;
        // Put backpressure on pipeline to avoid retiring WFI until we wake up.
        // Using limited version of halt_wb to avoid timing paths through cs_registers and bypass onto the data OBI bus.
        // Assertions exist to check that no CSR instruction can be in WB at this time.
        ctrl_fsm_o.halt_limited_wb   = 1'b1;

        // Wake up from SLEEP
        if (ctrl_fsm_o.wake_from_sleep) begin
          ctrl_fsm_ns = FUNCTIONAL;
          ctrl_fsm_o.ctrl_busy = 1'b1;
          // Keep IF/ID halted while waking up (EX contains a bubble)
          // Any jump/table jump/mret which is in ID in this cycle must also remain in ID
          // the next cycle for their side effects to be taken during the FUNCTIONAL state in case the interrupt is not actually taken.
          ctrl_fsm_o.halt_id = 1'b1;

          // Unhalt WB to allow WFI to retire when we exit SLEEP mode
          // Using limited version of halt_wb to avoid timing paths through cs_registers and bypass onto the data OBI bus.
          ctrl_fsm_o.halt_limited_wb = 1'b0;
        end
      end
      DEBUG_TAKEN: begin

        // Indicate that debug is taken
        ctrl_fsm_o.dbg_ack = 1'b1;

        // Clear flags for halting IF during single step
        single_step_halt_if_n = 1'b0;

        // Set pc
        ctrl_fsm_o.pc_set = 1'b1;
        ctrl_fsm_o.pc_mux = PC_TRAP_DBD;

        // Save CSRs
        ctrl_fsm_o.csr_save_cause = !(ebreak_in_wb && debug_mode_q);  // No CSR update for ebreak in debug mode
        ctrl_fsm_o.debug_csr_save = 1'b1;

        // debug_cause_q set when decision was made to enter debug
        if (debug_cause_q != DBG_CAUSE_STEP) begin
          // Kill pipeline
          ctrl_fsm_o.kill_if = 1'b1;
          ctrl_fsm_o.kill_id = 1'b1;
          ctrl_fsm_o.kill_ex = 1'b1;
          // Ebreak that causes debug entry should not be killed, otherwise RVFI will skip it
          // Trigger match should also be signalled as not killed (all write enables are suppressed in ID), otherwise RVFI/ISS will not attempt to execute and detect trigger
          // Exception trigger match should have nothing in WB, excepted instruction finished the previous cycle and set mepc and mcause due to the exception.
          // Ebreak during debug_mode restarts from dm_halt_addr, without CSR updates. Not killing ebreak due to the same RVFI/ISS reasons.
          // Neither ebreak nor trigger match have any state updates in WB. For trigger match, all write enables are suppressed in the ID stage.
          //   Thus this change is not visible to core state, only for RVFI use.
          // todo: Move some logic to RVFI instead?
          ctrl_fsm_o.kill_wb = !((debug_cause_q == DBG_CAUSE_EBREAK) || (debug_cause_q == DBG_CAUSE_TRIGGER));


          // Save pc from oldest valid instruction
          if (ex_wb_pipe_i.instr_valid) begin
            pipe_pc_mux_ctrl = PC_WB;
          end else if (id_ex_pipe_i.instr_valid) begin
            pipe_pc_mux_ctrl = PC_EX;
          end else if (if_id_pipe_i.instr_valid) begin
            pipe_pc_mux_ctrl = PC_ID;
          end else begin
            pipe_pc_mux_ctrl = PC_IF;
          end
        end else begin
          // Single step
          // Only kill IF. WB should be allowed to complete
          // ID and EX are empty as IF is blocked after one issue in single step mode
          ctrl_fsm_o.kill_if = 1'b1;
          ctrl_fsm_o.kill_id = 1'b0;
          ctrl_fsm_o.kill_ex = 1'b0;
          ctrl_fsm_o.kill_wb = 1'b0;

          // Should use pc from IF (next insn, as IF is halted after first issue)
          pipe_pc_mux_ctrl = PC_IF;
        end

        // Enter debug mode next cycle
        debug_mode_n = 1'b1;
        ctrl_fsm_ns = FUNCTIONAL;
      end

      default: begin
        // should never happen
        ctrl_fsm_o.instr_req = 1'b0;
        ctrl_fsm_ns = RESET;
      end
    endcase

    // Detect first insn issue in single step after dret
    // Any Zc sequence must fully complete (last_op_if_i) before halting the IF stage.
    // Used to block further issuing
    if (!ctrl_fsm_o.debug_mode && dcsr_i.step && !single_step_halt_if_q && (if_valid_i && id_ready_i && (last_op_if_i || abort_op_if_i))) begin
      single_step_halt_if_n = 1'b1;
    end

    // Clear jump/branch flag when new insn is emitted from IF
    if (branch_taken_q && if_valid_i && id_ready_i) begin
      branch_taken_n = 1'b0;
    end
  end

  // Wakeup from sleep
  assign ctrl_fsm_o.wake_from_sleep        = pending_nmi || irq_wu_ctrl_i || pending_async_debug || debug_mode_q || (wfe_in_wb && wu_wfe_i); // Only WFE wakes up for wfe_wu_i
  assign ctrl_fsm_o.debug_wfi_wfe_no_sleep = debug_mode_q || dcsr_i.step;

  ////////////////////
  // Flops          //
  ////////////////////

  // FSM state and debug_mode
  always_ff @(posedge clk , negedge rst_n) begin
    if (rst_n == 1'b0) begin
      ctrl_fsm_cs <= RESET;
      debug_mode_q <= 1'b0;
      debug_cause_q <= DBG_CAUSE_NONE;
    end else begin
      ctrl_fsm_cs   <= ctrl_fsm_ns;
      debug_mode_q  <= debug_mode_n;
      debug_cause_q <= debug_cause_n;
    end
  end

  // debug_mode_if is a control input for the if stage.
  // For both debug mode entry end exit, the IF, ID and EX stages are killed. While the IF stage is killed it starts
  // fetching the next instruction (sets the obi request high), requiring a valid debug mode signal for this fetch.
  // The debug_mode_if signal is valid for all IF fetches.
  assign ctrl_fsm_o.debug_mode_if = debug_mode_n;
  assign ctrl_fsm_o.debug_mode    = debug_mode_q;


  // Sticky version of lsu_err_wb_i
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      nmi_pending_q <= 1'b0;
      nmi_is_store_q <= 1'b0;
    end else begin
      if (lsu_err_wb_i[0] && !nmi_pending_q) begin
        // Set whenever an error occurs in WB for the LSU, unless we already have an NMI pending.
        // Later errors could overwrite the bit for load/store type, and with mtval the address would be overwritten.
        // todo: if mtval is implemented, address must be sticky as well
        nmi_pending_q <= 1'b1;
        nmi_is_store_q <= lsu_err_wb_i[1];
      // Clear when the controller takes the NMI
      end else if (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_NMI)) begin
        nmi_pending_q <= 1'b0;
      end
    end
  end

  // Flop used to gate if_valid after one instruction issued
  // in single step mode
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      single_step_halt_if_q <= 1'b0;
      branch_taken_q        <= 1'b0;
      csr_flush_ack_q       <= 1'b0;
    end else begin
      single_step_halt_if_q <= single_step_halt_if_n;
      branch_taken_q        <= branch_taken_n;
      csr_flush_ack_q       <= csr_flush_ack_n;
    end
  end

  // Flop used to track LSU instructions in WB. High in the cycle after an LSU instruction
  // leaves WB.
  // Used for disregarding interrupts one cycle after a load/store to make sure the
  // interrupt controller propagates the inputs through its flops.
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      interrupt_blanking_q <= 1'b0;
    end else begin
      interrupt_blanking_q <= ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.lsu_en;
    end
  end

  // Flops for fencei handshake request
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      fence_req_q          <= 1'b0;
      fencei_req_and_ack_q <= 1'b0;
    end else begin

      // Flop fencei_flush_ack_i to break timing paths
      // fencei_flush_ack_i must be qualified with fencei_flush_req_o
      fencei_req_and_ack_q <= fencei_flush_req_o && fencei_flush_ack_i;

      // Set and clear fence_req_q based on FSM output. Also clear when fence.i handshake is completed
      if (fence_req_clr || (fencei_flush_req_o && fencei_flush_ack_i)) begin
        fence_req_q <= 1'b0;
      end
      else if (fence_req_set) begin
        fence_req_q <= 1'b1;
      end
    end
  end

  // Set flush request if we have a fence.i
  assign fencei_flush_req_o = fencei_in_wb ? fence_req_q : 1'b0;

  // minstret event
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      wb_counter_event <= 1'b0;
    end else begin
      // When the last part of an instruction reaches WB we may increment counters,
      // unless WB stage is halted. WB stage is halted due to either halt_wb or halt_limited wb (SLEEP with WFI/WFE in WB only).
      // A halted instruction in WB may or may not be killed later,
      // thus we cannot count it until we know for sure if it will retire.
      // i.e halt_wb due to debug will result in killed WB, while for fence.i it will retire.
      // Note that this event bit is further gated before sent to the actual counters in case
      // other conditions prevent counting.
      // CLIC: Exluding pointer fetches as they are not instructions.
      //       mret pointers will finish the mret->ptr sequence and will update wb_counter_event (instr_meta.mret_ptr is 1)
      if (ex_valid_i && wb_ready_i && last_op_ex_i && !id_ex_pipe_i.instr_meta.clic_ptr)  begin
        wb_counter_event <= 1'b1;
      end else begin
        // Keep event flag high while WB is halted, as we don't know if it will retire yet
        if (!ctrl_fsm_o.halt_wb && !ctrl_fsm_o.halt_limited_wb) begin
          wb_counter_event <= 1'b0;
        end
      end
    end
  end

  // Instruction sequences may not be interrupted/killed if the first operation has already been retired.
  // Flop set when first_op without either last_op or abort_op is done in WB, and cleared when last_op is done.
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      sequence_in_progress_wb <= 1'b0;
    end else begin
      if (!sequence_in_progress_wb) begin
        if (wb_valid_i && ex_wb_pipe_i.first_op && !(last_op_wb_i || abort_op_wb_i)) begin // wb_valid implies ex_wb_pipe.instr_valid
          sequence_in_progress_wb <= 1'b1;
        end
      end else begin
        // sequence_in_progress_wb is set, clear when last_op retires or sequence is aborted due to exceptions.
        if (wb_valid_i && (last_op_wb_i || abort_op_wb_i)) begin
          sequence_in_progress_wb <= 1'b0;
        end

        // No need to reset this flag on kill_wb.
        // When flag is high, there should be no reason to kill WB as they are blocked by the flag itself.
        // This is checked by an assertion, no killing while !sequence_interruptible

        // If debug entry is caused by a watchpoint address trigger, then abort_op_wb_i will be 1 and a debug entry is initiated.
        // This must also cause the sequence_in_progress_wb to be reset as the sequence is effectively terminated, although the instruction itself is not killed or completed
        // in a normal manner. As the WB stage is halted for debug entry on a watchcpoint trigger, wb_valid_i is zero.
        if (ex_wb_pipe_i.instr_valid && wpt_match_wb_i && abort_op_wb_i) begin
          sequence_in_progress_wb <= 1'b0;
        end
      end
    end
  end

  // Logic to track first_op and last_op through the ID stage to detect unhaltable sequences
  // Flop set when first_op is done in ID, and cleared when last_op is done, or ID is killed
  // If the ID stage first_op has a known exception or trigger match the flop will not be set
  // as the controller will either take an exception or enter debug mode without finishing the sequence.
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      sequence_in_progress_id <= 1'b0;
    end else begin
      if (!sequence_in_progress_id) begin
        if (id_valid_i && ex_ready_i && first_op_id_i && !(last_op_id_i || abort_op_id_i)) begin // id_valid implies if_id_pipe.instr.valid
          sequence_in_progress_id <= 1'b1;
        end
      end else begin
        // sequence_in_progress_id is set, clear when last_op retires or ID stage is killed
        if (id_valid_i && ex_ready_i && (last_op_id_i || abort_op_id_i)) begin
          sequence_in_progress_id <= 1'b0;
        end
      end

      // Reset flag on a kill_id. May happen before sequence_in_progress_id gets set, or if a sequence gets an exception in the middle
      if (ctrl_fsm_o.kill_id) begin
        sequence_in_progress_id <= 1'b0;
      end
    end
  end

  // Flag for tracking CLIC pointer fetches. Only done when acking an SHV interrupt, not when an mret restarts a pointer fetch.
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      clic_ptr_in_progress_id <= 1'b0;
    end else begin
      if (!clic_ptr_in_progress_id) begin
        if (clic_ptr_in_progress_id_set) begin
          clic_ptr_in_progress_id <= 1'b1;
        end
      end else begin
        // clic_ptr_in_progress_id is set, clear when controller assert the clear-bit or ID stage is killed
        if (clic_ptr_in_progress_id_clear) begin
          clic_ptr_in_progress_id <= 1'b0;
        end
      end

      // When clic_ptr_in_progress_id is high, the ID stage can never be killed and thus no reset on kill_id is needed.
      // This is checked by an assertion. Taking an SHV interrupt kills the pipeline ensuring no exceptions may happen, and
      // the flag itself keeps debug or interrupts from killing the pipeline.
    end
  end

  // Flags for remembering if the core woke up due to a debug request or interrupt.
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      woke_to_debug_q <= 1'b0;
      woke_to_interrupt_q <= 1'b0;
    end else begin
      // Woke up to debug if no nmi was pending
      woke_to_debug_q     <= (ctrl_fsm_cs == SLEEP) && debug_req_i && !(pending_nmi);
      // Woke up to interrupts if no NMI or debug was pending
      woke_to_interrupt_q <= (ctrl_fsm_cs == SLEEP) && irq_wu_ctrl_i && !(pending_nmi || debug_req_i);
    end
  end

  /////////////////////
  // Debug state FSM //
  /////////////////////
  always_ff @(posedge clk , negedge rst_n) begin
    if (rst_n == 1'b0) begin
      debug_fsm_cs <= HAVERESET;
    end else begin
      debug_fsm_cs <= debug_fsm_ns;
    end
  end

  always_comb begin
    debug_fsm_ns = debug_fsm_cs;

    case (debug_fsm_cs)
      HAVERESET: begin
        if (debug_mode_n || (ctrl_fsm_ns == FUNCTIONAL)) begin
          if (debug_mode_n) begin
            debug_fsm_ns = HALTED;
          end else begin
            debug_fsm_ns = RUNNING;
          end
        end
      end

      RUNNING: begin
        if (debug_mode_n) begin
          debug_fsm_ns = HALTED;
        end
      end

      HALTED: begin
        if (!debug_mode_n) begin
          debug_fsm_ns = RUNNING;
        end
      end

      default: begin
        debug_fsm_ns = HAVERESET;
      end
    endcase
  end

  assign ctrl_fsm_o.debug_havereset = debug_fsm_cs[HAVERESET_INDEX];
  assign ctrl_fsm_o.debug_running   = debug_fsm_cs[RUNNING_INDEX];
  assign ctrl_fsm_o.debug_halted    = debug_fsm_cs[HALTED_INDEX];


  //---------------------------------------------------------------------------
  // eXtension interface
  //---------------------------------------------------------------------------

  generate
    if (X_EXT) begin : x_ext
      logic commit_valid_q; // Sticky bit for commit_valid
      logic commit_kill_q;  // Sticky bit for commit_kill
      logic kill_rejected;  // Signal used to kill rejected xif instructions

      // TODO: Add assertion to check the following:
      // Every issue interface transaction (whether accepted or not) has an associated commit interface
      // transaction and both interfaces use a matching transaction ordering.

      // Commit an offloaded instruction in the first cycle where EX is not halted, or EX is killed.
      //       Only commit when there is an offloaded instruction in EX (accepted or not), and we have not
      //       previously signalled commit for the same instruction. Rejected xif instructions gets killed
      //       with commit_kill=1 (pipeline is not killed as we need to handle the illegal instruction in WB)
      // Can only allow commit when older instructions are guaranteed to complete without exceptions
      //       - EX is halted if offloaded in WB can cause an exception, causing below to evaluate to 0.
      assign xif_commit_if.commit_valid       = (!ctrl_fsm_o.halt_ex || ctrl_fsm_o.kill_ex) &&
                                                 (id_ex_pipe_i.xif_en && id_ex_pipe_i.instr_valid) &&
                                                 !commit_valid_q; // Make sure we signal only once per instruction

      assign xif_commit_if.commit.id          = id_ex_pipe_i.xif_meta.id;
      assign xif_commit_if.commit.commit_kill = xif_csr_error_i || ctrl_fsm_o.kill_ex || kill_rejected;

      // Signal commit_kill=1 to all instructions rejected by the eXtension interface
      assign kill_rejected = (id_ex_pipe_i.xif_en && !id_ex_pipe_i.xif_meta.accepted) && id_ex_pipe_i.instr_valid;

      // Signal (to EX stage), that an (attempted) offloaded instructions is killed (clears ex_wb_pipe.xif_en)
      assign ctrl_fsm_o.kill_xif = xif_commit_if.commit.commit_kill || commit_kill_q;

      // Flag used to make sure we only signal commit_valid once for each instruction
      always_ff @(posedge clk, negedge rst_n) begin : commit_valid_ctrl
        if (rst_n == 1'b0) begin
          commit_valid_q <= 1'b0;
          commit_kill_q  <= 1'b0;
        end else begin
          if ((ex_valid_i && wb_ready_i) || ctrl_fsm_o.kill_ex) begin
            commit_valid_q <= 1'b0;
            commit_kill_q  <= 1'b0;
          end else begin
            commit_valid_q <= (xif_commit_if.commit_valid || commit_valid_q);
            commit_kill_q  <= (xif_commit_if.commit.commit_kill || commit_kill_q);
          end
        end
      end

    end else begin : no_x_ext

      assign xif_commit_if.commit_valid       = '0;
      assign xif_commit_if.commit.id          = '0;
      assign xif_commit_if.commit.commit_kill = '0;
      assign ctrl_fsm_o.kill_xif              = 1'b0;

    end
  endgenerate

endmodule
