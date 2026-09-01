// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Test pattern generator: turns a pixel coordinate into a colour.
//
// Purely combinational and deliberately free of multipliers and dividers, so it
// costs almost nothing and cannot limit the pixel clock.

module hdmi_pattern #(
    parameter int unsigned HActive = 640,
    parameter int unsigned VActive = 480
) (
    input logic [11:0] hpos_i,
    input logic [11:0] vpos_i,
    input logic [ 1:0] pattern_i,
    input logic [23:0] color_i,    // {red, green, blue}, used by pattern 3

    output logic [7:0] red_o,
    output logic [7:0] green_o,
    output logic [7:0] blue_o
);

  localparam int unsigned BarWidth = HActive / 8;

  // ------------------------------------------------------------ colour bars
  logic [2:0] bar;
  logic [7:0] bar_r, bar_g, bar_b;

  // A chain of comparators against the bar boundaries. HActive/8 is not a power
  // of two for 640, so this is cheaper than dividing.
  always_comb begin
    bar = 3'd0;
    for (int unsigned i = 1; i < 8; i++) begin
      if (hpos_i >= 12'(i * BarWidth)) bar = 3'(i);
    end
  end

  always_comb begin
    unique case (bar)
      3'd0:    {bar_r, bar_g, bar_b} = {8'hFF, 8'hFF, 8'hFF};  // white
      3'd1:    {bar_r, bar_g, bar_b} = {8'hFF, 8'hFF, 8'h00};  // yellow
      3'd2:    {bar_r, bar_g, bar_b} = {8'h00, 8'hFF, 8'hFF};  // cyan
      3'd3:    {bar_r, bar_g, bar_b} = {8'h00, 8'hFF, 8'h00};  // green
      3'd4:    {bar_r, bar_g, bar_b} = {8'hFF, 8'h00, 8'hFF};  // magenta
      3'd5:    {bar_r, bar_g, bar_b} = {8'hFF, 8'h00, 8'h00};  // red
      3'd6:    {bar_r, bar_g, bar_b} = {8'h00, 8'h00, 8'hFF};  // blue
      default: {bar_r, bar_g, bar_b} = {8'h00, 8'h00, 8'h00};  // black
    endcase
  end

  // ------------------------------------------------------- checkerboard frame
  // A one-pixel red border around the visible area makes it obvious whether the
  // monitor is showing the whole frame or overscanning it.
  logic border;
  logic check;

  assign border = (hpos_i == 12'd0) || (hpos_i == 12'(HActive - 1)) ||
                  (vpos_i == 12'd0) || (vpos_i == 12'(VActive - 1));
  assign check = hpos_i[5] ^ vpos_i[5];  // 32x32 squares

  // ------------------------------------------------------------------ select
  always_comb begin
    unique case (pattern_i)
      2'd0: begin
        red_o   = bar_r;
        green_o = bar_g;
        blue_o  = bar_b;
      end
      2'd1: begin
        // XOR texture: every output bit depends on both coordinates, so a stuck
        // or swapped address bit shows up immediately.
        red_o   = hpos_i[7:0];
        green_o = vpos_i[7:0];
        blue_o  = hpos_i[7:0] ^ vpos_i[7:0];
      end
      2'd2: begin
        red_o   = border ? 8'hFF : (check ? 8'hFF : 8'h00);
        green_o = border ? 8'h00 : (check ? 8'hFF : 8'h00);
        blue_o  = border ? 8'h00 : (check ? 8'hFF : 8'h00);
      end
      default: begin
        red_o   = color_i[23:16];
        green_o = color_i[15:8];
        blue_o  = color_i[7:0];
      end
    endcase
  end

endmodule  // hdmi_pattern
