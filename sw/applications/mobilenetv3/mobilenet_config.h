// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#ifndef _MOBILENET_CONFIG_H_
#define _MOBILENET_CONFIG_H_

#include <stdint.h>

/* ============================================
 *         MobileNetV3 Configuration
 * ============================================ */

// Data types:
// - Weights: int8 (packed 4 per 32-bit word for SIMD)
// - MatMul accumulator: int32
// - Activations: fp32
typedef int8_t  weight_t;
typedef int32_t matmul_acc_t;
typedef float   activation_t;

// SIMD configuration for int8
#define SIMD_FACTOR     4       // 4 int8 values per 32-bit word
#define SIMD_SHIFT      0       // Shift for address calculation (int8: 0, int16: 1, int32: 2)

// Tile sizes for Quadrilatero (4x4 or 8x8 output tiles)
#define TILE_SIZE_M     8       // Output tile rows
#define TILE_SIZE_N     8       // Output tile cols  
#define TILE_SIZE_K     16      // Inner dimension tile (must be multiple of SIMD_FACTOR)

// Convolution parameters
#define MAX_INPUT_H     224
#define MAX_INPUT_W     224
#define MAX_INPUT_C     64
#define MAX_OUTPUT_C    128
#define MAX_KERNEL_SIZE 5

// Memory section for interleaved access
#define INTERLEAVED_SECTION __attribute__((section(".xheep_data_interleaved")))

// Helper macro to pad K dimension to multiple of 4
#define PAD_K(k) (((k) + 3) / 4 * 4)

/* Print configuration */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif TARGET_PYNQ_Z2 && PRINTF_IN_FPGA
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

#endif /* _MOBILENET_CONFIG_H_ */