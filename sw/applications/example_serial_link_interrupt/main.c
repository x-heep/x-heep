// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Description: Example application to test the Serial Link FIFO and Direct Write interrupt.
//              In FIFO mode, when the Serial Link FIFO is not empty, the DMA transfers 
//              data from the FIFO to RAM. Once the expected number of words has been 
//              received, the DMA generates an interrupt to notify the CPU.
//              In Direct Write mode, incoming writes trigger a PLIC interrupt
//              once the expected number of words has been received.
//              The CPU is free to do other work while waiting for data.

#include <stdio.h>
#include <stdlib.h>
#include "csr.h"
#include "hart.h"
#include "handler.h"
#include "core_v_mini_mcu.h"
#include "dma.h"
#include "serial_link_single_channel_regs.h"
#include "serial_link_regs.h"
#include "serial_link.h"
#include "serial_link_xheep_wrapper_driver.h"
#include "serial_link_sdk.h"
#include "pad_control.h"
#include "pad_control_regs.h"
#include "rv_plic.h"
#include "example_serial_link_interrupt.h"

void handler_irq_sl_direct_write(uint32_t id) {
    sl_wrapper_direct_write_intr_flag = 1;
    plic_irq_set_enabled(SERIAL_LINK_DIRECT_WRITE_ID, kPlicToggleDisabled);
}

int main(int argc, char *argv[]) {

    sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);

#if TARGET_SIM
    // =========================================================================
    // SIMULATION: single board loopback test
    // =========================================================================

    sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR,
            (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);

    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
    dma_config_flags_t res = sl_wrapper_dma_read_launch(dma_buffer, NUM_WORDS);
    if (res != DMA_CONFIG_OK) {
        //PRINTF("DMA launch failed: %d\n", res);
        return EXIT_FAILURE;
    }

    for (int i = 0; i < NUM_WORDS; i++) {
        *SL_EXTERNAL_WRITE = test_data[i];
    }

    while (!sl_wrapper_dma_intr_flag) {
        wait_for_interrupt();
    }
    sl_wrapper_dma_intr_flag = 0;

    int errors = 0;
    for (int i = 0; i < NUM_WORDS; i++) {
        if (dma_buffer[i] != (uint32_t)test_data[i]) {
            errors++;
        } 
    }

    for (int i = 0; i < NUM_WORDS; i++)
        ((volatile uint32_t *)DIRECT_WRITE_TARGET_ADDR)[i] = 0;

    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);

    sl_wrapper_direct_write_arm(NUM_WORDS);

    for (int i = 0; i < NUM_WORDS; i++) {
        *((volatile int32_t *)SL_EXTERNAL_DIRECT_WRITE + i) = test_data[i];
    }

    while (!sl_wrapper_direct_write_intr_flag) {
        wait_for_interrupt();
    }
    sl_wrapper_direct_write_intr_flag = 0;

    for (int i = 0; i < NUM_WORDS; i++) {
        int32_t rcv = ((volatile int32_t *)DIRECT_WRITE_TARGET_ADDR)[i];
        if (rcv != test_data[i]) {
            errors++;
        } 
    }

    if (errors == 0) {
        PRINTF("DONE - All tests passed\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("FAILED\n");
        //PRINTF("FAILED - %d errors\n", errors);
        return EXIT_FAILURE;
    }

#elif FPGA_RECEIVE
    // =========================================================================
    // FPGA RECEIVER
    // =========================================================================

    PRINTF("=== Serial Link FIFO Interrupt Test (RECEIVE) ===\n");
    int32_t rcv_data;

    // Test 1: FIFO mode
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);

    dma_config_flags_t res = sl_wrapper_dma_read_launch(dma_buffer, NUM_WORDS); 
    if (res != DMA_CONFIG_OK) {
        PRINTF("DMA launch failed: %d\n", res);
        return EXIT_FAILURE;
    }

    while (!sl_wrapper_dma_intr_flag) {
        wait_for_interrupt();
    }
    sl_wrapper_dma_intr_flag = 0;

    int errors = 0;
    for (int i = 0; i < NUM_WORDS; i++) {
        if (dma_buffer[i] != (uint32_t)test_data[i]) {
            PRINTF("FIFO ERROR [%d]: got 0x%08x expected 0x%08x\n",
                   i, dma_buffer[i], test_data[i]);
            errors++;
        } else {
            PRINTF("FIFO OK [%d]: 0x%08x\n", i, dma_buffer[i]);
        }
    }

    // Test 2: Direct write mode
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);

    for (int i = 0; i < NUM_WORDS; i++)
        ((volatile uint32_t *)DIRECT_WRITE_TARGET_ADDR)[i] = 0;

    sl_wrapper_direct_write_arm(NUM_WORDS);

    sl_wrapper_direct_write(SYNC_ADDR, READY);

    while (!sl_wrapper_direct_write_intr_flag) {
        wait_for_interrupt();
    }
    sl_wrapper_direct_write_intr_flag = 0;

    for (int i = 0; i < NUM_WORDS; i++) {
        rcv_data = ((volatile int32_t *)DIRECT_WRITE_TARGET_ADDR)[i];
        if (rcv_data != test_data[i]) {
            PRINTF("DIRECT WRITE ERROR [%d]: got 0x%08x expected 0x%08x\n",
                i, rcv_data, test_data[i]);
            errors++;
        } else {
            PRINTF("DIRECT WRITE OK [%d]: 0x%08x\n", i, rcv_data);
        }
    }

    if (errors == 0) {
        PRINTF("DONE - All tests passed\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("FAILED - %d errors\n", errors);
        return EXIT_FAILURE;
    }

#else
    // =========================================================================
    // FPGA SENDER
    // =========================================================================
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
    volatile uint32_t *ready = (volatile uint32_t *)SYNC_ADDR;
    
    PRINTF("=== Serial Link FIFO Interrupt Test (SEND) ===\n");

    // Test 1: FIFO mode
    for (int i = 0; i < NUM_WORDS; i++) {
        *SL_WRITE = test_data[i];
        PRINTF("FIFO Sent [%d]: 0x%08x\n", i, test_data[i]);
    }

    while(*ready != READY);
    *ready = 0; 
   
    // Test 2: Direct write mode
    for (int i = 0; i < NUM_WORDS; i++) {
        sl_wrapper_direct_write(DIRECT_WRITE_TARGET_ADDR + i * 4, (uint32_t)test_data[i]);
        PRINTF("Direct write sent [%d]: 0x%08x\n", i, test_data[i]);
    }

    PRINTF("DONE\n");
    return EXIT_SUCCESS;
#endif
}