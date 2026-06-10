// Copyright 2026 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module sram_wrapper #(
    parameter int unsigned NumWords = 32'd1024,  // Number of Words in data array
    parameter int unsigned DataWidth = 32'd32,  // Data signal width
    // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
    parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1
) (
    input  logic                 clk_i,    // Clock
    input  logic                 rst_ni,   // Asynchronous reset active low
    // input ports
    input  logic                 req_i,    // request
    input  logic                 we_i,     // write enable
    input  logic [AddrWidth-1:0] addr_i,   // request address
    input  logic [         31:0] wdata_i,  // write data
    input  logic [          3:0] be_i,     // write byte enable
    input  logic                 set_retentive_ni, // set retentive state (unused here)
    input  logic                 pwrgate_ni,      // power gate enable active low (unused in sky130)
    output logic                 pwrgate_ack_no,  // power gate ack active low (tie-through)
    // output ports
    output logic [         31:0] rdata_o   // read data
);

  // Assemble bit mask
  logic [DataWidth:0] bm;
  for (genvar b = 0; b < DataWidth; ++b) begin : gen_bm_bits
    assign bm[b] = be_i[b/8];
  end

  assign pwrgate_ack_no = pwrgate_ni;

  generate;
    if (NumWords == 256) begin // 1KiB
      RM_IHPSG13_1P_256x32_c2_bm_bist sram_i (
        .A_CLK        ( clk_i   ),
        .A_DLY        (  1'b1   ),
        .A_ADDR       ( addr_i  ),
        .A_BM         ( bm      ),
        .A_MEN        ( req_i   ),
        .A_WEN        ( we_i    ),
        .A_REN        ( ~we_i   ),
        .A_DIN        ( wdata_i ),
        .A_DOUT       ( rdata_o ),
        // BIST disabled
        .A_BIST_CLK   (  1'b0 ),
        .A_BIST_ADDR  (  8'd0 ),
        .A_BIST_DIN   ( 32'd0 ),
        .A_BIST_BM    ( 32'd0 ),
        .A_BIST_MEN   (  1'b0 ),
        .A_BIST_WEN   (  1'b0 ),
        .A_BIST_REN   (  1'b0 ),
        .A_BIST_EN    (  1'b0 )
      );
    end else if (NumWords == 512) begin // 2KiB
      RM_IHPSG13_1P_512x32_c2_bm_bist sram_i (
        .A_CLK        ( clk_i   ),
        .A_DLY        (  1'b1   ),
        .A_ADDR       ( addr_i  ),
        .A_BM         ( bm      ),
        .A_MEN        ( req_i   ),
        .A_WEN        ( we_i    ),
        .A_REN        ( ~we_i   ),
        .A_DIN        ( wdata_i ),
        .A_DOUT       ( rdata_o ),
        // BIST disabled
        .A_BIST_CLK   (  1'b0 ),
        .A_BIST_ADDR  (  8'd0 ),
        .A_BIST_DIN   ( 32'd0 ),
        .A_BIST_BM    ( 32'd0 ),
        .A_BIST_MEN   (  1'b0 ),
        .A_BIST_WEN   (  1'b0 ),
        .A_BIST_REN   (  1'b0 ),
        .A_BIST_EN    (  1'b0 )
      );
    end else if (NumWords == 1024) begin // 4KiB
      RM_IHPSG13_1P_1024x32_c2_bm_bist sram_i (
        .A_CLK        ( clk_i   ),
        .A_DLY        (  1'b1   ),
        .A_ADDR       ( addr_i  ),
        .A_BM         ( bm      ),
        .A_MEN        ( req_i   ),
        .A_WEN        ( we_i    ),
        .A_REN        ( ~we_i   ),
        .A_DIN        ( wdata_i ),
        .A_DOUT       ( rdata_o ),
        // BIST disabled
        .A_BIST_CLK   (  1'b0 ),
        .A_BIST_ADDR  (  8'd0 ),
        .A_BIST_DIN   ( 32'd0 ),
        .A_BIST_BM    ( 32'd0 ),
        .A_BIST_MEN   (  1'b0 ),
        .A_BIST_WEN   (  1'b0 ),
        .A_BIST_REN   (  1'b0 ),
        .A_BIST_EN    (  1'b0 )
      );
    end else if (NumWords == 8192) begin // 32KiB
    RM_IHPSG13_1P_8192x32_c4 sram_i (
        .A_CLK        ( clk_i   ),
        .A_DLY        (  1'b1   ),
        .A_ADDR       ( addr_i  ),
        .A_MEN        ( req_i   ),
        .A_WEN        ( we_i    ),
        .A_REN        ( ~we_i   ),
        .A_DIN        ( wdata_i ),
        .A_DOUT       ( rdata_o )
      );
    end else begin
      $error("Unsupported NumWords value: %0d", NumWords); // Simulation check: stop if NumWords is unsupported
    end
  endgenerate

endmodule // sram_wrapper
