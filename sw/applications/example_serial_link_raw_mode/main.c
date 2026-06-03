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
#include "serial_link_sdk.h"
#include "pad_control.h"
#include "pad_control_regs.h"
#include "example_serial_link_raw_mode.h"

int main(int argc, char *argv[]) {

    sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);

    int errors = 0;

#if TARGET_SIM
    // =========================================================================
    // SIMULATION: single board loopback test
    // =========================================================================

    sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR,
            (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);

    //--- Test 1: Raw mode receive ---
    sl_raw_mode_enable(RAW_MODE_CH_SEL, RAW_MODE_CH_MASK);
    sl_ext_raw_mode_enable();

    for (int i = 0; i < NUM_WORDS; i++) {
        *SL_EXTERNAL_RAW_WRITE = test_data[i];
    }

    sl_raw_mode_recv(raw_buffer, NUM_WORDS);

    for (int i = 0; i < NUM_WORDS; i++) {
        if (raw_buffer[i] != test_data[i]) {
            errors++;
        }
    }

    sl_raw_mode_disable();
    sl_ext_raw_mode_disable(); 

    // --- Test 2: AXI mode after raw mode ---
    // Verifies sl_raw_mode_disable() correctly restores the AXI link
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);

    for (int i = 0; i < NUM_AXI_WORDS; i++) {
        *SL_EXTERNAL_WRITE = axi_test_data[i];
    }

    sl_dma_read(axi_buffer, (uint32_t *)SL_READ, NUM_AXI_WORDS);

    for (int i = 0; i < NUM_AXI_WORDS; i++) {
        if (axi_buffer[i] != (uint32_t)axi_test_data[i]) {
            errors++;
        }
    }

    if (errors == 0) {
        PRINTF("DONE - All tests passed\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("FAILED\n");
        return EXIT_FAILURE;
    }
#elif FPGA_RECEIVE
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