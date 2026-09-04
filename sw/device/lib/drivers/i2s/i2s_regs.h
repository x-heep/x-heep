// Generated register defines for i2s

// Copyright information found in source file:
// Copyright EPFL contributors.

// Licensing information found in source file:
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef _I2S_REG_DEFS_
#define _I2S_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Defines the maximal word width
#define I2S_PARAM_MAX_WORD_WIDTH 32

// Bits available for the clock divider
#define I2S_PARAM_CLK_DIVIDER_WIDTH 16

// Bits available for the watermark
#define I2S_PARAM_WATERMARK_WIDTH 16

// Register width
#define I2S_PARAM_REG_WIDTH 32

// control register
#define I2S_CONTROL_REG_OFFSET 0x0
#define I2S_CONTROL_EN_BIT 0
#define I2S_CONTROL_EN_WS_BIT 1
#define I2S_CONTROL_EN_RX_MASK 0x3
#define I2S_CONTROL_EN_RX_OFFSET 2
#define I2S_CONTROL_EN_RX_FIELD \
  ((bitfield_field32_t) { .mask = I2S_CONTROL_EN_RX_MASK, .index = I2S_CONTROL_EN_RX_OFFSET })
#define I2S_CONTROL_EN_RX_VALUE_DISABLED 0x0
#define I2S_CONTROL_EN_RX_VALUE_ONLY_LEFT 0x1
#define I2S_CONTROL_EN_RX_VALUE_ONLY_RIGHT 0x2
#define I2S_CONTROL_EN_RX_VALUE_BOTH_CHANNELS 0x3
#define I2S_CONTROL_INTR_EN_BIT 4
#define I2S_CONTROL_EN_WATERMARK_BIT 5
#define I2S_CONTROL_RESET_WATERMARK_BIT 6
#define I2S_CONTROL_EN_IO_BIT 7
#define I2S_CONTROL_DATA_WIDTH_MASK 0x3
#define I2S_CONTROL_DATA_WIDTH_OFFSET 8
#define I2S_CONTROL_DATA_WIDTH_FIELD \
  ((bitfield_field32_t) { .mask = I2S_CONTROL_DATA_WIDTH_MASK, .index = I2S_CONTROL_DATA_WIDTH_OFFSET })
#define I2S_CONTROL_DATA_WIDTH_VALUE_8_BITS 0x0
#define I2S_CONTROL_DATA_WIDTH_VALUE_16_BITS 0x1
#define I2S_CONTROL_DATA_WIDTH_VALUE_24_BITS 0x2
#define I2S_CONTROL_DATA_WIDTH_VALUE_32_BITS 0x3
#define I2S_CONTROL_RX_START_CHANNEL_BIT 10
#define I2S_CONTROL_RESET_RX_OVERFLOW_BIT 11
#define I2S_CONTROL_EN_TX_BIT 12
#define I2S_CONTROL_RESET_TX_UNDERFLOW_BIT 13
#define I2S_CONTROL_RESET_TX_OVERFLOW_BIT 14

// Status flags of the I2s peripheral
#define I2S_STATUS_REG_OFFSET 0x4
#define I2S_STATUS_RUNNING_BIT 0
#define I2S_STATUS_RX_DATA_READY_BIT 1
#define I2S_STATUS_RX_OVERFLOW_BIT 2
#define I2S_STATUS_TX_READY_BIT 3
#define I2S_STATUS_TX_UNDERFLOW_BIT 4
#define I2S_STATUS_TX_OVERFLOW_BIT 5

// Control register
#define I2S_CLKDIVIDX_REG_OFFSET 0x8
#define I2S_CLKDIVIDX_COUNT_MASK 0xffff
#define I2S_CLKDIVIDX_COUNT_OFFSET 0
#define I2S_CLKDIVIDX_COUNT_FIELD \
  ((bitfield_field32_t) { .mask = I2S_CLKDIVIDX_COUNT_MASK, .index = I2S_CLKDIVIDX_COUNT_OFFSET })

// I2s Receive data
#define I2S_RXDATA_REG_OFFSET 0xc

// Watermark to reach for an interrupt
#define I2S_WATERMARK_REG_OFFSET 0x10
#define I2S_WATERMARK_WATERMARK_MASK 0xffff
#define I2S_WATERMARK_WATERMARK_OFFSET 0
#define I2S_WATERMARK_WATERMARK_FIELD \
  ((bitfield_field32_t) { .mask = I2S_WATERMARK_WATERMARK_MASK, .index = I2S_WATERMARK_WATERMARK_OFFSET })

// Watermark counter level
#define I2S_WATERLEVEL_REG_OFFSET 0x14
#define I2S_WATERLEVEL_WATERLEVEL_MASK 0xffff
#define I2S_WATERLEVEL_WATERLEVEL_OFFSET 0
#define I2S_WATERLEVEL_WATERLEVEL_FIELD \
  ((bitfield_field32_t) { .mask = I2S_WATERLEVEL_WATERLEVEL_MASK, .index = I2S_WATERLEVEL_WATERLEVEL_OFFSET })

// I2s Transmit data
#define I2S_TXDATA_REG_OFFSET 0x18

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _I2S_REG_DEFS_
// End generated register defines for i2s