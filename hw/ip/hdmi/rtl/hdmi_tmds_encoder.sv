// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// TMDS channel encoder, as specified in DVI 1.0 section 3.2.3 (and reused
// unchanged by HDMI for video data periods).
//
// During an active pixel the 8 data bits are encoded in two steps: transition
// minimisation (XOR or XNOR chain, whichever produces fewer edges), then DC
// balancing driven by a running disparity counter. During blanking the encoder
// emits one of the four control tokens instead; those are deliberately
// transition-rich so the receiver can find the word boundary.
//
// The output is registered, adding one pixel-clock of latency. All three
// channels are identical so they stay aligned.

module hdmi_tmds_encoder (
    input logic clk_i,  // pixel clock
    input logic rst_ni,

    input logic [7:0] data_i,  // pixel component, used when de_i is high
    input logic [1:0] ctrl_i,  // {C1, C0}, used when de_i is low
    input logic       de_i,    // data enable: high inside the visible area

    output logic [9:0] tmds_o  // transmitted LSB first
);

  // ------------------------------------------------ Stage 1: fewer transitions
  logic [3:0] n1d;  // number of ones in data_i
  logic       use_xnor;
  logic [8:0] q_m;

  always_comb begin
    n1d = '0;
    for (int i = 0; i < 8; i++) begin
      n1d += {3'b000, data_i[i]};
    end
  end

  assign use_xnor = (n1d > 4'd4) || ((n1d == 4'd4) && (data_i[0] == 1'b0));

  // Continuous assignments rather than a loop inside always_comb: the chain
  // reads q_m[i-1] while producing q_m[i], so keeping it as pure dataflow
  // avoids any dependence on evaluation order.
  assign q_m[0]   = data_i[0];
  for (genvar i = 1; i < 8; i++) begin : gen_q_m
    assign q_m[i] = use_xnor ? ~(q_m[i-1] ^ data_i[i]) : (q_m[i-1] ^ data_i[i]);
  end
  assign q_m[8] = ~use_xnor;

  // ------------------------------------------------- Stage 2: DC balancing
  logic [3:0] n1q_m, n0q_m;

  always_comb begin
    n1q_m = '0;
    for (int i = 0; i < 8; i++) begin
      n1q_m += {3'b000, q_m[i]};
    end
  end

  assign n0q_m = 4'd8 - n1q_m;

  // Signed views of the population counts. Keeping these as explicitly signed
  // nets matters: a single unsigned operand would make the whole expression
  // unsigned and break the comparisons against a negative disparity.
  logic signed [5:0] n1_s, n0_s;
  logic signed [5:0] two_qm8, two_nqm8;

  assign n1_s     = signed'({2'b00, n1q_m});
  assign n0_s     = signed'({2'b00, n0q_m});
  assign two_qm8  = q_m[8] ? 6'sd2 : 6'sd0;
  assign two_nqm8 = q_m[8] ? 6'sd0 : 6'sd2;

  // Running disparity, in ones-minus-zeros. The encoding keeps it small; 8 bits
  // signed leaves plenty of headroom.
  logic signed [7:0] cnt_q, cnt_d;
  logic [9:0] tmds_d;

  always_comb begin
    if (!de_i) begin
      // Control period: fixed tokens, and the disparity restarts from zero for
      // the next video period.
      cnt_d = '0;
      unique case (ctrl_i)
        2'b00:   tmds_d = 10'b1101010100;
        2'b01:   tmds_d = 10'b0010101011;
        2'b10:   tmds_d = 10'b0101010100;
        default: tmds_d = 10'b1010101011;
      endcase
    end else if ((cnt_q == 8'sd0) || (n1q_m == n0q_m)) begin
      // No bias to correct: pick the inversion that keeps this word balanced.
      tmds_d = {~q_m[8], q_m[8], q_m[8] ? q_m[7:0] : ~q_m[7:0]};
      cnt_d  = q_m[8] ? (cnt_q + n1_s - n0_s) : (cnt_q + n0_s - n1_s);
    end else if (((cnt_q > 8'sd0) && (n1q_m > n0q_m)) || ((cnt_q < 8'sd0) && (n0q_m > n1q_m))) begin
      // Disparity and word pull the same way: invert to pull back.
      tmds_d = {1'b1, q_m[8], ~q_m[7:0]};
      cnt_d  = cnt_q + two_qm8 + n0_s - n1_s;
    end else begin
      tmds_d = {1'b0, q_m[8], q_m[7:0]};
      cnt_d  = cnt_q - two_nqm8 + n1_s - n0_s;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cnt_q  <= '0;
      tmds_o <= 10'b1101010100;  // the {C1,C0} = 00 control token
    end else begin
      cnt_q  <= cnt_d;
      tmds_o <= tmds_d;
    end
  end

endmodule  // hdmi_tmds_encoder
