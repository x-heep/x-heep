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
#include "i2s_tx_sink.h"
#include "x-heep.h"



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

#ifdef TARGET_IS_FPGA
/* Repeat the TX pattern until reset or a stream error; return false on failure. */
bool run_fpga_tx(void);
#endif

/* Zero the sample buffer before an RX test. */
void clear_samples(uint32_t *samples, uint32_t sample_count);

/* Launch a loaded DMA transaction and report launch errors using name. */
bool launch_dma_transaction(dma_trans_t *trans, const char *name);

/* Validate and load an I2S-to-memory DMA transfer with the chosen end event. */
bool configure_rx_dma(uint32_t *dst, uint32_t sample_count, uint8_t channel,
                      const char *name, dma_trans_end_evt_t end);

/* Load the TX pattern DMA transfer: circular on FPGA, single in simulation. */
bool configure_tx_dma(uint8_t channel);

/* Check the alternating microphone model pattern, accepting either channel first. */
bool check_rx_samples(uint32_t *samples, uint32_t sample_count);

/* Compare one captured TX word with the pattern entry at sample_idx. */
bool sink_sample_matches(uint32_t sample, uint32_t sample_idx);

/* Read and verify the simulation TX sink, allowing leading startup zeros. */
bool check_tx_sink_samples(void);

/* Select I2S on the shared SCK, WS, RX, and TX pads. */
void configure_i2s_pads(void);

/* Arm TX and both RX channels before i2s_init() starts the shared clocks. */
bool arm_i2s_rx_tx(void);

#endif /* TEST_I2S_H_ */
