// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Author: Davide Schiavone

module cv32e40px_xif_wrapper
  import cv32e40px_core_v_xif_pkg::*;
#(
    parameter COREV_PULP = 0, // PULP ISA Extension (incl. custom CSRs and hardware loop, excl. cv.elw)
    parameter COREV_CLUSTER = 0,  // PULP Cluster interface (incl. cv.elw)
    parameter FPU = 0,  // Floating Point Unit (interfaced via APU interface)
    parameter FPU_ADDMUL_LAT = 0,  // Floating-Point ADDition/MULtiplication computing lane pipeline registers number
    parameter FPU_OTHERS_LAT = 0,  // Floating-Point COMParison/CONVersion computing lanes pipeline registers number
    parameter ZFINX = 0,  // Float-in-General Purpose registers
    parameter NUM_MHPMCOUNTERS = 1,
    parameter bit X_INTERFACE = 0,
    parameter int unsigned X_INTERFACE_NUM_RS = 2
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    input logic pulp_clock_en_i,  // PULP clock enable (only used if COREV_CLUSTER = 1)
    input logic scan_cg_en_i,  // Enable all clock gates for testing

    // Core ID, Cluster ID, debug mode halt address and boot address are considered more or less static
    input logic [31:0] boot_addr_i,
    input logic [31:0] mtvec_addr_i,
    input logic [31:0] dm_halt_addr_i,
    input logic [31:0] hart_id_i,
    input logic [31:0] dm_exception_addr_i,

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
    input  logic [31:0] irq_i,      // CLINT interrupts + CLINT extension interrupts
    output logic        irq_ack_o,
    output logic [ 4:0] irq_id_o,

    // Debug Interface
    input  logic debug_req_i,
    output logic debug_havereset_o,
    output logic debug_running_o,
    output logic debug_halted_o,

    // CPU Control Signals
    input  logic fetch_enable_i,
    output logic core_sleep_o
);


  logic x_compressed_valid;
  logic x_compressed_ready;
  cv32e40px_core_v_xif_pkg::x_compressed_req_t x_compressed_req;
  cv32e40px_core_v_xif_pkg::x_compressed_resp_t x_compressed_resp;

  // Issue Interface
  logic x_issue_valid;
  logic x_issue_ready;
  cv32e40px_core_v_xif_pkg::x_issue_req_t x_issue_req;
  cv32e40px_core_v_xif_pkg::x_issue_resp_t x_issue_resp;

  // Commit Interface
  logic x_commit_valid;
  cv32e40px_core_v_xif_pkg::x_commit_t x_commit;

  // Memory request/response Interface
  logic x_mem_valid;
  logic x_mem_ready;
  cv32e40px_core_v_xif_pkg::x_mem_req_t x_mem_req;
  cv32e40px_core_v_xif_pkg::x_mem_resp_t x_mem_resp;

  // Memory Result Interface
  logic x_mem_result_valid;
  cv32e40px_core_v_xif_pkg::x_mem_result_t x_mem_result;

  // Result Interface
  logic x_result_valid;
  logic x_result_ready;
  cv32e40px_core_v_xif_pkg::x_result_t x_result;

  // Compressed interface
  //output logic x_compressed_valid_o,
  assign xif_compressed_if.compressed_valid = x_compressed_valid;
  //    output x_compressed_req_t x_compressed_req_o,
  assign xif_compressed_if.compressed_req   = x_compressed_req;
  //input logic x_compressed_ready_i,
  assign x_compressed_ready                 = xif_compressed_if.compressed_ready;
  //input x_compressed_resp_t x_compressed_resp_i,
  assign x_compressed_resp                  = xif_compressed_if.compressed_resp;

  // Issue Interface
  //output logic x_issue_valid_o,
  assign xif_issue_if.issue_valid           = x_issue_valid;
  //input logic x_issue_ready_i,
  assign x_issue_ready                      = xif_issue_if.issue_ready;

  //output x_issue_req_t x_issue_req_o,
  assign xif_issue_if.issue_req.instr       = x_issue_req.instr;
  assign xif_issue_if.issue_req.mode        = x_issue_req.mode;
  assign xif_issue_if.issue_req.id          = x_issue_req.id;
  assign xif_issue_if.issue_req.ecs         = x_issue_req.ecs;
  assign xif_issue_if.issue_req.ecs_valid   = x_issue_req.ecs_valid;
  generate
    if (X_INTERFACE_NUM_RS == 3) begin : gen_xif_same_rs
      //cv32e40px has 3 ports so no problem
      assign xif_issue_if.issue_req.rs       = x_issue_req.rs;
      assign xif_issue_if.issue_req.rs_valid = x_issue_req.rs_valid;
    end else begin : gen_xif_downsize_rs
      //if 2 ports (we do not support 1 or >3 ports)
      assign xif_issue_if.issue_req.rs[0]         = x_issue_req.rs[0];
      assign xif_issue_if.issue_req.rs[1]         = x_issue_req.rs[1];
      assign xif_issue_if.issue_req.rs_valid[1:0] = x_issue_req.rs_valid[1:0];
    end
  endgenerate

  //input x_issue_resp_t x_issue_resp_i,
  assign x_issue_resp = xif_issue_if.issue_resp;

  // Commit Interface
  //output logic x_commit_valid_o,
  assign xif_commit_if.commit_valid = x_commit_valid;
  //output x_commit_t x_commit_o,
  assign xif_commit_if.commit = x_commit;

  // Memory request/response Interface
  //input logic x_mem_valid_i,
  assign x_mem_valid = xif_mem_if.mem_valid;
  //output logic x_mem_ready_o,
  assign xif_mem_if.mem_ready = x_mem_ready;
  //input x_mem_req_t x_mem_req_i,
  assign x_mem_req = xif_mem_if.mem_req;
  //output x_mem_resp_t x_mem_resp_o,
  assign xif_mem_if.mem_resp = x_mem_resp;

  // Memory Result Interface
  // output logic x_mem_result_valid_o,
  assign xif_mem_result_if.mem_result_valid = x_mem_result_valid;
  // output x_mem_result_t x_mem_result_o,
  assign xif_mem_result_if.mem_result = x_mem_result;

  // Result Interface
  //input logic x_result_valid_i,
  assign x_result_valid = xif_result_if.result_valid;
  //output logic x_result_ready_o,
  assign xif_result_if.result_ready = x_result_ready;
  //input x_result_t x_result_i,
  assign x_result = xif_result_if.result;

  cv32e40px_top #(
      .COREV_X_IF(X_INTERFACE),
      .COREV_PULP(COREV_PULP),
      .COREV_CLUSTER(COREV_CLUSTER),
      .FPU(FPU),
      .FPU_ADDMUL_LAT(FPU_ADDMUL_LAT),
      .FPU_OTHERS_LAT(FPU_OTHERS_LAT),
      .ZFINX(ZFINX),
      .NUM_MHPMCOUNTERS(NUM_MHPMCOUNTERS)
  ) cv32e40px_top_i (
      .clk_i,
      .rst_ni,

      .pulp_clock_en_i,
      .scan_cg_en_i,

      .boot_addr_i,
      .mtvec_addr_i,
      .dm_halt_addr_i,
      .hart_id_i,
      .dm_exception_addr_i,

      .instr_addr_o,
      .instr_req_o,
      .instr_rdata_i,
      .instr_gnt_i,
      .instr_rvalid_i,

      .data_addr_o,
      .data_wdata_o,
      .data_we_o,
      .data_req_o,
      .data_be_o,
      .data_rdata_i,
      .data_gnt_i,
      .data_rvalid_i,

      // CORE-V-XIF
      // Compressed interface
      .x_compressed_valid_o(x_compressed_valid),
      .x_compressed_ready_i(x_compressed_ready),
      .x_compressed_req_o  (x_compressed_req),
      .x_compressed_resp_i (x_compressed_resp),

      // Issue Interface
      .x_issue_valid_o(x_issue_valid),
      .x_issue_ready_i(x_issue_ready),
      .x_issue_req_o  (x_issue_req),
      .x_issue_resp_i (x_issue_resp),

      // Commit Interface
      .x_commit_valid_o(x_commit_valid),
      .x_commit_o(x_commit),

      // Memory Request/Response Interface
      .x_mem_valid_i(x_mem_valid),
      .x_mem_ready_o(x_mem_ready),
      .x_mem_req_i  (x_mem_req),
      .x_mem_resp_o (x_mem_resp),

      // Memory Result Interface
      .x_mem_result_valid_o(x_mem_result_valid),
      .x_mem_result_o(x_mem_result),

      // Result Interface
      .x_result_valid_i(x_result_valid),
      .x_result_ready_o(x_result_ready),
      .x_result_i(x_result),

      .irq_i,
      .irq_ack_o,
      .irq_id_o,
      .debug_req_i,
      .debug_havereset_o,
      .debug_running_o,
      .debug_halted_o,
      .fetch_enable_i,
      .core_sleep_o
  );


endmodule
