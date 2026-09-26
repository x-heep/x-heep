// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef _DRIVERS_I2S_TX_SINK_H_
#define _DRIVERS_I2S_TX_SINK_H_

#include <stdbool.h>
#include <stdint.h>

#include "core_v_mini_mcu.h"

/* Address of the TX sink in the simulation testharness. */
#define I2S_TX_SINK_START_ADDRESS (EXT_PERIPHERAL_START_ADDRESS + 0x6000)

#ifdef __cplusplus
extern "C" {
#endif

/** Enable capture. The enable propagates on the incoming I2S clock. */
void i2s_tx_sink_start(void);

/*
 * Disable capture. The disable propagates on the incoming I2S clock.
 * This does not flush captured samples or clear the overflow flag.
 */
void i2s_tx_sink_stop(void);

/* Return whether a captured sample is available. */
bool i2s_tx_sink_data_available(void);

/* Return whether the capture FIFO overflowed. Only hardware reset clears it. */
bool i2s_tx_sink_overflow(void);

/*
 * Read and pop one captured sample.
 * The hardware stalls the bus read until a sample is available. If capture
 * cannot produce another sample, this call blocks indefinitely.
 */
uint32_t i2s_tx_sink_read_data(void);

#ifdef __cplusplus
}
#endif

#endif // _DRIVERS_I2S_TX_SINK_H_
