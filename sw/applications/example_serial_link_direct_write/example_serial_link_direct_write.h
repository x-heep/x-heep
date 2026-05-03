// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Description: Shared definitions for the Serial Link test application.
//              Included by main.c only, not a general-purpose header.
//
// Compile-time flags :
//   FPGA_RECEIVE  1 = receiver board, 0 = sender board  (FPGA only)


#ifndef EXAMPLE_SERIAL_LINK_DIRECT_WRITE_H
#define EXAMPLE_SERIAL_LINK_DIRECT_WRITE_H

// 1 = receiver board, 0 = sender board (FPGA only)
#define FPGA_RECEIVE 1

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

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

#define NUM_WORDS                   4
const int32_t test_data[NUM_WORDS] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};

static uint32_t dma_buffer[NUM_WORDS] __attribute__((aligned(4))) = {0};

// Simulation only
#if TARGET_SIM
    #define EXT_SLAVE_LENGTH   0x400   
    #define SL_EXTERNAL_WRITE           (volatile int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH)
    #define SL_EXTERNAL_CTRL_REG_ADDR   (int32_t *)(EXT_PERIPHERAL_START_ADDRESS + 0x06000 + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
    #define SL_EXTERNAL_DIRECT_WRITE    (int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH + DIRECT_WRITE_TARGET_ADDR)
#endif

#endif // EXAMPLE_SERIAL_LINK_DIRECT_WRITE_H