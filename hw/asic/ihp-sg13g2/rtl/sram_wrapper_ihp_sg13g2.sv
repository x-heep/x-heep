// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// IHP-SG13G2 SRAM bank, on byte-maskable macros (BIST disabled).
// Banks of 2048 words or more use 64-bit macros with two words per row, the
// address LSB selecting the half: the PDK 8192x32 macro has no byte mask, and
// two 2048x64 macros take ~5% more area than it (eight 1024x32 take ~20%).

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

  logic [31:0] bm;
  assign bm = {{8{be_i[3]}}, {8{be_i[2]}}, {8{be_i[1]}}, {8{be_i[0]}}};

  // 64-bit macros: write data in both halves, byte mask on the addressed one
  logic [63:0] din64, bm64, dout64;
  assign din64 = {wdata_i, wdata_i};
  assign bm64  = addr_i[0] ? {bm, 32'b0} : {32'b0, bm};

  // Address of the last request, to pick the read data
  logic [AddrWidth-1:0] addr_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) addr_q <= '0;
    else if (req_i) addr_q <= addr_i;
  end

  // The SRAM macros have no RTL: the flows read them from the PDK
  // verilator lint_off MODMISSING
  if (DataWidth != 32) begin : gen_width_error
    $error("Bank size not implemented.");
  end

  if (NumWords == 256) begin : gen_256x32
    (* keep *)
    RM_IHPSG13_1P_256x32_c2_bm_bist sram_inst (
        .A_CLK      (clk_i),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_ADDR     (addr_i),
        .A_DIN      (wdata_i),
        .A_DLY      (1'b1),
        .A_DOUT     (rdata_o),
        .A_BM       (bm),
        .A_BIST_CLK (1'b0),
        .A_BIST_EN  (1'b0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_ADDR('0),
        .A_BIST_DIN ('0),
        .A_BIST_BM  ('0)
    );
  end else if (NumWords == 512) begin : gen_512x32
    (* keep *)
    RM_IHPSG13_1P_512x32_c2_bm_bist sram_inst (
        .A_CLK      (clk_i),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_ADDR     (addr_i),
        .A_DIN      (wdata_i),
        .A_DLY      (1'b1),
        .A_DOUT     (rdata_o),
        .A_BM       (bm),
        .A_BIST_CLK (1'b0),
        .A_BIST_EN  (1'b0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_ADDR('0),
        .A_BIST_DIN ('0),
        .A_BIST_BM  ('0)
    );
  end else if (NumWords == 1024) begin : gen_1024x32
    (* keep *)
    RM_IHPSG13_1P_1024x32_c2_bm_bist sram_inst (
        .A_CLK      (clk_i),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_ADDR     (addr_i),
        .A_DIN      (wdata_i),
        .A_DLY      (1'b1),
        .A_DOUT     (rdata_o),
        .A_BM       (bm),
        .A_BIST_CLK (1'b0),
        .A_BIST_EN  (1'b0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_ADDR('0),
        .A_BIST_DIN ('0),
        .A_BIST_BM  ('0)
    );
  end else if (NumWords == 2048) begin : gen_1024x64
    (* keep *)
    RM_IHPSG13_1P_1024x64_c2_bm_bist sram_inst (
        .A_CLK      (clk_i),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_ADDR     (addr_i[10:1]),
        .A_DIN      (din64),
        .A_DLY      (1'b1),
        .A_DOUT     (dout64),
        .A_BM       (bm64),
        .A_BIST_CLK (1'b0),
        .A_BIST_EN  (1'b0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_ADDR('0),
        .A_BIST_DIN ('0),
        .A_BIST_BM  ('0)
    );
    assign rdata_o = addr_q[0] ? dout64[63:32] : dout64[31:0];
  end else if (NumWords % 4096 == 0) begin : gen_2048x64
    // One 2048x64 macro per 4096 words, selected by the address MSBs
    localparam int unsigned NumMacros = NumWords / 4096;

    logic [63:0] dout_macro[NumMacros];

    for (genvar i = 0; i < NumMacros; i++) begin : gen_macro
      (* keep *)
      RM_IHPSG13_1P_2048x64_c2_bm_bist sram_inst (
          .A_CLK      (clk_i),
          .A_MEN      (req_i && (addr_i >> 12) == i),
          .A_WEN      (we_i),
          .A_REN      (~we_i),
          .A_ADDR     (addr_i[11:1]),
          .A_DIN      (din64),
          .A_DLY      (1'b1),
          .A_DOUT     (dout_macro[i]),
          .A_BM       (bm64),
          .A_BIST_CLK (1'b0),
          .A_BIST_EN  (1'b0),
          .A_BIST_MEN (1'b0),
          .A_BIST_WEN (1'b0),
          .A_BIST_REN (1'b0),
          .A_BIST_ADDR('0),
          .A_BIST_DIN ('0),
          .A_BIST_BM  ('0)
      );
    end

    assign dout64  = dout_macro[addr_q>>12];
    assign rdata_o = addr_q[0] ? dout64[63:32] : dout64[31:0];
  end else begin : gen_size_error
    $error("Unsupported NumWords value: %0d", NumWords);
  end
  // verilator lint_on MODMISSING

endmodule
