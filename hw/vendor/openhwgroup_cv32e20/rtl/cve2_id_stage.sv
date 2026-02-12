// Copyright (c) 2025 Eclipse Foundation
// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifdef RISCV_FORMAL
  `define RVFI
`endif

/**
 * Instruction Decode Stage
 *
 * Decode stage of the core. It decodes the instructions and hosts the register
 * file.
 */

`include "prim_assert.sv"
`include "dv_fcov_macros.svh"

module cve2_id_stage #(
  parameter bit               RV32E           = 0,
  parameter cve2_pkg::rv32m_e RV32M           = cve2_pkg::RV32MFast,
  parameter cve2_pkg::rv32b_e RV32B           = cve2_pkg::RV32BNone,
  parameter bit               XInterface      = 1'b0
) (
  input  logic                      clk_i,
  input  logic                      rst_ni,

  input  logic                      fetch_enable_i,
  output logic                      ctrl_busy_o,
  output logic                      illegal_insn_o,

  // Interface to IF stage
  input  logic                      instr_valid_i,
  input  logic [31:0]               instr_rdata_i,         // from IF-ID pipeline registers
  input  logic [31:0]               instr_rdata_alu_i,     // from IF-ID pipeline registers
  input  logic [15:0]               instr_rdata_c_i,       // from IF-ID pipeline registers
  input  logic                      instr_is_compressed_i,
  output logic                      instr_req_o,
  output logic                      instr_first_cycle_id_o,
  output logic                      instr_valid_clear_o,   // kill instr in IF-ID reg
  output logic                      id_in_ready_o,         // ID stage is ready for next instr

  // Jumps and branches
  input  logic                      branch_decision_i,

  // IF and ID stage signals
  output logic                      pc_set_o,
  output cve2_pkg::pc_sel_e         pc_mux_o,
  output cve2_pkg::exc_pc_sel_e     exc_pc_mux_o,
  output cve2_pkg::exc_cause_e      exc_cause_o,

  input  logic                      illegal_c_insn_i,
  input  logic                      instr_fetch_err_i,
  input  logic                      instr_fetch_err_plus2_i,

  input  logic [31:0]               pc_id_i,

  // Stalls
  input  logic                      ex_valid_i,       // EX stage has valid output
  input  logic                      lsu_resp_valid_i, // LSU has valid output, or is done
  // ALU
  output cve2_pkg::alu_op_e         alu_operator_ex_o,
  output logic [31:0]               alu_operand_a_ex_o,
  output logic [31:0]               alu_operand_b_ex_o,

  // Multicycle Operation Stage Register
  input  logic [1:0]                imd_val_we_ex_i,
  input  logic [33:0]               imd_val_d_ex_i[2],
  output logic [33:0]               imd_val_q_ex_o[2],

  // MUL, DIV
  output logic                      mult_en_ex_o,
  output logic                      div_en_ex_o,
  output logic                      mult_sel_ex_o,
  output logic                      div_sel_ex_o,
  output cve2_pkg::md_op_e          multdiv_operator_ex_o,
  output logic  [1:0]               multdiv_signed_mode_ex_o,
  output logic [31:0]               multdiv_operand_a_ex_o,
  output logic [31:0]               multdiv_operand_b_ex_o,

  // CSR
  output logic                      csr_access_o,
  output cve2_pkg::csr_op_e         csr_op_o,
  output logic                      csr_op_en_o,
  output logic                      csr_save_if_o,
  output logic                      csr_save_id_o,
  output logic                      csr_restore_mret_id_o,
  output logic                      csr_restore_dret_id_o,
  output logic                      csr_save_cause_o,
  output logic [31:0]               csr_mtval_o,
  input  cve2_pkg::priv_lvl_e       priv_mode_i,
  input  logic                      csr_mstatus_tw_i,
  input  logic                      illegal_csr_insn_i,

  // Interface to load store unit
  output logic                      lsu_req_o,
  output logic                      lsu_we_o,
  output logic [1:0]                lsu_type_o,
  output logic                      lsu_sign_ext_o,
  output logic [31:0]               lsu_wdata_o,

  input  logic                      lsu_addr_incr_req_i,
  input  logic [31:0]               lsu_addr_last_i,

  //  Core-V eXtension Interface (CV-X-IF)
  input  logic [31:0]               hart_id_i,
  //  Issue Interface
  output logic                      x_issue_valid_o,
  input  logic                      x_issue_ready_i,
  output cve2_pkg::x_issue_req_t    x_issue_req_o,
  input  cve2_pkg::x_issue_resp_t   x_issue_resp_i,

  // Register Interface
  output  cve2_pkg::x_register_t    x_register_o,

  // Commit Interface
  output logic                      x_commit_valid_o,
  output cve2_pkg::x_commit_t       x_commit_o,

  // Result Interface
  input  logic                      x_result_valid_i,
  output logic                      x_result_ready_o,
  input   cve2_pkg::x_result_t      x_result_i,

  // Interrupt signals
  input  logic                      csr_mstatus_mie_i,
  input  logic                      irq_pending_i,
  input  cve2_pkg::irqs_t           irqs_i,
  input  logic                      irq_nm_i,
  output logic                      nmi_mode_o,

  input  logic                      lsu_load_err_i,
  input  logic                      lsu_store_err_i,

  // Debug Signal
  output logic                      debug_mode_o,
  output cve2_pkg::dbg_cause_e      debug_cause_o,
  output logic                      debug_csr_save_o,
  input  logic                      debug_req_i,
  input  logic                      debug_single_step_i,
  input  logic                      debug_ebreakm_i,
  input  logic                      debug_ebreaku_i,
  input  logic                      trigger_match_i,

  // Write back signal
  input  logic [31:0]               result_ex_i,
  input  logic [31:0]               csr_rdata_i,

  // Register file read
  output logic [4:0]                rf_raddr_a_o,
  input  logic [31:0]               rf_rdata_a_i,
  output logic [4:0]                rf_raddr_b_o,
  input  logic [31:0]               rf_rdata_b_i,
  output logic                      rf_ren_a_o,
  output logic                      rf_ren_b_o,

  // Register file write (via writeback)
  output logic [4:0]                rf_waddr_id_o,
  output logic [31:0]               rf_wdata_id_o,
  output logic                      rf_we_id_o,

  output  logic                     en_wb_o,
  output  logic                     instr_perf_count_id_o,

  // Performance Counters
  output logic                      perf_jump_o,    // executing a jump instr
  output logic                      perf_branch_o,  // executing a branch instr
  output logic                      perf_tbranch_o, // executing a taken branch instr
  output logic                      perf_dside_wait_o, // instruction in ID/EX is awaiting memory
                                                        // access to finish before proceeding
  output logic                      perf_wfi_wait_o,
  output logic                      perf_div_wait_o,
  output logic                      instr_id_done_o
);

  import cve2_pkg::*;

  // Decoder/Controller, ID stage internal signals
  logic        illegal_insn_dec;
  logic        ebrk_insn;
  logic        mret_insn_dec;
  logic        dret_insn_dec;
  logic        ecall_insn_dec;
  logic        wfi_insn_dec;

  logic        branch_in_dec;
  logic        branch_set, branch_set_raw, branch_set_raw_d;
  logic        branch_jump_set_done_q, branch_jump_set_done_d;
  logic        jump_in_dec;
  logic        jump_set_dec;
  logic        jump_set, jump_set_raw;

  logic        instr_first_cycle;
  logic        instr_executing_spec;
  logic        instr_executing;
  logic        instr_done;
  logic        controller_run;
  logic        stall_mem;
  logic        stall_multdiv;
  logic        stall_branch;
  logic        stall_jump;
  logic        stall_id;
  logic        flush_id;
  logic        multicycle_done;

  // Immediate decoding and sign extension
  logic [31:0] imm_i_type;
  logic [31:0] imm_s_type;
  logic [31:0] imm_b_type;
  logic [31:0] imm_u_type;
  logic [31:0] imm_j_type;
  logic [31:0] zimm_rs1_type;

  logic [31:0] imm_a;       // contains the immediate for operand b
  logic [31:0] imm_b;       // contains the immediate for operand b

  // Register file interface

  logic [XInterface:0] rf_wdata_sel;
  logic                rf_we_dec, rf_we_raw;
  logic                rf_ren_a, rf_ren_b;
  logic                rf_ren_a_dec, rf_ren_b_dec;

  // Read enables should only be asserted for valid and legal instructions
  assign rf_ren_a = instr_valid_i & ~instr_fetch_err_i & ~illegal_insn_o & rf_ren_a_dec;
  assign rf_ren_b = instr_valid_i & ~instr_fetch_err_i & ~illegal_insn_o & rf_ren_b_dec;

  assign rf_ren_a_o = rf_ren_a;
  assign rf_ren_b_o = rf_ren_b;

  logic [31:0] rf_rdata_a_fwd;
  logic [31:0] rf_rdata_b_fwd;

  // ALU Control
  alu_op_e     alu_operator;
  op_a_sel_e   alu_op_a_mux_sel, alu_op_a_mux_sel_dec;
  op_b_sel_e   alu_op_b_mux_sel, alu_op_b_mux_sel_dec;
  logic        alu_multicycle_dec;
  logic        stall_alu;

  logic [33:0] imd_val_q[2];

  imm_a_sel_e  imm_a_mux_sel;
  imm_b_sel_e  imm_b_mux_sel, imm_b_mux_sel_dec;

  // Multiplier Control
  logic        mult_en_id, mult_en_dec; // use integer multiplier
  logic        div_en_id, div_en_dec;   // use integer division or reminder
  logic        multdiv_en_dec;
  md_op_e      multdiv_operator;
  logic [1:0]  multdiv_signed_mode;

  // Data Memory Control
  logic        lsu_we;
  logic [1:0]  lsu_type;
  logic        lsu_sign_ext;
  logic        lsu_req, lsu_req_dec;
  logic        data_req_allowed;

  // CSR control
  logic        csr_pipe_flush;

  logic [31:0] alu_operand_a;
  logic [31:0] alu_operand_b;

  // CV-X-IF
  logic stall_coproc;
  logic scoreboard_busy;

  ///////////////
  // ID-EX FSM //
  ///////////////

  typedef enum logic { FIRST_CYCLE, MULTI_CYCLE } id_fsm_e;
  id_fsm_e id_fsm_q, id_fsm_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin : id_pipeline_reg
    if (!rst_ni) begin
      id_fsm_q <= FIRST_CYCLE;
    end else if (instr_executing) begin
      id_fsm_q <= id_fsm_d;
    end
  end

  // CV-X-IF
  if (XInterface) begin: gen_xif

    logic coproc_done;
    logic [X_INSTR_INFLIGHT-1:0] scoreboard_d, scoreboard_q;
    id_t x_instr_id_d, x_instr_id_q;

    logic scoreboard_free;

    // The cve2 can issue up to X_INSTR_INFLIGHT instructions over the X-IF 
    // without waiting for their completion.
    //
    // Each issued instruction, identified by a unique ID, sets its corresponding 
    // scoreboard bit to `1`. When the instruction completes, that bit is cleared 
    // back to `0`.
    //
    // The cve2 always issues instructions in order, but the co-processor may 
    // complete (commit) them out of order.
    //
    // Once the scoreboard has issued the X_INSTR_INFLIGHT-th instruction, 
    // the instruction ID counter wraps around to 0.
    //
    // If the previous instruction with ID 0 has already completed 
    // (i.e., scoreboard[0] == 0), the cve2 can issue a new instruction with ID 0. 
    // Otherwise, it waits for the instruction with ID 0 to finish before reusing it.
    //
    // This behavior applies similarly to all other instruction IDs.

    assign scoreboard_free = ~scoreboard_q[x_instr_id_q];


    assign scoreboard_busy = (scoreboard_q != '0);


    always_comb begin
      scoreboard_d = scoreboard_q;
      x_instr_id_d = x_instr_id_q;
      if (x_issue_valid_o && x_issue_ready_i && x_issue_resp_i.accept) begin
        scoreboard_d[x_instr_id_q] = 1'b1;
        x_instr_id_d = x_instr_id_q + 1'b1;
      end
      if (x_result_valid_i) begin
        scoreboard_d[x_result_i.id] = 1'b0;
      end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : x_scoreboard
      if (!rst_ni) begin
        scoreboard_q <= '0;
        x_instr_id_q <= '0;
      end else begin
        scoreboard_q <= scoreboard_d;
        x_instr_id_q <= x_instr_id_d;
      end
    end

    assign multicycle_done = lsu_req_dec ? lsu_resp_valid_i : (illegal_insn_dec ? coproc_done : ex_valid_i);

    assign coproc_done = (x_issue_valid_o & x_issue_ready_i & ~x_issue_resp_i.writeback) | (x_result_valid_i & x_result_i.we);

    // Issue Interface
    assign x_issue_valid_o      = instr_executing & illegal_insn_dec & (id_fsm_q == FIRST_CYCLE) & scoreboard_free;
    assign x_issue_req_o.instr  = instr_rdata_i;
    assign x_issue_req_o.id     = x_instr_id_q;
    assign x_issue_req_o.hartid = hart_id_i;

    // Register Interface
    assign x_register_o.rs[0]    = rf_rdata_a_fwd;
    assign x_register_o.rs[1]    = rf_rdata_b_fwd;
    assign x_register_o.rs_valid = '1;
    assign x_register_o.id       = x_instr_id_q;
    assign x_register_o.hartid   = hart_id_i;
    assign x_commit_valid_o       = x_issue_valid_o & x_issue_ready_i;
    assign x_commit_o.commit_kill = 1'b0;
    assign x_commit_o.id          = x_instr_id_q;
    assign x_commit_o.hartid      = hart_id_i;

    // Result Interface
    assign x_result_ready_o = 1'b1;

    assign illegal_insn_o = instr_valid_i & (illegal_csr_insn_i | (x_issue_valid_o & x_issue_ready_i & ~x_issue_resp_i.accept));
  end

  else begin: no_gen_xif
    logic          unused_x_issue_ready;
    x_issue_resp_t unused_x_issue_resp;
    logic          unused_x_result_valid;
    x_result_t     unused_x_result;


    assign multicycle_done = lsu_req_dec ? lsu_resp_valid_i : ex_valid_i;
    assign scoreboard_busy = 1'b0;

    // Issue Interface
    assign x_issue_valid_o      = 1'b0;
    assign unused_x_issue_ready = x_issue_ready_i;
    assign x_issue_req_o        = '0;
    assign unused_x_issue_resp  = x_issue_resp_i;

    // Register Interface
    assign x_register_o = '0;

    // Commit Interface
    assign x_commit_valid_o = 1'b0;
    assign x_commit_o       = '0;

    // Result Interface
    assign x_result_ready_o      = 1'b0;
    assign unused_x_result_valid = x_result_valid_i;
    assign unused_x_result       = x_result_i;

    assign illegal_insn_o = instr_valid_i & (illegal_csr_insn_i | illegal_insn_dec);
  end

  /////////////
  // LSU Mux //
  /////////////

  // Misaligned loads/stores result in two aligned loads/stores, compute second address
  assign alu_op_a_mux_sel = lsu_addr_incr_req_i ? OP_A_FWD        : alu_op_a_mux_sel_dec;
  assign alu_op_b_mux_sel = lsu_addr_incr_req_i ? OP_B_IMM        : alu_op_b_mux_sel_dec;
  assign imm_b_mux_sel    = lsu_addr_incr_req_i ? IMM_B_INCR_ADDR : imm_b_mux_sel_dec;

  ///////////////////
  // Operand MUXES //
  ///////////////////

  // Main ALU immediate MUX for Operand A
  assign imm_a = (imm_a_mux_sel == IMM_A_Z) ? zimm_rs1_type : '0;

  // Main ALU MUX for Operand A
  always_comb begin : alu_operand_a_mux
    unique case (alu_op_a_mux_sel)
      OP_A_REG_A:  alu_operand_a = rf_rdata_a_fwd;
      OP_A_FWD:    alu_operand_a = lsu_addr_last_i;
      OP_A_CURRPC: alu_operand_a = pc_id_i;
      OP_A_IMM:    alu_operand_a = imm_a;
      default:     alu_operand_a = pc_id_i;
    endcase
  end

  op_a_sel_e  unused_a_mux_sel;
  imm_b_sel_e unused_b_mux_sel;

  // Full main ALU immediate MUX for Operand B
  always_comb begin : immediate_b_mux
    unique case (imm_b_mux_sel)
      IMM_B_I:         imm_b = imm_i_type;
      IMM_B_S:         imm_b = imm_s_type;
      IMM_B_B:         imm_b = imm_b_type;
      IMM_B_U:         imm_b = imm_u_type;
      IMM_B_J:         imm_b = imm_j_type;
      IMM_B_INCR_PC:   imm_b = instr_is_compressed_i ? 32'h2 : 32'h4;
      IMM_B_INCR_ADDR: imm_b = 32'h4;
      default:         imm_b = 32'h4;
    endcase
  end
  `ASSERT(CVE2ImmBMuxSelValid, instr_valid_i |-> imm_b_mux_sel inside {
      IMM_B_I,
      IMM_B_S,
      IMM_B_B,
      IMM_B_U,
      IMM_B_J,
      IMM_B_INCR_PC,
      IMM_B_INCR_ADDR})

  // ALU MUX for Operand B
  assign alu_operand_b = (alu_op_b_mux_sel == OP_B_IMM) ? imm_b : rf_rdata_b_fwd;

  /////////////////////////////////////////
  // Multicycle Operation Stage Register //
  /////////////////////////////////////////

  for (genvar i = 0; i < 2; i++) begin : gen_intermediate_val_reg
    always_ff @(posedge clk_i or negedge rst_ni) begin : intermediate_val_reg
      if (!rst_ni) begin
        imd_val_q[i] <= '0;
      end else if (imd_val_we_ex_i[i]) begin
        imd_val_q[i] <= imd_val_d_ex_i[i];
      end
    end
  end

  assign imd_val_q_ex_o = imd_val_q;

  ///////////////////////
  // Register File MUX //
  ///////////////////////

  // Suppress register write if there is an illegal CSR access or instruction is not executing
  assign rf_we_id_o = rf_we_raw & instr_executing & ~illegal_csr_insn_i;

  // Register file write data mux
  always_comb begin : rf_wdata_id_mux
    unique case ($bits(rf_wd_sel_e)'({rf_wdata_sel}))
      RF_WD_EX:     rf_wdata_id_o   = result_ex_i;
      RF_WD_CSR:    rf_wdata_id_o   = csr_rdata_i;
      RF_WD_COPROC: rf_wdata_id_o   = XInterface? x_result_i.data : result_ex_i;
      default:      rf_wdata_id_o   = result_ex_i;
    endcase
  end

  /////////////
  // Decoder //
  /////////////

  cve2_decoder #(
    .RV32E          (RV32E),
    .RV32M          (RV32M),
    .RV32B          (RV32B),
    .XInterface     (XInterface)
  ) decoder_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    // controller
    .illegal_insn_o(illegal_insn_dec),
    .ebrk_insn_o   (ebrk_insn),
    .mret_insn_o   (mret_insn_dec),
    .dret_insn_o   (dret_insn_dec),
    .ecall_insn_o  (ecall_insn_dec),
    .wfi_insn_o    (wfi_insn_dec),
    .jump_set_o    (jump_set_dec),

    // from IF-ID pipeline register
    .instr_first_cycle_i(instr_first_cycle),
    .instr_rdata_i      (instr_rdata_i),
    .instr_rdata_alu_i  (instr_rdata_alu_i),
    .illegal_c_insn_i   (illegal_c_insn_i),

    // immediates
    .imm_a_mux_sel_o(imm_a_mux_sel),
    .imm_b_mux_sel_o(imm_b_mux_sel_dec),

    .imm_i_type_o   (imm_i_type),
    .imm_s_type_o   (imm_s_type),
    .imm_b_type_o   (imm_b_type),
    .imm_u_type_o   (imm_u_type),
    .imm_j_type_o   (imm_j_type),
    .zimm_rs1_type_o(zimm_rs1_type),

    // register file
    .rf_wdata_sel_o(rf_wdata_sel),
    .rf_we_o       (rf_we_dec),

    .rf_raddr_a_o(rf_raddr_a_o),
    .rf_raddr_b_o(rf_raddr_b_o),
    .rf_waddr_o  (rf_waddr_id_o),
    .rf_ren_a_o  (rf_ren_a_dec),
    .rf_ren_b_o  (rf_ren_b_dec),

    // ALU
    .alu_operator_o    (alu_operator),
    .alu_op_a_mux_sel_o(alu_op_a_mux_sel_dec),
    .alu_op_b_mux_sel_o(alu_op_b_mux_sel_dec),
    .alu_multicycle_o  (alu_multicycle_dec),

    // MULT & DIV
    .mult_en_o            (mult_en_dec),
    .div_en_o             (div_en_dec),
    .mult_sel_o           (mult_sel_ex_o),
    .div_sel_o            (div_sel_ex_o),
    .multdiv_operator_o   (multdiv_operator),
    .multdiv_signed_mode_o(multdiv_signed_mode),

    // CSRs
    .csr_access_o(csr_access_o),
    .csr_op_o    (csr_op_o),

    // LSU
    .data_req_o           (lsu_req_dec),
    .data_we_o            (lsu_we),
    .data_type_o          (lsu_type),
    .data_sign_extension_o(lsu_sign_ext),

    // Core-V eXtension Interface (CV-X-IF)
    .x_issue_resp_register_read_i(x_issue_resp_i.register_read),
    .x_issue_resp_writeback_i(x_issue_resp_i.writeback),

    // jump/branches
    .jump_in_dec_o  (jump_in_dec),
    .branch_in_dec_o(branch_in_dec)
  );

  /////////////////////////////////
  // CSR-related pipeline flushes //
  /////////////////////////////////
  always_comb begin : csr_pipeline_flushes
    csr_pipe_flush = 1'b0;

    // A pipeline flush is needed to let the controller react after modifying certain CSRs:
    // - When enabling interrupts, pending IRQs become visible to the controller only during
    //   the next cycle. If during that cycle the core disables interrupts again, it does not
    //   see any pending IRQs and consequently does not start to handle interrupts.
    // - When modifying any PMP CSR, PMP check of the next instruction might get invalidated.
    //   Hence, a pipeline flush is needed to instantiate another PMP check with the updated CSRs.
    // - When modifying debug CSRs - TODO: Check if this is really needed
    if (csr_op_en_o == 1'b1 && (csr_op_o == CSR_OP_WRITE || csr_op_o == CSR_OP_SET)) begin
      if (csr_num_e'(instr_rdata_i[31:20]) == CSR_MSTATUS ||
          csr_num_e'(instr_rdata_i[31:20]) == CSR_MIE     ||
          csr_num_e'(instr_rdata_i[31:20]) == CSR_MSECCFG ||
          // To catch all PMPCFG/PMPADDR registers, get the shared top most 7 bits.
          instr_rdata_i[31:25] == 7'h1D) begin
        csr_pipe_flush = 1'b1;
      end
    end else if (csr_op_en_o == 1'b1 && csr_op_o != CSR_OP_READ) begin
      if (csr_num_e'(instr_rdata_i[31:20]) == CSR_DCSR      ||
          csr_num_e'(instr_rdata_i[31:20]) == CSR_DPC       ||
          csr_num_e'(instr_rdata_i[31:20]) == CSR_DSCRATCH0 ||
          csr_num_e'(instr_rdata_i[31:20]) == CSR_DSCRATCH1) begin
        csr_pipe_flush = 1'b1;
      end
    end
  end

  ////////////////
  // Controller //
  ////////////////

  cve2_controller #(
  ) controller_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    .fetch_enable_i(fetch_enable_i),
    .ctrl_busy_o(ctrl_busy_o),

    // decoder related signals
    .illegal_insn_i  (illegal_insn_o),
    .ecall_insn_i    (ecall_insn_dec),
    .mret_insn_i     (mret_insn_dec),
    .dret_insn_i     (dret_insn_dec),
    .wfi_insn_i      (wfi_insn_dec),
    .ebrk_insn_i     (ebrk_insn),
    .csr_pipe_flush_i(csr_pipe_flush),

    .xif_scoreboard_busy_i(scoreboard_busy),

    // from IF-ID pipeline
    .instr_valid_i          (instr_valid_i),
    .instr_i                (instr_rdata_i),
    .instr_compressed_i     (instr_rdata_c_i),
    .instr_is_compressed_i  (instr_is_compressed_i),
    .instr_fetch_err_i      (instr_fetch_err_i),
    .instr_fetch_err_plus2_i(instr_fetch_err_plus2_i),
    .pc_id_i                (pc_id_i),

    // to IF-ID pipeline
    .instr_valid_clear_o(instr_valid_clear_o),
    .id_in_ready_o      (id_in_ready_o),
    .controller_run_o   (controller_run),

    // to prefetcher
    .instr_req_o           (instr_req_o),
    .pc_set_o              (pc_set_o),
    .pc_mux_o              (pc_mux_o),
    .exc_pc_mux_o          (exc_pc_mux_o),
    .exc_cause_o           (exc_cause_o),

    // LSU
    .lsu_addr_last_i(lsu_addr_last_i),
    .load_err_i     (lsu_load_err_i),
    .store_err_i    (lsu_store_err_i),
    // jump/branch control
    .branch_set_i     (branch_set),
    .jump_set_i       (jump_set),

    // interrupt signals
    .csr_mstatus_mie_i(csr_mstatus_mie_i),
    .irq_pending_i    (irq_pending_i),
    .irqs_i           (irqs_i),
    .irq_nm_i         (irq_nm_i),
    .nmi_mode_o       (nmi_mode_o),

    // CSR Controller Signals
    .csr_save_if_o        (csr_save_if_o),
    .csr_save_id_o        (csr_save_id_o),
    .csr_restore_mret_id_o(csr_restore_mret_id_o),
    .csr_restore_dret_id_o(csr_restore_dret_id_o),
    .csr_save_cause_o     (csr_save_cause_o),
    .csr_mtval_o          (csr_mtval_o),
    .priv_mode_i          (priv_mode_i),
    .csr_mstatus_tw_i     (csr_mstatus_tw_i),

    // Debug Signal
    .debug_mode_o       (debug_mode_o),
    .debug_cause_o      (debug_cause_o),
    .debug_csr_save_o   (debug_csr_save_o),
    .debug_req_i        (debug_req_i),
    .debug_single_step_i(debug_single_step_i),
    .debug_ebreakm_i    (debug_ebreakm_i),
    .debug_ebreaku_i    (debug_ebreaku_i),
    .trigger_match_i    (trigger_match_i),

    .stall_id_i(stall_id),
    .flush_id_o(flush_id),

    // Performance Counters
    .perf_jump_o   (perf_jump_o),
    .perf_tbranch_o(perf_tbranch_o)
  );

  assign multdiv_en_dec   = mult_en_dec | div_en_dec;

  assign lsu_req         = instr_executing ? data_req_allowed & lsu_req_dec  : 1'b0;
  assign mult_en_id      = instr_executing ? mult_en_dec                     : 1'b0;
  assign div_en_id       = instr_executing ? div_en_dec                      : 1'b0;

  assign lsu_req_o               = lsu_req;
  assign lsu_we_o                = lsu_we;
  assign lsu_type_o              = lsu_type;
  assign lsu_sign_ext_o          = lsu_sign_ext;
  assign lsu_wdata_o             = rf_rdata_b_fwd;
  // csr_op_en_o is set when CSR access should actually happen.
  // csv_access_o is set when CSR access instruction is present and is used to compute whether a CSR
  // access is illegal. A combinational loop would be created if csr_op_en_o was used along (as
  // asserting it for an illegal csr access would result in a flush that would need to deassert it).
  assign csr_op_en_o             = csr_access_o & instr_executing & instr_id_done_o;

  assign alu_operator_ex_o           = alu_operator;
  assign alu_operand_a_ex_o          = alu_operand_a;
  assign alu_operand_b_ex_o          = alu_operand_b;

  assign mult_en_ex_o                = mult_en_id;
  assign div_en_ex_o                 = div_en_id;

  assign multdiv_operator_ex_o       = multdiv_operator;
  assign multdiv_signed_mode_ex_o    = multdiv_signed_mode;
  assign multdiv_operand_a_ex_o      = rf_rdata_a_fwd;
  assign multdiv_operand_b_ex_o      = rf_rdata_b_fwd;

  ////////////////////////
  // Branch set control //
  ////////////////////////

  // SEC_CM: CORE.DATA_REG_SW.SCA
  // Branch set flopped without branch target ALU, or in fixed time execution mode
  // (condition pass/fail used next cycle where branch target is calculated)
  logic branch_set_raw_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      branch_set_raw_q <= 1'b0;
    end else begin
      branch_set_raw_q <= branch_set_raw_d;
    end
  end

  // Branches always take two cycles in fixed time execution mode, with or without the branch
  // target ALU (to avoid a path from the branch decision into the branch target ALU operand
  // muxing).
  assign branch_set_raw      = branch_set_raw_q;


  // Track whether the current instruction in ID/EX has done a branch or jump set.
  assign branch_jump_set_done_d = (branch_set_raw | jump_set_raw | branch_jump_set_done_q) &
    ~instr_valid_clear_o;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      branch_jump_set_done_q <= 1'b0;
    end else begin
      branch_jump_set_done_q <= branch_jump_set_done_d;
    end
  end

  // the _raw signals from the state machine may be asserted for multiple cycles when
  // instr_executing_spec is asserted and instr_executing is not asserted. This may occur where
  // a memory error is seen or a there are outstanding memory accesses (indicate a load or store is
  // in the WB stage). The branch or jump speculatively begins the fetch but is held back from
  // completing until it is certain the outstanding access hasn't seen a memory error. This logic
  // ensures only the first cycle of a branch or jump set is sent to the controller to prevent
  // needless extra IF flushes and fetches.
  assign jump_set        = jump_set_raw        & ~branch_jump_set_done_q;
  assign branch_set      = branch_set_raw      & ~branch_jump_set_done_q;

  // ID/EX stage can be in two states, FIRST_CYCLE and MULTI_CYCLE. An instruction enters
  // MULTI_CYCLE if it requires multiple cycles to complete regardless of stalls and other
  // considerations. An instruction may be held in FIRST_CYCLE if it's unable to begin executing
  // (this is controlled by instr_executing).
  always_comb begin
    id_fsm_d                = id_fsm_q;
    rf_we_raw               = rf_we_dec;
    stall_multdiv           = 1'b0;
    stall_jump              = 1'b0;
    stall_branch            = 1'b0;
    stall_alu               = 1'b0;
    stall_coproc            = 1'b0;
    branch_set_raw_d        = 1'b0;
    jump_set_raw            = 1'b0;
    perf_branch_o           = 1'b0;

    if (instr_executing_spec) begin
      unique case (id_fsm_q)
        FIRST_CYCLE: begin
          unique case (1'b1)
            lsu_req_dec: begin
              begin
                // LSU operation
                id_fsm_d    = MULTI_CYCLE;
              end
            end
            multdiv_en_dec: begin
              // MUL or DIV operation
              if (~ex_valid_i) begin
                // When single-cycle multiply is configured mul can finish in the first cycle so
                // only enter MULTI_CYCLE state if a result isn't immediately available
                id_fsm_d      = MULTI_CYCLE;
                rf_we_raw     = 1'b0;
                stall_multdiv = 1'b1;
              end
            end
            branch_in_dec: begin
              // cond branch operation
              // All branches take two cycles in fixed time execution mode, regardless of branch
              // condition.
              // SEC_CM: CORE.DATA_REG_SW.SCA
              id_fsm_d         = (branch_decision_i) ?
                                     MULTI_CYCLE : FIRST_CYCLE;
              stall_branch     = branch_decision_i;
              branch_set_raw_d = branch_decision_i;

              perf_branch_o = 1'b1;
            end
            jump_in_dec: begin
              // uncond branch operation
              id_fsm_d      = MULTI_CYCLE;
              stall_jump    = 1'b1;
              jump_set_raw  = jump_set_dec;
            end
            alu_multicycle_dec: begin
              stall_alu     = 1'b1;
              id_fsm_d      = MULTI_CYCLE;
              rf_we_raw     = 1'b0;
            end
            illegal_insn_dec: begin

              // CV-X-IF
              if(XInterface) begin
                if(x_issue_valid_o && x_issue_ready_i) begin
                  if(x_issue_resp_i.accept && x_issue_resp_i.writeback) begin
                      id_fsm_d = MULTI_CYCLE;
                      stall_coproc = 1'b1;
                  end
                  else begin
                    id_fsm_d = FIRST_CYCLE;
                  end
                end
                else begin
                  stall_coproc = 1'b1;
                  id_fsm_d = FIRST_CYCLE;
                end
              end
              else begin
                id_fsm_d = FIRST_CYCLE;
              end

            end

            default: begin
              id_fsm_d      = FIRST_CYCLE;
            end
          endcase
        end

        MULTI_CYCLE: begin
          if(multdiv_en_dec) begin
            rf_we_raw       = rf_we_dec & ex_valid_i;
          end

          if (multicycle_done) begin
            id_fsm_d        = FIRST_CYCLE;
          end else begin
            stall_multdiv   = multdiv_en_dec;
            stall_branch    = branch_in_dec;
            stall_jump      = jump_in_dec;
            stall_coproc    = XInterface & illegal_insn_dec;
          end
        end

        default: begin
          id_fsm_d          = FIRST_CYCLE;
        end
      endcase
    end
  end




  `ASSERT(StallIDIfMulticycle, (id_fsm_q == FIRST_CYCLE) & (id_fsm_d == MULTI_CYCLE) |-> stall_id)


  // Stall ID/EX stage for reason that relates to instruction in ID/EX, update assertion below if
  // modifying this.
  assign stall_id = stall_mem | stall_multdiv | stall_jump | stall_branch |
                      stall_alu | (XInterface & stall_coproc);

  // Generally illegal instructions have no reason to stall, however they must still stall waiting
  // for outstanding memory requests so exceptions related to them take priority over the illegal
  // instruction exception.
  `ASSERT(IllegalInsnStallMustBeMemStall, illegal_insn_o & stall_id |-> stall_mem &
    ~(stall_multdiv | stall_jump | stall_branch | stall_alu))

  assign instr_done = ~stall_id & ~flush_id & instr_executing;

  // Signal instruction in ID is in it's first cycle. It can remain in its
  // first cycle if it is stalled.
  assign instr_first_cycle      = instr_valid_i & (id_fsm_q == FIRST_CYCLE);
  // Used by RVFI to know when to capture register read data
  // Used by ALU to access RS3 if ternary instruction.
  assign instr_first_cycle_id_o = instr_first_cycle;

  assign data_req_allowed = instr_first_cycle;

  // Without Writeback Stage always stall the first cycle of a load/store.
  // Then stall until it is complete
  assign stall_mem = instr_valid_i & (lsu_req_dec & (~lsu_resp_valid_i | instr_first_cycle));

  // Without writeback stage any valid instruction that hasn't seen an error will execute
  assign instr_executing_spec = instr_valid_i & ~instr_fetch_err_i & controller_run;
  assign instr_executing = instr_executing_spec;

  `ASSERT(IbexStallIfValidInstrNotExecuting,
    instr_valid_i & ~instr_fetch_err_i & ~instr_executing & controller_run |-> stall_id)

  // No data forwarding without writeback stage so always take source register data direct from
  // register file
  assign rf_rdata_a_fwd = rf_rdata_a_i;
  assign rf_rdata_b_fwd = rf_rdata_b_i;

  // Unused Writeback stage only IO & wiring
  // Assign inputs and internal wiring to unused signals to satisfy lint checks
  // Tie-off outputs to constant values
  logic unused_data_req_done_ex;

  assign perf_dside_wait_o = instr_executing & lsu_req_dec & ~lsu_resp_valid_i;

  assign instr_id_done_o = instr_done;

  // Signal which instructions to count as retired in minstret, all traps along with ebrk and
  // ecall instructions are not counted.
  assign instr_perf_count_id_o = ~ebrk_insn & ~ecall_insn_dec & ~illegal_insn_dec &
      ~(dret_insn_dec & ~debug_mode_o) &
      ~illegal_csr_insn_i & ~instr_fetch_err_i;

  // An instruction is ready to move to the writeback
  assign en_wb_o = instr_done;

  assign perf_wfi_wait_o = wfi_insn_dec;
  assign perf_div_wait_o = stall_multdiv & div_en_dec;

  //////////
  // FCOV //
  //////////

  `DV_FCOV_SIGNAL(logic, branch_taken,
    instr_executing & (id_fsm_q == FIRST_CYCLE) & branch_decision_i)
  `DV_FCOV_SIGNAL(logic, branch_not_taken,
    instr_executing & (id_fsm_q == FIRST_CYCLE) & ~branch_decision_i)

  ////////////////
  // Assertions //
  ////////////////

  // Selectors must be known/valid.
  `ASSERT_KNOWN_IF(CVE2AluOpMuxSelKnown, alu_op_a_mux_sel, instr_valid_i)
  `ASSERT(CVE2AluAOpMuxSelValid, instr_valid_i |-> alu_op_a_mux_sel inside {
      OP_A_REG_A,
      OP_A_FWD,
      OP_A_CURRPC,
      OP_A_IMM})
  if (XInterface) begin: gen_asserts_xif
    `ASSERT(IbexRegfileWdataSelValid, instr_valid_i |-> rf_wdata_sel inside {
        RF_WD_EX,
        RF_WD_CSR,
        RF_WD_COPROC})
  end 
  else begin : no_gen_asserts_xif
    `ASSERT(IbexRegfileWdataSelValid, instr_valid_i |-> rf_wdata_sel inside {
        RF_WD_EX,
        RF_WD_CSR})
  end
  `ASSERT_KNOWN(IbexWbStateKnown, id_fsm_q)

  // Branch decision must be valid when jumping.
  `ASSERT_KNOWN_IF(CVE2BranchDecisionValid, branch_decision_i,
      instr_valid_i && !(illegal_csr_insn_i || instr_fetch_err_i))

  // Instruction delivered to ID stage can not contain X.
  `ASSERT_KNOWN_IF(CVE2IdInstrKnown, instr_rdata_i,
      instr_valid_i && !(illegal_c_insn_i || instr_fetch_err_i))

  // Instruction delivered to ID stage can not contain X.
  `ASSERT_KNOWN_IF(CVE2IdInstrALUKnown, instr_rdata_alu_i,
      instr_valid_i && !(illegal_c_insn_i || instr_fetch_err_i))

  // Multicycle enable signals must be unique.
  `ASSERT(IbexMulticycleEnableUnique,
      $onehot0({lsu_req_dec, multdiv_en_dec, branch_in_dec, jump_in_dec, illegal_insn_dec}))

  // Duplicated instruction flops must match
  // === as DV environment can produce instructions with Xs in, so must use precise match that
  // includes Xs
  `ASSERT(CVE2DuplicateInstrMatch, instr_valid_i |-> instr_rdata_i === instr_rdata_alu_i)

  `ifdef CHECK_MISALIGNED
  `ASSERT(CVE2MisalignedMemoryAccess, !lsu_addr_incr_req_i)
  `endif

endmodule
