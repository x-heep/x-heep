// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#ifndef _MODEL_DATA_H_
#define _MODEL_DATA_H_

#include <stdint.h>
#include "mobilenet_config.h"

/* ============================================
 *    MobileNetV3 Model Weights (INT8)
 * ============================================
 * 
 * Weight layout for Quadrilatero int8 SIMD:
 * - Weights stored as int8
 * - K dimension padded to multiple of 4 for SIMD
 * - Each 32-bit load brings 4 consecutive int8 values
 * 
 * Conv weights: (C_out, C_in*K*K) row-major, K dim padded
 * Depthwise:    (C, K*K) row-major
 * Pointwise:    (C_out, C_in) row-major, C_in padded
 */

/* Quantization parameters */
typedef struct {
    float scale;        // Quantization scale
    int8_t zero_point;  // Zero point for asymmetric quantization
} QuantParams;

/* Example: First conv layer 3x3, 3->16 channels
 * K_original = 3 * 3 * 3 = 27
 * K_padded = 28 (next multiple of 4)
 * Shape: (16, 28)
 */
#define CONV1_C_IN      3
#define CONV1_C_OUT     16
#define CONV1_K         3
#define CONV1_K_DIM     PAD_K(CONV1_C_IN * CONV1_K * CONV1_K)  // 28

INTERLEAVED_SECTION
extern const int8_t conv1_weights[CONV1_C_OUT * CONV1_K_DIM];

extern const QuantParams conv1_quant;

/* Batch norm parameters (fp32) */
extern const float conv1_bn_gamma[CONV1_C_OUT];
extern const float conv1_bn_beta[CONV1_C_OUT];
extern const float conv1_bn_mean[CONV1_C_OUT];
extern const float conv1_bn_var[CONV1_C_OUT];  // Stored as 1/sqrt(var+eps)

/* ============================================
 *    Example Inverted Residual Block
 * ============================================ */

// Block 1: 16 -> expand 64 -> depthwise 3x3 -> project 24
#define IR1_C_IN        16
#define IR1_C_EXP       64
#define IR1_C_OUT       24
#define IR1_K           3

// Expansion 1x1: (64, 16) -> padded to (64, 16)
#define IR1_EXP_K_DIM   PAD_K(IR1_C_IN)  // 16
INTERLEAVED_SECTION
extern const int8_t ir1_exp_weights[IR1_C_EXP * IR1_EXP_K_DIM];

// Depthwise 3x3: (64, 9) 
#define IR1_DW_K_DIM    (IR1_K * IR1_K)  // 9
INTERLEAVED_SECTION
extern const int8_t ir1_dw_weights[IR1_C_EXP * IR1_DW_K_DIM];

// Projection 1x1: (24, 64) -> padded to (24, 64)
#define IR1_PROJ_K_DIM  PAD_K(IR1_C_EXP)  // 64
INTERLEAVED_SECTION
extern const int8_t ir1_proj_weights[IR1_C_OUT * IR1_PROJ_K_DIM];

// Quantization for each sublayer
extern const QuantParams ir1_exp_quant;
extern const QuantParams ir1_dw_quant;
extern const QuantParams ir1_proj_quant;

#endif /* _MODEL_DATA_H_ */