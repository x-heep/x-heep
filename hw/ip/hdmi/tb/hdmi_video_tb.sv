// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Self-checking testbench for the portable part of the HDMI video path.
//
// It drives a real 25 MHz pixel clock, which the main X-HEEP simulation cannot do
// (there the pixel clock is tied to the bus clock), and checks three things:
//
//   1. the timing generator produces exactly 800x525 with 640x480 visible;
//   2. every encoded word decodes back to the byte that went in, which is the
//      real test of the 8b/10b encoder since the transform has to be invertible;
//   3. the running disparity stays bounded across each active video period, which
//      is what the DC balancing stage exists to guarantee. A sign error there
//      shows up as a steady drift rather than as a single wrong pixel.
//
// Run it standalone, it does not need the rest of X-HEEP:
//


module hdmi_video_tb;

  timeunit 1ns; timeprecision 1ps;

  localparam int unsigned HActive = 640;
  localparam int unsigned HFront = 16;
  localparam int unsigned HSyncLen = 96;
  localparam int unsigned HBack = 48;

  localparam int unsigned VActive = 480;
  localparam int unsigned VFront = 10;
  localparam int unsigned VSyncLen = 2;
  localparam int unsigned VBack = 33;

  localparam int unsigned HTotal = HActive + HFront + HSyncLen + HBack;  // 800
  localparam int unsigned VTotal = VActive + VFront + VSyncLen + VBack;  // 525

  // 25 MHz. Time unit is 1 ns, so this is a period in nanoseconds.
  localparam real PclkPeriod = 40.0;

  // DVI bounds the disparity inside a video period to a handful of units; the
  // encoder restarts from zero at every blanking interval. Anything near this
  // limit means the balancing logic is not pulling back.
  localparam int DispLimit = 40;

  localparam int MaxReports = 20;

  logic pclk = 1'b0;
  logic rst_n = 1'b0;

  always #(PclkPeriod / 2.0) pclk = ~pclk;

  int errors = 0;

  // -------------------------------------------------------------------- DUTs
  logic [11:0] hpos, vpos;
  logic de, hsync, vsync;

  hdmi_timing #(
      .HActive (HActive),
      .HFront  (HFront),
      .HSyncLen(HSyncLen),
      .HBack   (HBack),
      .VActive (VActive),
      .VFront  (VFront),
      .VSyncLen(VSyncLen),
      .VBack   (VBack)
  ) dut_timing (
      .clk_i  (pclk),
      .rst_ni (rst_n),
      .hpos_o (hpos),
      .vpos_o (vpos),
      .de_o   (de),
      .hsync_o(hsync),
      .vsync_o(vsync)
  );

  logic [ 1:0] pattern = 2'd0;
  logic [23:0] color = 24'h00_00_00;
  logic [7:0] red, green, blue;

  hdmi_pattern #(
      .HActive(HActive),
      .VActive(VActive)
  ) dut_pattern (
      .hpos_i   (hpos),
      .vpos_i   (vpos),
      .pattern_i(pattern),
      .color_i  (color),
      .red_o    (red),
      .green_o  (green),
      .blue_o   (blue)
  );

  logic [9:0] tmds_ch0, tmds_ch1, tmds_ch2;

  hdmi_tmds_encoder enc_ch0 (
      .clk_i (pclk),
      .rst_ni(rst_n),
      .data_i(blue),
      .ctrl_i({vsync, hsync}),
      .de_i  (de),
      .tmds_o(tmds_ch0)
  );

  hdmi_tmds_encoder enc_ch1 (
      .clk_i (pclk),
      .rst_ni(rst_n),
      .data_i(green),
      .ctrl_i(2'b00),
      .de_i  (de),
      .tmds_o(tmds_ch1)
  );

  hdmi_tmds_encoder enc_ch2 (
      .clk_i (pclk),
      .rst_ni(rst_n),
      .data_i(red),
      .ctrl_i(2'b00),
      .de_i  (de),
      .tmds_o(tmds_ch2)
  );

  // ------------------------------------------------------------- TMDS decode
  // The exact inverse of the encoder: undo the output inversion, then undo the
  // XOR or XNOR chain.
  function automatic logic [7:0] tmds_decode(input logic [9:0] w);
    logic [8:0] q_m;
    logic [7:0] d;
    q_m[7:0] = w[9] ? ~w[7:0] : w[7:0];
    q_m[8]   = w[8];
    d[0]     = q_m[0];
    for (int i = 1; i < 8; i++) begin
      d[i] = q_m[8] ? (q_m[i] ^ q_m[i-1]) : ~(q_m[i] ^ q_m[i-1]);
    end
    return d;
  endfunction

  function automatic logic [9:0] control_token(input logic [1:0] c);
    case (c)
      2'b00:   return 10'b1101010100;
      2'b01:   return 10'b0010101011;
      2'b10:   return 10'b0101010100;
      default: return 10'b1010101011;
    endcase
  endfunction

  function automatic int word_disparity(input logic [9:0] w);
    int ones = 0;
    for (int i = 0; i < 10; i++) begin
      ones += w[i];
    end
    return 2 * ones - 10;
  endfunction

  task automatic report(input string msg);
    errors++;
    if (errors <= MaxReports) $error("%s", msg);
    if (errors == MaxReports) $display("  (further errors suppressed)");
  endtask

  // The encoder registers its output, so line the stimulus up by one cycle.
  logic de_d, hsync_d, vsync_d;
  logic [7:0] red_d, green_d, blue_d;
  logic valid_d = 1'b0;

  always_ff @(posedge pclk) begin
    de_d    <= de;
    hsync_d <= hsync;
    vsync_d <= vsync;
    red_d   <= red;
    green_d <= green;
    blue_d  <= blue;
    valid_d <= rst_n;
  end

  // ------------------------------------------------------------ encoder checks
  // Disparity is only accumulated across an active video period. The control
  // tokens are deliberately not DC balanced (the vsync token carries -2 every
  // pixel), so accumulating through blanking would drift by design and say
  // nothing about the encoder.
  int running_disp = 0;
  int worst_disp = 0;
  int next_disp = 0;

  always_ff @(posedge pclk) begin
    if (!rst_n) begin
      running_disp <= 0;
    end else if (valid_d) begin
      if (!de_d) begin
        // Blanking: the encoder restarts its own counter here, so follow suit.
        running_disp <= 0;

        if (tmds_ch0 !== control_token({vsync_d, hsync_d})) begin
          report($sformatf(
                 "ch0 control token wrong for {vs,hs}=%02b: got %010b", {vsync_d, hsync_d}, tmds_ch0
                 ));
        end
        if (tmds_ch1 !== control_token(2'b00)) begin
          report($sformatf("ch1 should idle on the 00 token, got %010b", tmds_ch1));
        end
        if (tmds_ch2 !== control_token(2'b00)) begin
          report($sformatf("ch2 should idle on the 00 token, got %010b", tmds_ch2));
        end
      end else begin
        next_disp = running_disp + word_disparity(tmds_ch0);
        running_disp <= next_disp;

        if (next_disp > worst_disp) worst_disp <= next_disp;
        else if (-next_disp > worst_disp) worst_disp <= -next_disp;

        if ((next_disp > DispLimit) || (next_disp < -DispLimit)) begin
          report($sformatf("running disparity ran away: %0d at (%0d,%0d)", next_disp, hpos, vpos));
        end

        if (tmds_decode(tmds_ch0) !== blue_d) begin
          report($sformatf(
                 "ch0 decode mismatch: sent %02h, got %02h (word %010b)",
                 blue_d,
                 tmds_decode(
                     tmds_ch0
                 ),
                 tmds_ch0
                 ));
        end
        if (tmds_decode(tmds_ch1) !== green_d) begin
          report($sformatf(
                 "ch1 decode mismatch: sent %02h, got %02h", green_d, tmds_decode(tmds_ch1)));
        end
        if (tmds_decode(tmds_ch2) !== red_d) begin
          report($sformatf("ch2 decode mismatch: sent %02h, got %02h", red_d, tmds_decode(tmds_ch2)
                 ));
        end
      end
    end
  end

  // ------------------------------------------------------------- timing checks
  task automatic check_eq(input string what, input int got, input int want);
    if (got != want) begin
      report($sformatf("%s: got %0d, expected %0d", what, got, want));
    end else begin
      $display("  ok  %-24s %0d", what, got);
    end
  endtask

  // Measures one whole frame, from one rising edge of vsync to the next. Samples
  // on the falling edge so every DUT output has settled.
  task automatic measure_frame(input int frame_num);
    int cycles = 0;
    int de_cycles = 0;
    int lines = 0;
    int vsync_cycles = 0;
    int hsync_width = 0;
    int max_hsync_width = 0;
    logic hsync_prev, vsync_prev;

    // Line up on the start of a frame.
    while (vsync !== 1'b0) @(negedge pclk);
    while (vsync !== 1'b1) @(negedge pclk);

    hsync_prev = hsync;
    vsync_prev = vsync;

    forever begin
      @(negedge pclk);
      cycles++;
      if (de) de_cycles++;
      if (vsync) vsync_cycles++;

      if (hsync && !hsync_prev) hsync_width = 1;
      else if (hsync) hsync_width++;
      else if (!hsync && hsync_prev) begin
        lines++;
        if (hsync_width > max_hsync_width) max_hsync_width = hsync_width;
      end

      if (vsync && !vsync_prev) break;  // start of the next frame

      hsync_prev = hsync;
      vsync_prev = vsync;
    end

    $display("frame %0d (pattern %0d):", frame_num, pattern);
    check_eq("cycles per frame", cycles, HTotal * VTotal);
    check_eq("visible pixels", de_cycles, HActive * VActive);
    check_eq("lines per frame", lines, VTotal);
    check_eq("hsync width", max_hsync_width, HSyncLen);
    check_eq("vsync cycles", vsync_cycles, VSyncLen * HTotal);
  endtask

  // ---------------------------------------------------------------- stimulus
  initial begin
    $display("=== HDMI video path testbench ===");
    $display("mode %0dx%0d, %0dx%0d total, %0.3f MHz pixel clock", HActive, VActive, HTotal,
             VTotal, 1000.0 / PclkPeriod);

    rst_n = 1'b0;
    repeat (10) @(posedge pclk);
    rst_n = 1'b1;

    // One frame per pattern. The XOR texture is the interesting one for the
    // encoder: it sweeps all 256 byte values, including the ones with the worst
    // disparity.
    for (int p = 0; p < 4; p++) begin
      pattern = p[1:0];
      color   = 24'hA5_3C_7E;
      measure_frame(p);
    end

    $display("worst disparity seen within a video period: %0d (limit %0d)", worst_disp, DispLimit);

    if (errors == 0) $display("=== PASS ===");
    else $display("=== FAIL: %0d error(s) ===", errors);

    $finish;
  end

  // Never let a broken timing generator hang the run: 12 frames is well past the
  // 4 the test needs.
  initial begin
    #(12.0 * VTotal * HTotal * PclkPeriod);
    $display("=== FAIL: timeout ===");
    $finish;
  end

endmodule  // hdmi_video_tb

