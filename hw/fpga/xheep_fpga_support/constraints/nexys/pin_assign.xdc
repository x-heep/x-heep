# Copyright 2026 X-HEEP contibutors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

## Clock signal
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {clk_i}]; #IO_L12P_T1_MRCC_35 Sch=clk100mhz


set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports {rst_i}]; #IO_L3P_T0_DQS_AD1P_15 Sch=cpu_resetn

## LEDs
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports {rst_led_o}];
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {clk_led_o}];
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {exit_valid_o}];
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {exit_value_o}];
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_led_o_OBUF]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_led_o_OBUF]

##Switches
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {execute_from_flash_i}]; #Sch=sw[1]
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {boot_select_i}]; #Sch=sw[2]

##Switches
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {jtag_trst_ni}]; #IO_L24N_T3_RS0_15 Sch=sw[0]

##Pmod Headers
##Pmod Header JA
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports {spi_flash_csb_o}]; #IO_L20N_T3_A19_15 Sch=ja[1]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sck_o}]; #IO_L21N_T3_DQS_A18_15 Sch=ja[2]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[0]}]; #IO_L21P_T3_DQS_15 Sch=ja[3]
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[1]}]; #IO_L18N_T2_A23_15 Sch=ja[4]
set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[2]}]; #IO_L16N_T2_A27_15 Sch=ja[7]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_io[3]}]; #IO_L16P_T2_A28_15 Sch=ja[8]
#set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {gpio_io[6]}]; #IO_L22N_T3_A16_15 Sch=ja[9]
#set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS33} [get_ports {gpio_io[7]}]; #IO_L22P_T3_A17_15 Sch=ja[10]

##Pmod Header JC
set_property -dict {PACKAGE_PIN K1 IOSTANDARD LVCMOS33} [get_ports {spi_csb_o}]; #IO_L23N_T3_35 Sch=jc[1]
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33} [get_ports {spi_sck_o}]; #IO_L19N_T3_VREF_35 Sch=jc[2]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports {spi_sd_io[0]}]; #IO_L22N_T3_35 Sch=jc[3]
set_property -dict {PACKAGE_PIN G6 IOSTANDARD LVCMOS33} [get_ports {spi_sd_io[1]}]; #IO_L19P_T3_35 Sch=jc[4]
set_property -dict {PACKAGE_PIN E7 IOSTANDARD LVCMOS33} [get_ports {spi_sd_io[2]}]; #IO_L6P_T0_35 Sch=jc[7]
set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS33} [get_ports {spi_sd_io[3]}]; #IO_L22P_T3_35 Sch=jc[8]
#set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports {clk_out}]; #IO_L21P_T3_DQS_35 Sch=jc[9]
#set_property -dict {PACKAGE_PIN E6 IOSTANDARD LVCMOS33} [get_ports {JC[10]}]; #IO_L5P_T0_AD13P_35 Sch=jc[10]

##USB-RS232 Interface
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports {uart_rx_i}]; #IO_L7P_T1_AD6P_35 Sch=uart_txd_in
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports {uart_tx_o}]; #IO_L11N_T1_SRCC_35 Sch=uart_rxd_out

##Pmod Header JB
#set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS33} [get_ports {JB[1]}]; #IO_L1P_T0_AD0P_15 Sch=jb[1]
#set_property -dict {PACKAGE_PIN F16 IOSTANDARD LVCMOS33} [get_ports {JB[2]}]; #IO_L14N_T2_SRCC_15 Sch=jb[2]
#set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33} [get_ports {uart_tx_o}]; #IO_L13N_T2_MRCC_15 Sch=jb[3]
#set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS33} [get_ports {uart_rx_i}]; #IO_L15P_T2_DQS_15 Sch=jb[4]
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS33} [get_ports {jtag_tms_i}]; #IO_L11N_T1_SRCC_15 Sch=jb[7]
set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVCMOS33} [get_ports {jtag_tdi_i}]; #IO_L5P_T0_AD9P_15 Sch=jb[8]
set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} [get_ports {jtag_tdo_o}]; #IO_0_15 Sch=jb[9]
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports {jtag_tck_i}]; #IO_L13P_T2_MRCC_15 Sch=jb[10]

## LEDs
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {spi2_sd_io[1]}];
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {spi2_sd_io[2]}];
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {spi2_sd_io[3]}];
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {i2c_scl_io}];
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {i2c_sda_io}];
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {gpio_io[5]}];
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {gpio_io[6]}];
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {gpio_io[7]}];
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {gpio_io[8]}];
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {gpio_io[9]}];
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {gpio_io[10]}];

##Buttons
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {gpio_io[0]}]; #IO_L9P_T1_DQS_14 Sch=btnc
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports {gpio_io[1]}]; #IO_L4N_T0_D05_14 Sch=btnu
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports {gpio_io[2]}]; #IO_L12P_T1_MRCC_14 Sch=btnl
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports {gpio_io[3]}]; #IO_L10N_T1_D15_14 Sch=btnr
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {gpio_io[4]}]; #IO_L9N_T1_DQS_D13_14 Sch=btnd

##7 segment display
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports { spi_slave_sck_io }];
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33} [get_ports { spi_slave_cs_io }];
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports { spi_slave_miso_io }];
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33} [get_ports { spi_slave_mosi_io }];
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports { pdm2pcm_clk_io }];
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports { pdm2pcm_pdm_io }];
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports { i2s_sck_io }];
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports { i2s_ws_io }];
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33} [get_ports { i2s_sd_io }];
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[13] }]; #IO_L23P_T3_FOE_B_15 Sch=an[0]
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[12] }]; #IO_L23N_T3_FWE_B_15 Sch=an[1]
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { gpio_io[11] }]; #IO_L24P_T3_A01_D17_14 Sch=an[2]
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { spi2_csb_o[0] }]; #IO_L19P_T3_A22_15 Sch=an[3]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { spi2_csb_o[1] }]; #IO_L8N_T1_D12_14 Sch=an[4]
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { spi2_sck_o }]; #IO_L14P_T2_SRCC_14 Sch=an[5]
set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports { spi2_sd_io[0] }]; #IO_L23P_T3_35 Sch=an[6]


set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_tck_i_IBUF]

