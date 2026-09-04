/*
 * Copyright EPFL contributors.
 * Licensed under the Apache License, Version 2.0, see LICENSE for details.
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef TEST_I2S_H_
#define TEST_I2S_H_

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "core_v_mini_mcu.h"
#include "dma.h"
#include "mmio.h"
#include "x-heep.h"

/*
 * This code contains three I2S tests that can be run by defining the
 * corresponding TEST_ID_* macro.
 * - RX-only DMA capture from the I2S microphone stream
 * - TX-only DMA transfer to the I2S serial output
 * - Simultaneous TX and RX DMA transfers on different DMA channels
 */

#define TEST_ID_0
#define TEST_ID_1
#define TEST_ID_2

#if !defined(TEST_ID_0) && !defined(TEST_ID_1) && !defined(TEST_ID_2)
#error "example_i2s requires at least one TEST_ID_* macro"
#endif

#if defined(TEST_ID_2) && (DMA_CH_NUM < 2)
#error "example_i2s TEST_ID_2 requires at least two DMA channels"
#endif

#define I2S_TX_SINK_START_ADDRESS (EXT_PERIPHERAL_START_ADDRESS + 0x6000)

#define I2S_TX_SINK_CONTROL_SINK_EN_BIT 0
#define I2S_TX_SINK_SINK_EN (1u << I2S_TX_SINK_CONTROL_SINK_EN_BIT)

#define I2S_SIM_CLK_DIV  32
#define I2S_FPGA_CLK_DIV 8

#define I2S_RX_ONLY_DMA_CH 0
#define I2S_TX_DMA_CH      0
#define I2S_RX_DMA_CH      1

#define I2S_RX_SIM_SAMPLES   8
#define I2S_RX_FPGA_SAMPLES  100
#define I2S_RX_FPGA_BATCHES  16
#define I2S_RX_TX_SAMPLES    I2S_RX_SIM_SAMPLES
#define I2S_TX_SAMPLES       12
#define I2S_TX_SINK_EXTRA_READS 3
#define I2S_FPGA_WAIT_CYCLES ((3 * REFERENCE_CLOCK_Hz) / 8)

#ifdef TARGET_IS_FPGA
#define I2S_RX_ONLY_SAMPLES I2S_RX_FPGA_SAMPLES
#else
#define I2S_RX_ONLY_SAMPLES I2S_RX_SIM_SAMPLES
#endif

#define I2S_MIC_LEFT_SAMPLE  0x08765431u
#define I2S_MIC_RIGHT_SAMPLE 0x0fedcba9u

extern uint32_t rx_only_samples[I2S_RX_ONLY_SAMPLES];
extern uint32_t rx_tx_samples[I2S_RX_TX_SAMPLES];
extern uint32_t tx_samples[I2S_TX_SAMPLES];

extern dma_trans_t rx_trans;
extern dma_trans_t tx_trans;

void select_gpio_13_pad(uint8_t mux);
void clear_samples(uint32_t *samples, uint32_t sample_count);
bool launch_dma_transaction(dma_trans_t *trans, const char *name);
bool configure_rx_dma(uint32_t *dst, uint32_t sample_count, uint8_t channel,
                      const char *name, dma_trans_end_evt_t end);
bool configure_tx_dma(uint8_t channel);
bool check_rx_samples(uint32_t *samples, uint32_t sample_count);
bool sink_sample_matches(uint32_t sample, uint32_t sample_idx);
void disable_i2s_rx(void);
bool check_tx_sink_samples(mmio_region_t sink);
bool arm_i2s_rx_tx(void);

#endif /* TEST_I2S_H_ */
