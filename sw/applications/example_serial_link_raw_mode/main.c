// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Description: Test application for Serial Link Raw Mode.
//              Demonstrates no-protocol 8-bit word transfers over the
//              DDR physical layer, bypassing AXI framing entirely.
//              Also verifies AXI mode is correctly restored after raw mode.

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "core_v_mini_mcu.h"
#include "serial_link.h"
#include "serial_link_single_channel_regs.h"
#include "serial_link_regs.h"
#include "serial_link_xheep_wrapper_driver.h"
#include "pad_control.h"
#include "pad_control_regs.h"

// 1 = receiver board, 0 = sender board
#define FPGA_RECEIVE 1

#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

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

int main(int argc, char *argv[]) {

    // PAD MUX configuration
    pad_control_t pad_control;
    pad_control.base_addr = mmio_region_from_addr((uintptr_t)PAD_CONTROL_START_ADDRESS);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_1_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_2_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_3_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_6_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_7_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_8_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_9_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_10_REG_OFFSET), 1);

    sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);

    int errors = 0;

#if FPGA_RECEIVE
    // =========================================================================
    // FPGA RECEIVER
    // =========================================================================
    PRINTF("=== Serial Link Raw Mode Test (RECEIVE) ===\n");

    // --- Test 1: Raw mode receive ---
    PRINTF("--- Test 1: Raw mode ---\n");
    sl_raw_mode_enable(RAW_MODE_CH_SEL, RAW_MODE_CH_MASK);

    sl_raw_mode_recv(raw_buffer, NUM_WORDS);

    for (int i = 0; i < NUM_WORDS; i++) {
        if (raw_buffer[i] != test_data[i]) {
            PRINTF("RAW ERROR [%d]: got 0x%04x expected 0x%04x\n",
                   i, raw_buffer[i], test_data[i]);
            errors++;
        } else {
            PRINTF("RAW OK [%d]: 0x%04x\n", i, raw_buffer[i]);
        }
    }

    sl_raw_mode_disable();

    // --- Test 2: AXI mode after raw mode ---
    // Verifies sl_raw_mode_disable() correctly restores the AXI link
    PRINTF("--- Test 2: AXI mode after raw mode ---\n");
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);

    sl_wrapper_direct_write(SYNC_ADDR, READY);

    sl_dma_read(axi_buffer, (uint32_t *)SL_READ, NUM_AXI_WORDS);

    for (int i = 0; i < NUM_AXI_WORDS; i++) {
        if (axi_buffer[i] != (uint32_t)axi_test_data[i]) {
            PRINTF("AXI ERROR [%d]: got 0x%08x expected 0x%08x\n",
                   i, axi_buffer[i], axi_test_data[i]);
            errors++;
        } else {
            PRINTF("AXI OK [%d]: 0x%08x\n", i, axi_buffer[i]);
        }
    }

    if (errors == 0) {
        PRINTF("\nDONE - All tests passed\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("\nFAILED - %d errors\n", errors);
        return EXIT_FAILURE;
    }

#else
    // =========================================================================
    // FPGA SENDER
    // =========================================================================
    PRINTF("=== Serial Link Raw Mode Test (SEND) ===\n");
    
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
    volatile uint32_t *ready = (volatile uint32_t *)SYNC_ADDR;

    // --- Test 1: Raw mode send ---
    PRINTF("--- Test 1: Raw mode ---\n");
    sl_raw_mode_enable(RAW_MODE_CH_SEL, RAW_MODE_CH_MASK);

    sl_raw_mode_send((uint8_t *)test_data, NUM_WORDS);
    for (int i = 0; i < NUM_WORDS; i++) {
        PRINTF("RAW sent [%d]: 0x%04x\n", i, test_data[i]);
    }

    sl_raw_mode_disable();

    // Wait for receiver to signal raw mode test done before sending AXI data
    while (*ready != READY);
    *ready = 0;

    // --- Test 2: AXI mode after raw mode ---
    PRINTF("--- Test 2: AXI mode after raw mode ---\n");
    for (int i = 0; i < NUM_AXI_WORDS; i++) {
        *SL_WRITE = axi_test_data[i];
        PRINTF("AXI sent [%d]: 0x%08x\n", i, axi_test_data[i]);
    }

    PRINTF("\nDONE\n");
    return EXIT_SUCCESS;
#endif
}