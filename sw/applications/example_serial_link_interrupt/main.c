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
#define PRINTF_IN_SIM   0
#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

#define NUM_WORDS 4

#define FPGA_RECEIVE 1

#if TARGET_SIM
    #define EXT_SLAVE_LENGTH          0x400
    #define SL_EXTERNAL_WRITE         (volatile uint32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH)
    #define SL_EXTERNAL_CTRL_REG_ADDR (int32_t *)(EXT_PERIPHERAL_START_ADDRESS + 0x06000 + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
#endif

const int32_t test_data[NUM_WORDS] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};

// DMA destination buffer
static uint32_t dma_buffer[NUM_WORDS] __attribute__((aligned(4))) = {0};

volatile int8_t dma_intr_flag = 0;

void dma_intr_handler_trans_done(uint8_t channel) {
    dma_intr_flag = 1;
}

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
    // SIMULATION: simple DMA test without interrupts (RAM too small for PLIC+DMA+SL)
    // =========================================================================
    sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR,
            (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);

    uint32_t to_send[NUM_WORDS];
    for (int i = 0; i < NUM_WORDS; i++) to_send[i] = test_data[i];
    sl_dma_send(to_send, (uint32_t *)SL_EXTERNAL_WRITE, NUM_WORDS);
    sl_dma_read(dma_buffer, (uint32_t *)SL_READ, NUM_WORDS);

    int errors = 0;
    for (int i = 0; i < NUM_WORDS; i++) {
        if (dma_buffer[i] != (uint32_t)test_data[i]) {
            PRINTF("ERROR [%d]: got 0x%08x expected 0x%08x\n", i, dma_buffer[i], test_data[i]);
            errors++;
        }
    }
    if (errors == 0) PRINTF("DONE - All tests passed\n");
    else PRINTF("FAILED - %d errors\n", errors);
    return errors == 0 ? EXIT_SUCCESS : EXIT_FAILURE;

#elif FPGA_RECEIVE

    PRINTF("=== Serial Link FIFO HW-Triggered DMA Test (RECEIVE) ===\n");

    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);

    // Source: Serial Link FIFO read port
    static dma_target_t tgt_src = {
        .ptr        = (uint8_t *)SL_READ,
        .inc_d1_du  = 0,              // don't increment src (FIFO register)
        .type       = DMA_DATA_TYPE_WORD,
        .trig       = DMA_TRIG_SLOT_SL_FIFO_RX,
    };

    // Destination: RAM buffer
    static dma_target_t tgt_dst = {
        .ptr        = (uint8_t *)dma_buffer,
        .inc_d1_du  = 1,              // increment dst each word
        .type       = DMA_DATA_TYPE_WORD,
        .trig       = DMA_TRIG_MEMORY,
    };

    static dma_trans_t trans = {
        .src        = &tgt_src,
        .dst        = &tgt_dst,
        .size_d1_du = NUM_WORDS,
        .dim        = DMA_DIM_CONF_1D,
        .end        = DMA_TRANS_END_INTR,
        .channel    = 0,
    };

    // Enable global interrupts (needed for DMA done INTR_WAIT)
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);

    dma_init(NULL);

    dma_config_flags_t res;
    res = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN,
                                   DMA_PERFORM_CHECKS_INTEGRITY);
    if (res != DMA_CONFIG_OK) {
        PRINTF("DMA validate failed: %d\n", res);
        return EXIT_FAILURE;
    }

    res = dma_load_transaction(&trans);
    if (res != DMA_CONFIG_OK) {
        PRINTF("DMA load failed: %d\n", res);
        return EXIT_FAILURE;
    }

    PRINTF("DMA armed, waiting for Serial Link FIFO data...\n");

    res = dma_launch(&trans);
    if (res != DMA_CONFIG_OK) {
        PRINTF("DMA launch failed: %d\n", res);
        return EXIT_FAILURE;
    }

    while (!dma_intr_flag) {
        wait_for_interrupt();
    }
    dma_intr_flag = 0;

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