# Copyright 2026 X-HEEP contributors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# Avnet (Tria) AUBoard-15P, part xcau15p-ffvb676-2-e.
# Pin locations and I/O standards are those of Avnet's board files (aub15p 1.1, part0_pins.xml).
# The board files themselves are not needed to build.
#
# I/O voltages: bank 64 and 65 are 1.2 V, bank 84 is 1.8 V, bank 85 is 3.3 V.
# Banks 66 and 86 (FMC connector) follow jumper J46: 1.8 V (default) or 1.2 V.

## Configuration: bank 0 is 1.8 V on this board
set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

## Clock signal: 300 MHz LVDS oscillator on a 1.2 V bank (SYS_CLK_P/N)
set_property -dict {PACKAGE_PIN AD21 IOSTANDARD DIFF_SSTL12} [get_ports clk_300mhz_p]
set_property -dict {PACKAGE_PIN AE21 IOSTANDARD DIFF_SSTL12} [get_ports clk_300mhz_n]

## Reset: push button SYS_RST_N (printed PB3), active low
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS12} [get_ports rst_i]
# The reset reaches clock multiplexers in X-HEEP's reset generator, and the button is not on a clock pin.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_i_IBUF]

## Boot select: slide switch 1 (SLIDE_SW1)
set_property -dict {PACKAGE_PIN P19 IOSTANDARD LVCMOS12} [get_ports boot_select_i]

## Red LEDs 1 to 4 (RED_LED1..4), active high
set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS33} [get_ports rst_led_o]
set_property -dict {PACKAGE_PIN B10 IOSTANDARD LVCMOS33} [get_ports clk_led_o]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports exit_valid_o]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports exit_value_o]

## UART: channel B of the on-board FT2232 (the USB JTAG/UART port).
## Named from the FPGA: uart_tx_o goes to the computer.
set_property -dict {PACKAGE_PIN AF15 IOSTANDARD LVCMOS18} [get_ports uart_tx_o]
set_property -dict {PACKAGE_PIN AF14 IOSTANDARD LVCMOS18} [get_ports uart_rx_i]

## JTAG: mikroBUS (Click) header J20, 3.3 V. The header must hold no Click board.
## The pulls keep the debug transport idle when no probe is connected.
##   signal        J20 pin (Click name)
##   jtag_trst_ni  2 (RST)
##   jtag_tms_i    3 (CS)
##   jtag_tdi_i    4 (SCK)
##   jtag_tck_i    5 (MISO)
##   jtag_tdo_o    6 (MOSI)
##   3.3 V and GND are J20 pins 7 and 8.
set_property -dict {PACKAGE_PIN K10 IOSTANDARD LVCMOS33 PULLTYPE PULLUP} [get_ports jtag_trst_ni]
set_property -dict {PACKAGE_PIN H11 IOSTANDARD LVCMOS33 PULLTYPE PULLUP} [get_ports jtag_tms_i]
set_property -dict {PACKAGE_PIN G11 IOSTANDARD LVCMOS33 PULLTYPE PULLUP} [get_ports jtag_tdi_i]
set_property -dict {PACKAGE_PIN G10 IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN} [get_ports jtag_tck_i]
set_property -dict {PACKAGE_PIN G9 IOSTANDARD LVCMOS33} [get_ports jtag_tdo_o]
# The JTAG clock pin is in a high-density bank, which has no dedicated route to X-HEEP's clock multiplexer.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_tck_i_IBUF]

## I2C: the board's main I2C bus (MAIN_I2C_SCL/SDA), 3.3 V, pulled up on the board.
## On the bus: mux PCA9544A at 0x70 (channel 3: temperature sensor STTS22H at 0x3F)
## and the MAC-ID EEPROM at 0x50 and 0x58.
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33 PULLTYPE PULLUP} [get_ports i2c_scl_io]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33 PULLTYPE PULLUP} [get_ports i2c_sda_io]

## GPIO 0 to 3: push buttons PB_SW1..4 (PB_SW1..3 are printed PB4..PB6), active high
## (bank 65 is a high-performance bank: LVCMOS12 drives at most 8 mA)
set_property -dict {PACKAGE_PIN R21 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {gpio_io[0]}]
set_property -dict {PACKAGE_PIN R20 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {gpio_io[1]}]
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {gpio_io[2]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {gpio_io[3]}]

## GPIO 4 to 6: slide switches SLIDE_SW2..4
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {gpio_io[4]}]
set_property -dict {PACKAGE_PIN P23 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {gpio_io[5]}]
set_property -dict {PACKAGE_PIN N23 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {gpio_io[6]}]

## GPIO 7: mikroBUS (Click) header J20, PWM pin, 3.3 V
set_property -dict {PACKAGE_PIN J9 IOSTANDARD LVCMOS33} [get_ports {gpio_io[7]}]

## GPIO 8 to 10: RGB LED 1 blue, green, red (1.8 V), active high
set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVCMOS18} [get_ports {gpio_io[8]}]
set_property -dict {PACKAGE_PIN AD15 IOSTANDARD LVCMOS18} [get_ports {gpio_io[9]}]
set_property -dict {PACKAGE_PIN AE15 IOSTANDARD LVCMOS18} [get_ports {gpio_io[10]}]

## GPIO 11 and 12: RGB LED 2 blue, green (1.2 V), active high
set_property -dict {PACKAGE_PIN N24 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {gpio_io[11]}]
set_property -dict {PACKAGE_PIN P24 IOSTANDARD LVCMOS12 DRIVE 8} [get_ports {gpio_io[12]}]

## The board has no Pmod connector. The remaining X-HEEP pads are on the FMC connector, on
## LA pins of bank 66. They need J46 in its default position (1.8 V) and are not connected
## to anything unless a mezzanine card is fitted.

## FLASH: FMC LA00, LA02, LA03
set_property -dict {PACKAGE_PIN F24 IOSTANDARD LVCMOS18} [get_ports spi_flash_csb_o]      ; # LA00_P (G6)
set_property -dict {PACKAGE_PIN F25 IOSTANDARD LVCMOS18} [get_ports spi_flash_sck_o]      ; # LA00_N (G7)
set_property -dict {PACKAGE_PIN H26 IOSTANDARD LVCMOS18} [get_ports {spi_flash_sd_io[0]}] ; # LA02_P (H7)
set_property -dict {PACKAGE_PIN G26 IOSTANDARD LVCMOS18} [get_ports {spi_flash_sd_io[1]}] ; # LA02_N (H8)
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS18} [get_ports {spi_flash_sd_io[2]}] ; # LA03_P (G9)
set_property -dict {PACKAGE_PIN M21 IOSTANDARD LVCMOS18} [get_ports {spi_flash_sd_io[3]}] ; # LA03_N (G10)

## SPI SLAVE: FMC LA01 (clock-capable pair), LA04
set_property -dict {PACKAGE_PIN J23 IOSTANDARD LVCMOS18} [get_ports spi_slave_sck_io]     ; # LA01_P (D8)
set_property -dict {PACKAGE_PIN J24 IOSTANDARD LVCMOS18} [get_ports spi_slave_cs_io]      ; # LA01_N (D9)
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS18} [get_ports spi_slave_mosi_io]    ; # LA04_P (H10)
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS18} [get_ports spi_slave_miso_io]    ; # LA04_N (H11)

## SPI HOST: FMC LA05, LA06, LA08
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS18} [get_ports spi_csb_o]            ; # LA05_P (D11)
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS18} [get_ports spi_sck_o]            ; # LA05_N (D12)
set_property -dict {PACKAGE_PIN D26 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[0]}]       ; # LA06_P (C10)
set_property -dict {PACKAGE_PIN C26 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[1]}]       ; # LA06_N (C11)
set_property -dict {PACKAGE_PIN K25 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[2]}]       ; # LA08_P (G12)
set_property -dict {PACKAGE_PIN K26 IOSTANDARD LVCMOS18} [get_ports {spi_sd_io[3]}]       ; # LA08_N (G13)

## SPI2: FMC LA09, LA10, LA12, LA13
set_property -dict {PACKAGE_PIN H21 IOSTANDARD LVCMOS18} [get_ports {spi2_csb_o[0]}]      ; # LA09_P (D14)
set_property -dict {PACKAGE_PIN H22 IOSTANDARD LVCMOS18} [get_ports {spi2_csb_o[1]}]      ; # LA09_N (D15)
set_property -dict {PACKAGE_PIN E25 IOSTANDARD LVCMOS18} [get_ports spi2_sck_o]           ; # LA10_P (C14)
set_property -dict {PACKAGE_PIN E26 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[0]}]      ; # LA10_N (C15)
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[1]}]      ; # LA12_P (G15)
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[2]}]      ; # LA12_N (G16)
set_property -dict {PACKAGE_PIN K22 IOSTANDARD LVCMOS18} [get_ports {spi2_sd_io[3]}]      ; # LA13_P (D17)

## PDM2PCM: FMC LA14
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS18} [get_ports pdm2pcm_clk_io]       ; # LA14_P (C18)
set_property -dict {PACKAGE_PIN K20 IOSTANDARD LVCMOS18} [get_ports pdm2pcm_pdm_io]       ; # LA14_N (C19)

## I2S: FMC LA15, LA16
set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVCMOS18} [get_ports i2s_sck_io]           ; # LA15_P (H19)
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVCMOS18} [get_ports i2s_ws_io]            ; # LA15_N (H20)
set_property -dict {PACKAGE_PIN L24 IOSTANDARD LVCMOS18} [get_ports i2s_sd_rx_io]         ; # LA16_P (G18)
set_property -dict {PACKAGE_PIN L25 IOSTANDARD LVCMOS18} [get_ports i2s_sd_tx_io]         ; # LA16_N (G19)
