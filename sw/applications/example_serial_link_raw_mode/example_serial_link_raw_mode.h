// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Description: Shared definitions for the Serial Link raw mode test application.
//              Included by main.c only, not a general-purpose header.
//
// Compile-time flags :
//   FPGA_RECEIVE  1 = receiver board, 0 = sender board  (FPGA only)



#ifndef EXAMPLE_SERIAL_LINK_RAW_MODE_H
#define EXAMPLE_SERIAL_LINK_RAW_MODE_H

// 1 = receiver board, 0 = sender board
#define FPGA_RECEIVE 1

#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   1

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

// Single channel config
#define RAW_MODE_CH_SEL   0
#define RAW_MODE_CH_MASK  0x1

#if TARGET_SIM
    // 0x06000 = SL_REG_START_ADDRESS offset, see tb/testharness_pkg.sv
    #define EXT_SLAVE_LENGTH          0x400
    #define SL_EXT_REG_BASE           (EXT_PERIPHERAL_START_ADDRESS + 0x06000)
    #define SL_EXTERNAL_WRITE         ((volatile int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH))
    #define SL_EXTERNAL_CTRL_REG_ADDR ((volatile uint32_t *)(SL_EXT_REG_BASE + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET))
    #define SL_EXTERNAL_RAW_WRITE     ((volatile uint32_t *)(SL_EXT_REG_BASE + SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_REG_OFFSET))
    #define SL_EXT_REG_PTR            ((volatile uint32_t *)SL_EXT_REG_BASE)

    static inline void sl_ext_raw_mode_enable(void) {
        *SL_EXTERNAL_CTRL_REG_ADDR |= (1u << SERIAL_LINK_SINGLE_CHANNEL_CTRL_AXI_IN_ISOLATE_BIT);
        *SL_EXTERNAL_CTRL_REG_ADDR |= (1u << SERIAL_LINK_SINGLE_CHANNEL_CTRL_AXI_OUT_ISOLATE_BIT);
        SL_EXT_REG_PTR[SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_CH_MASK_REG_OFFSET/4] = RAW_MODE_CH_MASK;
        SL_EXT_REG_PTR[SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_EN_REG_OFFSET/4]          = 1u;
        SL_EXT_REG_PTR[SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_EN_REG_OFFSET/4]      = 1u;
    }

    static inline void sl_ext_raw_mode_disable(void) {
        SL_EXT_REG_PTR[SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_EN_REG_OFFSET/4] = 0u;
        SL_EXT_REG_PTR[SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_EN_REG_OFFSET/4]     = 0u;
        *SL_EXTERNAL_CTRL_REG_ADDR &= ~(1u << SERIAL_LINK_SINGLE_CHANNEL_CTRL_AXI_IN_ISOLATE_BIT);
        *SL_EXTERNAL_CTRL_REG_ADDR &= ~(1u << SERIAL_LINK_SINGLE_CHANNEL_CTRL_AXI_OUT_ISOLATE_BIT);
    }
#endif

// Sync for FPGA bidirectional coordination
#define SYNC_ADDR   0x00007F00
#define READY       0x00000001

// Test data : 8-bit words since raw mode transfers 2 * NumLanes = 2 * 4 = 8 bits
#define NUM_WORDS 8
const uint8_t test_data[NUM_WORDS] = {
    0x11, 0x22, 0x33, 0x44,
    0x55, 0x66, 0x77, 0x88
};

// AXI test data to verify link restored after raw mode
#define NUM_AXI_WORDS 4
const int32_t axi_test_data[NUM_AXI_WORDS] = {
    0x11111111, 0x22222222, 0x33333333, 0x44444444
};

static uint8_t raw_buffer[NUM_WORDS] __attribute__((aligned(4))) = {0};
static uint32_t axi_buffer[NUM_AXI_WORDS] __attribute__((aligned(4))) = {0};


#endif // EXAMPLE_SERIAL_LINK_RAW_MODE_H