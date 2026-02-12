// Copyright (c) 2025 Eclipse Foundation
// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifdef RISCV_FORMAL
  `define RVFI
`endif

`include "prim_assert.sv"

/**
 * Top level module of the CVE2 RISC-V core
 */
module cve2_core import cve2_pkg::*; #(
  parameter bit          PMPEnable         = 1'b0,
  parameter int unsigned PMPGranularity    = 0,
  parameter int unsigned PMPNumRegions     = 4,
  parameter int unsigned MHPMCounterNum    = 10,
  parameter int unsigned MHPMCounterWidth  = 40,
  parameter bit          RV32E             = 1'b0,
  parameter rv32m_e      RV32M             = RV32MFast,
  parameter rv32b_e      RV32B             = RV32BNone,
  parameter bit          DbgTriggerEn      = 1'b0,
  parameter int unsigned DbgHwBreakNum     = 1,
  parameter bit          XInterface        = 1'b0
) (
  // Clock and Reset
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic                         test_en_i,

  input  logic [31:0]                  hart_id_i,
  input  logic [31:0]                  boot_addr_i,

  // Instruction memory interface
  output logic                         instr_req_o,
  input  logic                         instr_gnt_i,
  input  logic                         instr_rvalid_i,
  output logic [31:0]                  instr_addr_o,
  input  logic [31:0]                  instr_rdata_i,
  input  logic                         instr_err_i,

  // Data memory interface
  output logic                         data_req_o,
  input  logic                         data_gnt_i,
  input  logic                         data_rvalid_i,
  output logic                         data_we_o,
  output logic [3:0]                   data_be_o,
  output logic [31:0]                  data_addr_o,
  output logic [31:0]                  data_wdata_o,
  input  logic [31:0]                  data_rdata_i,
  input  logic                         data_err_i,

  // Core-V Extension Interface (CV-X-IF)
  // Issue Interface
  output logic                         x_issue_valid_o,
  input  logic                         x_issue_ready_i,
  output x_issue_req_t                 x_issue_req_o,
  input  x_issue_resp_t                x_issue_resp_i,

  // Register Interface
  output x_register_t                  x_register_o,

  // Commit Interface
  output logic                         x_commit_valid_o,
  output x_commit_t                    x_commit_o,

  // Result Interface
  input  logic                         x_result_valid_i,
  output logic                         x_result_ready_o,
  input  x_result_t                    x_result_i,

  // Interrupt inputs
  input  logic                         irq_software_i,
  input  logic                         irq_timer_i,
  input  logic                         irq_external_i,
  input  logic [15:0]                  irq_fast_i,
  input  logic                         irq_nm_i,       // non-maskeable interrupt
  output logic                         irq_pending_o,

  // Debug Interface
  input  logic                         debug_req_i,
  output logic                         debug_halted_o,
  input  logic [31:0]                  dm_halt_addr_i,
  input  logic [31:0]                  dm_exception_addr_i,
  output crash_dump_t                  crash_dump_o,
  // SEC_CM: EXCEPTION.CTRL_FLOW.LOCAL_ESC
  // SEC_CM: EXCEPTION.CTRL_FLOW.GLOBAL_ESC

  // RISC-V Formal Interface
  // Does not comply with the coding standards of _i/_o suffixes, but follows
  // the convention of RISC-V Formal Interface Specification.
`ifdef RVFI
  output logic                         rvfi_valid,
  output logic [63:0]                  rvfi_order,
  output logic [31:0]                  rvfi_insn,
  output logic                         rvfi_trap,
  output logic                         rvfi_halt,
  output logic                         rvfi_intr,
  output logic [ 1:0]                  rvfi_mode,
  output logic [ 1:0]                  rvfi_ixl,
  output logic [ 4:0]                  rvfi_rs1_addr,
  output logic [ 4:0]                  rvfi_rs2_addr,
  output logic [ 4:0]                  rvfi_rs3_addr,
  output logic [31:0]                  rvfi_rs1_rdata,
  output logic [31:0]                  rvfi_rs2_rdata,
  output logic [31:0]                  rvfi_rs3_rdata,
  output logic [ 4:0]                  rvfi_rd_addr,
  output logic [31:0]                  rvfi_rd_wdata,
  output logic [31:0]                  rvfi_pc_rdata,
  output logic [31:0]                  rvfi_pc_wdata,
  output logic [31:0]                  rvfi_mem_addr,
  output logic [ 3:0]                  rvfi_mem_rmask,
  output logic [ 3:0]                  rvfi_mem_wmask,
  output logic [31:0]                  rvfi_mem_rdata,
  output logic [31:0]                  rvfi_mem_wdata,
  output logic [31:0]                  rvfi_ext_mip,
  output logic                         rvfi_ext_nmi,
  output logic                         rvfi_ext_debug_req,
  output logic [63:0]                  rvfi_ext_mcycle,
`endif

  // CPU Control Signals
  input  logic                         fetch_enable_i,
  output logic                         core_busy_o
);

  localparam int unsigned PMP_NUM_CHAN      = 3;
  // SEC_CM: CORE.DATA_REG_SW.SCA

  // IF/ID signals
  logic        instr_valid_id;
  logic        instr_new_id;
  logic [31:0] instr_rdata_id;                 // Instruction sampled inside IF stage
  logic [31:0] instr_rdata_alu_id;             // Instruction sampled inside IF stage (replicated to
                                               // ease fan-out)
  logic [15:0] instr_rdata_c_id;               // Compressed instruction sampled inside IF stage
  logic        instr_is_compressed_id;
  logic        instr_perf_count_id;
  logic        instr_fetch_err;                // Bus error on instr fetch
  logic        instr_fetch_err_plus2;          // Instruction error is misaligned
  logic        illegal_c_insn_id;              // Illegal compressed instruction sent to ID stage
  logic [31:0] pc_if;                          // Program counter in IF stage
  logic [31:0] pc_id;                          // Program counter in ID stage
  logic [33:0] imd_val_d_ex[2];                // Intermediate register for multicycle Ops
  logic [33:0] imd_val_q_ex[2];                // Intermediate register for multicycle Ops
  logic [1:0]  imd_val_we_ex;

  logic        instr_first_cycle_id;
  logic        instr_valid_clear;
  logic        pc_set;
  pc_sel_e     pc_mux_id;                      // Mux selector for next PC
  exc_pc_sel_e exc_pc_mux_id;                  // Mux selector for exception PC
  exc_cause_e  exc_cause;                      // Exception cause

  logic        lsu_load_err;
  logic        lsu_store_err;

  // LSU signals
  logic        lsu_addr_incr_req;
  logic [31:0] lsu_addr_last;

  // Jump and branch target and decision (EX->IF)
  logic [31:0] branch_target_ex;
  logic        branch_decision;

  // Core busy signals
  logic        ctrl_busy;
  logic        if_busy;
  logic        lsu_busy;

  // Register File
  logic [4:0]  rf_raddr_a;
  logic [31:0] rf_rdata_a;
  logic [4:0]  rf_raddr_b;
  logic [31:0] rf_rdata_b;
  logic        rf_ren_a;
  logic        rf_ren_b;
  logic [4:0]  rf_waddr_wb;
  logic [31:0] rf_wdata_wb;
  // Writeback register write data that can be used on the forwarding path (doesn't factor in memory
  // read data as this is too late for the forwarding path)
  logic [31:0] rf_wdata_lsu;
  logic        rf_we_wb;
  logic        rf_we_lsu;

  logic [4:0]  rf_waddr_id;
  logic [31:0] rf_wdata_id;
  logic        rf_we_id;

  // ALU Control
  alu_op_e     alu_operator_ex;
  logic [31:0] alu_operand_a_ex;
  logic [31:0] alu_operand_b_ex;

  logic [31:0] alu_adder_result_ex;    // Used to forward computed address to LSU
  logic [31:0] result_ex;

  // Multiplier Control
  logic        mult_en_ex;
  logic        div_en_ex;
  logic        mult_sel_ex;
  logic        div_sel_ex;
  md_op_e      multdiv_operator_ex;
  logic [1:0]  multdiv_signed_mode_ex;
  logic [31:0] multdiv_operand_a_ex;
  logic [31:0] multdiv_operand_b_ex;

  // CSR control
  logic        csr_access;
  csr_op_e     csr_op;
  logic        csr_op_en;
  csr_num_e    csr_addr;
  logic [31:0] csr_rdata;
  logic [31:0] csr_wdata;
  logic        illegal_csr_insn_id;    // CSR access to non-existent register,
                                       // with wrong priviledge level,
                                       // or missing write permissions

  // Data Memory Control
  logic        lsu_we;
  logic [1:0]  lsu_type;
  logic        lsu_sign_ext;
  logic        lsu_req;
  logic [31:0] lsu_wdata;

  // stall control
  logic        id_in_ready;
  logic        ex_valid;

  logic        lsu_resp_valid;
  logic        lsu_resp_err;

  // Signals between instruction core interface and pipe (if and id stages)
  logic        instr_req_int;          // Id stage asserts a req to instruction core interface
  logic        instr_req_gated;

  // Writeback
  logic        en_wb;

  // Interrupts
  logic        nmi_mode;
  irqs_t       irqs;
  logic        csr_mstatus_mie;
  logic [31:0] csr_mepc, csr_depc;

  // PMP signals
  logic [33:0]  csr_pmp_addr [PMPNumRegions];
  pmp_cfg_t     csr_pmp_cfg  [PMPNumRegions];
  pmp_mseccfg_t csr_pmp_mseccfg;
  logic         pmp_req_err  [PMP_NUM_CHAN];
  logic         data_req_out;

  logic        csr_save_if;
  logic        csr_save_id;
  logic        csr_restore_mret_id;
  logic        csr_restore_dret_id;
  logic        csr_save_cause;
  logic        csr_mtvec_init;
  logic [31:0] csr_mtvec;
  logic [31:0] csr_mtval;
  logic        csr_mstatus_tw;
  priv_lvl_e   priv_mode_id;
  priv_lvl_e   priv_mode_lsu;

  // debug mode and dcsr configuration
  logic        debug_mode;
  dbg_cause_e  debug_cause;
  logic        debug_csr_save;
  logic        debug_single_step;
  logic        debug_ebreakm;
  logic        debug_ebreaku;
  logic        trigger_match;

  // signals relating to instruction movements between pipeline stages
  // used by performance counters and RVFI
  logic        instr_id_done;

  logic        perf_instr_ret_wb;
  logic        perf_instr_ret_compressed_wb;
  logic        perf_iside_wait;
  logic        perf_dside_wait;
  logic        perf_wfi_wait;
  logic        perf_div_wait;
  logic        perf_jump;
  logic        perf_branch;
  logic        perf_tbranch;
  logic        perf_load;
  logic        perf_store;

  // for RVFI
  logic        illegal_insn_id, unused_illegal_insn_id; // ID stage sees an illegal instruction

  //////////////////////
  // Clock management //
  //////////////////////

  // Before going to sleep, wait for I- and D-side
  // interfaces to finish ongoing operations.
  assign core_busy_o = ctrl_busy | if_busy | lsu_busy;

  //////////////
  // IF stage //
  //////////////

  cve2_if_stage if_stage_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    .boot_addr_i(boot_addr_i),
    .req_i      (instr_req_gated),  // instruction request control

    // instruction cache interface
    .instr_req_o    (instr_req_o),
    .instr_addr_o   (instr_addr_o),
    .instr_gnt_i    (instr_gnt_i),
    .instr_rvalid_i (instr_rvalid_i),
    .instr_rdata_i  (instr_rdata_i),
    .instr_err_i    (instr_err_i),

    // outputs to ID stage
    .instr_valid_id_o        (instr_valid_id),
    .instr_new_id_o          (instr_new_id),
    .instr_rdata_id_o        (instr_rdata_id),
    .instr_rdata_alu_id_o    (instr_rdata_alu_id),
    .instr_rdata_c_id_o      (instr_rdata_c_id),
    .instr_is_compressed_id_o(instr_is_compressed_id),
    .instr_fetch_err_o       (instr_fetch_err),
    .instr_fetch_err_plus2_o (instr_fetch_err_plus2),
    .illegal_c_insn_id_o     (illegal_c_insn_id),
    .pc_if_o                 (pc_if),
    .pc_id_o                 (pc_id),
    .pmp_err_if_i            (pmp_req_err[PMP_I]),
    .pmp_err_if_plus2_i      (pmp_req_err[PMP_I2]),

    // control signals
    .instr_valid_clear_i   (instr_valid_clear),
    .pc_set_i              (pc_set),
    .pc_mux_i              (pc_mux_id),
    .exc_pc_mux_i          (exc_pc_mux_id),
    .exc_cause             (exc_cause),

    // branch targets
    .branch_target_ex_i(branch_target_ex),

    // CSRs
    .csr_mepc_i      (csr_mepc),  // exception return address
    .csr_depc_i      (csr_depc),  // debug return address
    .csr_mtvec_i     (csr_mtvec),  // trap-vector base address
    .csr_mtvec_init_o(csr_mtvec_init),

    // debug signals
    .dm_halt_addr_i       (dm_halt_addr_i),
    .dm_exception_addr_i  (dm_exception_addr_i),

    // pipeline stalls
    .id_in_ready_i(id_in_ready),

    .if_busy_o          (if_busy)
  );

  // Core is waiting for the ISide when ID/EX stage is ready for a new instruction but none are
  // available
  assign perf_iside_wait = id_in_ready & ~instr_valid_id;

  // For non secure CVE2 only the bottom bit of fetch enable is considered
  assign instr_req_gated = instr_req_int;

  //////////////
  // ID stage //
  //////////////

  cve2_id_stage #(
    .RV32E          (RV32E),
    .RV32M          (RV32M),
    .RV32B          (RV32B),
    .XInterface     (XInterface)
  ) id_stage_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    // Processor Enable
    .fetch_enable_i(fetch_enable_i),
    .ctrl_busy_o   (ctrl_busy),
    .illegal_insn_o(illegal_insn_id),

    // from/to IF-ID pipeline register
    .instr_valid_i        (instr_valid_id),
    .instr_rdata_i        (instr_rdata_id),
    .instr_rdata_alu_i    (instr_rdata_alu_id),
    .instr_rdata_c_i      (instr_rdata_c_id),
    .instr_is_compressed_i(instr_is_compressed_id),

    // Jumps and branches
    .branch_decision_i(branch_decision),

    // IF and ID control signals
    .instr_first_cycle_id_o(instr_first_cycle_id),
    .instr_valid_clear_o   (instr_valid_clear),
    .id_in_ready_o         (id_in_ready),
    .instr_req_o           (instr_req_int),
    .pc_set_o              (pc_set),
    .pc_mux_o              (pc_mux_id),
    .exc_pc_mux_o          (exc_pc_mux_id),
    .exc_cause_o           (exc_cause),

    .instr_fetch_err_i      (instr_fetch_err),
    .instr_fetch_err_plus2_i(instr_fetch_err_plus2),
    .illegal_c_insn_i       (illegal_c_insn_id),

    .pc_id_i(pc_id),

    // Stalls
    .ex_valid_i      (ex_valid),
    .lsu_resp_valid_i(lsu_resp_valid),

    .alu_operator_ex_o (alu_operator_ex),
    .alu_operand_a_ex_o(alu_operand_a_ex),
    .alu_operand_b_ex_o(alu_operand_b_ex),

    .imd_val_q_ex_o (imd_val_q_ex),
    .imd_val_d_ex_i (imd_val_d_ex),
    .imd_val_we_ex_i(imd_val_we_ex),

    .mult_en_ex_o            (mult_en_ex),
    .div_en_ex_o             (div_en_ex),
    .mult_sel_ex_o           (mult_sel_ex),
    .div_sel_ex_o            (div_sel_ex),
    .multdiv_operator_ex_o   (multdiv_operator_ex),
    .multdiv_signed_mode_ex_o(multdiv_signed_mode_ex),
    .multdiv_operand_a_ex_o  (multdiv_operand_a_ex),
    .multdiv_operand_b_ex_o  (multdiv_operand_b_ex),

    // CSR ID/EX
    .csr_access_o         (csr_access),
    .csr_op_o             (csr_op),
    .csr_op_en_o          (csr_op_en),
    .csr_save_if_o        (csr_save_if),  // control signal to save PC
    .csr_save_id_o        (csr_save_id),  // control signal to save PC
    .csr_restore_mret_id_o(csr_restore_mret_id),  // restore mstatus upon MRET
    .csr_restore_dret_id_o(csr_restore_dret_id),  // restore mstatus upon MRET
    .csr_save_cause_o     (csr_save_cause),
    .csr_mtval_o          (csr_mtval),
    .priv_mode_i          (priv_mode_id),
    .csr_mstatus_tw_i     (csr_mstatus_tw),
    .illegal_csr_insn_i   (illegal_csr_insn_id),

    // LSU
    .lsu_req_o     (lsu_req),  // to load store unit
    .lsu_we_o      (lsu_we),  // to load store unit
    .lsu_type_o    (lsu_type),  // to load store unit
    .lsu_sign_ext_o(lsu_sign_ext),  // to load store unit
    .lsu_wdata_o   (lsu_wdata),  // to load store unit

    .lsu_addr_incr_req_i(lsu_addr_incr_req),
    .lsu_addr_last_i    (lsu_addr_last),

    .lsu_load_err_i (lsu_load_err),
    .lsu_store_err_i(lsu_store_err),

    // Core-V Extension Interface (CV-X-IF)
    .hart_id_i      (hart_id_i),
    // Issue Interface
    .x_issue_valid_o(x_issue_valid_o),
    .x_issue_ready_i(x_issue_ready_i),
    .x_issue_req_o(x_issue_req_o),
    .x_issue_resp_i(x_issue_resp_i),

    // Register Interface
    .x_register_o(x_register_o),

    // Commit Interface
    .x_commit_valid_o(x_commit_valid_o),
    .x_commit_o(x_commit_o),

    // Result Interface
    .x_result_valid_i(x_result_valid_i),
    .x_result_ready_o(x_result_ready_o),
    .x_result_i(x_result_i),

    // Interrupt Signals
    .csr_mstatus_mie_i(csr_mstatus_mie),
    .irq_pending_i    (irq_pending_o),
    .irqs_i           (irqs),
    .irq_nm_i         (irq_nm_i),
    .nmi_mode_o       (nmi_mode),

    // Debug Signal
    .debug_mode_o       (debug_mode),
    .debug_cause_o      (debug_cause),
    .debug_csr_save_o   (debug_csr_save),
    .debug_req_i        (debug_req_i),
    .debug_single_step_i(debug_single_step),
    .debug_ebreakm_i    (debug_ebreakm),
    .debug_ebreaku_i    (debug_ebreaku),
    .trigger_match_i    (trigger_match),

    // write data to commit in the register file
    .result_ex_i(result_ex),
    .csr_rdata_i(csr_rdata),

    .rf_raddr_a_o      (rf_raddr_a),
    .rf_rdata_a_i      (rf_rdata_a),
    .rf_raddr_b_o      (rf_raddr_b),
    .rf_rdata_b_i      (rf_rdata_b),
    .rf_ren_a_o        (rf_ren_a),
    .rf_ren_b_o        (rf_ren_b),
    .rf_waddr_id_o     (rf_waddr_id),
    .rf_wdata_id_o     (rf_wdata_id),
    .rf_we_id_o        (rf_we_id),

    .en_wb_o           (en_wb),
    .instr_perf_count_id_o (instr_perf_count_id),

    // Performance Counters
    .perf_jump_o      (perf_jump),
    .perf_branch_o    (perf_branch),
    .perf_tbranch_o   (perf_tbranch),
    .perf_dside_wait_o(perf_dside_wait),
    .perf_wfi_wait_o  (perf_wfi_wait),
    .perf_div_wait_o  (perf_div_wait),
    .instr_id_done_o  (instr_id_done)
  );

  // for RVFI only
  assign unused_illegal_insn_id = illegal_insn_id;

  cve2_ex_block #(
    .RV32M          (RV32M),
    .RV32B          (RV32B)
  ) ex_block_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    // ALU signal from ID stage
    .alu_operator_i         (alu_operator_ex),
    .alu_operand_a_i        (alu_operand_a_ex),
    .alu_operand_b_i        (alu_operand_b_ex),
    .alu_instr_first_cycle_i(instr_first_cycle_id),

    // Multipler/Divider signal from ID stage
    .multdiv_operator_i   (multdiv_operator_ex),
    .mult_en_i            (mult_en_ex),
    .div_en_i             (div_en_ex),
    .mult_sel_i           (mult_sel_ex),
    .div_sel_i            (div_sel_ex),
    .multdiv_signed_mode_i(multdiv_signed_mode_ex),
    .multdiv_operand_a_i  (multdiv_operand_a_ex),
    .multdiv_operand_b_i  (multdiv_operand_b_ex),

    // Intermediate value register
    .imd_val_we_o(imd_val_we_ex),
    .imd_val_d_o (imd_val_d_ex),
    .imd_val_q_i (imd_val_q_ex),

    // Outputs
    .alu_adder_result_ex_o(alu_adder_result_ex),  // to LSU
    .result_ex_o          (result_ex),  // to ID

    .branch_target_o  (branch_target_ex),  // to IF
    .branch_decision_o(branch_decision),  // to ID

    .ex_valid_o(ex_valid)
  );

  /////////////////////
  // Load/store unit //
  /////////////////////

  assign data_req_o   = data_req_out & ~pmp_req_err[PMP_D];
  assign lsu_resp_err = lsu_load_err | lsu_store_err;

  cve2_load_store_unit load_store_unit_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    // data interface
    .data_req_o    (data_req_out),
    .data_gnt_i    (data_gnt_i),
    .data_rvalid_i (data_rvalid_i),
    .data_err_i    (data_err_i),
    .data_pmp_err_i(pmp_req_err[PMP_D]),

    .data_addr_o (data_addr_o),
    .data_we_o   (data_we_o),
    .data_be_o   (data_be_o),
    .data_wdata_o(data_wdata_o),
    .data_rdata_i(data_rdata_i),

    // signals to/from ID/EX stage
    .lsu_we_i      (lsu_we),
    .lsu_type_i    (lsu_type),
    .lsu_wdata_i   (lsu_wdata),
    .lsu_sign_ext_i(lsu_sign_ext),

    .lsu_rdata_o      (rf_wdata_lsu),
    .lsu_rdata_valid_o(rf_we_lsu),
    .lsu_req_i        (lsu_req),

    .adder_result_ex_i(alu_adder_result_ex),

    .addr_incr_req_o(lsu_addr_incr_req),
    .addr_last_o    (lsu_addr_last),


    .lsu_resp_valid_o(lsu_resp_valid),

    // exception signals
    .load_err_o (lsu_load_err),
    .store_err_o(lsu_store_err),

    .busy_o(lsu_busy),

    .perf_load_o (perf_load),
    .perf_store_o(perf_store)
  );

  cve2_wb #(
  ) wb_i (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .en_wb_i (en_wb),

    .instr_is_compressed_id_i(instr_is_compressed_id),
    .instr_perf_count_id_i   (instr_perf_count_id),

    .perf_instr_ret_wb_o                (perf_instr_ret_wb),
    .perf_instr_ret_compressed_wb_o     (perf_instr_ret_compressed_wb),

    .rf_waddr_id_i(rf_waddr_id),
    .rf_wdata_id_i(rf_wdata_id),
    .rf_we_id_i   (rf_we_id),

    .rf_wdata_lsu_i(rf_wdata_lsu),
    .rf_we_lsu_i   (rf_we_lsu),

    .rf_waddr_wb_o(rf_waddr_wb),
    .rf_wdata_wb_o(rf_wdata_wb),
    .rf_we_wb_o   (rf_we_wb),

    .lsu_resp_valid_i(lsu_resp_valid),
    .lsu_resp_err_i  (lsu_resp_err)
  );

  ///////////////////////
  // Crash dump output //
  ///////////////////////

  assign crash_dump_o.current_pc     = pc_id;
  assign crash_dump_o.next_pc        = pc_if;
  assign crash_dump_o.last_data_addr = lsu_addr_last;
  assign crash_dump_o.exception_addr = csr_mepc;

  ///////////////////////
  // Debug output      //
  ///////////////////////

  assign debug_halted_o = debug_mode;

  // Explict INC_ASSERT block to avoid unused signal lint warnings were asserts are not included
  `ifdef INC_ASSERT
  // Signals used for assertions only
  logic outstanding_load_resp;
  logic outstanding_store_resp;

  logic outstanding_load_id;
  logic outstanding_store_id;

  assign outstanding_load_id  = id_stage_i.instr_executing & id_stage_i.lsu_req_dec &
                                ~id_stage_i.lsu_we;
  assign outstanding_store_id = id_stage_i.instr_executing & id_stage_i.lsu_req_dec &
                                id_stage_i.lsu_we;

  // Without writeback stage only look into whether load or store is in ID to determine if
  // a response is expected.
  assign outstanding_load_resp  = outstanding_load_id;
  assign outstanding_store_resp = outstanding_store_id;

  `ASSERT(NoMemRFWriteWithoutPendingLoad, rf_we_lsu |-> outstanding_load_id, clk_i, !rst_ni)

  `ASSERT(NoMemResponseWithoutPendingAccess,
    data_rvalid_i |-> outstanding_load_resp | outstanding_store_resp, clk_i, !rst_ni)
  `endif

  ////////////////////////
  // RF (Register File) //
  ////////////////////////
  cve2_register_file_ff #(
    .RV32E            (RV32E),
    .DataWidth        (32),
    .WordZeroVal      (32'h0)
  ) register_file_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    .test_en_i(test_en_i),

    .raddr_a_i(rf_raddr_a),
    .rdata_a_o(rf_rdata_a),
    .raddr_b_i(rf_raddr_b),
    .rdata_b_o(rf_rdata_b),
    .waddr_a_i(rf_waddr_wb),
    .wdata_a_i(rf_wdata_wb),
    .we_a_i   (rf_we_wb)
  );


  /////////////////////////////////////////
  // CSRs (Control and Status Registers) //
  /////////////////////////////////////////

  assign csr_wdata  = alu_operand_a_ex;
  assign csr_addr   = csr_num_e'(csr_access ? alu_operand_b_ex[11:0] : 12'b0);

  cve2_cs_registers #(
    .DbgTriggerEn     (DbgTriggerEn),
    .DbgHwBreakNum    (DbgHwBreakNum),
    .MHPMCounterNum   (MHPMCounterNum),
    .MHPMCounterWidth (MHPMCounterWidth),
    .PMPEnable        (PMPEnable),
    .PMPGranularity   (PMPGranularity),
    .PMPNumRegions    (PMPNumRegions),
    .RV32E            (RV32E),
    .RV32M            (RV32M),
    .RV32B            (RV32B)
  ) cs_registers_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    // Hart ID from outside
    .hart_id_i      (hart_id_i),
    .priv_mode_id_o (priv_mode_id),
    .priv_mode_lsu_o(priv_mode_lsu),

    // mtvec
    .csr_mtvec_o     (csr_mtvec),
    .csr_mtvec_init_i(csr_mtvec_init),
    .boot_addr_i     (boot_addr_i),

    // Interface to CSRs     ( SRAM like                    )
    .csr_access_i(csr_access),
    .csr_addr_i  (csr_addr),
    .csr_wdata_i (csr_wdata),
    .csr_op_i    (csr_op),
    .csr_op_en_i (csr_op_en),
    .csr_rdata_o (csr_rdata),

    // Interrupt related control signals
    .irq_software_i   (irq_software_i),
    .irq_timer_i      (irq_timer_i),
    .irq_external_i   (irq_external_i),
    .irq_fast_i       (irq_fast_i),
    .nmi_mode_i       (nmi_mode),
    .irq_pending_o    (irq_pending_o),
    .irqs_o           (irqs),
    .csr_mstatus_mie_o(csr_mstatus_mie),
    .csr_mstatus_tw_o (csr_mstatus_tw),
    .csr_mepc_o       (csr_mepc),

    // PMP
    .csr_pmp_cfg_o    (csr_pmp_cfg),
    .csr_pmp_addr_o   (csr_pmp_addr),
    .csr_pmp_mseccfg_o(csr_pmp_mseccfg),

    // debug
    .csr_depc_o         (csr_depc),
    .debug_mode_i       (debug_mode),
    .debug_cause_i      (debug_cause),
    .debug_csr_save_i   (debug_csr_save),
    .debug_single_step_o(debug_single_step),
    .debug_ebreakm_o    (debug_ebreakm),
    .debug_ebreaku_o    (debug_ebreaku),
    .trigger_match_o    (trigger_match),

    .pc_if_i(pc_if),
    .pc_id_i(pc_id),

    .csr_save_if_i     (csr_save_if),
    .csr_save_id_i     (csr_save_id),
    .csr_restore_mret_i(csr_restore_mret_id),
    .csr_restore_dret_i(csr_restore_dret_id),
    .csr_save_cause_i  (csr_save_cause),
    .csr_mcause_i      (exc_cause),
    .csr_mtval_i       (csr_mtval),
    .illegal_csr_insn_o(illegal_csr_insn_id),

    // performance counter related signals
    .instr_ret_i                (perf_instr_ret_wb),
    .instr_ret_compressed_i     (perf_instr_ret_compressed_wb),
    .iside_wait_i               (perf_iside_wait),
    .jump_i                     (perf_jump),
    .branch_i                   (perf_branch),
    .branch_taken_i             (perf_tbranch),
    .mem_load_i                 (perf_load),
    .mem_store_i                (perf_store),
    .dside_wait_i               (perf_dside_wait),
    .wfi_wait_i                 (perf_wfi_wait),
    .div_wait_i                 (perf_div_wait)
  );

  // These assertions are in top-level as instr_valid_id required as the enable term
  `ASSERT(CVE2CsrOpValid, instr_valid_id |-> csr_op inside {
      CSR_OP_READ,
      CSR_OP_WRITE,
      CSR_OP_SET,
      CSR_OP_CLEAR
      })
  `ASSERT_KNOWN_IF(CVE2CsrWdataIntKnown, cs_registers_i.csr_wdata_int, csr_op_en)

  if (PMPEnable) begin : g_pmp
    logic [33:0] pmp_req_addr [PMP_NUM_CHAN];
    pmp_req_e    pmp_req_type [PMP_NUM_CHAN];
    priv_lvl_e   pmp_priv_lvl [PMP_NUM_CHAN];

    assign pmp_req_addr[PMP_I]  = {2'b00, pc_if};
    assign pmp_req_type[PMP_I]  = PMP_ACC_EXEC;
    assign pmp_priv_lvl[PMP_I]  = priv_mode_id;
    assign pmp_req_addr[PMP_I2] = {2'b00, (pc_if + 32'd2)};
    assign pmp_req_type[PMP_I2] = PMP_ACC_EXEC;
    assign pmp_priv_lvl[PMP_I2] = priv_mode_id;
    assign pmp_req_addr[PMP_D]  = {2'b00, data_addr_o[31:0]};
    assign pmp_req_type[PMP_D]  = data_we_o ? PMP_ACC_WRITE : PMP_ACC_READ;
    assign pmp_priv_lvl[PMP_D]  = priv_mode_lsu;

    cve2_pmp #(
      .PMPGranularity(PMPGranularity),
      .PMPNumChan    (PMP_NUM_CHAN),
      .PMPNumRegions (PMPNumRegions)
    ) pmp_i (
      .clk_i            (clk_i),
      .rst_ni           (rst_ni),
      // Interface to CSRs
      .csr_pmp_cfg_i    (csr_pmp_cfg),
      .csr_pmp_addr_i   (csr_pmp_addr),
      .csr_pmp_mseccfg_i(csr_pmp_mseccfg),
      .priv_mode_i      (pmp_priv_lvl),
      // Access checking channels
      .pmp_req_addr_i   (pmp_req_addr),
      .pmp_req_type_i   (pmp_req_type),
      .pmp_req_err_o    (pmp_req_err)
    );
  end else begin : g_no_pmp
    // Unused signal tieoff
    priv_lvl_e unused_priv_lvl_ls;
    logic [33:0] unused_csr_pmp_addr [PMPNumRegions];
    pmp_cfg_t    unused_csr_pmp_cfg  [PMPNumRegions];
    pmp_mseccfg_t unused_csr_pmp_mseccfg;
    assign unused_priv_lvl_ls = priv_mode_lsu;
    assign unused_csr_pmp_addr = csr_pmp_addr;
    assign unused_csr_pmp_cfg = csr_pmp_cfg;
    assign unused_csr_pmp_mseccfg = csr_pmp_mseccfg;

    // Output tieoff
    assign pmp_req_err[PMP_I]  = 1'b0;
    assign pmp_req_err[PMP_I2] = 1'b0;
    assign pmp_req_err[PMP_D]  = 1'b0;
  end

`ifdef RVFI
  // When writeback stage is present RVFI information is emitted when instruction is finished in
  // third stage but some information must be captured whilst the instruction is in the second
  // stage. Without writeback stage RVFI information is all emitted when instruction retires in
  // second stage. RVFI outputs are all straight from flops. So 2 stage pipeline requires a single
  // set of flops (instr_info => RVFI_out), 3 stage pipeline requires two sets (instr_info => wb
  // => RVFI_out)
  localparam int RVFI_STAGES = 1;

  logic        rvfi_stage_valid     [RVFI_STAGES];
  logic [63:0] rvfi_stage_order     [RVFI_STAGES];
  logic [31:0] rvfi_stage_insn      [RVFI_STAGES];
  logic        rvfi_stage_trap      [RVFI_STAGES];
  logic        rvfi_stage_halt      [RVFI_STAGES];
  logic [3:0]  rvfi_stage_dbg       [RVFI_STAGES];
  logic        rvfi_stage_dbg_mode  [RVFI_STAGES];
  logic [15:0] rvfi_stage_intr      [RVFI_STAGES];
  logic [ 1:0] rvfi_stage_mode      [RVFI_STAGES];
  logic [ 1:0] rvfi_stage_ixl       [RVFI_STAGES];
  logic [ 4:0] rvfi_stage_rs1_addr  [RVFI_STAGES];
  logic [ 4:0] rvfi_stage_rs2_addr  [RVFI_STAGES];
  logic [ 4:0] rvfi_stage_rs3_addr  [RVFI_STAGES];
  logic [31:0] rvfi_stage_rs1_rdata [RVFI_STAGES];
  logic [31:0] rvfi_stage_rs2_rdata [RVFI_STAGES];
  logic [31:0] rvfi_stage_rs3_rdata [RVFI_STAGES];
  logic [ 4:0] rvfi_stage_rd_addr   [RVFI_STAGES];
  logic [31:0] rvfi_stage_rd_wdata  [RVFI_STAGES];
  logic [31:0] rvfi_stage_pc_rdata  [RVFI_STAGES];
  logic [31:0] rvfi_stage_pc_wdata  [RVFI_STAGES];
  logic [31:0] rvfi_stage_mem_addr  [RVFI_STAGES];
  logic [ 3:0] rvfi_stage_mem_rmask [RVFI_STAGES];
  logic [ 3:0] rvfi_stage_mem_wmask [RVFI_STAGES];
  logic [31:0] rvfi_stage_mem_rdata [RVFI_STAGES];
  logic [31:0] rvfi_stage_mem_wdata [RVFI_STAGES];

  logic        rvfi_instr_new_wb;
  logic        rvfi_intr_d;
  logic        rvfi_intr_q;
  logic        rvfi_set_trap_pc_d;
  logic        rvfi_set_trap_pc_q;
  logic [31:0] rvfi_insn_id;
  logic [4:0]  rvfi_rs1_addr_d;
  logic [4:0]  rvfi_rs1_addr_q;
  logic [4:0]  rvfi_rs2_addr_d;
  logic [4:0]  rvfi_rs2_addr_q;
  logic [4:0]  rvfi_rs3_addr_d;
  logic [31:0] rvfi_rs1_data_d;
  logic [31:0] rvfi_rs1_data_q;
  logic [31:0] rvfi_rs2_data_d;
  logic [31:0] rvfi_rs2_data_q;
  logic [31:0] rvfi_rs3_data_d;
  logic [4:0]  rvfi_rd_addr_wb;
  logic [4:0]  rvfi_rd_addr_q;
  logic [4:0]  rvfi_rd_addr_d;
  logic [31:0] rvfi_rd_wdata_wb;
  logic [31:0] rvfi_rd_wdata_d;
  logic [31:0] rvfi_rd_wdata_q;
  logic        rvfi_rd_we_wb;
  logic [3:0]  rvfi_mem_mask_int;
  logic [31:0] rvfi_mem_rdata_d;
  logic [31:0] rvfi_mem_rdata_q;
  logic [31:0] rvfi_mem_wdata_d;
  logic [31:0] rvfi_mem_wdata_q;
  logic [31:0] rvfi_mem_addr_d;
  logic [31:0] rvfi_mem_addr_q;
  logic        rvfi_trap_id;
  logic [63:0] rvfi_stage_order_d;
  logic        rvfi_id_done;
  logic [3:0]  rvfi_dbg;
  logic        rvfi_dbg_mode;

  struct {
    logic          rvfi_valid;
    logic [63:0]   rvfi_order;
    logic [31:0]   rvfi_insn;
    logic          rvfi_trap;
    logic          rvfi_halt;
    logic [3:0]    rvfi_dbg;
    logic          rvfi_dbg_mode;
    logic [15:0]   rvfi_intr;
    logic [1:0]    rvfi_mode;
    logic [1:0]    rvfi_ixl;
    logic [4:0]    rvfi_rs1_addr;
    logic [31:0]   rvfi_rs1_rdata;
    logic [4:0]    rvfi_rs2_addr;
    logic [31:0]   rvfi_rs2_rdata;
    logic [4:0]    rvfi_rs3_addr;
    logic [31:0]   rvfi_rs3_rdata;
    logic [4:0]    rvfi_rd1_addr;
    logic [31:0]   rvfi_rd1_wdata;
    logic [31:0]   rvfi_pc_rdata;
    logic [31:0]   rvfi_pc_wdata;
    logic [31:0]   rvfi_mem_addr;
    logic [3:0]    rvfi_mem_rmask;
    logic [3:0]    rvfi_mem_wmask;
    logic [31:0]   rvfi_mem_rdata;
    logic [4:0]    rvfi_mem_wdata;
  } rvfi_instr_if;

  logic            new_debug_req;
  logic            new_nmi;
  logic            new_irq;
  cve2_pkg::irqs_t captured_mip;
  logic            captured_irq;
  logic            captured_nmi;
  logic            captured_debug_req;
  logic            captured_valid;

  logic [3:0]      captured_debug_cause;
  logic            captured_debug_valid;

  // RVFI extension for co-simulation support
  // debug_req and MIP captured at IF -> ID transition so one extra stage
  cve2_pkg::irqs_t rvfi_ext_stage_mip          [RVFI_STAGES+1];
  logic            rvfi_ext_stage_nmi          [RVFI_STAGES+1];
  logic            rvfi_ext_stage_debug_req    [RVFI_STAGES+1];
  logic [63:0]     rvfi_ext_stage_mcycle       [RVFI_STAGES];



  logic        rvfi_stage_valid_d   [RVFI_STAGES];

  assign rvfi_valid     = rvfi_stage_valid    [RVFI_STAGES-1];
  assign rvfi_order     = rvfi_stage_order    [RVFI_STAGES-1];
  assign rvfi_insn      = rvfi_stage_insn     [RVFI_STAGES-1];
  assign rvfi_trap      = rvfi_stage_trap     [RVFI_STAGES-1];
  assign rvfi_halt      = rvfi_stage_halt     [RVFI_STAGES-1];
  assign rvfi_intr      = rvfi_stage_intr     [RVFI_STAGES-1];
  assign rvfi_mode      = rvfi_stage_mode     [RVFI_STAGES-1];
  assign rvfi_ixl       = rvfi_stage_ixl      [RVFI_STAGES-1];
  assign rvfi_rs1_addr  = rvfi_stage_rs1_addr [RVFI_STAGES-1];
  assign rvfi_rs2_addr  = rvfi_stage_rs2_addr [RVFI_STAGES-1];
  assign rvfi_rs3_addr  = rvfi_stage_rs3_addr [RVFI_STAGES-1];
  assign rvfi_rs1_rdata = rvfi_stage_rs1_rdata[RVFI_STAGES-1];
  assign rvfi_rs2_rdata = rvfi_stage_rs2_rdata[RVFI_STAGES-1];
  assign rvfi_rs3_rdata = rvfi_stage_rs3_rdata[RVFI_STAGES-1];
  assign rvfi_rd_addr   = rvfi_stage_rd_addr  [RVFI_STAGES-1];
  assign rvfi_rd_wdata  = rvfi_stage_rd_wdata [RVFI_STAGES-1];
  assign rvfi_pc_rdata  = rvfi_stage_pc_rdata [RVFI_STAGES-1];
  assign rvfi_pc_wdata  = rvfi_stage_pc_wdata [RVFI_STAGES-1];
  assign rvfi_mem_addr  = rvfi_stage_mem_addr [RVFI_STAGES-1];
  assign rvfi_mem_rmask = rvfi_stage_mem_rmask[RVFI_STAGES-1];
  assign rvfi_mem_wmask = rvfi_stage_mem_wmask[RVFI_STAGES-1];
  assign rvfi_mem_rdata = rvfi_stage_mem_rdata[RVFI_STAGES-1];
  assign rvfi_mem_wdata = rvfi_stage_mem_wdata[RVFI_STAGES-1];

  assign rvfi_instr_if.rvfi_valid     = rvfi_stage_valid    [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_order     = rvfi_stage_order    [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_insn      = rvfi_stage_insn     [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_trap      = rvfi_stage_trap     [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_halt      = rvfi_stage_halt     [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_dbg       = rvfi_stage_dbg      [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_dbg_mode  = rvfi_stage_dbg_mode [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_intr      = rvfi_stage_intr     [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_mode      = rvfi_stage_mode     [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_ixl       = rvfi_stage_ixl      [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_rs1_addr  = rvfi_stage_rs1_addr [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_rs2_addr  = rvfi_stage_rs2_addr [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_rs3_addr  = rvfi_stage_rs3_addr [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_rs1_rdata = rvfi_stage_rs1_rdata[RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_rs2_rdata = rvfi_stage_rs2_rdata[RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_rs3_rdata = rvfi_stage_rs3_rdata[RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_rd1_addr   = rvfi_stage_rd_addr  [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_rd1_wdata  = rvfi_stage_rd_wdata [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_pc_rdata  = rvfi_stage_pc_rdata [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_pc_wdata  = rvfi_stage_pc_wdata [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_mem_addr  = rvfi_stage_mem_addr [RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_mem_rmask = rvfi_stage_mem_rmask[RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_mem_wmask = rvfi_stage_mem_wmask[RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_mem_rdata = rvfi_stage_mem_rdata[RVFI_STAGES-1];
  assign rvfi_instr_if.rvfi_mem_wdata = rvfi_stage_mem_wdata[RVFI_STAGES-1];

  assign rvfi_rd_addr_wb  = rf_waddr_wb;
  assign rvfi_rd_wdata_wb = rf_we_wb ? rf_wdata_wb : rf_wdata_lsu;
  assign rvfi_rd_we_wb    = rf_we_wb | rf_we_lsu;

  always_comb begin
    // Use always_comb instead of continuous assign so first assign can set 0 as default everywhere
    // that is overridden by more specific settings.
    rvfi_ext_mip                                     = '0;
    rvfi_ext_mip[CSR_MSIX_BIT]                       = rvfi_ext_stage_mip[RVFI_STAGES].irq_software;
    rvfi_ext_mip[CSR_MTIX_BIT]                       = rvfi_ext_stage_mip[RVFI_STAGES].irq_timer;
    rvfi_ext_mip[CSR_MEIX_BIT]                       = rvfi_ext_stage_mip[RVFI_STAGES].irq_external;
    rvfi_ext_mip[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW] = rvfi_ext_stage_mip[RVFI_STAGES].irq_fast;
  end

  assign rvfi_ext_nmi       = rvfi_ext_stage_nmi[RVFI_STAGES];
  assign rvfi_ext_debug_req = rvfi_ext_stage_debug_req[RVFI_STAGES];
  assign rvfi_ext_mcycle    = rvfi_ext_stage_mcycle[RVFI_STAGES-1];

  // When an instruction takes a trap the `rvfi_trap` signal will be set. Instructions that take
  // traps flush the pipeline so ordinarily wouldn't be seen to be retire. The RVFI tracking
  // pipeline is kept going for flushed instructions that trapped so they are still visible on the
  // RVFI interface.

  // Factor in exceptions taken in ID so RVFI tracking picks up flushed instructions that took
  // a trap
  // MRET causes MSTATUS to get written one clock later. Fix rvfi_valid when executing MRET
  assign rvfi_id_done = (instr_id_done & !id_stage_i.controller_i.mret_insn)|
                         id_stage_i.csr_restore_mret_id_o |
                        (id_stage_i.controller_i.rvfi_flush_next & id_stage_i.controller_i.exc_req_d);

  // Without writeback stage first RVFI stage is output stage so simply valid the cycle after
  // instruction leaves ID/EX (and so has retired)
  assign rvfi_stage_valid_d[0] = rvfi_id_done;
  // Without writeback stage signal new instr_new_wb when instruction enters ID/EX to correctly
  // setup register write signals
  assign rvfi_instr_new_wb = instr_new_id;
  assign rvfi_trap_id = id_stage_i.controller_i.exc_req_d | id_stage_i.controller_i.exc_req_lsu;

  assign rvfi_stage_order_d = rvfi_stage_order[0] + 64'd1;

  // For interrupts and debug CVE2 will take the relevant trap as soon as whatever instruction in ID
  // finishes or immediately if the ID stage is empty. The rvfi_ext interface provides the DV
  // environment with information about the irq/debug_req/nmi state that applies to a particular
  // instruction.
  //
  // When a irq/debug_req/nmi appears the ID stage will finish whatever instruction it is currently
  // executing (if any) then take the trap the cycle after that instruction leaves the ID stage. The
  // trap taken depends upon the state of irq/debug_req/nmi on that cycle. In the cycles following
  // that before the first instruction of the trap handler enters the ID stage the state of
  // irq/debug_req/nmi could change but this has no effect on the trap handler (e.g. a higher
  // priority interrupt might appear but this wouldn't stop the lower priority interrupt trap
  // handler executing first as it's already being fetched). To provide the DV environment with the
  // correct information for it to verify execution we need to capture the irq/debug_req/nmi state
  // the cycle the trap decision is made. Which the captured_X signals below do.
  //
  // The new_X signals take the raw irq/debug_req/nmi inputs and factor in the enable terms required
  // to determine if a trap will actually happen.
  //
  // These signals and the comment above are referred to in the documentation (cosim.rst). If
  // altering the names or meanings of these signals or this comment please adjust the documentation
  // appropriately.
  assign new_debug_req = (debug_req_i & ~debug_mode);
  assign new_nmi = irq_nm_i & ~nmi_mode & ~debug_mode;
  assign new_irq = irq_pending_o & csr_mstatus_mie & ~nmi_mode & ~debug_mode;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      captured_valid     <= 1'b0;
      captured_mip       <= '0;
      captured_irq       <= '0;
      captured_nmi       <= 1'b0;
      captured_debug_req <= 1'b0;
      captured_debug_cause <= 1'b0;
    end else  begin
      // Capture when ID stage has emptied out and something occurs that will cause a trap and we
      // haven't yet captured
      if (~instr_valid_id & (new_debug_req | new_irq | new_nmi) & ~captured_valid) begin
        captured_valid     <= 1'b1;
        captured_nmi       <= irq_nm_i;
        captured_irq       <= new_irq | new_nmi;
        captured_mip       <= cs_registers_i.mip;
        captured_debug_req <= debug_req_i;
      end

      if (debug_csr_save) begin
        captured_debug_valid <= 1'b1;
        captured_debug_cause <= debug_cause;
      end

      // Capture cleared out as soon as a new instruction appears in ID
      if (if_stage_i.instr_valid_id_d) begin
        captured_valid <= 1'b0;
        captured_debug_valid <= 1'b0;
      end
    end
  end

  // Pass the captured irq/debug_req/nmi state to the rvfi_ext interface tracking pipeline.
  //
  // To correctly capture we need to factor in various enable terms, should there be a fault in this
  // logic we won't tell the DV environment about a trap that should have been taken. So if there's
  // no valid capture we grab the raw values of the irq/debug_req/nmi inputs whatever they are and
  // the DV environment will see if a trap should have been taken but wasn't.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvfi_ext_stage_mip[0]       <= '0;
      rvfi_ext_stage_nmi[0]       <= '0;
      rvfi_ext_stage_debug_req[0] <= '0;
    end else if (if_stage_i.instr_valid_id_d & if_stage_i.instr_new_id_d) begin
      automatic logic ext_debug_req = instr_valid_id | ~captured_valid ? debug_req_i : captured_debug_req;

      rvfi_ext_stage_mip[0]       <= instr_valid_id | ~captured_valid ? cs_registers_i.mip :
                                                                        captured_mip;
      rvfi_ext_stage_nmi[0]       <= instr_valid_id | ~captured_valid ? irq_nm_i :
                                                                        captured_nmi;
      rvfi_ext_stage_debug_req[0] <= ext_debug_req;

    end
      rvfi_dbg <= (captured_debug_valid) ? captured_debug_cause : 0;
  end

  assign rvfi_dbg_mode = debug_mode;

  for (genvar i = 0; i < RVFI_STAGES; i = i + 1) begin : g_rvfi_stages
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        rvfi_stage_halt[i]            <= '0;
        rvfi_stage_trap[i]            <= '0;
        rvfi_stage_intr[i]            <= '0;
        rvfi_stage_order[i]           <= '0;
        rvfi_stage_insn[i]            <= '0;
        rvfi_stage_mode[i]            <= {PRIV_LVL_M};
        rvfi_stage_ixl[i]             <= CSR_MISA_MXL;
        rvfi_stage_rs1_addr[i]        <= '0;
        rvfi_stage_rs2_addr[i]        <= '0;
        rvfi_stage_rs3_addr[i]        <= '0;
        rvfi_stage_pc_rdata[i]        <= '0;
        rvfi_stage_pc_wdata[i]        <= '0;
        rvfi_stage_mem_rmask[i]       <= '0;
        rvfi_stage_mem_wmask[i]       <= '0;
        rvfi_stage_valid[i]           <= '0;
        rvfi_stage_rs1_rdata[i]       <= '0;
        rvfi_stage_rs2_rdata[i]       <= '0;
        rvfi_stage_rs3_rdata[i]       <= '0;
        rvfi_stage_rd_wdata[i]        <= '0;
        rvfi_stage_rd_addr[i]         <= '0;
        rvfi_stage_mem_rdata[i]       <= '0;
        rvfi_stage_mem_wdata[i]       <= '0;
        rvfi_stage_mem_addr[i]        <= '0;
        rvfi_ext_stage_mip[i+1]       <= '0;
        rvfi_ext_stage_nmi[i+1]       <= '0;
        rvfi_ext_stage_debug_req[i+1] <= '0;
        rvfi_ext_stage_mcycle[i]      <= '0;
      end else begin
        rvfi_stage_valid[i] <= rvfi_stage_valid_d[i];

        if (i == 0) begin
          if (rvfi_stage_valid_d[i]) begin
            rvfi_stage_halt[i]      <= '0;
            // TODO: Sort this out for writeback stage
            rvfi_stage_trap[i]            <= rvfi_trap_id;
            if (rvfi_intr_d) begin
                if (captured_irq) begin
                    rvfi_stage_intr[i] <= { cs_registers_i.mcause_q[5:0], 3'b101};
                end else begin
                    rvfi_stage_intr[i] <= { cs_registers_i.mcause_q[5:0], 3'b011};
                end
            end
            else
                rvfi_stage_intr[i] <= 'b000;

            rvfi_stage_order[i]           <= rvfi_stage_order_d;
            rvfi_stage_insn[i]            <= rvfi_insn_id;
            rvfi_stage_mode[i]            <= {priv_mode_id};
            rvfi_stage_ixl[i]             <= CSR_MISA_MXL;
            rvfi_stage_rs1_addr[i]        <= rvfi_rs1_addr_d;
            rvfi_stage_rs2_addr[i]        <= rvfi_rs2_addr_d;
            rvfi_stage_rs3_addr[i]        <= rvfi_rs3_addr_d;
            rvfi_stage_pc_rdata[i]        <= pc_id;
            rvfi_stage_pc_wdata[i]        <= pc_set ? branch_target_ex : pc_if;
            rvfi_stage_mem_rmask[i]       <= rvfi_mem_mask_int;
            rvfi_stage_mem_wmask[i]       <= data_we_o ? rvfi_mem_mask_int : 4'b0000;
            rvfi_stage_rs1_rdata[i]       <= rvfi_rs1_data_d;
            rvfi_stage_rs2_rdata[i]       <= rvfi_rs2_data_d;
            rvfi_stage_rs3_rdata[i]       <= rvfi_rs3_data_d;
            rvfi_stage_rd_addr[i]         <= rvfi_rd_addr_d;
            rvfi_stage_rd_wdata[i]        <= rvfi_rd_wdata_d;
            rvfi_stage_mem_rdata[i]       <= rvfi_mem_rdata_d;
            rvfi_stage_mem_wdata[i]       <= rvfi_mem_wdata_d;
            rvfi_stage_mem_addr[i]        <= rvfi_mem_addr_d;
            rvfi_ext_stage_mip[i+1]       <= rvfi_ext_stage_mip[i];
            rvfi_ext_stage_nmi[i+1]       <= rvfi_ext_stage_nmi[i];
            rvfi_ext_stage_debug_req[i+1] <= rvfi_ext_stage_debug_req[i];
            rvfi_ext_stage_mcycle[i]      <= cs_registers_i.mcycle_counter_i.counter_val_o;
            rvfi_stage_dbg[i]             <= rvfi_dbg;
            rvfi_stage_dbg_mode[i]        <= rvfi_dbg_mode;
          end
          else begin
            rvfi_stage_trap[i]            <= 0;
          end
        end else begin
            rvfi_stage_halt[i]      <= rvfi_stage_halt[i-1];
            rvfi_stage_trap[i]      <= rvfi_stage_trap[i-1];
            rvfi_stage_intr[i]      <= rvfi_stage_intr[i-1];
            rvfi_stage_order[i]     <= rvfi_stage_order[i-1];
            rvfi_stage_insn[i]      <= rvfi_stage_insn[i-1];
            rvfi_stage_mode[i]      <= rvfi_stage_mode[i-1];
            rvfi_stage_ixl[i]       <= rvfi_stage_ixl[i-1];
            rvfi_stage_rs1_addr[i]  <= rvfi_stage_rs1_addr[i-1];
            rvfi_stage_rs2_addr[i]  <= rvfi_stage_rs2_addr[i-1];
            rvfi_stage_rs3_addr[i]  <= rvfi_stage_rs3_addr[i-1];
            rvfi_stage_pc_rdata[i]  <= rvfi_stage_pc_rdata[i-1];
            rvfi_stage_pc_wdata[i]  <= rvfi_stage_pc_wdata[i-1];
            rvfi_stage_mem_rmask[i] <= rvfi_stage_mem_rmask[i-1];
            rvfi_stage_mem_wmask[i] <= rvfi_stage_mem_wmask[i-1];
            rvfi_stage_rs1_rdata[i] <= rvfi_stage_rs1_rdata[i-1];
            rvfi_stage_rs2_rdata[i] <= rvfi_stage_rs2_rdata[i-1];
            rvfi_stage_rs3_rdata[i] <= rvfi_stage_rs3_rdata[i-1];
            rvfi_stage_mem_wdata[i] <= rvfi_stage_mem_wdata[i-1];
            rvfi_stage_mem_addr[i]  <= rvfi_stage_mem_addr[i-1];

            // For 2 RVFI_STAGES/Writeback Stage ignore first stage flops for rd_addr, rd_wdata and
            // mem_rdata. For RF write addr/data actual write happens in writeback so capture
            // address/data there. For mem_rdata that is only available from the writeback stage.
            // Previous stage flops still exist in RTL as they are used by the non writeback config
            rvfi_stage_rd_addr[i]   <= rvfi_rd_addr_d;
            rvfi_stage_rd_wdata[i]  <= rvfi_rd_wdata_d;
            rvfi_stage_mem_rdata[i] <= rvfi_mem_rdata_d;

            rvfi_ext_stage_mip[i+1]       <= rvfi_ext_stage_mip[i];
            rvfi_ext_stage_nmi[i+1]       <= rvfi_ext_stage_nmi[i];
            rvfi_ext_stage_debug_req[i+1] <= rvfi_ext_stage_debug_req[i];
            rvfi_ext_stage_mcycle[i]      <= rvfi_ext_stage_mcycle[i-1];
        end
      end
    end
  end


  // Memory adddress/write data available first cycle of ld/st instruction from register read
  always_comb begin
    if (instr_first_cycle_id) begin
      rvfi_mem_addr_d  = alu_adder_result_ex;
      rvfi_mem_wdata_d = lsu_wdata;
    end else begin
      rvfi_mem_addr_d  = rvfi_mem_addr_q;
      rvfi_mem_wdata_d = rvfi_mem_wdata_q;
    end
  end

  // Capture read data from LSU when it becomes valid
  always_comb begin
    if (lsu_resp_valid) begin
      rvfi_mem_rdata_d = rf_wdata_lsu;
    end else begin
      rvfi_mem_rdata_d = rvfi_mem_rdata_q;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvfi_mem_addr_q  <= '0;
      rvfi_mem_rdata_q <= '0;
      rvfi_mem_wdata_q <= '0;
    end else begin
      rvfi_mem_addr_q  <= rvfi_mem_addr_d;
      rvfi_mem_rdata_q <= rvfi_mem_rdata_d;
      rvfi_mem_wdata_q <= rvfi_mem_wdata_d;
    end
  end
  // Byte enable based on data type
  always_comb begin
    unique case (lsu_type)
      2'b00:   rvfi_mem_mask_int = 4'b1111;
      2'b01:   rvfi_mem_mask_int = 4'b0011;
      2'b10:   rvfi_mem_mask_int = 4'b0001;
      default: rvfi_mem_mask_int = 4'b0000;
    endcase
  end

  always_comb begin
    if (instr_is_compressed_id) begin
      rvfi_insn_id = {16'b0, instr_rdata_c_id};
    end else begin
      rvfi_insn_id = instr_rdata_id;
    end
  end

  // Source registers 1 and 2 are read in the first instruction cycle
  // Source register 3 is read in the second instruction cycle.
  always_comb begin
    if (instr_first_cycle_id) begin
      rvfi_rs1_data_d = rf_ren_a ? multdiv_operand_a_ex : '0;
      rvfi_rs1_addr_d = rf_ren_a ? rf_raddr_a : '0;
      rvfi_rs2_data_d = rf_ren_b ? multdiv_operand_b_ex : '0;
      rvfi_rs2_addr_d = rf_ren_b ? rf_raddr_b : '0;
      rvfi_rs3_data_d = '0;
      rvfi_rs3_addr_d = '0;
    end else begin
      rvfi_rs1_data_d = rvfi_rs1_data_q;
      rvfi_rs1_addr_d = rvfi_rs1_addr_q;
      rvfi_rs2_data_d = rvfi_rs2_data_q;
      rvfi_rs2_addr_d = rvfi_rs2_addr_q;
      rvfi_rs3_data_d = multdiv_operand_a_ex;
      rvfi_rs3_addr_d = rf_raddr_a;
    end
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvfi_rs1_data_q <= '0;
      rvfi_rs1_addr_q <= '0;
      rvfi_rs2_data_q <= '0;
      rvfi_rs2_addr_q <= '0;

    end else begin
      rvfi_rs1_data_q <= rvfi_rs1_data_d;
      rvfi_rs1_addr_q <= rvfi_rs1_addr_d;
      rvfi_rs2_data_q <= rvfi_rs2_data_d;
      rvfi_rs2_addr_q <= rvfi_rs2_addr_d;
    end
  end

  always_comb begin
    if (rvfi_rd_we_wb) begin
      // Capture address/data of write to register file
      rvfi_rd_addr_d = rvfi_rd_addr_wb;
      // If writing to x0 zero write data as required by RVFI specification
      if (rvfi_rd_addr_wb == 5'b0) begin
        rvfi_rd_wdata_d = '0;
      end else begin
        rvfi_rd_wdata_d = rvfi_rd_wdata_wb;
      end
    end else if (rvfi_instr_new_wb) begin
      // If no RF write but new instruction in Writeback (when present) or ID/EX (when no writeback
      // stage present) then zero RF write address/data as required by RVFI specification
      rvfi_rd_addr_d  = '0;
      rvfi_rd_wdata_d = '0;
    end else begin
      // Otherwise maintain previous value
      rvfi_rd_addr_d  = rvfi_rd_addr_q;
      rvfi_rd_wdata_d = rvfi_rd_wdata_q;
    end
  end

  // RD write register is refreshed only once per cycle and
  // then it is kept stable for the cycle.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvfi_rd_addr_q    <= '0;
      rvfi_rd_wdata_q   <= '0;
    end else begin
      rvfi_rd_addr_q    <= rvfi_rd_addr_d;
      rvfi_rd_wdata_q   <= rvfi_rd_wdata_d;
    end
  end

  // rvfi_intr must be set for first instruction that is part of a trap handler.
  // On the first cycle of a new instruction see if a trap PC was set by the previous instruction,
  // otherwise maintain value.
  assign rvfi_intr_d = instr_first_cycle_id ? rvfi_set_trap_pc_q : rvfi_intr_q;

  always_comb begin
    rvfi_set_trap_pc_d = rvfi_set_trap_pc_q;

    if (pc_set && pc_mux_id == PC_EXC &&
        (exc_pc_mux_id == EXC_PC_EXC || exc_pc_mux_id == EXC_PC_IRQ)) begin
      // PC is set to enter a trap handler
      rvfi_set_trap_pc_d = 1'b1;
    end else if (rvfi_set_trap_pc_q && rvfi_id_done) begin
      // first instruction has been executed after PC is set to trap handler
      rvfi_set_trap_pc_d = 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvfi_set_trap_pc_q <= 1'b0;
      rvfi_intr_q        <= 1'b0;
    end else begin
      rvfi_set_trap_pc_q <= rvfi_set_trap_pc_d;
      rvfi_intr_q        <= rvfi_intr_d;
    end
  end

`else
  logic unused_instr_new_id, unused_instr_id_done;
  assign unused_instr_id_done = instr_id_done;
  assign unused_instr_new_id = instr_new_id;
`endif

endmodule
