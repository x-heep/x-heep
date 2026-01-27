# CLOCK
set_property -dict {PACKAGE_PIN D8 IOSTANDARD DIFF_SSTL12} [get_ports clk_100mhz_p]
set_property -dict {PACKAGE_PIN D6 IOSTANDARD DIFF_SSTL12} [get_ports clk_100mhz_n]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_tck_i_IBUF]

## LEDS (8 outputs)

set_property PACKAGE_PIN AF5 [get_ports {gpio_io[11]}]
set_property PACKAGE_PIN AE7 [get_ports {gpio_io[12]}]
set_property PACKAGE_PIN AH2 [get_ports {gpio_io[13]}]
# set_property PACKAGE_PIN AE5 [get_ports {PL_USER_LED[3]}]
# set_property PACKAGE_PIN AH1 [get_ports {PL_USER_LED[4]}]
# set_property PACKAGE_PIN AE4 [get_ports {PL_USER_LED[5]}]
# set_property PACKAGE_PIN AG1 [get_ports {PL_USER_LED[6]}]
# set_property PACKAGE_PIN AF2 [get_ports {PL_USER_LED[7]}]

## RGB LEDS (12 outputs)

# LED RESET
# set_property PACKAGE_PIN AD7 [get_ports {PL_LEDRGB0[0]}]
# set_property PACKAGE_PIN AD9 [get_ports {PL_LEDRGB0[1]}]
set_property PACKAGE_PIN AE9 [get_ports {rst_led_o}]

# LED CLOCK
# set_property PACKAGE_PIN AG9 [get_ports {PL_LEDRGB[0]}]
# set_property PACKAGE_PIN AE8 [get_ports {PL_LEDRGB1[1]}]
set_property PACKAGE_PIN AF8 [get_ports {clk_led_o}]

# LED EXIT_VALID
# set_property PACKAGE_PIN AF7 [get_ports {PL_LEDRGB2[0]}]
set_property PACKAGE_PIN AG8 [get_ports {exit_valid_o}]
# set_property PACKAGE_PIN AG6 [get_ports {PL_LEDRGB2[2]}]

#  LED EXIT_VALUE
set_property PACKAGE_PIN AF6 [get_ports {exit_value_o}]
# set_property PACKAGE_PIN AH6 [get_ports {PL_LEDRGB3[1]}]
# set_property PACKAGE_PIN AG5 [get_ports {PL_LEDRGB3[2]}]

# LED BUFFERS
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_led_OBUF]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_out_OBUF]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_led_OBUF]

## Pushbutton Switches (4 inputs)

# set_property PACKAGE_PIN AB6 [get_ports {PL_USER_PB[0]}]
# set_property PACKAGE_PIN AB7 [get_ports {PL_USER_PB[1]}]
# set_property PACKAGE_PIN AB2 [get_ports {PL_USER_PB[2]}]
# RESET
set_property PACKAGE_PIN AC6 [get_ports {rst_i}]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_i_IBUF]

## Slide Switches (8 inputs)

set_property PACKAGE_PIN AB1 [get_ports {execute_from_flash_i}]
set_property PACKAGE_PIN AF1 [get_ports {boot_select_i}]

# set_property PACKAGE_PIN AE3 [get_ports {PL_USER_SW[2]}]
# set_property PACKAGE_PIN AC2 [get_ports {PL_USER_SW[3]}]
# set_property PACKAGE_PIN AC1 [get_ports {PL_USER_SW[4]}]
# set_property PACKAGE_PIN AD6 [get_ports {PL_USER_SW[5]}]
# set_property PACKAGE_PIN AD1 [get_ports {PL_USER_SW[6]}]
# set_property PACKAGE_PIN AD2 [get_ports {PL_USER_SW[7]}]

## PMODS (22 pins)

# FLASH UART JTAG I2C
# QSPI
# Q0 / MOSI
# Q1 / MISO
# Q2 / nWP
# Q3 / nHLD
set_property PACKAGE_PIN J12 [get_ports {spi_flash_sck_o}] ; # Pmoda[0]
set_property PACKAGE_PIN H12 [get_ports {spi_flash_sd_io[1]}] ; # Pmoda[1]
set_property PACKAGE_PIN H11 [get_ports {spi_flash_sd_io[3]}] ; # Pmoda[2]
# set_property PACKAGE_PIN G10 [get_ports {JA_tri_io[3]}]

set_property PACKAGE_PIN K13 [get_ports {spi_flash_csb_o}] ; # Pmoda[4]
set_property PACKAGE_PIN K12 [get_ports {spi_flash_sd_io[0]}] ; # Pmoda[5]
set_property PACKAGE_PIN J11 [get_ports  {spi_flash_sd_io[2]}] ; # Pmoda[6]
set_property PACKAGE_PIN J10 [get_ports jtag_trst_ni] ; # Pmoda[7]

set_property PACKAGE_PIN E12 [get_ports uart_tx_o] ; # Pmodb[0]
set_property PACKAGE_PIN D11 [get_ports jtag_tdi_i] ; # Pmob[1]
set_property PACKAGE_PIN B11 [get_ports jtag_tms_i] ; # Pmodb[2]
set_property PACKAGE_PIN A10 [get_ports  {i2c_sda_io}] ; # Pmodb[3]
set_property PACKAGE_PIN C11 [get_ports  uart_rx_i] ; # Pmodb[4]
set_property PACKAGE_PIN B10 [get_ports jtag_tck_i] ; # Pmodb[5]
set_property PACKAGE_PIN A12 [get_ports jtag_tdo_o] ; # Pmodb[6]
set_property PACKAGE_PIN A11 [get_ports  {i2c_scl_io}] ; # Pmodb[7]

set_property PACKAGE_PIN F12 [get_ports spi_csb_o] ; # Pmodab[0]
set_property PACKAGE_PIN G11 [get_ports spi_sck_o] ; # Pmodab[1]
set_property PACKAGE_PIN E10 [get_ports {spi_sd_io[0]}] ; # Pmodab[2]
set_property PACKAGE_PIN D10 [get_ports {spi_sd_io[1]}] ; # Pmodab[3]
set_property PACKAGE_PIN F10 [get_ports {spi_sd_io[2]}] ; # Pmodab[4]
set_property PACKAGE_PIN F11 [get_ports {spi_sd_io[3]}] ; # Pmodab[5]

## Rasbery PI Headers

set_property PACKAGE_PIN AF10 [get_ports {gpio_io[0]}] ; # rpi_gpio_tri_io[0]
set_property PACKAGE_PIN AG10 [get_ports {gpio_io[1]}] ; # rpi_gpio_tri_io[1]
set_property PACKAGE_PIN AC12 [get_ports {gpio_io[2]}] ; # rpi_gpio_tri_io[2]
set_property PACKAGE_PIN AD12 [get_ports {gpio_io[3]}] ; # rpi_gpio_tri_io[3]
set_property PACKAGE_PIN AE12 [get_ports {gpio_io[4]}] ; # rpi_gpio_tri_io[4]
set_property PACKAGE_PIN AE10 [get_ports {gpio_io[5]}] ; # rpi_gpio_tri_io[5]
set_property PACKAGE_PIN AB11 [get_ports {gpio_io[6]}] ; # rpi_gpio_tri_io[6]
set_property PACKAGE_PIN AD11 [get_ports {gpio_io[7]}] ; # rpi_gpio_tri_io[7]
set_property PACKAGE_PIN AG11 [get_ports {gpio_io[8]}] ; # rpi_gpio_tri_io[8]
set_property PACKAGE_PIN AH11 [get_ports {gpio_io[9]}] ; # rpi_gpio_tri_io[9]
set_property PACKAGE_PIN AH12 [get_ports {gpio_io[10]}] ; # rpi_gpio_tri_io[10]

# SPI SLAVE
set_property PACKAGE_PIN AH10 [get_ports {spi_slave_sck_io}] ; # rpi_gpio_tri_io[11]
set_property PACKAGE_PIN AD10 [get_ports {spi_slave_cs_io}] ; # rpi_gpio_tri_io[12]
set_property PACKAGE_PIN AA11 [get_ports {spi_slave_miso_io}] ; # rpi_gpio_tri_io[13]
set_property PACKAGE_PIN AE15 [get_ports {spi_slave_mosi_io}] ; # rpi_gpio_tri_io[14]

# PDM2PCM
set_property PACKAGE_PIN AF13 [get_ports {pdm2pcm_clk_io}] ; # rpi_gpio_tri_io[15]
set_property PACKAGE_PIN AB10 [get_ports {pdm2pcm_pdm_io}] ; # rpi_gpio_tri_io[16]

# I2S
set_property PACKAGE_PIN AG14 [get_ports {i2s_sck_io}] ; # rpi_gpio_tri_io[17]
set_property PACKAGE_PIN AC11 [get_ports {i2s_ws_io}] ; # rpi_gpio_tri_io[18]
set_property PACKAGE_PIN AB9 [get_ports {i2s_sd_io}] ; # rpi_gpio_tri_io[19]

# SPI 2
set_property PACKAGE_PIN AA10 [get_ports {spi2_csb_o[0]}] ; # rpi_gpio_tri_io[20]
set_property PACKAGE_PIN Y9 [get_ports {spi2_csb_o[1]}] ; # rpi_gpio_tri_io[21]
set_property PACKAGE_PIN AH13 [get_ports {spi2_sck_o}] ; # rpi_gpio_tri_io[22]
set_property PACKAGE_PIN AG13 [get_ports {spi2_sd_io[0]}] ; # rpi_gpio_tri_io[23]
set_property PACKAGE_PIN AF12 [get_ports {spi2_sd_io[1]}] ; # rpi_gpio_tri_io[24]
set_property PACKAGE_PIN AF11 [get_ports {spi2_sd_io[2]}] ; # rpi_gpio_tri_io[25]
set_property PACKAGE_PIN AA8 [get_ports {spi2_sd_io[3]}] ; # rpi_gpio_tri_io[26]
# set_property PACKAGE_PIN AH14 [get_ports {RBP_GPIO_tri_io[27]}] ; # rpi_gpio_tri_io[27]

## Grove PL

# set_property PACKAGE_PIN AE14 [get_ports {PL_GRV_tri_io[0]}]
# set_property PACKAGE_PIN AE13 [get_ports {PL_GRV_tri_io[1]}]
# set_property PACKAGE_PIN AD15 [get_ports {PL_GRV_tri_io[2]}]
# set_property PACKAGE_PIN AD14 [get_ports {PL_GRV_tri_io[3]}]

## Servo PWMs

# set_property PACKAGE_PIN W14 [get_ports {SERVO[0]}]
# set_property PACKAGE_PIN Y14 [get_ports {SERVO[1]}]
# set_property PACKAGE_PIN W13 [get_ports {SERVO[2]}]
# set_property PACKAGE_PIN Y13 [get_ports {SERVO[3]}]

## Joystick Selection

# set_property PACKAGE_PIN AC13 [get_ports {SEL_JOYSTICK[0]}]

set_property BITSTREAM.CONFIG.UNUSEDPIN PULLDOWN [current_design] ; # pull-down to turn OFF unused  led
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design] ; # enable overtemp shutdown
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

## Audio I2C
set_property PACKAGE_PIN F5 [get_ports i2c_aic_scl_io]
set_property PACKAGE_PIN G5 [get_ports i2c_aic_sda_io]
set_property IOSTANDARD LVCMOS18 [get_ports i2c_aic*]

set_property PACKAGE_PIN E2 [get_ports {AIC_nRST[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {AIC_nRST[0]}]

## FPGA's sdata Output to AIC Codec's sdata Input
set_property PACKAGE_PIN G3 [get_ports AIC_sdata_o]
set_property IOSTANDARD LVCMOS18 [get_ports AIC_sdata_o]
## AIC Codec's sdata Output to FPGA sdata Input
set_property PACKAGE_PIN G4 [get_ports AIC_sdata_i]                   
set_property IOSTANDARD LVCMOS18 [get_ports AIC_sdata_i]
## FPGA sclk out to AIC Codec
set_property PACKAGE_PIN G1 [get_ports AIC_sclk_o]
set_property IOSTANDARD LVCMOS18 [get_ports AIC_sclk_o]
## FPGA lrclk out to AIC codec
set_property PACKAGE_PIN F2 [get_ports AIC_lrclk_o]
set_property IOSTANDARD LVCMOS18 [get_ports AIC_lrclk_o]
## FPGA mclk out to AIC codec
set_property PACKAGE_PIN F3 [get_ports AIC_mclk_o]
set_property IOSTANDARD LVCMOS18 [get_ports AIC_mclk_o]

## Camera loopback
# set_property PACKAGE_PIN AH3 [get_ports CAM0_IN[0]];
# set_property IOSTANDARD LVCMOS12 [get_ports CAM0_IN[0]];
# set_property PACKAGE_PIN AH4 [get_ports CAM0_IN[1]];
# set_property IOSTANDARD LVCMOS12 [get_ports CAM0_IN[1]];
# set_property PACKAGE_PIN AD4 [get_ports CAM0_IN[2]];
# set_property IOSTANDARD LVCMOS12 [get_ports CAM0_IN[2]];
# set_property PACKAGE_PIN K14 [get_ports CAM0_IN[3]];
# set_property IOSTANDARD LVCMOS33 [get_ports CAM0_IN[3]];
# set_property PACKAGE_PIN L14 [get_ports CAM0_IN[4]];
# set_property IOSTANDARD LVCMOS33 [get_ports CAM0_IN[4]];
# set_property PACKAGE_PIN AG3 [get_ports CAM0_OUT[0]];
# set_property IOSTANDARD LVCMOS12 [get_ports CAM0_OUT[0]];
# set_property PACKAGE_PIN AG4 [get_ports CAM0_OUT[1]];
# set_property IOSTANDARD LVCMOS12 [get_ports CAM0_OUT[1]];
# set_property PACKAGE_PIN AD5 [get_ports CAM0_OUT[2]];
# set_property IOSTANDARD LVCMOS12 [get_ports CAM0_OUT[2]];
# set_property PACKAGE_PIN J14 [get_ports CAM0_OUT[3]];

# PIN PROPERTY SETTINGS

# LED
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_io[11] gpio_io[12] gpio_io[13]}]
set_property DRIVE 8 [get_ports {gpio_io[11] gpio_io[12] gpio_io[13]}]

# LED RGB
set_property IOSTANDARD LVCMOS12 [get_ports {rst_led_o clk_led_o exit_valid_o exit_value_o}]

# BUTTON
set_property IOSTANDARD LVCMOS12 [get_ports {rst_i}]

# SWITCHES
set_property IOSTANDARD LVCMOS12 [get_ports {execute_from_flash_i boot_select_i}]

# QSPI PMOD-A
set_property IOSTANDARD LVCMOS33 [get_ports {spi_flash_sck_o spi_flash_sd_io[0] spi_flash_sd_io[1] spi_flash_sd_io[2] spi_flash_sd_io[3] spi_flash_csb_o}]

# UART / I2C / JTAG PMOD-B
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx_o uart_rx_i i2c_sda_io i2c_scl_io jtag_tdi_i jtag_tms_i jtag_tck_i jtag_tdo_o jtag_trst_ni}]

# RasPi GPIO
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_io[0] gpio_io[1] gpio_io[2] gpio_io[3] gpio_io[4] gpio_io[5] gpio_io[6] gpio_io[7] gpio_io[8] gpio_io[9] gpio_io[10]}]

# RasPi SPI / PDM / I2S / SPI2 
set_property IOSTANDARD LVCMOS33 [get_ports {spi_slave_sck_io spi_slave_cs_io spi_slave_miso_io spi_slave_mosi_io \
                                             pdm2pcm_clk_io pdm2pcm_pdm_io \
                                             i2s_sck_io i2s_ws_io i2s_sd_io \
                                             spi2_csb_o[0] spi2_csb_o[1] spi2_sck_o spi2_sd_io[0] spi2_sd_io[1] spi2_sd_io[2] spi2_sd_io[3]}]
# SPI
set_property IOSTANDARD LVCMOS33 [get_ports {spi_sd_io[*] spi_sck_o spi_csb_o}]
