// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include "soc_ctrl.h"

#include <stddef.h>
#include <stdint.h>

#include "mmio.h"

#include "soc_ctrl.h"
#include "soc_ctrl_regs.h"  // Generated.

void soc_ctrl_set_valid(const soc_ctrl_t *soc_ctrl, uint8_t valid) {
  mmio_region_write8(soc_ctrl->base_addr, (ptrdiff_t)(SOC_CTRL_EXIT_VALID_REG_OFFSET), valid);
}

void soc_ctrl_set_exit_value(const soc_ctrl_t *soc_ctrl, uint32_t exit_value) {
  mmio_region_write32(soc_ctrl->base_addr, (ptrdiff_t)(SOC_CTRL_EXIT_VALUE_REG_OFFSET), exit_value);
}

uint32_t soc_ctrl_get_frequency(const soc_ctrl_t *soc_ctrl) {
  return mmio_region_read32(soc_ctrl->base_addr, (ptrdiff_t)(SOC_CTRL_SYSTEM_FREQUENCY_HZ_REG_OFFSET));
}

void soc_ctrl_set_frequency(const soc_ctrl_t *soc_ctrl, uint32_t frequency) {
  mmio_region_write32(soc_ctrl->base_addr, (ptrdiff_t)(SOC_CTRL_SYSTEM_FREQUENCY_HZ_REG_OFFSET), frequency);
}

uint32_t get_xheep_instance_id(const soc_ctrl_t *soc_ctrl) {
  return mmio_region_read32(soc_ctrl->base_addr, (ptrdiff_t)(SOC_CTRL_XHEEP_ID_REG_OFFSET));
}

soc_ctrl_xheep_ao_peripheral_config_t get_xheep_ao_peripheral_config(const soc_ctrl_t *soc_ctrl) {
  uint32_t peripheral_config = mmio_region_read32(soc_ctrl->base_addr, (ptrdiff_t)(SOC_CTRL_XHEEP_AO_PERIPHERAL_CONFIG_REG_OFFSET));
  soc_ctrl_xheep_ao_peripheral_config_t config;
  config.has_spi_flash = (peripheral_config & (1 << SOC_CTRL_XHEEP_AO_PERIPHERAL_CONFIG_SPI_FLASH_BIT)) != 0;
  config.has_dma = (peripheral_config & (1 << SOC_CTRL_XHEEP_AO_PERIPHERAL_CONFIG_DMA_BIT)) != 0;
  config.has_pad_control = (peripheral_config & (1 << SOC_CTRL_XHEEP_AO_PERIPHERAL_CONFIG_PAD_CONTROL_BIT)) != 0;
  config.has_gpio_ao = (peripheral_config & (1 << SOC_CTRL_XHEEP_AO_PERIPHERAL_CONFIG_GPIO_AO_BIT)) != 0;
  return config;
}

soc_ctrl_xheep_peripheral_config_t get_xheep_peripheral_config(const soc_ctrl_t *soc_ctrl) {
  uint32_t peripheral_config = mmio_region_read32(soc_ctrl->base_addr, (ptrdiff_t)(SOC_CTRL_XHEEP_PERIPHERAL_CONFIG_REG_OFFSET));
  soc_ctrl_xheep_peripheral_config_t config;
  config.has_rv_plic = (peripheral_config & (1 << SOC_CTRL_XHEEP_PERIPHERAL_CONFIG_RV_PLIC_BIT)) != 0;
  config.has_spi_host = (peripheral_config & (1 << SOC_CTRL_XHEEP_PERIPHERAL_CONFIG_SPI_HOST_BIT)) != 0;
  config.has_gpio = (peripheral_config & (1 << SOC_CTRL_XHEEP_PERIPHERAL_CONFIG_GPIO_BIT)) != 0;
  config.has_i2c = (peripheral_config & (1 << SOC_CTRL_XHEEP_PERIPHERAL_CONFIG_I2C_BIT)) != 0;
  config.has_rv_timer = (peripheral_config & (1 << SOC_CTRL_XHEEP_PERIPHERAL_CONFIG_RV_TIMER_BIT)) != 0;
  config.has_spi2 = (peripheral_config & (1 << SOC_CTRL_XHEEP_PERIPHERAL_CONFIG_SPI2_BIT)) != 0;
  config.has_pdm2pcm = (peripheral_config & (1 << SOC_CTRL_XHEEP_PERIPHERAL_CONFIG_PDM2PCM_BIT)) != 0;
  config.has_i2s = (peripheral_config & (1 << SOC_CTRL_XHEEP_PERIPHERAL_CONFIG_I2S_BIT)) != 0;
  config.has_uart = (peripheral_config & (1 << SOC_CTRL_XHEEP_PERIPHERAL_CONFIG_UART_BIT)) != 0;
  return config;
}

