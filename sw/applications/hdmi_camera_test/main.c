// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Camera -> HDMI DMA bridge.
//
// Bridges the camera peripheral's live pixel stream straight into the HDMI
// PIXEL window via DMA: source is the camera's DATA window, destination is
// hdmi_peri->PIXEL, both fixed (non-incrementing) addresses. No CPU touches
// individual pixels, and there is no frame buffer anywhere in the path --
// both windows are simple bus-backpressured FIFOs (camera_window.sv /
// hdmi_window.sv), so the DMA transfer naturally paces itself to whichever
// side is slower. This works as a single DMA transaction with both targets
// set to DMA_TRIG_MEMORY (fixed addresses standing in for peripherals, not
// real trigger slots), the same way each side already works on its own in
// sw/applications/camera and hdmi_camera_test's earlier DMA-fed test image.
//
// The camera is natively 640x480, matching HDMI's active area exactly, so
// hdmi_pixel_stream.sv pushes one word per screen pixel with no replication
// (see that file). It still flushes any stale FIFO contents every HDMI
// frame, so the picture won't progressively drift/scroll even when this
// loop's timing doesn't line up with the frame boundary -- each burst just
// resumes wherever the previous one left off relative to the screen raster.
//
// Known caveats, both pre-existing and orthogonal to this bridge:
//  - camera_if.sv currently has UseTestPattern hardcoded on, so what
//    actually streams through right now is a free-running counter
//    (0xA9A8A7A6, ...), not real sensor pixels, until that capture path is
//    finished and verified against real camera hardware. Through this
//    bridge that shows up as a slow sweep of colour across the screen,
//    which at least proves data is flowing end to end.
//  - camera_if.sv also doesn't yet convert whatever pixel format the real
//    sensor produces (e.g. RGB565, 2 bytes/pixel) into the 0x00RRGGBB the
//    PIXEL window expects: that repacking has to be added before real
//    sensor data will show correct colours here.
//  - Moving a full 640x480 frame one 32-bit word at a time over a 15 MHz
//    bus is nowhere near the bandwidth real-time video needs; expect the
//    picture to update slowly (a fraction of a frame per DMA burst) rather
//    than smoothly, until a wider/bulkier transfer path replaces this
//    word-at-a-time bridge.

#include <stdint.h>
#include <stdio.h>

#include "camera_regs.h"
#include "camera_structs.h"
#include "dma.h"
#include "hdmi_regs.h"
#include "hdmi_structs.h"
#include "x-heep.h"

#ifndef CAMERA_IS_INCLUDED
#error ("This app does NOT work as the CAMERA peripheral is not included")
#endif

#ifndef HDMI_IS_INCLUDED
#error ("This app does NOT work as the HDMI peripheral is not included")
#endif

#define HDMI_PATTERN_STREAM 4

#define IMG_COLS 640
#define IMG_ROWS 480
#define IMG_PIXELS (IMG_COLS * IMG_ROWS)

int main(void) {
  printf("=== Camera -> HDMI DMA bridge ===\n");
  printf("640x480, one word per pixel, no frame buffer\n");

  hdmi_peri->CTRL = (1 << HDMI_CTRL_EN_BIT) |
                    (HDMI_PATTERN_STREAM << HDMI_CTRL_PATTERN_OFFSET);

  camera_peri->CONTROL |= (0x1 << CAMERA_CONTROL_START_BIT);

  dma_init(NULL);

  static dma_target_t tgt_src = {
      .ptr = (uint8_t *)((uintptr_t)camera_peri + CAMERA_DATA_REG_OFFSET),
      .inc_d1_du = 0,  // fixed address: every read drains the camera's FIFO
      .trig      = DMA_TRIG_MEMORY,
      .type      = DMA_DATA_TYPE_WORD,
  };
  static dma_target_t tgt_dst = {
      .ptr       = (uint8_t *)&hdmi_peri->PIXEL,
      .inc_d1_du = 0,  // fixed address: every word pushes into the same FIFO
      .trig      = DMA_TRIG_MEMORY,
  };
  static dma_trans_t trans = {
      .src        = &tgt_src,
      .dst        = &tgt_dst,
      .size_d1_du = IMG_PIXELS,
      .mode       = DMA_TRANS_MODE_SINGLE,
      .win_du     = 0,
      .end        = DMA_TRANS_END_POLLING,
  };

  // Returning lets the runtime stop the core, and any reset after that
  // clears CTRL and blanks the screen, so this loops forever instead.
  for (;;) {
    dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    dma_load_transaction(&trans);
    dma_launch(&trans);
    while (!dma_is_ready(0));
  }
}
