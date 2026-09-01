// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Video timing generator. Defaults are 640x480@60 (VESA DMT), which needs a
// 25.175 MHz pixel clock; 25.000 MHz gives 59.5 Hz and is accepted by every
// monitor we know of.
//
// The line is laid out as: active pixels, front porch, sync, back porch.

module hdmi_timing #(
    parameter int unsigned HActive  = 640,
    parameter int unsigned HFront   = 16,
    parameter int unsigned HSyncLen = 96,
    parameter int unsigned HBack    = 48,

    parameter int unsigned VActive  = 480,
    parameter int unsigned VFront   = 10,
    parameter int unsigned VSyncLen = 2,
    parameter int unsigned VBack    = 33
) (
    input logic clk_i,
    input logic rst_ni,

    // Position of the pixel currently on the outputs. Only meaningful when de_o
    // is high.
    output logic [11:0] hpos_o,
    output logic [11:0] vpos_o,

    output logic de_o,
    output logic hsync_o,
    output logic vsync_o
);

  localparam int unsigned HTotal = HActive + HFront + HSyncLen + HBack;
  localparam int unsigned VTotal = VActive + VFront + VSyncLen + VBack;

  localparam int unsigned HSyncStart = HActive + HFront;
  localparam int unsigned HSyncEnd = HSyncStart + HSyncLen;
  localparam int unsigned VSyncStart = VActive + VFront;
  localparam int unsigned VSyncEnd = VSyncStart + VSyncLen;

  logic [11:0] hcnt, vcnt;
  logic line_end;

  assign line_end = (hcnt == 12'(HTotal - 1));

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      hcnt <= '0;
      vcnt <= '0;
    end else if (line_end) begin
      hcnt <= '0;
      vcnt <= (vcnt == 12'(VTotal - 1)) ? 12'd0 : vcnt + 12'd1;
    end else begin
      hcnt <= hcnt + 12'd1;
    end
  end

  assign hpos_o  = hcnt;
  assign vpos_o  = vcnt;

  assign de_o    = (hcnt < 12'(HActive)) && (vcnt < 12'(VActive));

  // Active-high sync pulses. On a digital link the control tokens carry "sync
  // asserted", so the negative polarity that 640x480@60 uses on analog VGA does
  // not apply here.
  assign hsync_o = (hcnt >= 12'(HSyncStart)) && (hcnt < 12'(HSyncEnd));
  assign vsync_o = (vcnt >= 12'(VSyncStart)) && (vcnt < 12'(VSyncEnd));

endmodule  // hdmi_timing
