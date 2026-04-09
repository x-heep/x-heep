// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Driver implementation for serial_link_xheep_wrapper.
// See serial_link_xheep_wrapper_driver.h for full documentation.

#include "serial_link_xheep_wrapper_driver.h"

volatile int8_t sl_wrapper_dma_intr_flag = 0;

void dma_intr_handler_trans_done(uint8_t channel) {
    sl_wrapper_dma_intr_flag = 1;
}

static dma_target_t sl_dma_tgt_src = {
    .ptr       = (uint8_t *)SL_READ,
    .inc_d1_du = 0,
    .type      = DMA_DATA_TYPE_WORD,
    .trig      = DMA_TRIG_SLOT_SL_FIFO_RX,
};

static dma_target_t sl_dma_tgt_dst = {
    .inc_d1_du = 1,
    .type      = DMA_DATA_TYPE_WORD,
    .trig      = DMA_TRIG_MEMORY,
};

static dma_trans_t sl_dma_trans = {
    .src     = &sl_dma_tgt_src,
    .dst     = &sl_dma_tgt_dst,
    .dim     = DMA_DIM_CONF_1D,
    .end     = DMA_TRANS_END_INTR,
    .channel = 0,
};

void sl_wrapper_set_rx_mode(sl_wrapper_rx_mode_t mode) {
    volatile uint32_t *rx_mode_reg = SL_WRAPPER_RX_MODE_REG;
    if (mode == SL_WRAPPER_RX_MODE_DIRECT_WRITE) {
        *rx_mode_reg |= (1u << SERIAL_LINK_XHEEP_WRAPPER_RX_MODE_DIRECT_WRITE_EN_BIT);
    } else {
        *rx_mode_reg &= ~(1u << SERIAL_LINK_XHEEP_WRAPPER_RX_MODE_DIRECT_WRITE_EN_BIT);
    }
}

sl_wrapper_rx_mode_t sl_wrapper_get_rx_mode(void) {
    volatile uint32_t *rx_mode_reg = SL_WRAPPER_RX_MODE_REG;
    return (*rx_mode_reg >> SERIAL_LINK_XHEEP_WRAPPER_RX_MODE_DIRECT_WRITE_EN_BIT) & 0x1;
}

void sl_wrapper_direct_write(uint32_t dest, uint32_t data) {
    *SL_WRAPPER_DIRECT_WRITE_ADDR(dest) = data;
}

void sl_wrapper_direct_write_multiple(uint32_t dest, const uint32_t *data, uint32_t count) {
    for (uint32_t i = 0; i < count; i++) {
        sl_wrapper_direct_write(dest + i * 4, data[i]);
    }
}

dma_config_flags_t sl_wrapper_dma_read_launch(uint32_t *dst, uint32_t count) { 

    if (!dma_is_ready(0)) {
        return DMA_CONFIG_TRANS_OVERRIDE;
    }

    if (sl_wrapper_get_rx_mode() != SL_WRAPPER_RX_MODE_FIFO) {
        sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
    }

    sl_dma_tgt_dst.ptr      = (uint8_t *)dst;
    sl_dma_trans.size_d1_du = count;

    sl_wrapper_dma_intr_flag = 0;

    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);

    dma_init(NULL);

    dma_config_flags_t res;

    res = dma_validate_transaction(&sl_dma_trans, DMA_ENABLE_REALIGN,
                                   DMA_PERFORM_CHECKS_INTEGRITY);
    if (res != DMA_CONFIG_OK) return res;

    res = dma_load_transaction(&sl_dma_trans);
    if (res != DMA_CONFIG_OK) return res;

    res = dma_launch(&sl_dma_trans);
    return res;
}