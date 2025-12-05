# Copyright 2025 UPM
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

## Clock Signal
set_property -dict { PACKAGE_PIN AD11  IOSTANDARD LVDS     } [get_ports { clk_200mhz_n }]; # Sch=sysclk_n
set_property -dict { PACKAGE_PIN AD12  IOSTANDARD LVDS     } [get_ports { clk_200mhz_p }]; # Sch=sysclk_p
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_tck_i]

## CPU reset
set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports { rst_i }]; # Sch=cpu_resetn
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_i]

## Status LEDs
set_property -dict { PACKAGE_PIN T28   IOSTANDARD LVCMOS33 } [get_ports { rst_led_o }]; # Sch=led[0]
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports { clk_led_o }]; # Sch=led[1]
set_property -dict { PACKAGE_PIN U30   IOSTANDARD LVCMOS33 } [get_ports { exit_value_o }]; # Sch=led[2]
set_property -dict { PACKAGE_PIN U29   IOSTANDARD LVCMOS33 } [get_ports { exit_valid_o }]; # Sch=led[3]

## Mode selection switches
set_property -dict { PACKAGE_PIN G25   IOSTANDARD LVCMOS12 } [get_ports { execute_from_flash_i }]; # Sch=sw[1]
set_property -dict { PACKAGE_PIN G19   IOSTANDARD LVCMOS12 } [get_ports { boot_select_i }]; # Sch=sw[0]

## FLASH - PMOD Header JC
## PMOD Header JC
set_property -dict { PACKAGE_PIN AD26  IOSTANDARD LVCMOS33 } [get_ports { spi_flash_csb_o }]; # jc[4]
set_property -dict { PACKAGE_PIN AC26  IOSTANDARD LVCMOS33 } [get_ports { spi_flash_sck_o }]; # jc[0]
set_property -dict { PACKAGE_PIN AG30  IOSTANDARD LVCMOS33 } [get_ports { spi_flash_sd_io[0] }]; # jc[5]
set_property -dict { PACKAGE_PIN AJ27  IOSTANDARD LVCMOS33 } [get_ports { spi_flash_sd_io[1] }]; # jc[1]
set_property -dict { PACKAGE_PIN AK30  IOSTANDARD LVCMOS33 } [get_ports { spi_flash_sd_io[2] }]; # jc[6]
set_property -dict { PACKAGE_PIN AH30  IOSTANDARD LVCMOS33 } [get_ports { spi_flash_sd_io[3] }]; # jc[2]

## PMOD Header JD
## UART
set_property -dict { PACKAGE_PIN V27   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }]; # jd[0]
set_property -dict { PACKAGE_PIN U24   IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }]; # jd[4]

## JTAG
set_property -dict { PACKAGE_PIN Y30   IOSTANDARD LVCMOS33 } [get_ports { jtag_tdi_i }]; # jd[1]
set_property -dict { PACKAGE_PIN V24   IOSTANDARD LVCMOS33 } [get_ports { jtag_tms_i }]; # jd[2]
set_property -dict { PACKAGE_PIN Y26   IOSTANDARD LVCMOS33 } [get_ports { jtag_tck_i }]; # jd[5]
set_property -dict { PACKAGE_PIN V22   IOSTANDARD LVCMOS33 } [get_ports { jtag_tdo_o }]; # jd[6]
set_property -dict { PACKAGE_PIN AK28  IOSTANDARD LVCMOS33 } [get_ports { jtag_trst_ni }]; # jc[7] JC!

## IIC Bus
set_property -dict { PACKAGE_PIN W21   IOSTANDARD LVCMOS33 } [get_ports { i2c_scl_io }]; # jd[7]
set_property -dict { PACKAGE_PIN W22   IOSTANDARD LVCMOS33 } [get_ports { i2c_sda_io }]; # jd[3]

## SPI 1 - PMOD Header JA
## PMOD Header JA
set_property -dict { PACKAGE_PIN T22   IOSTANDARD LVCMOS33 } [get_ports { spi_csb_o }]; # ja[4]
set_property -dict { PACKAGE_PIN U27   IOSTANDARD LVCMOS33 } [get_ports { spi_sck_o }]; # ja[0]
set_property -dict { PACKAGE_PIN T23   IOSTANDARD LVCMOS33 } [get_ports { spi_sd_io[0] }]; # ja[5]
set_property -dict { PACKAGE_PIN U28   IOSTANDARD LVCMOS33 } [get_ports { spi_sd_io[1] }]; # ja[1]
set_property -dict { PACKAGE_PIN T20   IOSTANDARD LVCMOS33 } [get_ports { spi_sd_io[2] }]; # ja[6]
set_property -dict { PACKAGE_PIN T26   IOSTANDARD LVCMOS33 } [get_ports { spi_sd_io[3] }]; # ja[2]

## SPI 2 - PMOD Header JB
## PMOD Header JB
set_property -dict { PACKAGE_PIN T25   IOSTANDARD LVCMOS33 } [get_ports { spi2_csb_o[0] }]; # jb[4]
set_property -dict { PACKAGE_PIN W26   IOSTANDARD LVCMOS33 } [get_ports { spi2_csb_o[1] }]; # jb[3]
set_property -dict { PACKAGE_PIN V29   IOSTANDARD LVCMOS33 } [get_ports { spi2_sck_o }]; # jb[0]
set_property -dict { PACKAGE_PIN U25   IOSTANDARD LVCMOS33 } [get_ports { spi2_sd_io[0] }]; # jb[5]
set_property -dict { PACKAGE_PIN V30   IOSTANDARD LVCMOS33 } [get_ports { spi2_sd_io[1] }]; # jb[1]
set_property -dict { PACKAGE_PIN U22   IOSTANDARD LVCMOS33 } [get_ports { spi2_sd_io[2] }]; # jb[6]
set_property -dict { PACKAGE_PIN V25   IOSTANDARD LVCMOS33 } [get_ports { spi2_sd_io[3] }]; # jb[2]

## GPIOs (0 - 17)
## Buttons
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS12 } [get_ports { gpio_io[0] }]; # Sch=btnc
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS12 } [get_ports { gpio_io[1] }]; # Sch=btnd
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS12 } [get_ports { gpio_io[2] }]; # Sch=btnl
set_property -dict { PACKAGE_PIN C19   IOSTANDARD LVCMOS12 } [get_ports { gpio_io[3] }]; # Sch=btnr
set_property -dict { PACKAGE_PIN B19   IOSTANDARD LVCMOS12 } [get_ports { gpio_io[4] }]; # Sch=btnu
## LEDs
set_property -dict { PACKAGE_PIN V20   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[5] }]; # Sch=led[4]
set_property -dict { PACKAGE_PIN V26   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[6] }]; # Sch=led[5]
set_property -dict { PACKAGE_PIN W24   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[7] }]; # Sch=led[6]
set_property -dict { PACKAGE_PIN W23   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[8] }]; # Sch=led[7]
## Switches
set_property -dict { PACKAGE_PIN H24   IOSTANDARD LVCMOS12 } [get_ports { gpio_io[9] }]; # Sch=sw[2]
set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS12 } [get_ports { gpio_io[10] }]; # Sch=sw[3]
set_property -dict { PACKAGE_PIN N19   IOSTANDARD LVCMOS12 } [get_ports { gpio_io[11] }]; # Sch=sw[4]
set_property -dict { PACKAGE_PIN P19   IOSTANDARD LVCMOS12 } [get_ports { gpio_io[12] }]; # Sch=sw[5]
set_property -dict { PACKAGE_PIN P26   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[13] }]; # Sch=sw[6]

## FMA dummy
set_property -dict { PACKAGE_PIN P27   IOSTANDARD LVCMOS33 } [get_ports { spi_slave_cs_io }]; # Sch=sw[7]
set_property -dict { PACKAGE_PIN F20   IOSTANDARD LVCMOS12 } [get_ports { spi_slave_sck_io }]; # Sch=fmc_clk0_m2c_p
set_property -dict { PACKAGE_PIN N26   IOSTANDARD LVCMOS12 } [get_ports { spi_slave_miso_io }]; # Sch=fmc_ha_n[03]
set_property -dict { PACKAGE_PIN N25   IOSTANDARD LVCMOS12 } [get_ports { spi_slave_mosi_io }]; # Sch=fmc_ha_p[03]

## PDM2PCM
set_property -dict { PACKAGE_PIN K29   IOSTANDARD LVCMOS12 } [get_ports { pdm2pcm_clk_io }]; # Sch=fmc_ha_n[00]
set_property -dict { PACKAGE_PIN K28   IOSTANDARD LVCMOS12 } [get_ports { pdm2pcm_pdm_io }]; # Sch=fmc_ha_p[00]

## I2S
set_property -dict { PACKAGE_PIN L28   IOSTANDARD LVCMOS12 } [get_ports { i2s_sck_io }]; # Sch=fmc_ha_n[01]
set_property -dict { PACKAGE_PIN M28   IOSTANDARD LVCMOS12 } [get_ports { i2s_ws_io }]; # Sch=fmc_ha_p[01]
set_property -dict { PACKAGE_PIN P22   IOSTANDARD LVCMOS12 } [get_ports { i2s_sd_io }]; # Sch=fmc_ha_n[02]
