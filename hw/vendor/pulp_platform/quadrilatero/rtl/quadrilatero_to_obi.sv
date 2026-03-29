// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

/* 
 *  Description: Bridge between Matrix coprocessor and OBI bus
 *  It does not support multiple outstanding transactions.
 * 
 *  This module is currently working only for BUS_WIDTH = 128.
 *  For a different BUS_WIDTH value, modify it accordingly where marked.
 */
module quadrilatero_to_obi
  import quadrilatero_pkg::*;
  import xif_pkg::*;
  import obi_pkg::*;
(
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Memory Interface to x-heep OBI
    input logic                                     mem_req_i,
    input logic                                     mem_we_i,
    input logic [quadrilatero_pkg::BUS_WIDTH/8 - 1:0] mem_be_i,
    input logic [                             31:0] mem_addr_i,
    input logic [  quadrilatero_pkg::BUS_WIDTH - 1:0] mem_wdata_i,

    output logic                                   mem_gnt_o,
    output logic                                   mem_rvalid_o,
    output logic [quadrilatero_pkg::BUS_WIDTH - 1:0] mem_rdata_o,

    // OBI signals  -- MODIFY IF BUS_WIDTH != 128 
    output obi_req_t  quadrilatero_ch0_req_o,
    input  obi_resp_t quadrilatero_ch0_resp_i,
    output obi_req_t  quadrilatero_ch1_req_o,
    input  obi_resp_t quadrilatero_ch1_resp_i,
    output obi_req_t  quadrilatero_ch2_req_o,
    input  obi_resp_t quadrilatero_ch2_resp_i,
    output obi_req_t  quadrilatero_ch3_req_o,
    input  obi_resp_t quadrilatero_ch3_resp_i
);

  // Internal signals and parameters
  localparam int N_PLL_PORTS = quadrilatero_pkg::BUS_WIDTH / 32;

  obi_req_t                                    matrix_req[0:N_PLL_PORTS-1];
  obi_resp_t                                   matrix_rsp[0:N_PLL_PORTS-1];

  logic      [              N_PLL_PORTS-1 : 0] gnt_q      ;
  logic      [              N_PLL_PORTS-1 : 0] gnt_d      ;
  logic      [              N_PLL_PORTS-1 : 0] rvalid_q   ;
  logic      [              N_PLL_PORTS-1 : 0] rvalid_d   ;
  logic      [quadrilatero_pkg::BUS_WIDTH - 1:0] rdata_q    ;
  logic      [quadrilatero_pkg::BUS_WIDTH - 1:0] rdata_d    ;
  logic      [              N_PLL_PORTS-1 : 0] gnt        ;
  logic      [              N_PLL_PORTS-1 : 0] rvalid     ;
  logic      [quadrilatero_pkg::BUS_WIDTH - 1:0] rdata      ;
  logic                                        all_gnt    ;
  logic                                        all_rvalid ;

  assign all_gnt    = &gnt   ;
  assign all_rvalid = &rvalid;

  // OBI output generation
  always_comb begin : obi_out
    for (int ii = 0; ii < N_PLL_PORTS; ii++) begin
      matrix_req[ii].req   = mem_req_i & ~gnt_q[ii];
      matrix_req[ii].we    = mem_we_i;
      matrix_req[ii].be    = mem_be_i[4*ii+:4];
      matrix_req[ii].addr  = mem_addr_i + 32'(4 * ii);
      matrix_req[ii].wdata = mem_wdata_i[32*ii+:32];

      gnt[ii]    = matrix_rsp[ii].gnt    | gnt_q[ii]   ;
      rvalid[ii] = matrix_rsp[ii].rvalid | rvalid_q[ii];
      
      rdata[32*ii+:32] = (rvalid_q[ii]) ? rdata_q[32*ii+:32] : matrix_rsp[ii].rdata;

    end
  end

  // Compute next value to FF
  always_comb begin : next_value
    gnt_d    = gnt_q;
    rdata_d  = rdata_q;
    rvalid_d = rvalid_q;

    for (int ii = 0; ii < N_PLL_PORTS; ii++) begin

      // Grant
      if( all_gnt ) begin
        gnt_d[ii] = 1'b0;
      end else if (matrix_rsp[ii].gnt) begin
        gnt_d[ii] = 1'b1;
      end 

      // Read Valid
      if (all_rvalid) begin
        rvalid_d[ii] = 1'b0;
      end else if (matrix_rsp[ii].rvalid) begin
        rvalid_d[ii] = 1'b1;
      end

      // Read Data
      if (matrix_rsp[ii].rvalid &~ all_rvalid) begin
        rdata_d[32*ii+:32] = matrix_rsp[ii].rdata;
      end

    end

  end

  // Sequential block
  always_ff @(negedge rst_ni, posedge clk_i) begin : seq_block
    if (!rst_ni) begin
      gnt_q    <= '0;
      rdata_q  <= '0;
      rvalid_q <= '0;
    end else begin
      gnt_q    <= gnt_d;
      rdata_q  <= rdata_d;
      rvalid_q <= rvalid_d;
    end
  end

  // Input re-assignment  -- MODIFY IF BUS_WIDTH != 128
  assign matrix_rsp[0] = quadrilatero_ch0_resp_i;
  assign matrix_rsp[1] = quadrilatero_ch1_resp_i;
  assign matrix_rsp[2] = quadrilatero_ch2_resp_i;
  assign matrix_rsp[3] = quadrilatero_ch3_resp_i;

  // Output re-assignment  -- MODIFY IF BUS_WIDTH != 128
  assign quadrilatero_ch0_req_o = matrix_req[0];
  assign quadrilatero_ch1_req_o = matrix_req[1];
  assign quadrilatero_ch2_req_o = matrix_req[2];
  assign quadrilatero_ch3_req_o = matrix_req[3];

  assign mem_gnt_o    = all_gnt   ;
  assign mem_rvalid_o = all_rvalid;
  assign mem_rdata_o  = rdata     ;


  // Assertions -- MODIFY IF BUS_WIDTH != 128
  if (quadrilatero_pkg::BUS_WIDTH != 128) begin
    $error(
        "[quadrilatero_to_obi] The quadrilatero_pkg::BUS_WIDTH needs to be 128 for the current implementation.\n"
    );
  end

  if (quadrilatero_pkg::BUS_WIDTH != ((quadrilatero_pkg::BUS_WIDTH >> 5) << 5)) begin
    $error(
        "[quadrilatero_to_obi] The quadrilatero_pkg::BUS_WIDTH needs to be a multiple of 32.\n"
    );
  end

endmodule
