// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Author: Tim Frey <tim.frey@epfl.ch>, EPFL, STI-SEL
// Date: 29.04.2023
// Description: Event Counter
//
// Overflow at custom limit

module event_counter #(
    parameter int unsigned WIDTH = 4
) (
    input  logic             clk_i,
    input  logic             rst_ni,
    input  logic             clear_i,    // synchronous clear
    input  logic             en_i,       // enable the counter
    input  logic [WIDTH-1:0] limit_i,    // set limit to trigger overflow
    output logic [WIDTH-1:0] q_o,
    output logic             overflow_o
);
  logic [WIDTH-1:0] counter_q, counter_d, counter_q_plus1;
  logic overlimit;

  assign counter_q_plus1 = counter_q + {{WIDTH - 1{1'b0}}, 1'b1};
  assign overlimit = (counter_q_plus1 >= limit_i);

  // counter overflowed if counter == limit
  assign overflow_o = en_i & overlimit;

  assign q_o = counter_q[WIDTH-1:0];

  always_comb begin
    counter_d = counter_q;

    if (clear_i | overflow_o) begin
      counter_d = '0;
    end else if (en_i) begin
      counter_d = counter_q_plus1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      counter_q <= '0;
    end else begin
      counter_q <= counter_d;
    end
  end
endmodule
