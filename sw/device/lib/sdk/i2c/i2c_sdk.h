// Copyright 2026 EPFL and Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: i2c_sdk.h
// Authors: Enrico Manfredi 
// Date: 06/03/2026
// Description: I2C SDK for basic interaction with the I2C peripheral

#ifndef I2C_SDK_H_
#define I2C_SDK_H_

#include <stdint.h>

#include "i2c.h"
#include "soc_ctrl.h"
#include "core_v_mini_mcu.h"
#include "x-heep.h"

#define WRITE_CMD  0x00
#define READ_CMD   0x01

/********************************/
/* ---- EXPORTED FUNCTIONS ---- */
/********************************/

/**
 * @brief Initialize the I2C peripheral
 * 
 * @return i2c_result_t Result of the initialization
 */
i2c_result_t initialize_i2c();

/**
 * @brief Set the timing configuration for the I2C peripheral. Clock period is automatically set.
 * 
 */
void set_timing_config(i2c_speed_t lowest_target_device_speed,
                       uint32_t sda_rise_ns,
                       uint32_t sda_fall_ns,
                       uint32_t scl_period_ns,
                       uint16_t data_signal_hold_cycles);

/**
 * @brief Set the watermark levels for the I2C peripheral
 * 
 */
void set_watermark_levels(i2c_level_t rx_level, i2c_level_t fmt_level);

/**
 * @brief Write data to an I2C target device
 * 
 * @return i2c_result_t Result of the writing operation
 */
i2c_result_t i2c_write(uint8_t dev_addr, uint8_t reg, uint8_t *source, uint32_t num_bytes);

/**
 * @brief Read data from an I2C target device
 * 
 * @return i2c_result_t Result of the reading operation
 */
i2c_result_t i2c_read(uint8_t dev_addr, uint8_t reg, uint8_t *destination, uint32_t num_bytes);

#endif /* I2C_SDK_H_ */
