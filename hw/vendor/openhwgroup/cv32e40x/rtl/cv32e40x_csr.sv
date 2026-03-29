// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Control / status register primitive
 */


module cv32e40x_csr #(
    parameter int unsigned    WIDTH      = 32,
    parameter bit [WIDTH-1:0] RESETVALUE = '0,
    parameter bit [WIDTH-1:0] MASK       = '1
 ) (
    input  logic             clk,
    input  logic             rst_n,

    input  logic [WIDTH-1:0] wr_data_i,
    input  logic             wr_en_i,
    output logic [WIDTH-1:0] rd_data_o
);

  logic [WIDTH-1:0] rdata_q;

  generate
    for (genvar i = 0; i < WIDTH; i++) begin : gen_csr
      if (MASK[i]) begin : gen_unmasked
        // Bits with mask set are actual flipflops
        always_ff @(posedge clk or negedge rst_n) begin
          if (!rst_n) begin
            rdata_q[i] <= RESETVALUE[i];
          end else if (wr_en_i) begin
            rdata_q[i] <= wr_data_i[i];
          end
        end
      end else begin : gen_masked
        // Bits with mask cleared are tied off to the reset value
        assign rdata_q[i] = RESETVALUE[i];
      end
    end // for
  endgenerate

  assign rd_data_o = rdata_q;



endmodule
