// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#ifndef _IM2COL_H_
#define _IM2COL_H_

#include <stdint.h>
#include "mobilenet_config.h"

/* ============================================
 *         Im2col Transformation
 * ============================================
 * 
 * Converts convolution to matrix multiplication by
 * rearranging input patches into columns.
 */

// Im2col producing int8 output for convolution
void im2col_int8(
    const int8_t* input,    // Input tensor (C_in x H_in x W_in) as int8
    int8_t* col_buffer,     // Output column buffer (K x N) as int8
    int C_in,
    int H_in, int W_in,
    int K,                  // Kernel size (KxK)
    int stride,
    int pad,
    int H_out, int W_out
);

// Pad K dimension to multiple of 4 for SIMD
static inline int pad_k_dimension(int K_original) {
    return ((K_original + SIMD_FACTOR - 1) / SIMD_FACTOR) * SIMD_FACTOR;
}

#endif /* _IM2COL_H_ */