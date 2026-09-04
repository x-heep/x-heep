// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module i2s_microphone (
    input logic rst_ni,

    // i2s interface ports
    input logic i2s_sck_i,
    input logic i2s_ws_i,

    // output ports
    output logic i2s_sd_o
);

  logic [31:0] left;
  logic [31:0] right;
  logic [31:0] data;

  logic [5:0] bit_count;
  logic s_ws;
  logic r_ws;
  logic sd;

  assign s_ws = i2s_ws_i;

  assign left = 32'h8765431;
  assign right = 32'hfedcba9;
  assign data = s_ws == 1'b0 ? left : right;
  assign i2s_sd_o = sd;

  always_ff @(posedge i2s_sck_i or negedge rst_ni) begin
    if (~rst_ni) begin
      bit_count <= 0;
      r_ws <= 0;
    end else begin
      if (s_ws != r_ws) begin
        bit_count <= 0;
        r_ws <= s_ws;
      end else begin
        bit_count <= bit_count + 1;
      end
    end
  end

  always_ff @(negedge i2s_sck_i) begin
    sd <= data[31-bit_count];  // MSB first
  end

endmodule
