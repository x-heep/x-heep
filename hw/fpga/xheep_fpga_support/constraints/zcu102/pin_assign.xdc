# Copyright 2026 X-HEEP contibutors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# CLOCK
set_property -dict {PACKAGE_PIN AL8 IOSTANDARD DIFF_SSTL12} [get_ports clk_125mhz_p]
set_property -dict {PACKAGE_PIN AL7 IOSTANDARD DIFF_SSTL12} [get_ports clk_125mhz_n]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_tck_i]

# RESET
set_property -dict {PACKAGE_PIN AM13 IOSTANDARD LVCMOS33} [get_ports rst_i]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_i]

# LEDS
set_property -dict {PACKAGE_PIN AG14 IOSTANDARD LVCMOS33} [get_ports rst_led_o]
set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVCMOS33} [get_ports clk_led_o]
set_property -dict {PACKAGE_PIN AE13 IOSTANDARD LVCMOS33} [get_ports exit_valid_o]
set_property -dict {PACKAGE_PIN AJ14 IOSTANDARD LVCMOS33} [get_ports exit_value_o]

# SWITCHES
set_property -dict {PACKAGE_PIN AN14 IOSTANDARD LVCMOS33} [get_ports execute_from_flash_i]
set_property -dict {PACKAGE_PIN AP14 IOSTANDARD LVCMOS33} [get_ports boot_select_i]

# FLASH
# QSPI
# Q0 / MOSI
# Q1 / MISO
# Q2 / nWP
# Q3 / nHLD
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS33} [get_ports spi_flash_csb_o]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports spi_flash_sck_o]
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[0]}]
set_property -dict {PACKAGE_PIN E20 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[1]}]
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[2]}]
set_property -dict {PACKAGE_PIN D22 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[3]}]

# UART
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS33} [get_ports uart_tx_o]
set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVCMOS33} [get_ports uart_rx_i]

# JTAG
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS33} [get_ports jtag_tdi_i]
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS33} [get_ports jtag_tdo_o]
set_property -dict {PACKAGE_PIN A22 IOSTANDARD LVCMOS33} [get_ports jtag_tms_i]
set_property -dict {PACKAGE_PIN C21 IOSTANDARD LVCMOS33} [get_ports jtag_tck_i]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS33} [get_ports jtag_trst_ni]

# I2C
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS33} [get_ports i2c_scl_io]
set_property -dict {PACKAGE_PIN A21 IOSTANDARD LVCMOS33} [get_ports i2c_sda_io]

## The following pins are sent to the FMC connector, using the LA pins as single-ended.
## The bank only supports up to 1.8 V.

# SPI SD
set_property -dict {PACKAGE_PIN AC2 IOSTANDARD LVCMOS18} [get_ports spi_csb_o]
set_property -dict {PACKAGE_PIN AC1 IOSTANDARD LVCMOS18} [get_ports spi_sck_o]
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[0]}]
set_property -dict {PACKAGE_PIN W4 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[1]}]
set_property -dict {PACKAGE_PIN AC7 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[2]}]
set_property -dict {PACKAGE_PIN AC6 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[3]}]

# GPIOs
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS18} [get_ports {gpio_io[0]}]
set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVCMOS18} [get_ports {gpio_io[1]}]
set_property -dict {PACKAGE_PIN U6 IOSTANDARD LVCMOS18} [get_ports {gpio_io[2]}]
set_property -dict {PACKAGE_PIN V6 IOSTANDARD LVCMOS18} [get_ports {gpio_io[3]}]
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS18} [get_ports {gpio_io[4]}]
set_property -dict {PACKAGE_PIN T7 IOSTANDARD LVCMOS18} [get_ports {gpio_io[5]}]
set_property -dict {PACKAGE_PIN K12 IOSTANDARD LVCMOS18} [get_ports {gpio_io[6]}]
set_property -dict {PACKAGE_PIN L12 IOSTANDARD LVCMOS18} [get_ports {gpio_io[7]}]
set_property -dict {PACKAGE_PIN N12 IOSTANDARD LVCMOS18} [get_ports {gpio_io[8]}]
set_property -dict {PACKAGE_PIN P12 IOSTANDARD LVCMOS18} [get_ports {gpio_io[9]}]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS18} [get_ports {gpio_io[10]}]
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS18} [get_ports {spi_slave_sck_io}]
set_property -dict {PACKAGE_PIN Y9 IOSTANDARD LVCMOS18} [get_ports {spi_slave_cs_io}]
set_property -dict {PACKAGE_PIN Y10 IOSTANDARD LVCMOS18} [get_ports {spi_slave_miso_io}]
set_property -dict {PACKAGE_PIN AB5 IOSTANDARD LVCMOS18} [get_ports {spi_slave_mosi_io}]
set_property -dict {PACKAGE_PIN AB6 IOSTANDARD LVCMOS18} [get_ports {gpio_io[11]}]
set_property -dict {PACKAGE_PIN U4 IOSTANDARD LVCMOS18} [get_ports {gpio_io[12]}]
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS18} [get_ports {gpio_io[13]}]

# PDM2PCM
set_property -dict {PACKAGE_PIN Y2 IOSTANDARD LVCMOS18} [get_ports pdm2pcm_clk_io]
set_property -dict {PACKAGE_PIN Y1 IOSTANDARD LVCMOS18} [get_ports pdm2pcm_pdm_io]

# I2S
set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS18} [get_ports i2s_sck_io]
set_property -dict {PACKAGE_PIN V3 IOSTANDARD LVCMOS18} [get_ports i2s_ws_io]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS18} [get_ports i2s_sd_io]

# SPI2 -- NO LPC 
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS18} [get_ports {spi2_csb_o[0]}]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS18} [get_ports {spi2_csb_o[1]}]
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS18} [get_ports spi2_sck_o]
set_property -dict {PACKAGE_PIN V8 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[0]}]
set_property -dict {PACKAGE_PIN U8 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[1]}]
set_property -dict {PACKAGE_PIN U9 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[2]}]
set_property -dict {PACKAGE_PIN L11 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[3]}]
