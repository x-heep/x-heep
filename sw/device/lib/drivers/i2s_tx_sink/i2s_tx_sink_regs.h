// Generated register defines for i2s_tx_sink

// Copyright information found in source file:
// Copyright EPFL contributors.

// Licensing information found in source file:
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef _I2S_TX_SINK_REG_DEFS_
#define _I2S_TX_SINK_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define I2S_TX_SINK_PARAM_REG_WIDTH 32

// Sink control. Bit 0 enables TX capture.
#define I2S_TX_SINK_CONTROL_REG_OFFSET 0x0

// Decoded I2S TX sample FIFO output
#define I2S_TX_SINK_RXDATA_REG_OFFSET 0x4

// I2S TX sink status
#define I2S_TX_SINK_STATUS_REG_OFFSET 0x8
#define I2S_TX_SINK_STATUS_EMPTY_BIT 0
#define I2S_TX_SINK_STATUS_AVAILABLE_BIT 1
#define I2S_TX_SINK_STATUS_OVERFLOW_BIT 2

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _I2S_TX_SINK_REG_DEFS_
// End generated register defines for i2s_tx_sink