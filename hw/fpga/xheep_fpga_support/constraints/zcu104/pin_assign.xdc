# Copyright 2026 X-HEEP contibutors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# CLOCK
set_property -dict {PACKAGE_PIN AH18 IOSTANDARD DIFF_SSTL12} [get_ports clk_300mhz_p]
set_property -dict {PACKAGE_PIN AH17 IOSTANDARD DIFF_SSTL12} [get_ports clk_300mhz_n]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_tck_i]

# RESET
set_property -dict {PACKAGE_PIN M11 IOSTANDARD LVCMOS33} [get_ports rst_i]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_i]

# LEDS
set_property -dict {PACKAGE_PIN D5 IOSTANDARD LVCMOS33} [get_ports rst_led_o]
set_property -dict {PACKAGE_PIN D6 IOSTANDARD LVCMOS33} [get_ports clk_led_o]
set_property -dict {PACKAGE_PIN A5 IOSTANDARD LVCMOS33} [get_ports exit_valid_o]
set_property -dict {PACKAGE_PIN B5 IOSTANDARD LVCMOS33} [get_ports exit_value_o]

# SWITCHES
set_property -dict {PACKAGE_PIN E4 IOSTANDARD LVCMOS33} [get_ports execute_from_flash_i]
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports boot_select_i]

# FLASH
# QSPI
# Q0 / MOSI
# Q1 / MISO
# Q2 / nWP
# Q3 / nHLD
set_property -dict {PACKAGE_PIN L10 IOSTANDARD LVCMOS33} [get_ports spi_flash_csb_o]
set_property -dict {PACKAGE_PIN J9 IOSTANDARD LVCMOS33} [get_ports spi_flash_sck_o]
set_property -dict {PACKAGE_PIN M10 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[0]}]
set_property -dict {PACKAGE_PIN K9 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[1]}]
set_property -dict {PACKAGE_PIN M8 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[2]}]
set_property -dict {PACKAGE_PIN K8 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[3]}]

# UART
set_property -dict {PACKAGE_PIN G8 IOSTANDARD LVCMOS33} [get_ports uart_tx_o]
set_property -dict {PACKAGE_PIN G6 IOSTANDARD LVCMOS33} [get_ports uart_rx_i]

# JTAG
set_property -dict {PACKAGE_PIN H8 IOSTANDARD LVCMOS33} [get_ports jtag_tdi_i]
set_property -dict {PACKAGE_PIN J6 IOSTANDARD LVCMOS33} [get_ports jtag_tdo_o]
set_property -dict {PACKAGE_PIN G7 IOSTANDARD LVCMOS33} [get_ports jtag_tms_i]
set_property -dict {PACKAGE_PIN H6 IOSTANDARD LVCMOS33} [get_ports jtag_tck_i]
set_property -dict {PACKAGE_PIN M9 IOSTANDARD LVCMOS33} [get_ports jtag_trst_ni]

# I2C
set_property -dict {PACKAGE_PIN J7 IOSTANDARD LVCMOS33} [get_ports i2c_scl_io]
set_property -dict {PACKAGE_PIN H7 IOSTANDARD LVCMOS33} [get_ports i2c_sda_io]

## The following pins are sent to the FMC connector, using the LA pins as single-ended.
## The bank only supports up to 1.8 V.

# SPI SD
set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS18} [get_ports spi_csb_o]
set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS18} [get_ports spi_sck_o]
set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[0]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[1]}]
set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[2]}]
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[3]}]

# GPIOs
set_property -dict {PACKAGE_PIN D11 IOSTANDARD LVCMOS18} [get_ports {gpio_io[0]}]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS18} [get_ports {gpio_io[1]}]
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS18} [get_ports {gpio_io[2]}]
set_property -dict {PACKAGE_PIN A7 IOSTANDARD LVCMOS18} [get_ports {gpio_io[3]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVCMOS18} [get_ports {gpio_io[4]}]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS18} [get_ports {gpio_io[5]}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS18} [get_ports {gpio_io[6]}]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS18} [get_ports {gpio_io[7]}]
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS18} [get_ports {gpio_io[8]}]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS18} [get_ports {gpio_io[9]}]
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS18} [get_ports {gpio_io[10]}]
set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS18} [get_ports {spi_slave_sck_io}]
set_property -dict {PACKAGE_PIN F11 IOSTANDARD LVCMOS18} [get_ports {spi_slave_cs_io}]
set_property -dict {PACKAGE_PIN E10 IOSTANDARD LVCMOS18} [get_ports {spi_slave_miso_io}]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS18} [get_ports {spi_slave_mosi_io}]
set_property -dict {PACKAGE_PIN A11 IOSTANDARD LVCMOS18} [get_ports {gpio_io[11]}]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS18} [get_ports {gpio_io[12]}]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS18} [get_ports {gpio_io[13]}]

# PDM2PCM
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVCMOS18} [get_ports pdm2pcm_clk_io]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS18} [get_ports pdm2pcm_pdm_io]

# I2S
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS18} [get_ports i2s_sck_io]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS18} [get_ports i2s_ws_io]
set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS18} [get_ports i2s_sd_io]

# SPI2
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS18} [get_ports {spi2_csb_o[0]}]
set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVCMOS18} [get_ports {spi2_csb_o[1]}]
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS18} [get_ports spi2_sck_o]
set_property -dict {PACKAGE_PIN F12 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[0]}]
set_property -dict {PACKAGE_PIN E12 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[1]}]
set_property -dict {PACKAGE_PIN H13 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[2]}]
set_property -dict {PACKAGE_PIN H12 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[3]}]
