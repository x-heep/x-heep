// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "core_v_mini_mcu.h"
#include "x-heep.h"

#define TEST_DATA_SIZE 16

/* By default, PRINTs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

#if TARGET_SIM && PRINTF_IN_SIM
        #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif


// Register map (32-bit word offsets) of the HLS-generated 'dot_product'
// CTRL AXI4-Lite port, from hw/fpga/hls/vitis/dot_product's generated
// dot_product_CTRL_s_axi.v (standard Vitis HLS ap_ctrl_hs + s_axilite
// layout: AP_CTRL @0x00, a @0x10/0x14, b @0x1c/0x20, size @0x28,
// result @0x30/0x34). Base address defined in testharness_pkg.sv as
// DOT_PRODUCT_CTRL_START_ADDRESS = EXT_SLAVE_START_ADDRESS + 0x20000.
//
// 'a'/'b' are 64-bit registers in hardware (Vitis HLS derives the m_axi
// pointer width from the host's native 64-bit pointers), but X-HEEP only
// has a 32-bit address space. Only the low word (@0x10/@0x1c) is exposed
// here: the high word resets to 0 and nothing else ever writes it, so it
// stays 0 without software having to touch it -- the 64-bit-pointer detail
// is entirely internal to the accelerator, not visible from X-HEEP's side.
#define DOT_PRODUCT_CTRL_BASE_ADDRESS (EXT_SLAVE_START_ADDRESS + 0x20000)

#define DOT_PRODUCT_AP_CTRL_OFFSET (0x00 / 4)
#define DOT_PRODUCT_A_ADDR_OFFSET (0x10 / 4)
#define DOT_PRODUCT_B_ADDR_OFFSET (0x1c / 4)
#define DOT_PRODUCT_SIZE_OFFSET (0x28 / 4)
#define DOT_PRODUCT_RESULT_LO_OFFSET (0x30 / 4)
#define DOT_PRODUCT_RESULT_HI_OFFSET (0x34 / 4)

#define DOT_PRODUCT_AP_START (1u << 0)
#define DOT_PRODUCT_AP_DONE (1u << 1)

int main(int argc, char *argv[]) {
  static int32_t vec_a[TEST_DATA_SIZE] __attribute__((aligned(4)));
  static int32_t vec_b[TEST_DATA_SIZE] __attribute__((aligned(4)));

  int64_t expected = 0;
  for (int i = 0; i < TEST_DATA_SIZE; i++) {
    vec_a[i] = i + 1;
    vec_b[i] = TEST_DATA_SIZE - i;
    expected += (int64_t)vec_a[i] * (int64_t)vec_b[i];
  }

  volatile uint32_t *dot_product = (uint32_t *)DOT_PRODUCT_CTRL_BASE_ADDRESS;

  dot_product[DOT_PRODUCT_A_ADDR_OFFSET] = (uint32_t)(uintptr_t)&vec_a[0];
  dot_product[DOT_PRODUCT_B_ADDR_OFFSET] = (uint32_t)(uintptr_t)&vec_b[0];
  dot_product[DOT_PRODUCT_SIZE_OFFSET] = TEST_DATA_SIZE;

  // START
  dot_product[DOT_PRODUCT_AP_CTRL_OFFSET] = DOT_PRODUCT_AP_START;

  // UNTIL DONE
  while ((dot_product[DOT_PRODUCT_AP_CTRL_OFFSET] & DOT_PRODUCT_AP_DONE) == 0);

  int64_t result = (int64_t)dot_product[DOT_PRODUCT_RESULT_LO_OFFSET] |
                    ((int64_t)dot_product[DOT_PRODUCT_RESULT_HI_OFFSET] << 32);

  // X-HEEP's simulation printf doesn't support %lld, so split 64-bit
  // values into hi/lo 32-bit halves for display.
  if (result == expected) {
    PRINTF("Dot Product Accelerator Successful: 0x%08x%08x\n\r", (uint32_t)(result >> 32), (uint32_t)result);
    return EXIT_SUCCESS;
  } else {
    PRINTF("Dot Product Accelerator failure: got 0x%08x%08x, expected 0x%08x%08x\n\r", (uint32_t)(result >> 32),
           (uint32_t)result, (uint32_t)(expected >> 32), (uint32_t)expected);
    return EXIT_FAILURE;
  }
}
