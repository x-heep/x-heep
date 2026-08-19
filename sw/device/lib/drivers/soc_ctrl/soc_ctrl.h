// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#ifndef _DRIVERS_SOC_CTRL_H_
#define _DRIVERS_SOC_CTRL_H_

#include <stddef.h>
#include <stdint.h>

#include "mmio.h"

#ifdef __cplusplus
extern "C" {
#endif

#define SOC_CTRL_SPI_FLASH_MODE_SPIMEMIO 1
#define SOC_CTRL_SPI_FLASH_MODE_SPIHOST 0

/**
 * Initialization parameters for SOC CTRL.
 *
 */
typedef struct /*soc_ctrl*/ {
  /**
   * The base address for the soc_ctrl hardware registers.
   */
  mmio_region_t base_addr;
} soc_ctrl_t;

typedef struct {
  uint8_t has_spi_flash;
  uint8_t has_dma;
  uint8_t has_pad_control;
  uint8_t has_gpio_ao;
} soc_ctrl_xheep_ao_peripheral_config_t;

typedef struct {
  uint8_t has_rv_plic;
  uint8_t has_spi_host;
  uint8_t has_gpio;
  uint8_t has_i2c;
  uint8_t has_rv_timer;
  uint8_t has_spi2;
  uint8_t has_pdm2pcm;
  uint8_t has_i2s;
  uint8_t has_uart;
} soc_ctrl_xheep_peripheral_config_t;


/**
 * Write a to valid register of the SOC CTRL.
 * @param soc_ctrl Pointer to soc_ctrl_t represting the target SOC CTRL.
 * @param valid (1 or 0) data to write.
 */
void soc_ctrl_set_valid(const soc_ctrl_t *soc_ctrl, uint8_t valid);

/**
 * Write a the exit value of the SOC CTRL.
 * @param soc_ctrl Pointer to soc_ctrl_t represting the target SOC CTRL.
 * @param exit value data to write.
 */
void soc_ctrl_set_exit_value(const soc_ctrl_t *soc_ctrl, uint32_t exit_value);


uint32_t soc_ctrl_get_frequency(const soc_ctrl_t *soc_ctrl);

void soc_ctrl_set_frequency(const soc_ctrl_t *soc_ctrl, uint32_t frequency);


/**
 * Get the X-HEEP Instance ID
 * @param soc_ctrl Pointer to soc_ctrl_t represting the target SOC CTRL.
 */

uint32_t get_xheep_instance_id(const soc_ctrl_t *soc_ctrl);

/**
 * Get the X-HEEP AO Peripheral Config (HJSON file)
 * @param soc_ctrl Pointer to soc_ctrl_t represting the target SOC CTRL.
 */

soc_ctrl_xheep_ao_peripheral_config_t get_xheep_ao_peripheral_config(const soc_ctrl_t *soc_ctrl);


/**
 * Get the X-HEEP Peripheral Config (HJSON file)
 * @param soc_ctrl Pointer to soc_ctrl_t represting the target SOC CTRL.
 */

soc_ctrl_xheep_peripheral_config_t get_xheep_peripheral_config(const soc_ctrl_t *soc_ctrl);


#ifdef __cplusplus
}
#endif

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DRIVERS_SOC CTRL_H_
