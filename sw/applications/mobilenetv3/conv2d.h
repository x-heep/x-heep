// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#ifndef _CONV2D_H_
#define _CONV2D_H_

#include <stdint.h>
#include "mobilenet_config.h"

/* ============================================
 *    Tiled Convolution Functions
 * ============================================ */

// Standard convolution (e.g., 3x3, 5x5)
void conv2d_tiled_int8(
    const int8_t* input,        // Input: C_in x H_in x W_in (int8)
    const int8_t* weights,      // Weights: C_out x (C_in x K x K) (int8, padded)
    int32_t* output,            // Output: C_out x H_out x W_out (int32)
    int C_in, int H_in, int W_in,
    int C_out,
    int K,
    int stride,
    int pad
);

// Pointwise (1x1) convolution
void pointwise_conv2d_int8(
    const int8_t* input,        // C_in x H x W (int8)
    const int8_t* weights,      // C_out x C_in (int8, padded)
    int32_t* output,            // C_out x H x W (int32)
    int C_in, int C_out,
    int H, int W
);

// Depthwise convolution
void depthwise_conv2d_int8(
    const int8_t* input,        // C x H_in x W_in (int8)
    const int8_t* weights,      // C x K x K (int8)
    int32_t* output,            // C x H_out x W_out (int32)
    int C, int H_in, int W_in,
    int K,
    int stride,
    int pad
);

#endif /* _CONV2D_H_ */