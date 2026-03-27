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
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                                                                            //
// Description:    RTL assertions for the core module                         //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_core_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
  #(
    parameter a_ext_e A_EXT = A_NONE,
    parameter bit     DEBUG = 1,
    parameter int     PMA_NUM_REGIONS = 0,
    parameter bit     CLIC = 0
  )
  (
  input logic        clk,
  input logic        clk_i,
  input logic        rst_ni,

  input ctrl_fsm_t   ctrl_fsm,
  input logic [10:0] exc_cause,
  input logic [31:0] mie,
  input logic [31:0] mie_n,
  input logic        mie_we,
  input logic [31:0] mip,
  input dcsr_t       dcsr,
  input              if_id_pipe_t if_id_pipe,
  input id_ex_pipe_t id_ex_pipe,
  input              id_stage_multi_cycle_id_stall,
  input logic        id_stage_id_valid,
  input logic        ex_ready,
  input logic        irq_ack, // irq ack output
  input logic        irq_clic_shv, // ack'ed irq is a CLIC SHV
  input logic        irq_req_ctrl, // Interrupt controller request an interrupt
  input ex_wb_pipe_t ex_wb_pipe,
  input logic        wb_valid,
  input logic        branch_taken_in_ex,
  input logic        last_op_wb,

  input logic        fetch_enable_i,
  input logic        debug_req_i,

  input alu_op_a_mux_e alu_op_a_mux_sel_id_i,
  input alu_op_b_mux_e alu_op_b_mux_sel_id_i,
  input logic [31:0]   operand_a_id_i,
  input logic [31:0]   operand_b_id_i,
  input logic [31:0]   jalr_fw_id_i,
  input logic          last_op_id,
  input logic [31:0]   rf_wdata_wb,
  input logic          rf_we_wb,
  input lsu_atomic_e   lsu_atomic_wb,
  input logic          lsu_valid_wb,
  input logic          lsu_exception_wb,
  input logic          lsu_wpt_match_wb,
  input logic [31:0]   lsu_rdata_wb,
  input logic          lsu_exokay_wb,

  input logic        alu_jmpr_id_i,
  input logic        alu_en_id_i,

  // probed OBI signals
  input logic [31:0] instr_addr_o,
  input logic [1:0]  instr_memtype_o,
  input logic        instr_req_o,
  input logic        instr_dbg_o,
  input logic [1:0]  data_memtype_o,
  input logic        data_req_o,
  input logic        data_gnt_i,
  input logic        data_rvalid_i,
  input logic        data_we_o,
  input logic [5:0]  data_atop_o,
  input logic        data_dbg_o,

  // probed controller signals
  input logic        ctrl_debug_mode_n,
  input logic        ctrl_pending_async_debug,
  input logic        ctrl_async_debug_allowed,
  input logic        ctrl_pending_sync_debug,
  input logic        ctrl_sync_debug_allowed,
  input logic        ctrl_interrupt_allowed,
  input logic        ctrl_pending_interrupt,
  input ctrl_byp_t   ctrl_byp,
  input logic [2:0]  ctrl_debug_cause_n,
  input logic        ctrl_pending_nmi,
  input ctrl_state_e ctrl_fsm_cs,

  input logic        debug_halted_o,

  // probed cs_registers signals
  input logic [31:0] cs_registers_mie_q,
  input logic [31:0] cs_registers_mepc_n,
  input mcause_t     cs_registers_csr_cause_i, // From controller
  input mcause_t     cs_registers_mcause_q,    // From cs_registers, flopped mcause
  input mstatus_t    cs_registers_mstatus_q);

if (CLIC) begin
  property p_clic_mie_tieoff;
    @(posedge clk)
    |mie == 1'b0;
  endproperty
  a_clic_mie_tieoff : assert property(p_clic_mie_tieoff) else `uvm_error("core", "MIE not tied to 0 in CLIC mode")

  property p_clic_mip_tieoff;
    @(posedge clk)
    |mip == 1'b0;
  endproperty
  a_clic_mip_tieoff : assert property(p_clic_mip_tieoff) else `uvm_error("core", "MIP not tied to 0 in CLIC mode")

  //todo: add CLIC related assertions (level thresholds etc)
end else begin
  // CLIC == 0
  // Check that a taken IRQ is actually enabled (e.g. that we do not react to an IRQ that was just disabled in MIE)
  // The actual mie_n value may be different from mie_q if mie is not
  // written to.
  property p_irq_enabled_0;
    @(posedge clk) disable iff (!rst_ni)
    (ctrl_fsm.pc_set && (ctrl_fsm.pc_mux == PC_TRAP_IRQ)) |->
    (mie[exc_cause[4:0]] && cs_registers_mstatus_q.mie && (exc_cause[10:5] == 6'b0));
  endproperty

  a_irq_enabled_0 : assert property(p_irq_enabled_0) else `uvm_error("core", "Assertion a_irq_enabled_0 failed")

  // Check that a taken IRQ was for an enabled cause and that mstatus.mie gets disabled
  property p_irq_enabled_1;
    @(posedge clk) disable iff (!rst_ni)
      (ctrl_fsm.pc_set && (ctrl_fsm.pc_mux == PC_TRAP_IRQ)) |=>
      (cs_registers_mcause_q.irq && cs_registers_mie_q[cs_registers_mcause_q.exception_code[4:0]] && !cs_registers_mstatus_q.mie);
  endproperty

  a_irq_enabled_1 : assert property(p_irq_enabled_1) else `uvm_error("core", "Assertion a_irq_enabled_1 failed")

  // Assert that no pointer can be in any pipeline stage when CLIC == 0
  property p_clic_noptr_in_pipeline;
    @(posedge clk) disable iff (!rst_ni)
      1'b1
      |->
      (!if_id_pipe.instr_meta.clic_ptr && !id_ex_pipe.instr_meta.clic_ptr && !ex_wb_pipe.instr_meta.clic_ptr &&
       !if_id_pipe.instr_meta.mret_ptr && !id_ex_pipe.instr_meta.mret_ptr && !ex_wb_pipe.instr_meta.mret_ptr);
  endproperty

  a_clic_noptr_in_pipeline : assert property(p_clic_noptr_in_pipeline) else `uvm_error("core", "CLIC pointer in pipeline when CLIC is not configured.")
end // CLIC

// First illegal instruction decoded
logic         first_illegal_found;
logic         first_ecall_found;
logic         first_ebrk_found;
logic         first_instr_err_found;
logic         first_instr_mpuerr_found;
logic [31:0]  expected_illegal_mepc;
logic [31:0]  expected_ecall_mepc;
logic [31:0]  expected_ebrk_mepc;
logic [31:0]  expected_instr_err_mepc;
logic [31:0]  expected_instr_mpuerr_mepc;

logic pending_debug;
assign pending_debug = (ctrl_pending_async_debug && ctrl_async_debug_allowed) || (ctrl_pending_sync_debug && ctrl_sync_debug_allowed);

always_ff @(posedge clk , negedge rst_ni)
  begin
    if (rst_ni == 1'b0) begin
      first_illegal_found   <= 1'b0;
      first_ecall_found     <= 1'b0;
      first_ebrk_found      <= 1'b0;
      first_instr_err_found <= 1'b0;
      first_instr_mpuerr_found <= 1'b0;
      expected_illegal_mepc <= 32'b0;
      expected_ecall_mepc   <= 32'b0;
      expected_ebrk_mepc    <= 32'b0;
      expected_instr_err_mepc <= 32'b0;
      expected_instr_mpuerr_mepc <= 32'b0;
    end
    else begin
      // The code below checks for first occurence of each exception type in WB
      // Multiple exceptions may occur at the same time, so the following
      // code needs to check priority of what to expect
      if (!first_illegal_found && ex_wb_pipe.instr_valid && !irq_ack && !pending_debug &&
        !(ex_wb_pipe.instr.bus_resp.err || (ex_wb_pipe.instr.mpu_status != MPU_OK)) &&
        !(ctrl_fsm.pc_mux == PC_TRAP_NMI) &&
          ex_wb_pipe.illegal_insn && !ctrl_debug_mode_n) begin
        first_illegal_found   <= 1'b1;
        expected_illegal_mepc <= ex_wb_pipe.pc;
      end
      if (!first_ecall_found && ex_wb_pipe.instr_valid && !irq_ack && !pending_debug &&
        !(ex_wb_pipe.instr.bus_resp.err || (ex_wb_pipe.instr.mpu_status != MPU_OK) || ex_wb_pipe.illegal_insn) &&
        !(ctrl_fsm.pc_mux == PC_TRAP_NMI) &&
          ex_wb_pipe.sys_en &&  ex_wb_pipe.sys_ecall_insn && !ctrl_debug_mode_n) begin
        first_ecall_found   <= 1'b1;
        expected_ecall_mepc <= ex_wb_pipe.pc;
      end
      if (!first_ebrk_found && ex_wb_pipe.instr_valid && !irq_ack && !pending_debug &&
        !(ex_wb_pipe.instr.bus_resp.err || (ex_wb_pipe.instr.mpu_status != MPU_OK) || ex_wb_pipe.illegal_insn || (ex_wb_pipe.sys_en && ex_wb_pipe.sys_ecall_insn)) &&
        !(ctrl_fsm.pc_mux == PC_TRAP_NMI) && ex_wb_pipe.sys_en && ex_wb_pipe.sys_ebrk_insn) begin
        first_ebrk_found   <= 1'b1;
        expected_ebrk_mepc <= ex_wb_pipe.pc;
      end

      if (!first_instr_err_found && (ex_wb_pipe.instr.mpu_status == MPU_OK) && (ex_wb_pipe.instr.align_status == ALIGN_OK) && !irq_ack && !pending_debug &&
         !(ctrl_fsm.pc_mux == PC_TRAP_NMI) &&
          ex_wb_pipe.instr_valid && ex_wb_pipe.instr.bus_resp.err && !ctrl_debug_mode_n ) begin
        first_instr_err_found   <= 1'b1;
        expected_instr_err_mepc <= ex_wb_pipe.pc;
      end

      if (!first_instr_mpuerr_found && ex_wb_pipe.instr_valid && !irq_ack && !pending_debug &&
         !(ctrl_fsm.pc_mux == PC_TRAP_NMI) &&
          (ex_wb_pipe.instr.mpu_status != MPU_OK) && !ctrl_debug_mode_n) begin
        first_instr_mpuerr_found   <= 1'b1;
        expected_instr_mpuerr_mepc <= ex_wb_pipe.pc;
      end

    end
  end

  // First mepc write for illegal instruction exception
  logic         first_cause_illegal_found;
  logic         first_cause_ecall_found;
  logic         first_cause_ebrk_found;
  logic         first_cause_instr_err_found;
  logic         first_cause_instr_mpuerr_found;
  logic [31:0]  actual_illegal_mepc;
  logic [31:0]  actual_ecall_mepc;
  logic [31:0]  actual_ebrk_mepc;
  logic [31:0]  actual_instr_err_mepc;
  logic [31:0]  actual_instr_mpuerr_mepc;

  always_ff @(posedge clk , negedge rst_ni)
    begin
      if (rst_ni == 1'b0) begin
        first_cause_illegal_found <= 1'b0;
        first_cause_ecall_found   <= 1'b0;
        first_cause_ebrk_found    <= 1'b0;
        first_cause_instr_err_found <= 1'b0;
        first_cause_instr_mpuerr_found <= 1'b0;
        actual_illegal_mepc       <= 32'b0;
        actual_ecall_mepc         <= 32'b0;
        actual_ebrk_mepc          <= 32'b0;
        actual_instr_err_mepc     <= 32'b0;
        actual_instr_mpuerr_mepc  <= 32'b0;
      end
      else begin
        // Disregard saved CSR due to interrupts when chekcing exceptions
        if (!cs_registers_csr_cause_i.irq) begin
          if (!first_cause_illegal_found && (cs_registers_csr_cause_i.exception_code == EXC_CAUSE_ILLEGAL_INSN) && ctrl_fsm.csr_save_cause) begin
            first_cause_illegal_found <= 1'b1;
            actual_illegal_mepc       <= cs_registers_mepc_n;
          end
          if (!first_cause_ecall_found && (cs_registers_csr_cause_i.exception_code == EXC_CAUSE_ECALL_MMODE) && ctrl_fsm.csr_save_cause) begin
            first_cause_ecall_found <= 1'b1;
            actual_ecall_mepc       <= cs_registers_mepc_n;
          end
          if (!first_cause_ebrk_found && (cs_registers_csr_cause_i.exception_code == EXC_CAUSE_BREAKPOINT) && ctrl_fsm.csr_save_cause) begin
            first_cause_ebrk_found <= 1'b1;
            actual_ebrk_mepc       <= cs_registers_mepc_n;
          end
          if (!first_cause_instr_err_found && (cs_registers_csr_cause_i.exception_code == EXC_CAUSE_INSTR_BUS_FAULT) && ctrl_fsm.csr_save_cause) begin
            first_cause_instr_err_found <= 1'b1;
            actual_instr_err_mepc       <= cs_registers_mepc_n;
          end
          if (!first_cause_instr_mpuerr_found && (cs_registers_csr_cause_i.exception_code == EXC_CAUSE_INSTR_FAULT) && ctrl_fsm.csr_save_cause) begin
            first_cause_instr_mpuerr_found <= 1'b1;
            actual_instr_mpuerr_mepc       <= cs_registers_mepc_n;
          end
        end
      end
    end

  // Check that mepc is updated with PC of illegal instruction
  property p_illegal_mepc;
    @(posedge clk) disable iff (!rst_ni)
      (first_illegal_found && first_cause_illegal_found) |=> (expected_illegal_mepc == actual_illegal_mepc);
  endproperty

  a_illegal_mepc : assert property(p_illegal_mepc) else `uvm_error("core", "Assertion a_illegal_mepc failed")

  // Check that mepc is updated with PC of the ECALL instruction
  property p_ecall_mepc;
    @(posedge clk) disable iff (!rst_ni)
      (first_ecall_found && first_cause_ecall_found) |=> (expected_ecall_mepc == actual_ecall_mepc);
  endproperty

  a_ecall_mepc : assert property(p_ecall_mepc) else `uvm_error("core", "Assertion p_ecall_mepc failed")

  // Check that mepc is updated with PC of EBRK instruction
  property p_ebrk_mepc;
    @(posedge clk) disable iff (!rst_ni)
      (first_ebrk_found && first_cause_ebrk_found) |=> (expected_ebrk_mepc == actual_ebrk_mepc);
  endproperty


  // Check that mepc is updated with PC of instr_err instruction
  property p_instr_err_mepc;
    @(posedge clk) disable iff (!rst_ni)
      (first_instr_err_found && first_cause_instr_err_found) |=> (expected_instr_err_mepc == actual_instr_err_mepc);
  endproperty

  a_instr_err_mepc : assert property(p_instr_err_mepc) else `uvm_error("core", "Assertion a_instr_err_mepc failed")

  // Check that mepc is updated with PC of mpu_err instruction
  property p_instr_mpuerr_mepc;
    @(posedge clk) disable iff (!rst_ni)
      (first_instr_mpuerr_found && first_cause_instr_mpuerr_found) |=> (expected_instr_mpuerr_mepc == actual_instr_mpuerr_mepc);
  endproperty

  // No mpu errors will occur if the PMA is deconfigured
  generate
    if (PMA_NUM_REGIONS) begin
      a_instr_mpuerr_mepc : assert property(p_instr_mpuerr_mepc) else `uvm_error("core", "Assertion a_instr_mpuerr_mepc failed")
    end
  endgenerate

  // For checking single step, ID stage is used as it contains a 'multi_cycle_id_stall' signal.
  // This makes it easy to count misaligned LSU ins as one instruction instead of two.
  logic inst_taken;
  assign inst_taken = id_stage_id_valid && ex_ready && last_op_id && !id_stage_multi_cycle_id_stall; // todo: the && !id_stage_multi_cycle_id_stall signal should now no longer be needed

  // Support for single step assertion
  // In case of single step + taken interrupt, the first instruction
  // of the interrupt handler must be fetched and passed down the pipeline.
  // In that case ID stage will issue two instructions in M-mode instead of one.
  logic interrupt_taken;
  always_ff @(posedge clk , negedge rst_ni)
    begin
      if (rst_ni == 1'b0) begin
        interrupt_taken <= 1'b0;
      end
      else begin
        if (irq_ack == 1'b1) begin
          interrupt_taken <= 1'b1;
        end else if (ctrl_debug_mode_n) begin
          interrupt_taken <= 1'b0;
        end
      end
    end


if (CLIC) begin
  if (DEBUG) begin
    // Non-SHV interrupt taken during single stepping.
    // If this happens, no instructions should retire until the core is in debug mode.
    // irq_ack is asserted during FUNCTIONAL state. debug_mode_n will be set during
    // DEBUG_TAKEN one cycle later
    a_single_step_with_irq_nonshv :
      assert property (@(posedge clk) disable iff (!rst_ni)
                        (dcsr.step && !ctrl_fsm.debug_mode && irq_ack && !irq_clic_shv)
                        |->
                        !wb_valid ##1 (!wb_valid && ctrl_debug_mode_n && dcsr.step))
        else `uvm_error("core", "Assertion a_single_step_with_irq_nonshv failed")
  end // DEBUG

  // An SHV CLIC interrupt will first do one fetch to get a function pointer,
  // then a second fetch to the actual interrupt handler. If the first fetch has
  // no faults, debug is entered with dpc pointing to the handler entry when the pointer reaches the WB stage.
  // Otherwise, if the pointer fetch failed, we will start fetching the appropriate exception handler
  // before entering debug with DPC pointing to the first exception handler instruction.
  // External debug entry and interrupts (including NMIs) are not allowed to be taken while there is
  // a live pointer in WB (IF-ID: guarded by POINTER_FETCH STATE, EX-WB: guarded by clic_ptr_in_pipeline).
  //   - this could cause the address of the pointer to end up in DPC, making dret jumping to a mtvt entry instead of an instruction.
  /*
      todo: Reintroduce (and update) when debug single step logic has been updated and POINTER_FETCH state removed.
             -should likely flop the event that causes single step entry to evaluate all debug reasons
              when the pipeline is guaranteed to not disallow any debug reason to enter debug.
  a_single_step_with_irq_shv :
    assert property (@(posedge clk) disable iff (!rst_ni)
                      (dcsr.step && !ctrl_fsm.debug_mode && irq_ack && irq_clic_shv)
                      |->
                         (!wb_valid until (wb_valid && ex_wb_pipe.instr_meta.clic_ptr) // CLIC pointer in WB, enter DEBUG_TAKEN
                         ##1 ctrl_debug_mode_n)   // Debug mode from next cycle
                      or
                         (!wb_valid until (ctrl_debug_mode_n && (ctrl_debug_cause_n == DBG_CAUSE_HALTREQ)))) // external debug happened before pointer reached WB
      else `uvm_error("core", "Assertion a_single_step_with_irq_shv failed")
*/

end else begin
  // Interrupt taken during single stepping.
  // If this happens, no intstructions should retire until the core is in debug mode.
  // irq_ack is asserted during FUNCTIONAL state. debug_mode_n will be set during
  // DEBUG_TAKEN one cycle later
  a_single_step_with_irq :
    assert property (@(posedge clk) disable iff (!rst_ni)
                      (dcsr.step && !ctrl_fsm.debug_mode && irq_ack)
                      |->
                      !wb_valid ##1 (!wb_valid && ctrl_debug_mode_n && dcsr.step))
      else `uvm_error("core", "Assertion a_single_step_with_irq failed")
end


  // Check that instruction fetches are always word aligned
  a_instr_addr_word_aligned :
    assert property (@(posedge clk) disable iff (!rst_ni)
                     (instr_addr_o[1:0] == 2'b00))
      else `uvm_error("core", "Instruction fetch not word aligned")

  // Check that instruction fetches are always non-bufferable
  a_instr_non_bufferable :
    assert property (@(posedge clk) disable iff (!rst_ni)
                     (!instr_memtype_o[0]))
      else `uvm_error("core", "Instruction fetch classified as bufferable")

  // Check that loads are always non-bufferable
  a_load_non_bufferable :
    assert property (@(posedge clk) disable iff (!rst_ni)
                     (data_req_o && !data_we_o |-> !data_memtype_o[0]))
      else `uvm_error("core", "Load instruction classified as bufferable")


  generate
    if (A_EXT == A_NONE) begin
      a_atomic_disabled_never_atop :
        assert property (@(posedge clk) disable iff (!rst_ni)
                         (data_atop_o == 6'b0) &&
                         (lsu_atomic_wb == AT_NONE))
          else `uvm_error("core", "Atomic operations should never occur without A-extension enabled")

      a_never_atomic_stall:
      assert property (@(posedge clk) disable iff (!rst_ni)
                       !ctrl_byp.atomic_stall)
          else `uvm_error("core", "Stalling for atomics without A_EXT enabled")


    end
    else begin
      // Helper logic:
      /////////////////////////////////////////////////////////////
      // Count outstanding transaction on the data OBI bus
      logic count_up;
      logic count_down;
      logic [1:0] next_cnt;
      logic [1:0] cnt_q;
      assign count_up = data_req_o && data_gnt_i;
      assign count_down = data_rvalid_i;

      always_comb begin
        case ({count_up, count_down})
          2'b00 : begin
            next_cnt = cnt_q;
          end
          2'b01 : begin
            next_cnt = cnt_q - 1'b1;
          end
          2'b10 : begin
            next_cnt = cnt_q + 1'b1;
          end
          2'b11 : begin
            next_cnt = cnt_q;
          end
          default:;
        endcase
      end

      always_ff @(posedge clk, negedge rst_ni)
      begin
        if (rst_ni == 1'b0) begin
          cnt_q <= '0;
        end else begin
          cnt_q <= next_cnt;
        end
      end

      /////////////////////////////////////////////////////////////

      // Check that atomic operations are always non-bufferable
      a_atomic_non_bufferable :
        assert property (@(posedge clk) disable iff (!rst_ni)
                         (data_req_o && |data_atop_o |-> !data_memtype_o[0]))
          else `uvm_error("core", "Atomic operation classified as bufferable")


      // All instructions from the A-extension write the register file
      a_all_atop_write_rf:
        assert property (@(posedge clk) disable iff (!rst_ni)
                        (lsu_atomic_wb != AT_NONE) && lsu_valid_wb && !lsu_exception_wb && !lsu_wpt_match_wb
                        |->
                        rf_we_wb)
          else `uvm_error("core", "Atomic instruction did not write the register file")

      // SC.W which receives !exokay must write 1 to the register file
      a_atop_sc_fault_rf_wdata:
        assert property (@(posedge clk) disable iff (!rst_ni)
                        (lsu_atomic_wb == AT_SC) && lsu_valid_wb && !lsu_exception_wb && !lsu_wpt_match_wb &&
                        !lsu_exokay_wb
                        |->
                        (lsu_rdata_wb == 32'h1))
          else `uvm_error("core", "Register file not written with 1 on SC fault due to exokay==0")

      // SC.W which receives exokay must write 0 to the register file
      a_atop_sc_success_rf_wdata:
        assert property (@(posedge clk) disable iff (!rst_ni)
                        (lsu_atomic_wb == AT_SC) && lsu_valid_wb && !lsu_exception_wb && !lsu_wpt_match_wb &&
                        lsu_exokay_wb
                        |->
                        (lsu_rdata_wb == 32'h0))
          else `uvm_error("core", "Register file not written with 0 on SC success.")

      // Do not allow any atomic address phase in EX if there are unfinished LSU instructions in WB
      // This implies that there shall be no outstanding transactions on the OBI bus (cnt_q == 0)
      a_no_atop_until_lsu_clear:
        assert property (@(posedge clk) disable iff (!rst_ni)
                        (cnt_q != 2'b00)
                        |->
                        !(data_atop_o[5] && data_req_o))
          else `uvm_error("core", "Atomic instruction allowed on bus while there are outstanding transactions")

      // Do not allow any memory address phase in EX if there are unfinished atomic instructions in WB
      // This implies that if an atomic is in WB, the outstanding counter must be 1.
      a_no_lsu_until_atop_clear:
        assert property (@(posedge clk) disable iff (!rst_ni)
                        (ex_wb_pipe.lsu_en && ex_wb_pipe.instr_valid) &&   // Valid LSU instruction in WB
                        (lsu_atomic_wb != AT_NONE) &&                      // LSU instruction is atomic
                        !(lsu_exception_wb || lsu_wpt_match_wb)            // No exception or watchpoint (it reached the bus)
                        |->
                        !data_req_o &&
                        (cnt_q == 2'b01))
            else `uvm_error("core", "Non-atomic LSU instruction allowed on bus before preceeding atomic is finished")

    end
  endgenerate


  // Check that operand_a data forwarded from EX to ID actually is written to RF in WB
  property p_opa_fwd_ex;
    logic [31:0] opa;
    @(posedge clk) disable iff (!rst_ni)
    (id_stage_id_valid && ex_ready && (alu_op_a_mux_sel_id_i == OP_A_REGA_OR_FWD) && (ctrl_byp.operand_a_fw_mux_sel == SEL_FW_EX), opa=operand_a_id_i)
    |=> (opa == rf_wdata_wb) && (rf_we_wb || (ctrl_fsm.kill_ex || ctrl_fsm.halt_ex));
  endproperty

  a_opa_fwd_ex: assert property (p_opa_fwd_ex)
    else `uvm_error("core", "Forwarded data (operand_a) from EX not written to RF the following cycle")

  // Check that operand_a data forwarded from WB to ID actually is written to RF in WB
  property p_opa_fwd_wb;
    @(posedge clk) disable iff (!rst_ni)
    (id_stage_id_valid && ex_ready && (alu_op_a_mux_sel_id_i == OP_A_REGA_OR_FWD) && (ctrl_byp.operand_a_fw_mux_sel == SEL_FW_WB))
    |-> (operand_a_id_i == rf_wdata_wb) && rf_we_wb;
  endproperty

  a_opa_fwd_wb: assert property (p_opa_fwd_wb)
    else `uvm_error("core", "Forwarded data (operand_a) from WB not written to RF in the same cycle")

  // Check that operand_b data forwarded from EX to ID actually is written to RF in WB
  property p_opb_fwd_ex;
    logic [31:0] opb;
    @(posedge clk) disable iff (!rst_ni)
    (id_stage_id_valid && ex_ready && (alu_op_b_mux_sel_id_i == OP_B_REGB_OR_FWD) && (ctrl_byp.operand_b_fw_mux_sel == SEL_FW_EX), opb=operand_b_id_i)
    |=> (opb == rf_wdata_wb) && (rf_we_wb || (ctrl_fsm.kill_ex || ctrl_fsm.halt_ex));
  endproperty

  a_opb_fwd_ex: assert property (p_opb_fwd_ex)
    else `uvm_error("core", "Forwarded data (operand_b) from EX not written to RF the following cycle")

  // Check that operand_b data forwarded from WB to ID actually is written to RF in WB
  property p_opb_fwd_wb;
    @(posedge clk) disable iff (!rst_ni)
    (id_stage_id_valid && ex_ready && (alu_op_b_mux_sel_id_i == OP_B_REGB_OR_FWD) && (ctrl_byp.operand_b_fw_mux_sel == SEL_FW_WB))
    |-> (operand_b_id_i == rf_wdata_wb) && rf_we_wb;
  endproperty

  a_opb_fwd_wb: assert property (p_opb_fwd_wb)
    else `uvm_error("core", "Forwarded data (operand_b) from WB not written to RF in the same cycle")

  // Check that data forwarded from WB to a JALR instruction in ID is actully written to the RF
  property p_jalr_fwd;
    @(posedge clk) disable iff (!rst_ni)
    (alu_jmpr_id_i && alu_en_id_i && if_id_pipe.instr_valid) && (ctrl_byp.jalr_fw_mux_sel == SELJ_FW_WB) && !ctrl_byp.jalr_stall
    |->
    (jalr_fw_id_i == rf_wdata_wb) && (rf_we_wb || (ctrl_fsm.kill_id || ctrl_fsm.halt_id));
  endproperty

  a_jalr_fwd: assert property(p_jalr_fwd)
    else `uvm_error("core", "Forwarded jalr data from WB to ID not written to RF")

  // Check that a table jump in ID is stalled when a CSR is written in EX or WB (could be JVT being written)
  property p_tbljmp_stall;
    @(posedge clk) disable iff (!rst_ni)
    (id_ex_pipe.instr_valid && id_ex_pipe.csr_en) ||
    (ex_wb_pipe.instr_valid && ex_wb_pipe.csr_en)
    |->
    !ctrl_fsm.pc_set_tbljmp;
  endproperty;

  a_tbljmp_stall: assert property(p_tbljmp_stall)
    else `uvm_error("core", "Table jump not stalled while CSR is written");

if (!CLIC) begin
  // Check that a pending interrupt is taken as soon as possible after being enabled
  property p_mip_mie_write_enable;
    @(posedge clk) disable iff (!rst_ni)
    ( !irq_req_ctrl
       ##1
       irq_req_ctrl && $stable(mip) && !(ctrl_fsm.debug_mode || (dcsr.step && !dcsr.stepie))
       |-> (ctrl_pending_interrupt && ctrl_interrupt_allowed));
  endproperty;

  a_mip_mie_write_enable: assert property(p_mip_mie_write_enable)
    else `uvm_error("core", "Interrupt not taken soon enough after enabling");

  // Check that only NMI and external debug take presedence over interrupts after being enabled by mret or CSR writes
  property p_irq_pri;
    @(posedge clk) disable iff (!rst_ni)
    ( !irq_req_ctrl  // No interrupt pending
       ##1          // Next cycle
       irq_req_ctrl && $stable(mip) && !(ctrl_fsm.debug_mode || (dcsr.step && !dcsr.stepie)) && // Interrupt pending but irq inputs are unchanged
       (ctrl_fsm_cs != DEBUG_TAKEN) &&  // Make sure we are not handling a debug entry already (could be a single stepped mret enabling interrupts for instance)
       !(ctrl_pending_nmi || ctrl_pending_async_debug)   // No pending events with higher priority than interrupts are taking place
       |->
       ctrl_fsm.irq_ack);  // We must take the interrupt if enabled (mret or CSR write) and no NMI or external debug is pending
  endproperty;

  a_irq_pri: assert property(p_irq_pri)
    else `uvm_error("core", "Interrupt not taken soon enough after enabling");

  // Check a pending interrupt that is disabled is actually not taken
  property p_mip_mie_write_disable;
    @(posedge clk) disable iff (!rst_ni)
    (  irq_req_ctrl
        ##1
        !irq_req_ctrl && $stable(mip)
        |-> !(ctrl_pending_interrupt && ctrl_interrupt_allowed));
  endproperty;

  a_mip_mie_write_disable: assert property(p_mip_mie_write_disable)
    else `uvm_error("core", "Interrupt taken after disabling");
end

// Clearing external interrupts via a store instruction causes irq_i to go low the next cycle.
  // The interrupt controller uses flopped versions of irq_i, and thus we need to disregard interrupts
  // for one cycle after an rvalid has been observed.
property p_no_irq_after_lsu;
  @(posedge clk) disable iff (!rst_ni)
  (  wb_valid && ex_wb_pipe.lsu_en && ex_wb_pipe.instr_valid
     |=>
     !ctrl_interrupt_allowed);
endproperty;

a_no_irq_after_lsu: assert property(p_no_irq_after_lsu)
  else `uvm_error("core", "Interrupt taken after disabling");



generate
  if (!DEBUG) begin
    a_nodebug_never_debug:
      assert property (@(posedge clk_i) disable iff (!rst_ni)
                      !ctrl_fsm.debug_mode)
          else `uvm_error("core", "Debug mode entered without support for debug.")

    a_nodebug_never_debug_halted:
      assert property (@(posedge clk_i) disable iff (!rst_ni)
                      !debug_halted_o)
          else `uvm_error("core", "Debug_halated_o set without support for debug.")

    a_nodebug_never_instr_dbg:
      assert property (@(posedge clk_i) disable iff (!rst_ni)
                      !instr_dbg_o)
          else `uvm_error("core", "instr_dbg_o set without support for debug.")

    a_nodebug_never_data_dbg:
      assert property (@(posedge clk_i) disable iff (!rst_ni)
                      !data_dbg_o)
          else `uvm_error("core", "data_dbg_o set without support for debug.")
  end else begin
    // DEBUG related assertions

    // If debug_req_i is asserted when fetch_enable_i gets asserted we should not execute any
    // instruction until the core is in debug mode.
    a_reset_into_debug:
    assert property (@(posedge clk_i) disable iff (!rst_ni)
                    (ctrl_fsm_cs == RESET) &&
                    fetch_enable_i &&
                    debug_req_i
                    ##1
                    debug_req_i // Controller gets a one cycle delayed fetch enable, must keep debug_req_i asserted for two cycles
                    |->
                    !wb_valid until (wb_valid && ctrl_fsm.debug_mode))
      else `uvm_error("controller", "Debug out of reset but executed instruction outside debug mode")

    // When entering debug out of reset, the first fetch must also flag debug on the instruction OBI interface
    a_first_fetch_debug:
    assert property (@(posedge clk_i) disable iff (!rst_ni)
                    (ctrl_fsm_cs == RESET) &&
                    fetch_enable_i &&
                    debug_req_i
                    ##1
                    debug_req_i // Controller gets a one cycle delayed fetch enable, must keep debug_req_i asserted for two cycles
                    |->
                    !instr_req_o until (instr_req_o && instr_dbg_o))
      else `uvm_error("controller", "Debug out of reset but fetched without setting instr_dbg_o")

    // Check that only a single instruction can retire during single step
    a_single_step_retire :
    assert property (@(posedge clk) disable iff (!rst_ni)
                      (wb_valid && last_op_wb && dcsr.step && !ctrl_fsm.debug_mode)
                      ##1 wb_valid [->1]
                      |-> (ctrl_fsm.debug_mode && dcsr.step))
      else `uvm_error("core", "Multiple instructions retired during single stepping")

    // Single step without interrupts
    // Should issue exactly one instruction from ID before entering debug_mode
    a_single_step_no_irq :
    assert property (@(posedge clk) disable iff (!rst_ni || interrupt_taken)
                    (inst_taken && dcsr.step && !ctrl_fsm.debug_mode)
                    ##1 inst_taken [->1]
                    |-> (ctrl_fsm.debug_mode && dcsr.step))
      else `uvm_error("core", "Assertion a_single_step_no_irq failed")

    // todo: add similar assertion as above to check that only one instruction moves from IF to ID while taking a single step (rename inst_taken to inst_taken_id and introduce similar inst_taken_if signal)

  end
endgenerate
endmodule // cv32e40x_core_sva
