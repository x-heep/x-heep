// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

// Matrix cps wrapper



module quadrilatero_wrapper
  import quadrilatero_pkg::*;
  import xif_pkg::*;
  import obi_pkg::*;
#(
    parameter INPUT_BUFFER_DEPTH = 4,
    parameter RES_IF_FIFO_DEPTH  = 4,
    parameter MATRIX_FPU         = 1
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // eXtension interface
    if_xif.coproc_compressed xif_compressed_if,
    if_xif.coproc_issue      xif_issue_if,
    if_xif.coproc_commit     xif_commit_if,
    if_xif.coproc_mem        xif_mem_if,
    if_xif.coproc_mem_result xif_mem_result_if,
    if_xif.coproc_result     xif_result_if,

    // OBI signals 
    output obi_req_t  quadrilatero_ch0_req_o,
    input  obi_resp_t quadrilatero_ch0_resp_i,
    output obi_req_t  quadrilatero_ch1_req_o,
    input  obi_resp_t quadrilatero_ch1_resp_i,
    output obi_req_t  quadrilatero_ch2_req_o,
    input  obi_resp_t quadrilatero_ch2_resp_i,
    output obi_req_t  quadrilatero_ch3_req_o,
    input  obi_resp_t quadrilatero_ch3_resp_i
);

  // Internal signals
  logic                                     mem_req;
  logic                                     mem_we;
  logic [quadrilatero_pkg::BUS_WIDTH/8 - 1:0] mem_be;
  logic [                             31:0] mem_addr;
  logic [  quadrilatero_pkg::BUS_WIDTH - 1:0] mem_wdata;
  logic                                     mem_gnt;
  logic                                     mem_rvalid;
  logic [  quadrilatero_pkg::BUS_WIDTH - 1:0] mem_rdata;


  // Matrix coprocessor
  quadrilatero #(
      .INPUT_BUFFER_DEPTH(INPUT_BUFFER_DEPTH),  // 0 means no input buffer 
      .RES_IF_FIFO_DEPTH (RES_IF_FIFO_DEPTH ),
      .FPU               (MATRIX_FPU        )
  ) mat_inst (
      .clk_i,
      .rst_ni,

      // OBI signals
      .mem_req_o   (mem_req),
      .mem_we_o    (mem_we),
      .mem_be_o    (mem_be),
      .mem_addr_o  (mem_addr),
      .mem_wdata_o (mem_wdata),
      .mem_gnt_i   (mem_gnt),
      .mem_rvalid_i(mem_rvalid),
      .mem_rdata_i (mem_rdata),

      // Compressed Interface
      .x_compressed_valid_i(xif_compressed_if.compressed_valid),
      .x_compressed_ready_o(xif_compressed_if.compressed_ready),
      .x_compressed_req_i  (xif_compressed_if.compressed_req),
      .x_compressed_resp_o (xif_compressed_if.compressed_resp),

      // Issue Interface
      .x_issue_valid_i(xif_issue_if.issue_valid),
      .x_issue_ready_o(xif_issue_if.issue_ready),
      .x_issue_req_i  (xif_issue_if.issue_req),
      .x_issue_resp_o (xif_issue_if.issue_resp),

      // Commit Interface
      .x_commit_valid_i(xif_commit_if.commit_valid),
      .x_commit_i      (xif_commit_if.commit),

      // Memory Request/Response Interface
      .x_mem_valid_o(xif_mem_if.mem_valid),
      .x_mem_ready_i(xif_mem_if.mem_ready),
      .x_mem_req_o  (xif_mem_if.mem_req),
      .x_mem_resp_i (xif_mem_if.mem_resp),

      // Memory Result Interface
      .x_mem_result_valid_i(xif_mem_result_if.mem_result_valid),
      .x_mem_result_i      (xif_mem_result_if.mem_result),

      // Result Interface
      .x_result_valid_o(xif_result_if.result_valid),
      .x_result_ready_i(xif_result_if.result_ready),
      .x_result_o      (xif_result_if.result)
  );


  // Bridge to OBI
  quadrilatero_to_obi bridge_inst (
      // Clock and Reset
      .clk_i,
      .rst_ni,

      // Memory Interface to x-heep OBI
      .mem_req_i  (mem_req),
      .mem_we_i   (mem_we),
      .mem_be_i   (mem_be),
      .mem_addr_i (mem_addr),
      .mem_wdata_i(mem_wdata),

      .mem_gnt_o   (mem_gnt),
      .mem_rvalid_o(mem_rvalid),
      .mem_rdata_o (mem_rdata),

      // OBI signals 
      .quadrilatero_ch0_req_o,
      .quadrilatero_ch0_resp_i,
      .quadrilatero_ch1_req_o,
      .quadrilatero_ch1_resp_i,
      .quadrilatero_ch2_req_o,
      .quadrilatero_ch2_resp_i,
      .quadrilatero_ch3_req_o,
      .quadrilatero_ch3_resp_i
  );

endmodule
