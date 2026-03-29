// Copyright 2021 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Wrapper for a fpu_ss, containing fpu_ss, and tracer
// Contributor: Moritz Imfeld <moimfeld@student.ethz.ch>

`ifdef FPU_SS_TRACER
`include "fpu_ss_tracer.sv"
`endif
module fpu_ss_wrapper
    import fpu_ss_pkg::*;
#(
    parameter                                 PULP_ZFINX         = 0,
    parameter                                 INPUT_BUFFER_DEPTH = 1,
    parameter                                 OUT_OF_ORDER       = 1,
    parameter                                 FORWARDING         = 1,
    parameter fpnew_pkg::fpu_features_t       FPU_FEATURES       = fpu_ss_pkg::FPU_FEATURES,
    parameter fpnew_pkg::fpu_implementation_t FPU_IMPLEMENTATION = fpu_ss_pkg::FPU_IMPLEMENTATION
) (
    // clock and reset
    input logic clk_i,
    input logic rst_ni,

    // Compressed Interface
    input  logic x_compressed_valid_i,
    output logic x_compressed_ready_o,
    input  x_compressed_req_t x_compressed_req_i,
    output x_compressed_resp_t x_compressed_resp_o,

    // Issue Interface
    input  logic x_issue_valid_i,
    output logic x_issue_ready_o,
    input  x_issue_req_t x_issue_req_i,
    output x_issue_resp_t x_issue_resp_o,

    // Commit Interface
    input  logic x_commit_valid_i,
    input  x_commit_t x_commit_i,

    // Memory request/response Interface
    output logic x_mem_valid_o,
    input  logic x_mem_ready_i,
    output x_mem_req_t x_mem_req_o,
    input  x_mem_resp_t x_mem_resp_i,

    // Memory Result Interface
    input  logic x_mem_result_valid_i,
    input  x_mem_result_t x_mem_result_i,

    // Result Interface
    output logic x_result_valid_o,
    input  logic x_result_ready_i,
    output x_result_t x_result_o
);

	`ifdef FPU_SS_TRACER
	  fpu_ss_tracer fpu_ss_tracer_i (
	      .clk_i                (fpu_ss_i.clk_i),
	      .rst_ni               (fpu_ss_i.rst_ni),
	      .x_mem_valid_i        (fpu_ss_i.x_mem_valid_o),
	      .fpu_in_valid_i       (fpu_ss_i.fpu_in_valid),
          .rs1_i                (fpu_ss_i.rs1),
          .rs2_i                (fpu_ss_i.rs2),
          .rs3_i                (fpu_ss_i.rs3),
	      .instr_i              (fpu_ss_i.instr),
	      .fpu_out_valid_i      (fpu_ss_i.fpu_out_valid),
	      .fpu_out_ready_i      (fpu_ss_i.fpu_out_ready),
	      .fpu_waddr_i          (fpu_ss_i.fpr_wb_addr),
	      .fpu_result_i         (fpu_ss_i.fpu_result),
	      .x_mem_result_valid_i (fpu_ss_i.x_mem_result_valid_i),
	      .fpr_we_i             (fpu_ss_i.fpr_we),
	      .x_mem_result_i       (fpu_ss_i.fpr_wb_data)
	  );
	`endif

	  // instantiate the fpu_ss
	  fpu_ss #(
      .PULP_ZFINX(PULP_ZFINX),
      .INPUT_BUFFER_DEPTH(INPUT_BUFFER_DEPTH),
      .OUT_OF_ORDER(OUT_OF_ORDER),
      .FORWARDING(FORWARDING),
      .FPU_FEATURES(FPU_FEATURES),
      .FPU_IMPLEMENTATION(FPU_IMPLEMENTATION)
	  ) fpu_ss_i (
	      .*
	  );
	endmodule