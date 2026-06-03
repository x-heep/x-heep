// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Description: Shared definitions for the Serial Link performance application.
//              Included by main.c only, not a general-purpose header.
//
// Compile-time flags :
//   FPGA_RECEIVE  1 = receiver board, 0 = sender board  (FPGA only)

#ifndef EXAMPLE_SERIAL_LINK_PERFORMANCE_H
#define EXAMPLE_SERIAL_LINK_PERFORMANCE_H

// 1 = receiver board, 0 = sender board 
#define FPGA_RECEIVE 1

#define PRINTF_IN_FPGA  1

#if PRINTF_IN_FPGA 
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

#define DIRECT_WRITE_TARGET_ADDR    0x0000F800
#define MAX_WORDS                   32

const int32_t test_data[MAX_WORDS] = {
    0x11111111, 0x22222222, 0x33333333, 0x44444444,
    0x55555555, 0x66666666, 0x77777777, 0x88888888,
    0x99999999, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC,
    0xDDDDDDDD, 0xEEEEEEEE, 0xFFFFFFFF, 0x12345678,
    0x11111111, 0x22222222, 0x33333333, 0x44444444,
    0x55555555, 0x66666666, 0x77777777, 0x88888888,
    0x99999999, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC,
    0xDDDDDDDD, 0xEEEEEEEE, 0xFFFFFFFF, 0x12345678
};

// Word counts to test
const int test_sizes[] = {1, 4, 8, 16, 32};
#define NUM_SIZES 5

#endif // EXAMPLE_SERIAL_LINK_PERFORMANCE_H
