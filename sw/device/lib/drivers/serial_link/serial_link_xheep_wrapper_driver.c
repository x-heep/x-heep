// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Driver implementation for serial_link_xheep_wrapper.
// See serial_link_xheep_wrapper_driver.h for full documentation.

#include "serial_link_xheep_wrapper_driver.h"

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