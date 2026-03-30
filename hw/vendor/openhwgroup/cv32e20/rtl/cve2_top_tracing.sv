// Copyright (c) 2025 Eclipse Foundation
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Top level module of the cve2 RISC-V core with tracing enabled
 */

module cve2_top_tracing import cve2_pkg::*; #(
  parameter int unsigned MHPMCounterNum   = 10,
  parameter int unsigned MHPMCounterWidth = 40,
  parameter bit          RV32E            = 1'b0,
  parameter rv32m_e      RV32M            = RV32MFast
) (
  // Clock and Reset
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic                         test_en_i,     // enable all clock gates for testing
  input  prim_ram_1p_pkg::ram_1p_cfg_t ram_cfg_i,


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

  // Debug Interface
  input  logic                         debug_req_i,
  output logic                         debug_halted_o,
  input  logic [31:0]                  dm_halt_addr_i,
  input  logic [31:0]                  dm_exception_addr_i,
  output crash_dump_t                  crash_dump_o,

  // CPU Control Signals
  input  logic                         fetch_enable_i,
  output logic                         core_sleep_o

);

  // cve2_tracer relies on the signals from the RISC-V Formal Interface
  `ifndef RVFI
    $fatal("Fatal error: RVFI needs to be defined globally.");
  `endif

  logic        rvfi_valid;
  logic [63:0] rvfi_order;
  logic [31:0] rvfi_insn;
  logic        rvfi_trap;
  logic        rvfi_halt;
  logic        rvfi_intr;
  logic [ 1:0] rvfi_mode;
  logic [ 1:0] rvfi_ixl;
  logic [ 4:0] rvfi_rs1_addr;
  logic [ 4:0] rvfi_rs2_addr;
  logic [ 4:0] rvfi_rs3_addr;
  logic [31:0] rvfi_rs1_rdata;
  logic [31:0] rvfi_rs2_rdata;
  logic [31:0] rvfi_rs3_rdata;
  logic [ 4:0] rvfi_rd_addr;
  logic [31:0] rvfi_rd_wdata;
  logic [31:0] rvfi_pc_rdata;
  logic [31:0] rvfi_pc_wdata;
  logic [31:0] rvfi_mem_addr;
  logic [ 3:0] rvfi_mem_rmask;
  logic [ 3:0] rvfi_mem_wmask;
  logic [31:0] rvfi_mem_rdata;
  logic [31:0] rvfi_mem_wdata;
  logic [31:0] rvfi_ext_mip;
  logic        rvfi_ext_nmi;
  logic        rvfi_ext_debug_req;
  logic [63:0] rvfi_ext_mcycle;

  logic [31:0] unused_rvfi_ext_mip;
  logic        unused_rvfi_ext_nmi;
  logic        unused_rvfi_ext_debug_req;
  logic [63:0] unused_rvfi_ext_mcycle;

  // Tracer doesn't use these signals, though other modules may probe down into tracer to observe
  // them.
  assign unused_rvfi_ext_mip = rvfi_ext_mip;
  assign unused_rvfi_ext_nmi = rvfi_ext_nmi;
  assign unused_rvfi_ext_debug_req = rvfi_ext_debug_req;
  assign unused_rvfi_ext_mcycle = rvfi_ext_mcycle;

  cve2_top #(
    .MHPMCounterNum   ( MHPMCounterNum   ),
    .MHPMCounterWidth ( MHPMCounterWidth ),
    .RV32E            ( RV32E            ),
    .RV32M            ( RV32M            )
  ) u_cve2_top (
    .clk_i,
    .rst_ni,

    .test_en_i,
    .ram_cfg_i,

    .hart_id_i,
    .boot_addr_i,

    .instr_req_o,
    .instr_gnt_i,
    .instr_rvalid_i,
    .instr_addr_o,
    .instr_rdata_i,
    .instr_err_i,

    .data_req_o,
    .data_gnt_i,
    .data_rvalid_i,
    .data_we_o,
    .data_be_o,
    .data_addr_o,
    .data_wdata_o,
    .data_rdata_i,
    .data_err_i,

    // Core-V Extension Interface (CV-X-IF)
    // Issue Interface
    .x_issue_valid_o,
    .x_issue_ready_i,
    .x_issue_req_o,
    .x_issue_resp_i,

    // Register Interface
    .x_register_o,

    // Commit Interface
    .x_commit_valid_o,
    .x_commit_o,

    // Result Interface
    .x_result_valid_i,
    .x_result_ready_o,
    .x_result_i,

    .irq_software_i,
    .irq_timer_i,
    .irq_external_i,
    .irq_fast_i,
    .irq_nm_i,

    .debug_req_i,
    .debug_halted_o,
    .dm_halt_addr_i,
    .dm_exception_addr_i,
    .crash_dump_o,

    .rvfi_valid,
    .rvfi_order,
    .rvfi_insn,
    .rvfi_trap,
    .rvfi_halt,
    .rvfi_intr,
    .rvfi_mode,
    .rvfi_ixl,
    .rvfi_rs1_addr,
    .rvfi_rs2_addr,
    .rvfi_rs3_addr,
    .rvfi_rs1_rdata,
    .rvfi_rs2_rdata,
    .rvfi_rs3_rdata,
    .rvfi_rd_addr,
    .rvfi_rd_wdata,
    .rvfi_pc_rdata,
    .rvfi_pc_wdata,
    .rvfi_mem_addr,
    .rvfi_mem_rmask,
    .rvfi_mem_wmask,
    .rvfi_mem_rdata,
    .rvfi_mem_wdata,
    .rvfi_ext_mip,
    .rvfi_ext_nmi,
    .rvfi_ext_debug_req,
    .rvfi_ext_mcycle,

    .fetch_enable_i,
    .core_sleep_o
  );

  cve2_tracer
  u_cve2_tracer (
    .clk_i,
    .rst_ni,

    .hart_id_i,

    .rvfi_valid,
    .rvfi_order,
    .rvfi_insn,
    .rvfi_trap,
    .rvfi_halt,
    .rvfi_intr,
    .rvfi_mode,
    .rvfi_ixl,
    .rvfi_rs1_addr,
    .rvfi_rs2_addr,
    .rvfi_rs3_addr,
    .rvfi_rs1_rdata,
    .rvfi_rs2_rdata,
    .rvfi_rs3_rdata,
    .rvfi_rd_addr,
    .rvfi_rd_wdata,
    .rvfi_pc_rdata,
    .rvfi_pc_wdata,
    .rvfi_mem_addr,
    .rvfi_mem_rmask,
    .rvfi_mem_wmask,
    .rvfi_mem_rdata,
    .rvfi_mem_wdata
  );

endmodule
