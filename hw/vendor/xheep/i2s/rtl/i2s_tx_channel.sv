// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Description: I2S TX channel. Consumes one stream word on each WS edge and
// shifts it MSB first on the falling edge of SCK.

module i2s_tx_channel #(
    parameter  int unsigned MaxWordWidth = 32,
    localparam int unsigned CounterWidth = $clog2(MaxWordWidth)
) (
    input logic sck_i,
    input logic rst_ni,
    input logic en_i,
    input logic ws_i,

    // config
    input logic [CounterWidth-1:0] word_width_i,  // must not be changed while en_i = 1

    // TX stream input
    input  logic [MaxWordWidth-1:0] data_i,
    input  logic                    data_valid_i,
    output logic                    data_ready_o,

    output logic sd_o,
    output logic underflow_o,
    input  logic clear_underflow_i
);

  logic                    r_ws_old;
  logic                    s_ws_edge;
  logic                    r_started;
  logic                    r_have_word;
  logic [CounterWidth-1:0] r_count_bit;
  logic [MaxWordWidth-1:0] r_shiftreg;

  assign s_ws_edge = ws_i ^ r_ws_old;

  // Consume the next word exactly when a new left/right frame starts.
  assign data_ready_o = en_i & s_ws_edge;

  always_ff @(posedge sck_i or negedge rst_ni) begin
    if (~rst_ni) begin
      r_ws_old    <= 1'b0;
      r_started   <= 1'b0;
      r_have_word <= 1'b0;
      r_count_bit <= '0;
      r_shiftreg  <= '0;
    end else begin
      if (en_i) begin
        r_ws_old <= ws_i;

        if (s_ws_edge) begin
          r_started   <= 1'b1;
          r_count_bit <= '0;
          if (data_valid_i) begin
            r_shiftreg  <= data_i;
            r_have_word <= 1'b1;
          end else begin
            r_shiftreg  <= '0;
            r_have_word <= 1'b0;
          end
        end else if (r_started && (r_count_bit < word_width_i)) begin
          r_count_bit <= r_count_bit + 1'b1;
        end
      end else begin
        r_ws_old    <= ws_i;
        r_started   <= 1'b0;
        r_have_word <= 1'b0;
        r_count_bit <= '0;
        r_shiftreg  <= '0;
      end
    end
  end

  always_ff @(negedge sck_i or negedge rst_ni) begin
    if (~rst_ni) begin
      sd_o <= 1'b0;
    end else if (en_i && r_started && r_have_word) begin
      sd_o <= r_shiftreg[word_width_i-r_count_bit];
    end else begin
      sd_o <= 1'b0;
    end
  end

  always_ff @(posedge sck_i or negedge rst_ni) begin
    if (~rst_ni) begin
      underflow_o <= 1'b0;
    end else if (clear_underflow_i) begin
      underflow_o <= 1'b0;
    end else if (en_i && s_ws_edge && !data_valid_i) begin
      underflow_o <= 1'b1;
    end
  end

endmodule : i2s_tx_channel
