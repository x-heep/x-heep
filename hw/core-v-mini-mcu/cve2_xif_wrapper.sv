// Copyright 2025 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Author: Davide Schiavone

/**
 * CVE2 XIF Wrapper that partially translates the X-IF 1.0v to 0.2v
 * v1.0 specs: https://docs.openhwgroup.org/projects/openhw-group-core-v-xif/en/v1.0.0/intro.html
 * v0.2.0 specs: https://docs.openhwgroup.org/projects/openhw-group-core-v-xif/en/v0.2.0/intro.html
 */
module cve2_xif_wrapper
  import cve2_pkg::*;
#(
    parameter int unsigned MHPMCounterNum     = 0,
    parameter int unsigned MHPMCounterWidth   = 40,
    parameter bit          RV32E              = 1'b0,
    parameter rv32m_e      RV32M              = RV32MFast,
    parameter bit          X_INTERFACE        = 1'b0,
    parameter int unsigned X_INTERFACE_NUM_RS = 2
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    input logic test_en_i,  // enable all clock gates for testing

    input logic [31:0] hart_id_i,
    input logic [31:0] boot_addr_i,

    // Instruction memory interface
    output logic        instr_req_o,
    input  logic        instr_gnt_i,
    input  logic        instr_rvalid_i,
    output logic [31:0] instr_addr_o,
    input  logic [31:0] instr_rdata_i,

    // Data memory interface
    output logic        data_req_o,
    input  logic        data_gnt_i,
    input  logic        data_rvalid_i,
    output logic        data_we_o,
    output logic [ 3:0] data_be_o,
    output logic [31:0] data_addr_o,
    output logic [31:0] data_wdata_o,
    input  logic [31:0] data_rdata_i,

    // CORE-V-XIF
    if_xif.cpu_compressed xif_compressed_if,
    if_xif.cpu_issue      xif_issue_if,
    if_xif.cpu_commit     xif_commit_if,
    if_xif.cpu_mem        xif_mem_if,
    if_xif.cpu_mem_result xif_mem_result_if,
    if_xif.cpu_result     xif_result_if,

    // Interrupt inputs
    input logic        irq_software_i,
    input logic        irq_timer_i,
    input logic        irq_external_i,
    input logic [15:0] irq_fast_i,

    // Debug Interface
    input  logic        debug_req_i,
    output logic        debug_halted_o,
    input  logic [31:0] dm_halt_addr_i,
    input  logic [31:0] dm_exception_addr_i,

    // CPU Control Signals
    input  logic fetch_enable_i,
    output logic core_sleep_o
);
  // CVE2 X-IF signals
  logic                    cve2_x_issue_valid;
  logic                    cve2_x_issue_ready;
  cve2_pkg::x_issue_req_t  cve2_x_issue_req;
  cve2_pkg::x_issue_resp_t cve2_x_issue_resp;
  cve2_pkg::x_register_t   cve2_x_register;

  logic                    cve2_x_commit_valid;
  cve2_pkg::x_commit_t     cve2_x_commit;

  logic                    cve2_x_result_valid;
  logic                    cve2_x_result_ready;
  cve2_pkg::x_result_t     cve2_x_result;

  // ------------------
  // CORE-V X-IF BRIDGE
  // ------------------
  // CV32E20 implements a newer version of the interface compared to CV32E40X/CV32E40PX

  // Compressed Interface (not implemented by CV32E20)
  assign xif_compressed_if.compressed_valid = 1'b0;
  assign xif_compressed_if.compressed_req   = '0;

  // Issue Interface <--> Issue/Register Interface
  assign xif_issue_if.issue_valid           = cve2_x_issue_valid;
  assign cve2_x_issue_ready                 = xif_issue_if.issue_ready;
  assign xif_issue_if.issue_req.instr       = cve2_x_issue_req.instr;
  assign xif_issue_if.issue_req.mode        = '0;
  assign xif_issue_if.issue_req.id          = cve2_x_issue_req.id;
  assign xif_issue_if.issue_req.ecs         = '0;
  assign xif_issue_if.issue_req.ecs_valid   = 1'b0;
  assign cve2_x_issue_resp.accept           = xif_issue_if.issue_resp.accept;
  assign cve2_x_issue_resp.writeback        = xif_issue_if.issue_resp.writeback;
  generate
    if (X_INTERFACE_NUM_RS == 3) begin : gen_xif_upsize_rs
      // The third operand is tied to zero
      assign xif_issue_if.issue_req.rs       = {{X_RFR_WIDTH{1'b0}}, cve2_x_register.rs};
      assign xif_issue_if.issue_req.rs_valid = {1'b0, cve2_x_register.rs_valid};
    end else begin : gen_xif_same_rs
      assign xif_issue_if.issue_req.rs[1:0]       = cve2_x_register.rs;
      assign xif_issue_if.issue_req.rs_valid[1:0] = cve2_x_register.rs_valid;
    end
  endgenerate
  // NOTE: the following is suboptimal as it forces CVE2 to read all the registers,
  //       regardless of the coprocessor actually using them. Since CVE2 does not
  //       have other instructions in flight, there is no performance penalty.
  assign cve2_x_issue_resp.register_read    = '1;

  // Commit Interface
  assign xif_commit_if.commit_valid         = cve2_x_commit_valid;
  assign xif_commit_if.commit.id            = cve2_x_commit.id;
  assign xif_commit_if.commit.commit_kill   = cve2_x_commit.commit_kill;

  // Memory Interface (not implemented by CV32E20)
  assign xif_mem_if.mem_ready               = 1'b0;
  assign xif_mem_if.mem_resp                = '0;

  // Memory Result Interface (not implemented by CV32E20)
  assign xif_mem_result_if.mem_result_valid = 1'b0;
  assign xif_mem_result_if.mem_result       = '0;

  // Result Interface
  assign cve2_x_result_valid                = xif_result_if.result_valid;
  assign xif_result_if.result_ready         = cve2_x_result_ready;
  assign cve2_x_result.hartid               = '0;
  assign cve2_x_result.id                   = xif_result_if.result.id;
  assign cve2_x_result.data                 = xif_result_if.result.data;
  assign cve2_x_result.rd                   = xif_result_if.result.rd;
  assign cve2_x_result.we                   = xif_result_if.result.we;

  // ------------
  // CV32E20 CORE
  // ------------
  cve2_top #(
      .MHPMCounterNum,
      .MHPMCounterWidth,
      .RV32E,
      .RV32M,
      .XInterface(X_INTERFACE != '0)
  ) u_cve2_top (
      .clk_i,
      .rst_ni,
      .test_en_i,

      .hart_id_i,
      .boot_addr_i,
      .ram_cfg_i('0),

      .instr_req_o,
      .instr_gnt_i,
      .instr_rvalid_i,
      .instr_addr_o,
      .instr_rdata_i,
      .instr_err_i(1'b0),

      .data_req_o,
      .data_gnt_i,
      .data_rvalid_i,
      .data_we_o,
      .data_be_o,
      .data_addr_o,
      .data_wdata_o,
      .data_rdata_i,
      .data_err_i(1'b0),

      // Core-V Extension Interface (CV-X-IF)
      // Issue Interface
      .x_issue_valid_o(cve2_x_issue_valid),
      .x_issue_ready_i(cve2_x_issue_ready),
      .x_issue_req_o  (cve2_x_issue_req),
      .x_issue_resp_i (cve2_x_issue_resp),

      // Register Interface
      .x_register_o(cve2_x_register),

      // Commit Interface
      .x_commit_valid_o(cve2_x_commit_valid),
      .x_commit_o(cve2_x_commit),

      // Result Interface
      .x_result_valid_i(cve2_x_result_valid),
      .x_result_ready_o(cve2_x_result_ready),
      .x_result_i(cve2_x_result),

      .irq_software_i,
      .irq_timer_i,
      .irq_external_i,
      .irq_fast_i,
      .irq_nm_i(1'b0),

      .debug_req_i,
      .debug_halted_o,
      .dm_halt_addr_i,
      .dm_exception_addr_i,
      .crash_dump_o(),

      .fetch_enable_i,
      .core_sleep_o
  );

endmodule
