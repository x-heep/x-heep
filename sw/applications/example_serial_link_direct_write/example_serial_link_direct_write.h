// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Description: Shared definitions for the Serial Link test application.
//              Included by main.c only, not a general-purpose header.
//
// Compile-time flags :
//   FPGA_RECEIVE  1 = receiver board, 0 = sender board  (FPGA only)
//   PERF_EVAL     1 = performance evaluation mode (FPGA only),  0 = functional test (default)
//
// Note : for TARGET_SIM you need at least 3 ram_banks 

#ifndef EXAMPLE_SERIAL_LINK_DIRECT_WRITE_H
#define EXAMPLE_SERIAL_LINK_DIRECT_WRITE_H

#include <stdio.h>
#include <stdlib.h>

// 1 = receiver board, 0 = sender board (FPGA only)
#define FPGA_RECEIVE 1

// 1 = performance evaluation (FPGA only), 0 = functional test 
#define PERF_EVAL 0

#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   1

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

#define DIRECT_WRITE_TARGET_ADDR    0x0000F800
#define SYNC_ADDR                   0x00007F00
#define READY                       0x00000001

#define MAX_WORDS   32
#define NUM_WORDS   4   // used by the functional test

static uint32_t dma_buffer[NUM_WORDS] __attribute__((aligned(4))) = {0};

// Simulation-only address aliases (functional test only)
#if TARGET_SIM && !PERF_EVAL
    #define EXT_SLAVE_LENGTH            0x400
    #define SL_EXTERNAL_WRITE           (volatile int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH)
    #define SL_EXTERNAL_CTRL_REG_ADDR   (int32_t *)(EXT_PERIPHERAL_START_ADDRESS + 0x06000 + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
    #define SL_EXTERNAL_DIRECT_WRITE    (int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH + DIRECT_WRITE_TARGET_ADDR)
#endif

#if PERF_EVAL
    const int test_sizes[] = {1, 4, 8, 16, 32};
    #define NUM_SIZES 5
    #define TEST_DATA_SIZE  MAX_WORDS
#else
    #define TEST_DATA_SIZE  NUM_WORDS
#endif

const int32_t test_data[TEST_DATA_SIZE] = {
    0x11111111, 0x22222222, 0x33333333, 0x44444444,
#if TEST_DATA_SIZE > 4
    0x55555555, 0x66666666, 0x77777777, 0x88888888,
    0x99999999, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC,
    0xDDDDDDDD, 0xEEEEEEEE, 0xFFFFFFFF, 0x12345678,
    0x11111111, 0x22222222, 0x33333333, 0x44444444,
    0x55555555, 0x66666666, 0x77777777, 0x88888888,
    0x99999999, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC,
    0xDDDDDDDD, 0xEEEEEEEE, 0xFFFFFFFF, 0x12345678,
#endif
};

#endif // EXAMPLE_SERIAL_LINK_DIRECT_WRITE_H