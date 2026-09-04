/*
 * Copyright EPFL contributors.
 * Licensed under the Apache License, Version 2.0, see LICENSE for details.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "bitfield.h"
#include "i2s.h"
#include "i2s_structs.h"
#include "i2s_tx_sink_regs.h"
#include "pad_control.h"
#include "pad_control_regs.h"

#include "test_i2s.h"

uint32_t rx_only_samples[I2S_RX_ONLY_SAMPLES] __attribute__((aligned(4)));
uint32_t rx_tx_samples[I2S_RX_TX_SAMPLES] __attribute__((aligned(4)));
uint32_t tx_samples[I2S_TX_SAMPLES] __attribute__((aligned(4))) = {
    0x01234567u, 0x89abcdefu, 0x0badcafeu, 0x13579bdfu,
    0x2468ace0u, 0xfdb97531u, 0xa5a55a5au, 0xc001d00du,
    0x55aa00ffu, 0xff00aa55u, 0xdeadbeefu, 0x10203040u,
};

static dma_target_t rx_src;
static dma_target_t rx_dst;
dma_trans_t rx_trans;
static dma_target_t tx_src;
static dma_target_t tx_dst;
dma_trans_t tx_trans;

void select_gpio_13_pad(uint8_t mux)
{
    pad_control_t pad_control = {
        .base_addr = mmio_region_from_addr((uintptr_t)PAD_CONTROL_START_ADDRESS),
    };

    pad_control_set_mux(&pad_control,
                        (ptrdiff_t)PAD_CONTROL_PAD_MUX_GPIO_13_REG_OFFSET,
                        mux);
}

void clear_samples(uint32_t *samples, uint32_t sample_count)
{
    for (uint32_t i = 0; i < sample_count; ++i) {
        samples[i] = 0;
    }
}

static bool load_dma_transaction(dma_trans_t *trans, const char *name)
{
    dma_config_flags_t res =
        dma_validate_transaction(trans, DMA_ENABLE_REALIGN,
                                 DMA_PERFORM_CHECKS_INTEGRITY);
    if (res != DMA_CONFIG_OK) {
        printf("%s DMA validate failed with %u\n", name, (unsigned)res);
        return false;
    }

    res = dma_load_transaction(trans);
    if (res != DMA_CONFIG_OK) {
        printf("%s DMA load failed with %u\n", name, (unsigned)res);
        return false;
    }

    return true;
}

bool launch_dma_transaction(dma_trans_t *trans, const char *name)
{
    dma_config_flags_t res = dma_launch(trans);
    if (res != DMA_CONFIG_OK) {
        printf("%s DMA launch failed with %u\n", name, (unsigned)res);
        return false;
    }

    return true;
}

bool configure_rx_dma(uint32_t *dst, uint32_t sample_count, uint8_t channel,
                      const char *name, dma_trans_end_evt_t end)
{
    rx_src = (dma_target_t){
        .ptr = (uint8_t *)I2S_RX_DATA_ADDRESS,
        .inc_d1_du = 0,
        .trig = DMA_TRIG_SLOT_I2S_RX,
        .type = DMA_DATA_TYPE_WORD,
    };

    rx_dst = (dma_target_t){
        .ptr = (uint8_t *)dst,
        .inc_d1_du = 1,
        .trig = DMA_TRIG_MEMORY,
        .type = DMA_DATA_TYPE_WORD,
    };

    rx_trans = (dma_trans_t){
        .src = &rx_src,
        .dst = &rx_dst,
        .size_d1_du = sample_count,
        .src_type = DMA_DATA_TYPE_WORD,
        .dst_type = DMA_DATA_TYPE_WORD,
        .mode = DMA_TRANS_MODE_SINGLE,
        .dim = DMA_DIM_CONF_1D,
        .sign_ext = 0,
        .win_du = 0,
        .end = end,
        .channel = channel,
    };

    return load_dma_transaction(&rx_trans, name);
}

bool configure_tx_dma(uint8_t channel)
{
    tx_src = (dma_target_t){
        .ptr = (uint8_t *)tx_samples,
        .inc_d1_du = 1,
        .trig = DMA_TRIG_MEMORY,
        .type = DMA_DATA_TYPE_WORD,
    };

    tx_dst = (dma_target_t){
        .ptr = (uint8_t *)I2S_TX_DATA_ADDRESS,
        .inc_d1_du = 0,
        .trig = DMA_TRIG_SLOT_I2S_TX,
        .type = DMA_DATA_TYPE_WORD,
    };

    tx_trans = (dma_trans_t){
        .src = &tx_src,
        .dst = &tx_dst,
        .size_d1_du = I2S_TX_SAMPLES,
        .src_type = DMA_DATA_TYPE_WORD,
        .dst_type = DMA_DATA_TYPE_WORD,
        .mode = DMA_TRANS_MODE_SINGLE,
        .dim = DMA_DIM_CONF_1D,
        .sign_ext = 0,
        .win_du = 0,
        .end = DMA_TRANS_END_INTR_WAIT,
        .channel = channel,
    };

    return load_dma_transaction(&tx_trans, "I2S TX");
}

static bool rx_sample_matches(uint32_t sample, uint32_t sample_idx,
                              uint32_t *first_sample)
{
    if (sample_idx == 0) {
        if ((sample != I2S_MIC_LEFT_SAMPLE) &&
            (sample != I2S_MIC_RIGHT_SAMPLE)) {
            printf("RX sample 0 = 0x%08x, expected microphone pattern\n",
                   sample);
            return false;
        }

        *first_sample = sample;
        return true;
    }

    uint32_t expected =
        (*first_sample == I2S_MIC_LEFT_SAMPLE)
            ? ((sample_idx & 1u) ? I2S_MIC_RIGHT_SAMPLE : I2S_MIC_LEFT_SAMPLE)
            : ((sample_idx & 1u) ? I2S_MIC_LEFT_SAMPLE : I2S_MIC_RIGHT_SAMPLE);

    if (sample != expected) {
        printf("RX sample %u = 0x%08x, expected 0x%08x\n", sample_idx,
               sample, expected);
        return false;
    }

    return true;
}

bool check_rx_samples(uint32_t *samples, uint32_t sample_count)
{
    uint32_t first_sample = 0;

    for (uint32_t i = 0; i < sample_count; ++i) {
        if (!rx_sample_matches(samples[i], i, &first_sample)) {
            return false;
        }
    }

    return true;
}

bool sink_sample_matches(uint32_t sample, uint32_t sample_idx)
{
    if (sample != tx_samples[sample_idx]) {
        printf("TX sink sample %u = 0x%08x, expected 0x%08x\n", sample_idx,
               sample, tx_samples[sample_idx]);
        return false;
    }

    return true;
}

void disable_i2s_rx(void)
{
    i2s_peri->CONTROL &=
        ~(I2S_CONTROL_EN_RX_MASK << I2S_CONTROL_EN_RX_OFFSET);
}

bool check_tx_sink_samples(mmio_region_t sink)
{
    uint32_t sample_idx = 0;
    uint32_t leading_zeros = 0;
    bool payload_started = false;

    for (uint32_t i = 0; i < I2S_TX_SAMPLES + I2S_TX_SINK_EXTRA_READS; ++i) {
        uint32_t sample =
            mmio_region_read32(sink, I2S_TX_SINK_RXDATA_REG_OFFSET);

        if (!payload_started) {
            if (sample == 0) {
                ++leading_zeros;
                continue;
            }

            payload_started = true;
        }

        if (sample_idx >= I2S_TX_SAMPLES) {
            continue;
        }

        if (!sink_sample_matches(sample, sample_idx)) {
            return false;
        }

        ++sample_idx;
    }

    if (sample_idx != I2S_TX_SAMPLES) {
        printf("TX sink returned only %u/%u expected samples after %u leading zero samples\n",
               sample_idx, I2S_TX_SAMPLES, leading_zeros);
        return false;
    }

    return true;
}

bool arm_i2s_rx_tx(void)
{
    uint32_t control = i2s_peri->CONTROL;

    if ((bitfield_field32_read(control, I2S_CONTROL_EN_RX_FIELD) !=
         I2S_DISABLE) ||
        (control & (1u << I2S_CONTROL_EN_TX_BIT))) {
        printf("I2S RX or TX was already enabled\n");
        return false;
    }

    control =
        bitfield_field32_write(control, I2S_CONTROL_EN_RX_FIELD, I2S_BOTH_CH);
    control |= (1u << I2S_CONTROL_EN_TX_BIT);
    control |= (1u << I2S_CONTROL_RESET_WATERMARK_BIT);
    i2s_peri->CONTROL = control;

    return true;
}
