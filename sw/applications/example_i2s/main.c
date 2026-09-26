/*
 *  Copyright EPFL contributors.
 *  Licensed under the Apache License, Version 2.0, see LICENSE for details.
 *  SPDX-License-Identifier: Apache-2.0
 *  
 *  Author: Tommaso Terzano <tommaso.terzano@epfl.ch>
 *                         <tommaso.terzano@gmail.com>
 *  
 *  Info: Example application of the I2S driver, with DMA support. 
 * 
 */

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "dma.h"
#include "i2s.h"
#include "i2s_tx_sink.h"
#include "mmio.h"
#include "test_i2s.h"

/*
 * This code contains three I2S tests that can be run by defining the
 * corresponding TEST_ID_* macro.
 * - RX-only DMA capture of N samples from the I2S microphone stream
 * - TX-only DMA transfer of N samples to the I2S serial output
 * - Simultaneous TX and RX DMA transfers on different DMA channels
 */

#ifdef TARGET_IS_FPGA
#define TEST_ID_1
#else
#define TEST_ID_0
#define TEST_ID_1
#define TEST_ID_2
#endif

#if !defined(TEST_ID_0) && !defined(TEST_ID_1) && !defined(TEST_ID_2)
#error "example_i2s requires at least one TEST_ID_* macro"
#endif

#if defined(TEST_ID_2) && (DMA_CH_NUM < 2)
#error "example_i2s TEST_ID_2 requires at least two DMA channels"
#endif

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

extern uint32_t rx_only_samples[I2S_RX_ONLY_SAMPLES];
extern uint32_t rx_tx_samples[I2S_RX_TX_SAMPLES];
extern uint32_t tx_samples[I2S_TX_SAMPLES];

extern dma_trans_t rx_trans;
extern dma_trans_t tx_trans;

int main(void)
{
    bool passed = true;

    configure_i2s_pads();

    #ifdef TEST_ID_0

    /* Testing receiving data through the I2S RX channel */

    PRINTF("TEST_ID_0: I2S RX-only DMA test\n\r");

    #ifdef TARGET_IS_FPGA

    /* Wait for the FPGA to be ready */
    for (uint32_t i = 0; i < I2S_FPGA_WAIT_CYCLES; ++i) {
        asm volatile("nop");
    }

    PRINTF("This application takes multiple I2S microphone batches");

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

        if (i2s_is_running()) {
            (void)i2s_rx_stop();
        }

        i2s_terminate();
        PRINTF("Batch done!\r\n\r");
    }
    #else
    
    /* 
     * Clear the data in the RX FIFO. This avoids having samples from 
     * previous test runs that could interfere with the current test.
     */
    clear_samples(rx_only_samples, I2S_RX_ONLY_SAMPLES);

    dma_init(NULL);

    /* Helper to configure the DMA CH0, used in this app for the RX channel */
    passed = configure_rx_dma(rx_only_samples, I2S_RX_ONLY_SAMPLES,
                              I2S_RX_ONLY_DMA_CH, "I2S RX-only",
                              DMA_TRANS_END_INTR_WAIT);

    /* Set-up the I2S peripheral */
    if (passed && (i2s_init(I2S_SIM_CLK_DIV, I2S_32_BITS) != kI2sOk)) {
        printf("I2S init failed\n");
        passed = false;
    }

    /* Start the I2S RX channel */
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

    /* Stops I2S RX channel after the DMA transaction has finished */
    if (i2s_is_running()) {
        i2s_rx_stop();
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

    dma_init(NULL);

    /* Configure the DMA CH1, used in this app for the TX channel */
    passed = configure_tx_dma(I2S_TX_DMA_CH);

    if (passed) {
        i2s_result_t tx_start_res = i2s_tx_start();
        if (tx_start_res != kI2sOk) {
            printf("I2S TX start failed with %d\n", tx_start_res);
            passed = false;
        }
    }

    /* Start the TX sink and initialize the I2S peripheral */
    if (passed) {
        i2s_tx_sink_start();
        if (i2s_init(I2S_SIM_CLK_DIV, I2S_32_BITS) != kI2sOk) {
            printf("I2S init failed\n");
            passed = false;
        }
    }

    if (passed) {
        passed = launch_dma_transaction(&tx_trans, "I2S TX");
    }

    if (passed) {
        tx_only_completed = check_tx_sink_samples();
        passed = tx_only_completed;
    }

    i2s_terminate();
    i2s_tx_sink_stop();
#elif defined(TARGET_IS_FPGA)
    passed = run_fpga_tx();
#else
    PRINTF("Skipping I2S TX-only test on this target.\n\r");
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

    clear_samples(rx_tx_samples, I2S_RX_TX_SAMPLES);
    dma_init(NULL);

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
        i2s_tx_sink_start();
        if (i2s_init(I2S_SIM_CLK_DIV, I2S_32_BITS) != kI2sOk) {
            printf("I2S init failed\n");
            passed = false;
        }
    }

    if (passed) {
        passed = launch_dma_transaction(&tx_trans, "I2S TX");
    }

    if (passed) {
        rx_tx_tx_completed = check_tx_sink_samples();
        passed = rx_tx_tx_completed;
    }

    if (passed && !check_rx_samples(rx_tx_samples, I2S_RX_TX_SAMPLES)) {
        passed = false;
    }

    if (i2s_is_running()) {
        (void)i2s_rx_stop();
    }
    i2s_terminate();
    i2s_tx_sink_stop();
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