// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Pixel source for pattern 4: software (via DMA) pushes one 0x00RRGGBB word
// per screen pixel, in raster order (row-major, matching HActive x VActive
// 1:1 -- no replication, so this only makes sense at native resolution),
// through the PIXEL register window. There is deliberately no frame buffer
// here, only a shallow CDC FIFO between the bus and pixel clock domains,
// matching the same cdc_fifo_gray primitive camera_if.sv already uses for
// its own DATA window. Because there is no frame buffer, the whole frame has
// to be re-pushed roughly every 16ms (once per HDMI frame) or the picture
// starts showing stale pixels; a write to the window stalls while the FIFO
// is full, which is what paces a DMA transfer through it -- including one
// sourced directly from another peripheral's window, such as the camera's,
// with no CPU involvement per pixel.
//
// The pixel-domain side never stalls: video timing runs in real time and
// cannot pause for data. If a new pixel is due (every active hpos column)
// and the FIFO is empty, the previously displayed pixel is held instead of
// glitching.
//
// Without more, that "hold instead of stalling" behaviour is exactly what
// makes the picture drift: every time a pop finds the FIFO empty, the raster
// moves on to the next cell while the FIFO's next word is still the one that
// was meant for the cell that was just skipped. Every following word then
// lands one cell later than intended, forever, since nothing ever
// resynchronises: the picture visibly scrolls, a little more each frame.
//
// The fix is to flush any leftover words from the previous frame during the
// blanking gap, so each frame starts from a known-empty FIFO. This is a
// plain, always-safe pop (dst_ready_i), not a cross-domain reset: nothing
// analogous to cdc_fifo_gray_clearable's src/dst_clear_i handshake is
// needed. The drain window is a fixed, short number of pclk_i cycles right
// after the active area ends -- comfortably longer than it takes to flush a
// full FIFO (a handful of cycles), comfortably shorter than blanking itself
// (~26000 cycles) or than software can plausibly restart its DMA burst (bus
// round-trip plus several driver calls), so it only ever discards the
// outgoing frame's stale tail, never the incoming frame's first real pixel.

module hdmi_pixel_stream #(
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,
    parameter int unsigned FifoLogDepth = 4
) (
    // Bus clock domain: register window
    input  logic     clk_i,
    input  logic     rst_ni,
    input  reg_req_t win_i,
    output reg_rsp_t win_o,

    // Pixel clock domain: raster position
    input logic pclk_i,
    input logic pclk_rst_ni,
    input logic de_i,

    output logic [7:0] red_o,
    output logic [7:0] green_o,
    output logic [7:0] blue_o
);

  logic push_valid, push_ready;
  logic [31:0] push_data;

  hdmi_window #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) hdmi_window_i (
      .win_i,
      .win_o,
      .push_ready_i(push_ready),
      .push_valid_o(push_valid),
      .push_data_o (push_data)
  );

  logic pop_valid, pop_pop;
  logic [31:0] pop_data;

  cdc_fifo_gray #(
      .T(logic [31:0]),
      .LOG_DEPTH(FifoLogDepth)
  ) pixel_fifo_i (
      .src_clk_i  (clk_i),
      .src_rst_ni (rst_ni),
      .src_data_i (push_data),
      .src_valid_i(push_valid),
      .src_ready_o(push_ready),

      .dst_clk_i  (pclk_i),
      .dst_rst_ni (pclk_rst_ni),
      .dst_data_o (pop_data),
      .dst_valid_o(pop_valid),
      .dst_ready_i(pop_pop)
  );

  // A new pixel is due on every active-area cycle: 1:1 with the screen.
  logic advance;
  assign advance = de_i;

  // Drain whatever is left in the FIFO for a short window right after the
  // active area ends, so the next frame starts from empty. See the header
  // comment for why this window's length is safe.
  localparam int unsigned FifoDepth = 2 ** FifoLogDepth;
  localparam int unsigned DrainCycles = 4 * FifoDepth;
  localparam int unsigned DrainCntWidth = $clog2(DrainCycles + 1);

  logic de_q;
  logic [DrainCntWidth-1:0] drain_cnt;
  logic draining;

  assign draining = (drain_cnt != '0);

  always_ff @(posedge pclk_i or negedge pclk_rst_ni) begin
    if (!pclk_rst_ni) begin
      de_q      <= 1'b0;
      drain_cnt <= '0;
    end else begin
      de_q <= de_i;
      if (de_q && !de_i) drain_cnt <= DrainCntWidth'(DrainCycles);
      else if (draining) drain_cnt <= drain_cnt - 1'b1;
    end
  end

  assign pop_pop = pop_valid && (advance || draining);

  logic [23:0] held_pixel;

  always_ff @(posedge pclk_i or negedge pclk_rst_ni) begin
    if (!pclk_rst_ni) held_pixel <= 24'h0;
    else if (advance && pop_valid) held_pixel <= pop_data[23:0];
  end

  assign {red_o, green_o, blue_o} = held_pixel;

endmodule  // hdmi_pixel_stream
