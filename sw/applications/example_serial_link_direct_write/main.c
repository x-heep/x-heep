// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Description: Example application to test the Serial Link direct write mode.
//              Tests both FIFO mode and direct write mode. 

#include <stdio.h>
#include <stdlib.h>
#include "serial_link_single_channel_regs.h"
#include "serial_link_regs.h"
#include "serial_link.h"
#include "serial_link_xheep_wrapper_driver.h"
#include "core_v_mini_mcu.h"
#include "csr.h"
#include "pad_control.h"
#include "pad_control_regs.h"
#include "example_serial_link_direct_write.h"

int main(int argc, char *argv[]) {

    // PAD MUX configuration
    pad_control_t pad_control;
    pad_control.base_addr = mmio_region_from_addr((uintptr_t)PAD_CONTROL_START_ADDRESS);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_1_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_2_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_3_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_6_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_7_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_8_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_9_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_10_REG_OFFSET), 1);

    sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);
    
#if TARGET_SIM
    // =========================================================================
    // SIMULATION: single board loopback test
    // =========================================================================
    
    sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR,
            (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);

    int errors = 0;
    int32_t rcv_data;

    PRINTF("=== Serial Link MUX Mode Test (SIM) ===\n");

    // Test 1: FIFO mode
    volatile int32_t *addr_p_fifo   = SL_READ;
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
    for (int i = 0; i < NUM_WORDS; i++) {
        *SL_EXTERNAL_WRITE = test_data[i];
        rcv_data = *addr_p_fifo; 
        if (rcv_data != test_data[i]) {
            errors++;
        }
    }


    // Test 2: Direct write mode
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
    volatile int32_t *addr_p_direct = (volatile int32_t *)DIRECT_WRITE_TARGET_ADDR;
    volatile int32_t *addr_p_direct_send = SL_EXTERNAL_DIRECT_WRITE;
    for (int i = 0; i < NUM_WORDS; i++) addr_p_direct[i] = 0;

    for (int i = 0; i < NUM_WORDS; i++) {
        *(addr_p_direct_send + i) = test_data[i];
        rcv_data = addr_p_direct[i];
        if (rcv_data != test_data[i]) {
            errors++;
        }
    }

    // Test 3: FIFO mode with dma
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
    uint32_t to_send[NUM_WORDS];
    for (int i = 0; i < NUM_WORDS; i++) to_send[i] = test_data[i];
    sl_dma_send(to_send, (uint32_t *)SL_EXTERNAL_WRITE, NUM_WORDS);
    sl_dma_read(dma_buffer, (uint32_t *)SL_READ, NUM_WORDS);

    for (int i = 0; i < NUM_WORDS; i++) {
        if (dma_buffer[i] != (uint32_t)test_data[i]) {
            errors++;
        }
    }

    if (errors == 0) {
        PRINTF("\nDONE - All tests passed\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("\nFAILED - %d errors\n", errors);
        return EXIT_FAILURE;
    }

#elif FPGA_RECEIVE
    // =========================================================================
    // FPGA RECEIVER
    // =========================================================================
    int errors = 0;
    int32_t rcv_data;

    PRINTF("=== Serial Link MUX Mode Test (FPGA RECEIVE) ===\n");

    // Test 1: FIFO mode
    PRINTF("--- Test 1: FIFO mode ---\n");
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
    for (int i = 0; i < NUM_WORDS; i++) {
        rcv_data = *SL_READ;
        if (rcv_data != test_data[i]) {
            PRINTF("FIFO ERROR [%d]: got 0x%08x, expected 0x%08x\n", i, rcv_data, test_data[i]);
            errors++;
        } else {
            PRINTF("FIFO OK [%d]: 0x%08x\n", i, rcv_data);
        }
    }

    // Test 2: Direct write mode
    PRINTF("--- Test 2: Direct write mode ---\n");
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);

    sl_wrapper_direct_write(SYNC_ADDR, READY);

    for (int i = 0; i < NUM_WORDS; i++) {
        volatile uint32_t *target = (volatile uint32_t *)(DIRECT_WRITE_TARGET_ADDR + i * 4);
        *target = 0; // clear before waiting
        while(*target == 0); // poll until data arrives
        rcv_data = (int32_t)*target;
        if (rcv_data != test_data[i]) {
            PRINTF("DIRECT WRITE ERROR [%d]: got 0x%08x, expected 0x%08x\n", i, rcv_data, test_data[i]);
            errors++;
        } else {
            PRINTF("DIRECT WRITE OK [%d]: 0x%08x\n", i, rcv_data);
        }
    }

    // Test 3: FIFO mode with dma
    PRINTF("--- Test 3: FIFO mode with dma---\n");
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);

    sl_wrapper_direct_write(SYNC_ADDR, READY);
     
    for (int i = 0; i < NUM_WORDS; i++) dma_buffer[i] = 0;

    sl_dma_read(dma_buffer, (uint32_t *)SL_READ, NUM_WORDS);

    for (int i = 0; i < NUM_WORDS; i++) {
        if (dma_buffer[i] != (uint32_t)test_data[i]){
            PRINTF("FIFO WITH DMA ERROR [%d]: got 0x%08x, expected 0x%08x\n", i, dma_buffer[i], test_data[i]);
            errors++;
        } else {
            PRINTF("FIFO WITH DMA OK [%d]: 0x%08x\n", i, dma_buffer[i]);
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
    PRINTF("=== Serial Link MUX Mode Test (FPGA SEND) ===\n");

    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
    volatile uint32_t *ready = (volatile uint32_t *)SYNC_ADDR;

    // Test 1: FIFO mode
    PRINTF("--- Test 1: FIFO mode ---\n");
    for (int i = 0; i < NUM_WORDS; i++) {
        *SL_WRITE = test_data[i];
        PRINTF("FIFO sent [%d]: 0x%08x\n", i, test_data[i]);
    }

    while(*ready != READY);
    *ready = 0; // clear for next sync

    // Test 2: Direct write mode
    PRINTF("--- Test 2: Direct write mode ---\n");
    for (int i = 0; i < NUM_WORDS; i++) {
        sl_wrapper_direct_write(DIRECT_WRITE_TARGET_ADDR + i * 4, (uint32_t)test_data[i]);
        PRINTF("Direct write sent [%d]: 0x%08x\n", i, test_data[i]);
    }

    while(*ready != READY);
    *ready = 0; 

    // Test 3: FIFO mode with dma  
    PRINTF("--- Test 3: FIFO mode with dma---\n");
    sl_dma_send((uint32_t *)test_data, (uint32_t *)SL_WRITE, NUM_WORDS);
    for (int i = 0; i < NUM_WORDS; i++) {
        PRINTF("FIFO with dma sent [%d]: 0x%08x\n", i, test_data[i]);
    }

    PRINTF("\nDONE\n");
    return EXIT_SUCCESS;
#endif
}

