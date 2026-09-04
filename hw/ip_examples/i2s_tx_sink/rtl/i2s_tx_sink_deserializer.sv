// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module i2s_tx_sink_deserializer #(
    parameter int unsigned WordWidth = 32,
    localparam int unsigned CounterWidth = $clog2(WordWidth),
    localparam logic [CounterWidth-1:0] WordLastBit = CounterWidth'(WordWidth - 1)
) (
    input logic sck_i,
    input logic rst_ni,
    input logic en_i,
    input logic ws_i,
    input logic sd_i,

    output logic [WordWidth-1:0] data_o,
    output logic                 data_valid_o
);

  logic                    r_ws_old;
  logic                    s_ws_edge;
  logic                    r_started;
  logic [CounterWidth-1:0] r_count_bit;
  logic [   WordWidth-1:0] r_shiftreg;
  logic [   WordWidth-1:0] s_shiftreg;

  assign s_ws_edge = ws_i ^ r_ws_old;

  always_comb begin
    s_shiftreg = r_shiftreg;
    if (r_started) begin
      s_shiftreg[WordLastBit-r_count_bit] = i2s_bit_to_logic(sd_i);
    end
  end

  always_ff @(posedge sck_i or negedge rst_ni) begin
    if (~rst_ni) begin
      r_ws_old     <= 1'b0;
      r_started    <= 1'b0;
      r_count_bit  <= '0;
      r_shiftreg   <= '0;
      data_o       <= '0;
      data_valid_o <= 1'b0;
    end else begin
      data_valid_o <= 1'b0;

      if (en_i) begin
        r_ws_old <= ws_i;

        if (s_ws_edge) begin
          if (r_started) begin
            data_o       <= s_shiftreg;
            data_valid_o <= 1'b1;
          end
          r_started   <= 1'b1;
          r_count_bit <= '0;
          r_shiftreg  <= '0;
        end else if (r_started) begin
          r_shiftreg <= s_shiftreg;
          if (r_count_bit < WordLastBit) begin
            r_count_bit <= r_count_bit + 1'b1;
          end
        end
      end else begin
        r_ws_old     <= ws_i;
        r_started    <= 1'b0;
        r_count_bit  <= '0;
        r_shiftreg   <= '0;
        data_o       <= '0;
        data_valid_o <= 1'b0;
      end
    end
  end

  function automatic logic i2s_bit_to_logic(input logic bit_i);
    if (bit_i === 1'b1) begin
      i2s_bit_to_logic = 1'b1;
    end else begin
      i2s_bit_to_logic = 1'b0;
    end
  endfunction

endmodule : i2s_tx_sink_deserializer
