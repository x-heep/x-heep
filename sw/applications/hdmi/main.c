// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// HDMI output smoke test.

#include <stdint.h>
#include <stdio.h>

#include "hdmi_regs.h"
#include "hdmi_structs.h"
#include "soc_ctrl.h"
#include "timer_sdk.h"
#include "x-heep.h"

#ifndef HDMI_IS_INCLUDED
#error ("This app does NOT work as the HDMI peripheral is not included")
#endif

/* By default, PRINTFs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA 1
#define PRINTF_IN_SIM 1

#if TARGET_SIM && PRINTF_IN_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#else
#define PRINTF(...)
#endif

#define HDMI_PATTERN_BARS 0
#define HDMI_PATTERN_XOR 1
#define HDMI_PATTERN_CHECKER 2
#define HDMI_PATTERN_SOLID 3

// How long each pattern stays on screen,
#define PATTERN_SECONDS 5
#define MEASURE_SECONDS 2

typedef struct {
  const char* name;
  uint32_t pattern;
  uint32_t color;  // only used by HDMI_PATTERN_SOLID
} hdmi_step_t;

static const hdmi_step_t steps[] = {
    {"colour bars", HDMI_PATTERN_BARS, 0},
    {"xor texture", HDMI_PATTERN_XOR, 0},
    {"checkerboard with border", HDMI_PATTERN_CHECKER, 0},
    {"solid red", HDMI_PATTERN_SOLID, 0xFF0000},
    {"solid green", HDMI_PATTERN_SOLID, 0x00FF00},
    {"solid blue", HDMI_PATTERN_SOLID, 0x0000FF},
};

#define NUM_STEPS (sizeof(steps) / sizeof(steps[0]))

static void hdmi_show(const hdmi_step_t* step) {
  // COLOR first, so the pixel side never latches a new pattern against a stale
  // colour. Both only take effect at the next vertical sync anyway.
  hdmi_peri->COLOR = step->color & HDMI_COLOR_RGB_MASK;
  hdmi_peri->CTRL =
      (1 << HDMI_CTRL_EN_BIT) |
      ((step->pattern & HDMI_CTRL_PATTERN_MASK) << HDMI_CTRL_PATTERN_OFFSET);
}

// Busy-waits on the cycle counter rather than using timer_wait_us, which parks
// the core in wfi and would need the timer interrupt wired up.
static void wait_cycles(uint32_t cycles) {
  uint32_t start = timer_get_cycles();
  while ((timer_get_cycles() - start) < cycles);
}

int main(void) {
  soc_ctrl_t soc_ctrl;
  soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);
  uint32_t freq_hz = soc_ctrl_get_frequency(&soc_ctrl);

  timer_cycles_init();
  timer_start();

  PRINTF("=== HDMI Test ===\n");
  PRINTF("system clock: %u Hz\n", freq_hz);

  // Get a picture up before doing anything else.
  hdmi_show(&steps[0]);

  // The frame counter lives in the bus clock domain but only advances on
  // vertical sync coming from the pixel domain. If it never moves, the pixel
  // clock is dead and nothing else is worth debugging.
#if TARGET_SIM
  // In simulation the pixel clock is tied to the bus clock, so one frame takes
  // 800*525 cycles. Wait for a couple of them rather than for real time.
  uint32_t measure_cycles = 2 * 800 * 525;
#else
  uint32_t measure_cycles = freq_hz * MEASURE_SECONDS;
#endif

  uint32_t frames_before = hdmi_peri->FRAME_CNT;
  wait_cycles(measure_cycles);
  uint32_t frames = hdmi_peri->FRAME_CNT - frames_before;

  PRINTF("frames in %u cycles: %u\n", measure_cycles, frames);

  if (frames == 0) {
    PRINTF("[ERROR] frame counter is stuck: no pixel clock\n");
    return -1;
  }

#if !TARGET_SIM
  PRINTF("refresh: ~%u Hz (expect ~59)\n", frames / MEASURE_SECONDS);
#endif

  uint32_t pattern_cycles = freq_hz * PATTERN_SECONDS;

  // On the board, cycle forever. Returning from main lets the runtime stop the
  // core, and any reset after that clears CTRL and blanks the screen, which
  // looks exactly like the display flickering to black.
  for (;;) {
    for (unsigned i = 0; i < NUM_STEPS; i++) {  // NUM_STEPS
      PRINTF("%s\n", steps[i].name);
      hdmi_show(&steps[i]);
#if TARGET_SIM
      wait_cycles(measure_cycles);
#else
      wait_cycles(pattern_cycles);
#endif
    }

#if TARGET_SIM
    break;
#endif
  }

  PRINTF("=== Test finished ===\n");
  return 0;
}