// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Author: Tim Frey <tim.frey@epfl.ch>, EPFL, STI-SEL
// Date: 13.02.2023
// Description: I2s WS (word select) signal generation

// Adapted from github.com/pulp-platform/udma_i2s/blob/master/rtl/i2s_ws_gen.sv 
// by Antonio Pullini (pullinia@iis.ee.ethz.ch)

module i2s_ws_gen #(
    parameter MaxWordWidth = 32,
    localparam int unsigned CounterWidth = $clog2(MaxWordWidth)
) (
    input logic sck_i,
    input logic rst_ni,
    input logic en_i,

    output logic ws_o,

    input logic [CounterWidth-1:0] word_width_i  // must not be changed while en_i = 1
);

  logic [CounterWidth-1:0] r_counter;
  logic ws;

  assign ws_o = en_i & ws;

  always_ff @(posedge sck_i, negedge rst_ni) begin
    if (~rst_ni) begin
      r_counter <= 'h0;
    end else begin
      if (en_i) begin
        if (r_counter == word_width_i) r_counter <= 'h0;
        else r_counter <= r_counter + 1;
      end else begin
        r_counter <= 0;
      end
    end
  end

  //Generate the internal WS signal
  always_ff @(negedge sck_i, negedge rst_ni) begin
    if (~rst_ni) begin
      ws <= 1'b0;
    end else begin
      if (en_i) begin
        if (r_counter == word_width_i) ws <= ~ws;
      end else begin
        ws <= 0;
      end
    end
  end


endmodule : i2s_ws_gen
