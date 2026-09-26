// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "i2s_tx_sink.h"
#include "i2s_tx_sink_regs.h"
#include "i2s_tx_sink_structs.h"
#include "bitfield.h"

/* CONTROL is a full-width field; bit 0 enables capture. */
#define I2S_TX_SINK_CONTROL_SINK_EN_BIT 0

void i2s_tx_sink_start(void)
{
  i2s_tx_sink_peri->CONTROL = 1u << I2S_TX_SINK_CONTROL_SINK_EN_BIT;
}

void i2s_tx_sink_stop(void)
{
  i2s_tx_sink_peri->CONTROL = 0;
}

bool i2s_tx_sink_data_available(void)
{
  return bitfield_bit32_read(
      i2s_tx_sink_peri->STATUS,
      I2S_TX_SINK_STATUS_AVAILABLE_BIT);
}

bool i2s_tx_sink_overflow(void)
{
  return bitfield_bit32_read(
      i2s_tx_sink_peri->STATUS,
      I2S_TX_SINK_STATUS_OVERFLOW_BIT);
}

uint32_t i2s_tx_sink_read_data(void)
{
  return i2s_tx_sink_peri->RXDATA;
}
