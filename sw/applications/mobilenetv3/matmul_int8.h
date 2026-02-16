// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#ifndef _MATMUL_INT8_H_
#define _MATMUL_INT8_H_

#include <stdint.h>
#include "mobilenet_config.h"

/* ============================================
 *    Matrix Multiplication (INT8 SIMD)
 * ============================================
 * 
 * Using Quadrilatero mmaqa.b instruction:
 * - Multiplies 4 packed int8 values simultaneously
 * - Accumulates into int32
 * - K dimension must be multiple of 4
 */

// 8x8 tiled matmul using Quadrilatero
void matmul_8x8_int8(
    int8_t* addrA,      // Weights: M x K (int8, K packed by 4)
    int8_t* addrB,      // Im2col: K x N (int8, transposed)
    int32_t* addrC,     // Output: M x N (int32 accumulator)
    int K,              // Inner dimension (divided by 4 for SIMD)
    int N,              // Output columns
    int M               // Output rows
);

// 4x4 tiled matmul for smaller tiles
void matmul_4x4_int8(
    int8_t* addrA,
    int8_t* addrB,
    int32_t* addrC,
    int K,
    int N,
    int M
);

// Scalar fallback for non-aligned dimensions
void matmul_scalar_int8(
    const int8_t* A,
    const int8_t* B,
    int32_t* C,
    int M, int K, int N
);

#endif /* _MATMUL_INT8_H_ */