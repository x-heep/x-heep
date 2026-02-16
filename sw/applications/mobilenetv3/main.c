// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include <stdio.h>
#include <stdlib.h>
#include "csr.h"
#include "x-heep.h"

#include "mobilenet_config.h"
#include "model_data.h"
#include "conv2d.h"
#include "activations.h"

/* Workspace buffers */
static int32_t INTERLEAVED_SECTION conv_output_int32[MAX_OUTPUT_C * MAX_INPUT_H * MAX_INPUT_W / 4];
static float INTERLEAVED_SECTION activation_buffer[MAX_OUTPUT_C * MAX_INPUT_H * MAX_INPUT_W / 4];
static int8_t INTERLEAVED_SECTION next_layer_input[MAX_OUTPUT_C * MAX_INPUT_H * MAX_INPUT_W / 4];

int main() {
    uint32_t errors = 0;
    unsigned int cycles_start, cycles_end;
    
    // Enable mcycle counter
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    CSR_WRITE(CSR_REG_MCYCLE, 0);
    
    PRINTF("MobileNetV3 Tiled Convolution Test\n\r");
    PRINTF("==================================\n\r");
    PRINTF("Configuration:\n\r");
    PRINTF("  - Weights: int8 (SIMD factor: %d)\n\r", SIMD_FACTOR);
    PRINTF("  - Accumulator: int32\n\r");
    PRINTF("  - Activations: fp32\n\r");
    PRINTF("  - Tile size: %dx%d\n\r", TILE_SIZE_M, TILE_SIZE_N);
    
    // Example: Test first conv layer
    // TODO: Add actual test with model weights from model_data.h
    
    CSR_READ(CSR_REG_MCYCLE, &cycles_end);
    PRINTF("\n\rTotal cycles: %d\n\r", cycles_end);
    PRINTF("Test completed with %d errors\n\r", errors);
    
    return errors;
}