// Copyright 2026 Politecnico di Torino
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module sram_wrapper #(
    parameter int unsigned NumWords = 32'd1024,  // Number of Words in data array
    parameter int unsigned DataWidth = 32'd32,  // Data signal width
    // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
    parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1
) (
    input  logic clk_i,
    input  logic rst_ni,
    // input ports
    input  logic req_i,
    input  logic we_i,
    input  logic [AddrWidth-1:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic [3:0] be_i,
    input  logic pwrgate_ni,
    output logic pwrgate_ack_no,
    input  logic set_retentive_ni,
    // output ports
    output logic [31:0] rdata_o
);

    // Power gating not supported
    assign pwrgate_ack_no = pwrgate_ni;

    // Assemble bit mask
    logic [DataWidth-1:0] bm;
    for (genvar b = 0; b < DataWidth; ++b) begin : gen_bm_bits
        assign bm[b] = be_i[b/8];
    end

    generate
        if (DataWidth != 32) begin
            $error("Bank size not implemented.");
        end
        if (NumWords == 256) begin // 1KiB
            (* keep, blackbox *)
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
                .A_BIST_ADDR  (  '0   ),
                .A_BIST_DIN   (  '0   ),
                .A_BIST_BM    (  '0   ),
                .A_BIST_MEN   (  1'b0 ),
                .A_BIST_WEN   (  1'b0 ),
                .A_BIST_REN   (  1'b0 ),
                .A_BIST_EN    (  1'b0 )
            );
        end else if (NumWords == 512) begin // 2KiB
            (* keep, blackbox *)
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
                .A_BIST_ADDR  (  '0   ),
                .A_BIST_DIN   (  '0   ),
                .A_BIST_BM    (  '0   ),
                .A_BIST_MEN   (  1'b0 ),
                .A_BIST_WEN   (  1'b0 ),
                .A_BIST_REN   (  1'b0 ),
                .A_BIST_EN    (  1'b0 )
            );
        end else if (NumWords == 1024) begin // 4KiB
            (* keep, blackbox *)
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
                .A_BIST_ADDR  (  '0   ),
                .A_BIST_DIN   (  '0   ),
                .A_BIST_BM    (  '0   ),
                .A_BIST_MEN   (  1'b0 ),
                .A_BIST_WEN   (  1'b0 ),
                .A_BIST_REN   (  1'b0 ),
                .A_BIST_EN    (  1'b0 )
            );
        end else if (NumWords == 2048 || NumWords == 4096 || NumWords == 8192) begin : gen_sram_1024_split // 8KiB, 16KiB, 32KiB
            // 1024x32 macros: the PDK has no 2048x32, and its 8192x32 has no byte mask

            localparam int unsigned NumMacros = NumWords / 1024;
            localparam int unsigned SelWidth  = $clog2(NumMacros);

            logic [SelWidth-1:0]        bank_sel;
            logic [SelWidth-1:0]        bank_sel_q;
            logic [NumMacros-1:0][31:0] rdata_macro;

            assign bank_sel = addr_i[AddrWidth-1:10];

            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (!rst_ni) bank_sel_q <= '0;
                else if (req_i) bank_sel_q <= bank_sel;
            end

            assign rdata_o = rdata_macro[bank_sel_q];

            for (genvar i = 0; i < NumMacros; i++) begin : gen_macro
                (* keep, blackbox *)
                RM_IHPSG13_1P_1024x32_c2_bm_bist sram_i (
                    .A_CLK        ( clk_i          ),
                    .A_DLY        (  1'b1          ),
                    .A_ADDR       ( addr_i[9:0]    ),
                    .A_BM         ( bm             ),
                    .A_MEN        ( req_i & (bank_sel == SelWidth'(i)) ),
                    .A_WEN        ( we_i           ),
                    .A_REN        ( ~we_i          ),
                    .A_DIN        ( wdata_i        ),
                    .A_DOUT       ( rdata_macro[i] ),
                    // BIST disabled
                    .A_BIST_CLK   (  1'b0 ),
                    .A_BIST_ADDR  (  '0   ),
                    .A_BIST_DIN   (  '0   ),
                    .A_BIST_BM    (  '0   ),
                    .A_BIST_MEN   (  1'b0 ),
                    .A_BIST_WEN   (  1'b0 ),
                    .A_BIST_REN   (  1'b0 ),
                    .A_BIST_EN    (  1'b0 )
                );
            end
        end else begin
            $error("Unsupported NumWords value: %0d", NumWords);
        end
    endgenerate

endmodule
