/*
 * Copyright EPFL contributors.
 * Licensed under the Apache License, Version 2.0, see LICENSE for details.
 * SPDX-License-Identifier: Apache-2.0
 *
 * I2S example application.
 */

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "bitfield.h"
#include "dma.h"
#include "i2s.h"
#include "i2s_structs.h"
#include "i2s_tx_sink_regs.h"
#include "mmio.h"
#include "test_i2s.h"

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA 1
#define PRINTF_IN_SIM  0

#if TARGET_SIM && PRINTF_IN_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#else
#define PRINTF(...)
#endif

int main(void)
{
    bool passed = true;

#ifdef TEST_ID_0
    PRINTF("TEST_ID_0: I2S RX-only DMA test\n\r");

#ifdef TARGET_IS_FPGA
    for (uint32_t i = 0; i < I2S_FPGA_WAIT_CYCLES; ++i) {
        asm volatile("nop");
    }

#pragma message("this application takes multiple I2S microphone batches")

    for (uint32_t batch = 0; batch < I2S_RX_FPGA_BATCHES; ++batch) {
        PRINTF("starting\r\n\r");

        clear_samples(rx_only_samples, I2S_RX_ONLY_SAMPLES);
        dma_init(NULL);

        passed = configure_rx_dma(rx_only_samples, I2S_RX_ONLY_SAMPLES,
                                  I2S_RX_ONLY_DMA_CH, "I2S RX-only",
                                  DMA_TRANS_END_INTR_WAIT);

        if (passed && (i2s_init(I2S_FPGA_CLK_DIV, I2S_32_BITS) != kI2sOk)) {
            printf("I2S init failed\n");
            passed = false;
        }

        if (passed) {
            i2s_result_t rx_start_res = i2s_rx_start(I2S_LEFT_CH);
            if (rx_start_res != kI2sOk) {
                printf("I2S RX start failed with %d\n", rx_start_res);
                passed = false;
            }
        }

        if (passed) {
            passed = launch_dma_transaction(&rx_trans, "I2S RX-only");
        }

        if (i2s_is_running() &&
            (bitfield_field32_read(i2s_peri->CONTROL,
                                   I2S_CONTROL_EN_RX_FIELD) != I2S_DISABLE)) {
            disable_i2s_rx();
        }

        i2s_terminate();
        PRINTF("Batch done!\r\n\r");
    }
#else
    clear_samples(rx_only_samples, I2S_RX_ONLY_SAMPLES);
    dma_init(NULL);

    passed = configure_rx_dma(rx_only_samples, I2S_RX_ONLY_SAMPLES,
                              I2S_RX_ONLY_DMA_CH, "I2S RX-only",
                              DMA_TRANS_END_INTR_WAIT);

    if (passed && (i2s_init(I2S_SIM_CLK_DIV, I2S_32_BITS) != kI2sOk)) {
        printf("I2S init failed\n");
        passed = false;
    }

    if (passed) {
        i2s_result_t rx_start_res = i2s_rx_start(I2S_BOTH_CH);
        if (rx_start_res != kI2sOk) {
            printf("I2S RX start failed with %d\n", rx_start_res);
            passed = false;
        }
    }

    if (passed) {
        passed = launch_dma_transaction(&rx_trans, "I2S RX-only");
    }

    if (i2s_is_running() &&
        (bitfield_field32_read(i2s_peri->CONTROL, I2S_CONTROL_EN_RX_FIELD) !=
         I2S_DISABLE)) {
        disable_i2s_rx();
    }

    i2s_terminate();

#if TARGET_SIM
    if (passed && !check_rx_samples(rx_only_samples, I2S_RX_ONLY_SAMPLES)) {
        passed = false;
    }
#endif
#endif

    if (!passed) {
        PRINTF("TEST_ID_0 failed\n\r");
        return EXIT_FAILURE;
    }
#endif

#ifdef TEST_ID_1
    PRINTF("TEST_ID_1: I2S TX-only DMA test\n\r");

#if TARGET_SIM
    bool tx_only_completed = false;
    mmio_region_t tx_only_sink =
        mmio_region_from_addr((uintptr_t)I2S_TX_SINK_START_ADDRESS);

    select_gpio_13_pad(1);
    dma_init(NULL);
    mmio_region_write32(tx_only_sink, I2S_TX_SINK_CONTROL_REG_OFFSET, 0);

    passed = configure_tx_dma(I2S_TX_DMA_CH);

    if (passed) {
        i2s_result_t tx_start_res = i2s_tx_start();
        if (tx_start_res != kI2sOk) {
            printf("I2S TX start failed with %d\n", tx_start_res);
            passed = false;
        }
    }

    if (passed) {
        mmio_region_write32(tx_only_sink, I2S_TX_SINK_CONTROL_REG_OFFSET,
                            I2S_TX_SINK_SINK_EN);
        if (i2s_init(I2S_SIM_CLK_DIV, I2S_32_BITS) != kI2sOk) {
            printf("I2S init failed\n");
            passed = false;
        }
    }

    if (passed) {
        passed = launch_dma_transaction(&tx_trans, "I2S TX");
    }

    if (passed) {
        tx_only_completed = check_tx_sink_samples(tx_only_sink);
        passed = tx_only_completed;
    }

    i2s_terminate();
    mmio_region_write32(tx_only_sink, I2S_TX_SINK_CONTROL_REG_OFFSET, 0);
    select_gpio_13_pad(0);
#else
    PRINTF("Skipping I2S TX-only test outside simulation.\n\r");
#endif

    if (!passed) {
        PRINTF("TEST_ID_1 failed\n\r");
        return EXIT_FAILURE;
    }
#endif

#ifdef TEST_ID_2
    PRINTF("TEST_ID_2: simultaneous I2S RX/TX DMA test\n\r");

#if TARGET_SIM
    bool rx_tx_tx_completed = false;
    mmio_region_t rx_tx_sink =
        mmio_region_from_addr((uintptr_t)I2S_TX_SINK_START_ADDRESS);

    clear_samples(rx_tx_samples, I2S_RX_TX_SAMPLES);
    select_gpio_13_pad(1);
    dma_init(NULL);
    mmio_region_write32(rx_tx_sink, I2S_TX_SINK_CONTROL_REG_OFFSET, 0);

    passed = configure_rx_dma(rx_tx_samples, I2S_RX_TX_SAMPLES, I2S_RX_DMA_CH,
                              "I2S RX", DMA_TRANS_END_INTR);
    passed = passed && configure_tx_dma(I2S_TX_DMA_CH);

    if (passed) {
        passed = arm_i2s_rx_tx();
    }

    if (passed) {
        passed = launch_dma_transaction(&rx_trans, "I2S RX");
    }

    if (passed) {
        mmio_region_write32(rx_tx_sink, I2S_TX_SINK_CONTROL_REG_OFFSET,
                            I2S_TX_SINK_SINK_EN);
        if (i2s_init(I2S_SIM_CLK_DIV, I2S_32_BITS) != kI2sOk) {
            printf("I2S init failed\n");
            passed = false;
        }
    }

    if (passed) {
        passed = launch_dma_transaction(&tx_trans, "I2S TX");
    }

    if (passed) {
        rx_tx_tx_completed = check_tx_sink_samples(rx_tx_sink);
        passed = rx_tx_tx_completed;
    }

    if (passed && !check_rx_samples(rx_tx_samples, I2S_RX_TX_SAMPLES)) {
        passed = false;
    }

    i2s_terminate();
    disable_i2s_rx();
    mmio_region_write32(rx_tx_sink, I2S_TX_SINK_CONTROL_REG_OFFSET, 0);
    select_gpio_13_pad(0);
#else
    PRINTF("Skipping simultaneous I2S RX/TX test outside simulation.\n\r");
#endif

    if (!passed) {
        PRINTF("TEST_ID_2 failed\n\r");
        return EXIT_FAILURE;
    }
#endif

    PRINTF("Success.\n\r");
    return EXIT_SUCCESS;
}