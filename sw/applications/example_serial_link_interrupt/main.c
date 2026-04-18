// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Description: Example application to test the Serial Link FIFO interrupt.
//              When data arrives in the Serial Link FIFO, an interrupt fires
//              and directly triggers a DMA transfer from the FIFO to RAM.
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
#include "pad_control.h"
#include "pad_control_regs.h"

#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   1

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

#define NUM_WORDS 4

// 1 = receiver board, 0 = sender board 
#define FPGA_RECEIVE 1

const int32_t test_data[NUM_WORDS] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};

// DMA destination buffer
static uint32_t dma_buffer[NUM_WORDS] __attribute__((aligned(4))) = {0};

// Simulation only
#if TARGET_SIM
    #define EXT_SLAVE_LENGTH            0x400
    #define SL_EXTERNAL_WRITE           (volatile int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH)
    #define SL_EXTERNAL_CTRL_REG_ADDR   (int32_t *)(EXT_PERIPHERAL_START_ADDRESS + 0x06000 + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
#endif

int main(int argc, char *argv[]) {

    // PAD MUX
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
    PRINTF("=== Serial Link FIFO Interrupt Test (SIM) ===\n");

    sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR,
            (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);

    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
    dma_config_flags_t res = sl_wrapper_dma_read_launch(dma_buffer, NUM_WORDS);
    if (res != DMA_CONFIG_OK) {
        PRINTF("DMA launch failed: %d\n", res);
        return EXIT_FAILURE;
    }

    for (int i = 0; i < NUM_WORDS; i++) {
        *SL_EXTERNAL_WRITE = test_data[i];
    }

    PRINTF("Waiting for DMA completion...\n");
    while (!sl_wrapper_dma_intr_flag) {
        wait_for_interrupt();
    }
    sl_wrapper_dma_intr_flag = 0;

    PRINTF("DMA complete! Verifying...\n");
    int errors = 0;
    for (int i = 0; i < NUM_WORDS; i++) {
        if (dma_buffer[i] != (uint32_t)test_data[i]) {
            PRINTF("ERROR [%d]: got 0x%08x expected 0x%08x\n",
                   i, dma_buffer[i], (uint32_t)test_data[i]);
            errors++;
        } else {
            PRINTF("OK [%d]: 0x%08x\n", i, dma_buffer[i]);
        }
    }

    if (errors == 0) {
        PRINTF("DONE - All tests passed\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("FAILED - %d errors\n", errors);
        return EXIT_FAILURE;
    }

#elif FPGA_RECEIVE
    // =========================================================================
    // FPGA RECEIVER
    // =========================================================================

    PRINTF("=== Serial Link FIFO Interrupt Test (RECEIVE) ===\n");

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

    PRINTF("DMA complete! Verifying data...\n");

    int errors = 0;
    for (int i = 0; i < NUM_WORDS; i++) {
        if (dma_buffer[i] != (uint32_t)test_data[i]) {
            PRINTF("ERROR [%d]: got 0x%08x expected 0x%08x\n",
                   i, dma_buffer[i], test_data[i]);
            errors++;
        } else {
            PRINTF("OK [%d]: 0x%08x\n", i, dma_buffer[i]);
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
    PRINTF("=== Serial Link FIFO Interrupt Test (SEND) ===\n");

    for (int i = 0; i < NUM_WORDS; i++) {
        *SL_WRITE = test_data[i];
        PRINTF("Sent [%d]: 0x%08x\n", i, test_data[i]);
    }

    PRINTF("DONE\n");
    return EXIT_SUCCESS;
#endif
}