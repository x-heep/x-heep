# Copyright 2026 EPFL
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# File: xilinx_generate_ps_wizard.tcl
# Author: Mohammadhossein Nikkhahghomi
# Date: 06/04/2026
#

set design_name xilinx_ps_wizard
create_bd_design $design_name
current_bd_design $design_name
current_bd_instance /

# -----------------------------------------------------------------------------
# External PL-facing ports for the SV wrapper
# -----------------------------------------------------------------------------

# set ps_quadspi_io [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:spi_rtl:1.0 ps_quadspi_io]

set ps_tdi_o  [create_bd_port -dir O ps_tdi_o]
set ps_tms_o  [create_bd_port -dir O ps_tms_o]
set ps_tck_o  [create_bd_port -dir O -from 0 -to 0 ps_tck_o]
set ps_tdo_i  [create_bd_port -dir I ps_tdo_i]
set ps_gpio_i [create_bd_port -dir I -from 1 -to 0 ps_gpio_i]
set ps_gpio_o [create_bd_port -dir O -from 4 -to 0 ps_gpio_o]
set pl0_resetn [create_bd_port -dir O -from 0 -to 0 -type rst pl0_resetn]

set UART_0 [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:uart_rtl:1.0 UART_0]
set ch0_lpddr4_trip1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:lpddr4_rtl:1.0 ch0_lpddr4_trip1 ]
set ch1_lpddr4_trip1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:lpddr4_rtl:1.0 ch1_lpddr4_trip1 ]
set lpddr4_clk1 [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 lpddr4_clk1]
set_property -dict [list CONFIG.FREQ_HZ {200000000}] $lpddr4_clk1


# -----------------------------------------------------------------------------
# CIPS
# -----------------------------------------------------------------------------


set versal_cips_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips:3.4 versal_cips_0 ]

# Full System mode so M_AXI_FPD / IRQs / PL clocks-resets are available

set_property CONFIG.DESIGN_MODE {1} $versal_cips_0
  set_property -dict [list \
    CONFIG.CLOCK_MODE {Custom} \
    CONFIG.DDR_MEMORY_MODE {Custom} \
    CONFIG.DEBUG_MODE {Custom} \
    CONFIG.DESIGN_MODE {1} \
    CONFIG.PS_BOARD_INTERFACE {ps_pmc_fixed_io} \
    CONFIG.PS_PL_CONNECTIVITY_MODE {Custom} \
    CONFIG.PS_PMC_CONFIG { \
      CLOCK_MODE {Custom} \
      DDR_MEMORY_MODE {Connectivity to DDR via NOC} \
      DESIGN_MODE {1} \
      DEVICE_INTEGRITY_MODE {Sysmon temperature voltage and external IO monitoring} \
      PMC_CRP_PL0_REF_CTRL_FREQMHZ {10} \
      PMC_CRP_PL1_REF_CTRL_FREQMHZ {334} \
      PMC_GPIO0_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 25}}} \
      PMC_GPIO1_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 26 .. 51}}} \
      PMC_MIO37 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA high} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_QSPI_FBCLK {{ENABLE 1} {IO {PMC_MIO 6}}} \
      PMC_QSPI_PERIPHERAL_DATA_MODE {x4} \
      PMC_QSPI_PERIPHERAL_ENABLE {1} \
      PMC_QSPI_PERIPHERAL_MODE {Dual Parallel} \
      PMC_REF_CLK_FREQMHZ {33.3333} \
      PMC_SD1 {{CD_ENABLE 1} {CD_IO {PMC_MIO 28}} {POW_ENABLE 1} {POW_IO {PMC_MIO 51}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 12}} {WP_ENABLE 0} {WP_IO {PMC_MIO 1}}} \
      PMC_SD1_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x3} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x2A} {CLK_50_DDR_OTAP_DLY 0x3} {CLK_50_SDR_ITAP_DLY 0x25} {CLK_50_SDR_OTAP_DLY 0x4} {ENABLE 1} {IO\
{PMC_MIO 26 .. 36}}} \
      PMC_SD1_SLOT_TYPE {SD 3.0 AUTODIR} \
      PMC_USE_PMC_NOC_AXI0 {1} \
      PS_BOARD_INTERFACE {ps_pmc_fixed_io} \
      PS_ENET0_MDIO {{ENABLE 1} {IO {PS_MIO 24 .. 25}}} \
      PS_ENET0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 11}}} \
      PS_GEN_IPI0_ENABLE {1} \
      PS_GEN_IPI0_MASTER {A72} \
      PS_GEN_IPI1_ENABLE {1} \
      PS_GEN_IPI2_ENABLE {1} \
      PS_GEN_IPI3_ENABLE {1} \
      PS_GEN_IPI4_ENABLE {1} \
      PS_GEN_IPI5_ENABLE {1} \
      PS_GEN_IPI6_ENABLE {1} \
      PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 46 .. 47}}} \
      PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 44 .. 45}}} \
      PS_I2CSYSMON_PERIPHERAL {{ENABLE 0} {IO {PMC_MIO 39 .. 40}}} \
      PS_IRQ_USAGE {{CH0 0} {CH1 0} {CH10 0} {CH11 0} {CH12 0} {CH13 0} {CH14 0} {CH15 0} {CH2 0} {CH3 0} {CH4 0} {CH5 0} {CH6 0} {CH7 0} {CH8 1} {CH9 0}} \
      PS_MIO7 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO9 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_NUM_FABRIC_RESETS {1} \
      PS_PCIE_EP_RESET1_IO {PS_MIO 18} \
      PS_PCIE_EP_RESET2_IO {PS_MIO 19} \
      PS_PCIE_RESET {ENABLE 1} \
      PS_PL_CONNECTIVITY_MODE {Custom} \
      PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 42 .. 43}}} \
      PS_USB3_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 13 .. 25}}} \
      PS_USE_FPD_CCI_NOC {1} \
      PS_USE_FPD_CCI_NOC0 {1} \
      PS_USE_M_AXI_FPD {1} \
      PS_USE_NOC_LPD_AXI0 {1} \
      PS_USE_PMCPL_CLK0 {1} \
      PS_USE_PMCPL_CLK1 {0} \
      SMON_ALARMS {Set_Alarms_On} \
      SMON_ENABLE_TEMP_AVERAGING {0} \
      SMON_INTERFACE_TO_USE {I2C} \
      SMON_PMBUS_ADDRESS {0x18} \
      SMON_TEMP_AVERAGING_SAMPLES {0} \
    } \
  ] $versal_cips_0


# -----------------------------------------------------------------------------
# AXI NOC
# -----------------------------------------------------------------------------


### MAIN  NOC to DDR connection
set axi_noc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_0 ]
  set_property -dict [list \
    CONFIG.CH0_LPDDR4_0_BOARD_INTERFACE {ch0_lpddr4_trip1} \
    CONFIG.CH1_LPDDR4_0_BOARD_INTERFACE {ch1_lpddr4_trip1} \
    CONFIG.MC1_FLIPPED_PINOUT {true} \
    CONFIG.MC_CHANNEL_INTERLEAVING {true} \
    CONFIG.MC_CHAN_REGION0 {DDR_LOW1} \
    CONFIG.MC_CHAN_REGION1 {DDR_LOW1} \
    CONFIG.MC_DM_WIDTH {4} \
    CONFIG.MC_DQS_WIDTH {4} \
    CONFIG.MC_DQ_WIDTH {32} \
    CONFIG.MC_EN_INTR_RESP {TRUE} \
    CONFIG.MC_SYSTEM_CLOCK {Differential} \
    CONFIG.NUM_CLKS {6} \
    CONFIG.NUM_MC {1} \
    CONFIG.NUM_MCP {4} \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_SI {6} \
    CONFIG.NUM_NSI {1} \
    CONFIG.sys_clk0_BOARD_INTERFACE {lpddr4_clk1} \
  ] $axi_noc_0  

set_property -dict [list CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S00_INI]
set_property -dict [list CONFIG.REGION {0} CONFIG.CONNECTIONS {MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4}}} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {ps_cci}] [get_bd_intf_pins /axi_noc_0/S00_AXI]
set_property -dict [list CONFIG.REGION {0} CONFIG.CONNECTIONS {MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4}}} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {ps_cci}] [get_bd_intf_pins /axi_noc_0/S01_AXI]
set_property -dict [list CONFIG.REGION {0} CONFIG.CONNECTIONS {MC_0 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4}}} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {ps_cci}] [get_bd_intf_pins /axi_noc_0/S02_AXI]
set_property -dict [list CONFIG.REGION {0} CONFIG.CONNECTIONS {MC_1 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4}}} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {ps_cci}] [get_bd_intf_pins /axi_noc_0/S03_AXI]
set_property -dict [list CONFIG.REGION {0} CONFIG.CONNECTIONS {MC_3 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4}}} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {ps_rpu}] [get_bd_intf_pins /axi_noc_0/S04_AXI]
set_property -dict [list CONFIG.REGION {0} CONFIG.CONNECTIONS {MC_2 {read_bw {100} write_bw {100} read_avg_burst {4} write_avg_burst {4}}} CONFIG.NOC_PARAMS {} CONFIG.CATEGORY {ps_pmc}] [get_bd_intf_pins /axi_noc_0/S05_AXI]


set_property CONFIG.ASSOCIATED_BUSIF {S00_AXI} [get_bd_pins /axi_noc_0/aclk0]
set_property CONFIG.ASSOCIATED_BUSIF {S01_AXI} [get_bd_pins /axi_noc_0/aclk1]
set_property CONFIG.ASSOCIATED_BUSIF {S02_AXI} [get_bd_pins /axi_noc_0/aclk2]
set_property CONFIG.ASSOCIATED_BUSIF {S03_AXI} [get_bd_pins /axi_noc_0/aclk3]
set_property CONFIG.ASSOCIATED_BUSIF {S04_AXI} [get_bd_pins /axi_noc_0/aclk4]
set_property CONFIG.ASSOCIATED_BUSIF {S05_AXI} [get_bd_pins /axi_noc_0/aclk5]

connect_bd_intf_net [get_bd_intf_ports ch0_lpddr4_trip1] [get_bd_intf_pins axi_noc_0/CH0_LPDDR4_0]
connect_bd_intf_net [get_bd_intf_ports ch1_lpddr4_trip1] [get_bd_intf_pins axi_noc_0/CH1_LPDDR4_0]
connect_bd_intf_net [get_bd_intf_ports lpddr4_clk1] [get_bd_intf_pins axi_noc_0/sys_clk0]

connect_bd_intf_net [get_bd_intf_pins versal_cips_0/FPD_CCI_NOC_0] [get_bd_intf_pins axi_noc_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/FPD_CCI_NOC_1] [get_bd_intf_pins axi_noc_0/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/FPD_CCI_NOC_2] [get_bd_intf_pins axi_noc_0/S02_AXI]
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/FPD_CCI_NOC_3] [get_bd_intf_pins axi_noc_0/S03_AXI]
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/LPD_AXI_NOC_0] [get_bd_intf_pins axi_noc_0/S04_AXI]
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/PMC_NOC_AXI_0] [get_bd_intf_pins axi_noc_0/S05_AXI]

connect_bd_net [get_bd_pins versal_cips_0/fpd_cci_noc_axi0_clk] [get_bd_pins axi_noc_0/aclk0]
connect_bd_net [get_bd_pins versal_cips_0/fpd_cci_noc_axi1_clk] [get_bd_pins axi_noc_0/aclk1]
connect_bd_net [get_bd_pins versal_cips_0/fpd_cci_noc_axi2_clk] [get_bd_pins axi_noc_0/aclk2]
connect_bd_net [get_bd_pins versal_cips_0/fpd_cci_noc_axi3_clk] [get_bd_pins axi_noc_0/aclk3]
connect_bd_net [get_bd_pins versal_cips_0/lpd_axi_noc_clk] [get_bd_pins axi_noc_0/aclk4]
connect_bd_net [get_bd_pins versal_cips_0/pmc_axi_noc_axi0_clk] [get_bd_pins axi_noc_0/aclk5]



### ADDRESS REMAPPING: 

set axi_noc_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_1 ]
  set_property -dict [list \
    CONFIG.NUM_MI {0} \
    CONFIG.NUM_NMI {1} \
  ] $axi_noc_1


connect_bd_intf_net [get_bd_intf_pins axi_noc_1/M00_INI] [get_bd_intf_pins axi_noc_0/S00_INI]
set_property -dict [list \
  CONFIG.CONNECTIONS {M00_INI {read_bw {500} write_bw {500}}} \
  CONFIG.REMAPS {M00_INI {{0xC000_0000 0x0000_0008_0000_0000 1G}}} \
] [get_bd_intf_pins /axi_noc_1/S00_AXI]

### DDR AXI interface :


create_bd_port -dir I -type clk -freq_hz 50000000 ddr_clk_i
set_property -dict [list CONFIG.CLK_DOMAIN [get_property CONFIG.CLK_DOMAIN [get_bd_pins axi_noc_1/aclk0]]] [get_bd_ports ddr_clk_i]

connect_bd_net [get_bd_pins /axi_noc_1/aclk0] [get_bd_ports ddr_clk_i]

create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 DDR_S_AXI
set_property -dict [list CONFIG.ID_WIDTH [get_property CONFIG.ID_WIDTH [get_bd_intf_pins axi_noc_1/S00_AXI]] CONFIG.ADDR_WIDTH [get_property CONFIG.ADDR_WIDTH [get_bd_intf_pins axi_noc_1/S00_AXI]]] [get_bd_intf_ports DDR_S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_noc_1/S00_AXI] [get_bd_intf_ports DDR_S_AXI]









# -----------------------------------------------------------------------------
# AXI Uartlite
# -----------------------------------------------------------------------------

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0
connect_bd_intf_net [get_bd_intf_ports UART_0] [get_bd_intf_pins axi_uartlite_0/UART]


# -----------------------------------------------------------------------------
# AXI helper plane in PL
# -----------------------------------------------------------------------------

set axi_jtag [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_jtag:1.0 axi_jtag]
set_property CONFIG.C_TCK_CLOCK_RATIO {20} [get_bd_cells axi_jtag]

set axi_smc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc]
set_property -dict [list \
  CONFIG.NUM_MI {4} \
  CONFIG.NUM_SI {1} \
] $axi_smc

set rst_versal_cips [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_versal_cips]

set axi_gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio]
set_property -dict [list \
  CONFIG.C_ALL_OUTPUTS {1} \
  CONFIG.C_ALL_INPUTS_2 {1} \
  CONFIG.C_GPIO_WIDTH {5} \
  CONFIG.C_GPIO2_WIDTH {2} \
  CONFIG.C_IS_DUAL {1} \
] $axi_gpio

set ilconcat_0 [create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 ilconcat_0]

# set_property CONFIG.NUM_PORTS {2} $ilconcat_0
set_property CONFIG.NUM_PORTS {1} $ilconcat_0
connect_bd_net [get_bd_pins axi_uartlite_0/interrupt] [get_bd_pins ilconcat_0/In0]


# -----------------------------------------------------------------------------
# UTILITY BUFFER 
# -----------------------------------------------------------------------------

set util_ds_buf_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0]
set_property CONFIG.C_BUF_TYPE {BUFG} $util_ds_buf_0

# set axi_quad_spi [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 axi_quad_spi]
# set_property -dict [list \
#   CONFIG.C_SPI_MODE {2} \
#   CONFIG.C_USE_STARTUP {0} \
# ] $axi_quad_spi

# -----------------------------------------------------------------------------
# AXI interface connections
# -----------------------------------------------------------------------------

# Direct PS master to helper interconnect
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/M_AXI_FPD] [get_bd_intf_pins axi_smc/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins axi_gpio/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M01_AXI] [get_bd_intf_pins axi_jtag/s_axi]
# connect_bd_intf_net [get_bd_intf_pins axi_smc/M02_AXI] [get_bd_intf_pins axi_quad_spi/AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M03_AXI] [get_bd_intf_pins axi_uartlite_0/S_AXI]

# connect_bd_intf_net [get_bd_intf_ports ps_quadspi_io] [get_bd_intf_pins axi_quad_spi/SPI_0]

# -----------------------------------------------------------------------------
# Clocking
# -----------------------------------------------------------------------------

# PL clock 0 drives the internal helper AXI plane
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] \
  [get_bd_pins versal_cips_0/m_axi_fpd_aclk] \
  [get_bd_pins axi_smc/aclk] \
  [get_bd_pins rst_versal_cips/slowest_sync_clk] \
  [get_bd_pins axi_jtag/s_axi_aclk] \
  [get_bd_pins axi_gpio/s_axi_aclk] \
  [get_bd_pins axi_uartlite_0/s_axi_aclk]
#  [get_bd_pins axi_quad_spi/s_axi_aclk] \
#  [get_bd_pins axi_quad_spi/ext_spi_clk] 

# -----------------------------------------------------------------------------
# Reset
# -----------------------------------------------------------------------------

connect_bd_net [get_bd_pins versal_cips_0/pl0_resetn] \
  [get_bd_pins rst_versal_cips/ext_reset_in]

# Peripheral active-low resets
connect_bd_net [get_bd_pins rst_versal_cips/peripheral_aresetn] \
  [get_bd_pins axi_smc/aresetn] \
  [get_bd_pins axi_jtag/s_axi_aresetn] \
  [get_bd_pins axi_gpio/s_axi_aresetn] \
  [get_bd_pins axi_uartlite_0/s_axi_aresetn] \
  [get_bd_ports pl0_resetn]
#  [get_bd_pins axi_quad_spi/s_axi_aresetn] 

# -----------------------------------------------------------------------------
# GPIO / JTAG / IRQ connections
# -----------------------------------------------------------------------------

connect_bd_net [get_bd_pins axi_gpio/gpio_io_o] \
  [get_bd_ports ps_gpio_o]
connect_bd_net [get_bd_ports ps_gpio_i]          [get_bd_pins axi_gpio/gpio2_io_i]

connect_bd_net [get_bd_pins axi_jtag/tck] [get_bd_pins util_ds_buf_0/BUFG_I]
connect_bd_net [get_bd_pins util_ds_buf_0/BUFG_O] \
  [get_bd_ports ps_tck_o]
connect_bd_net [get_bd_pins axi_jtag/tms] \
  [get_bd_ports ps_tms_o]
connect_bd_net [get_bd_pins axi_jtag/tdi] \
  [get_bd_ports ps_tdi_o]
connect_bd_net [get_bd_ports ps_tdo_i] \
  [get_bd_pins axi_jtag/tdo]

# Only SPI interrupt used for now
# connect_bd_net [get_bd_pins axi_quad_spi/ip2intc_irpt] [get_bd_pins ilconcat_0/In1]
connect_bd_net [get_bd_pins ilconcat_0/dout] [get_bd_pins versal_cips_0/pl_ps_irq8]

# -----------------------------------------------------------------------------
# Address map for direct M_AXI_FPD helper plane
# -----------------------------------------------------------------------------

assign_bd_address -offset 0xA4020000 -range 0x00010000 -with_name SEG_axi_gpio_Reg \
  -target_address_space [get_bd_addr_spaces versal_cips_0/M_AXI_FPD] \
  [get_bd_addr_segs axi_gpio/S_AXI/Reg] -force

assign_bd_address -offset 0xA4000000 -range 0x00010000 \
  -target_address_space [get_bd_addr_spaces versal_cips_0/M_AXI_FPD] \
  [get_bd_addr_segs axi_jtag/s_axi/reg0] -force


assign_bd_address -offset 0xA4040000 -range 0x00010000 -with_name SEG_axi_uartlite_Reg \
  -target_address_space [get_bd_addr_spaces versal_cips_0/M_AXI_FPD] \
  [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg] -force

# assign_bd_address -offset 0xA4030000 -range 0x00010000 -with_name SEG_axi_quad_spi_Reg \
#   -target_address_space [get_bd_addr_spaces versal_cips_0/M_AXI_FPD] \
#   [get_bd_addr_segs axi_quad_spi/AXI_LITE/Reg] -force


assign_bd_address -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces versal_cips_0/FPD_CCI_NOC_0] [get_bd_addr_segs axi_noc_0/S00_AXI/C3_DDR_LOW1] -force
assign_bd_address -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces versal_cips_0/FPD_CCI_NOC_1] [get_bd_addr_segs axi_noc_0/S01_AXI/C2_DDR_LOW1] -force
assign_bd_address -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces versal_cips_0/FPD_CCI_NOC_2] [get_bd_addr_segs axi_noc_0/S02_AXI/C0_DDR_LOW1] -force
assign_bd_address -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces versal_cips_0/FPD_CCI_NOC_3] [get_bd_addr_segs axi_noc_0/S03_AXI/C1_DDR_LOW1] -force
assign_bd_address -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces versal_cips_0/LPD_AXI_NOC_0] [get_bd_addr_segs axi_noc_0/S04_AXI/C3_DDR_LOW1] -force
assign_bd_address -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces versal_cips_0/PMC_NOC_AXI_0] [get_bd_addr_segs axi_noc_0/S05_AXI/C2_DDR_LOW1] -force

assign_bd_address -target_address_space /DDR_S_AXI [get_bd_addr_segs axi_noc_0/S00_INI/C0_DDR_LOW1] -force

# -----------------------------------------------------------------------------
# Finalize
# -----------------------------------------------------------------------------

validate_bd_design
save_bd_design
close_bd_design $design_name

set wrapper_path [make_wrapper -fileset sources_1 -files [get_files -norecurse xilinx_ps_wizard.bd] -top]
add_files -norecurse -fileset sources_1 $wrapper_path
