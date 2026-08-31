# Copyright 2026 EPFL
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# VPK180 timing constraints for the PS-enabled flow.

# The PL clock wizard and NoC IP XDCs create clocks for their LPDDR4 inputs.

# The SPI slave debug port remains an external clock domain even when PS_ENABLE=1.
create_clock -add -name spi_slave_clk_pin -period 16.000 -waveform {0.000 8.000} \
  [get_ports {spi_slave_sck_io}]

# Treat JTAG TAP clocking as asynchronous to the main X-HEEP system clock.
# The AXI JTAG IP XDC creates the generated TCK clock on tck_i_reg/Q, so do not
# create another clock here; collect the IP-owned clock from the generated pin.
set xheep_core_clks [get_clocks -quiet -include_generated_clocks -of_objects \
  [get_ports -quiet {lpddr4_clk3_clk_p}]]

set axi_jtag_tck_pins [get_pins -quiet -hierarchical -filter \
  {NAME =~ "*/axi_jtag/inst/u_jtag_proc/tck_i_reg/Q"}]
set axi_jtag_tck_clks [get_clocks -quiet -of_objects $axi_jtag_tck_pins]

if {[llength $xheep_core_clks] && [llength $axi_jtag_tck_clks]} {
  set_clock_groups -asynchronous \
    -group $xheep_core_clks \
    -group $axi_jtag_tck_clks
}

# False paths
## TODO: check the following false paths:
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *dmcontrol_q_reg[ndmreset]}]
## TODO: seem normal, double-check
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *synch_regs_q_reg[3]}]
set_false_path -hold -through [get_pins x_heep_system_i/core_v_mini_mcu_i/debug_subsystem_i/dmi_jtag_i/i_dmi_cdc/i_cdc_resp/i_src/async*]
set_false_path -hold -through [get_pins x_heep_system_i/core_v_mini_mcu_i/debug_subsystem_i/dmi_jtag_i/i_dmi_cdc/i_cdc_req/i_src/async*]


#set_false_path -from [get_pins {x_heep_system_i/core_v_mini_mcu_i/debug_subsystem_i/gen_spi_slave.obi_spi_slave_i/u_slave_sm/FSM_sequential_state_reg[*]_fret/C}] -to [get_pins {x_heep_system_i/core_v_mini_mcu_i/debug_subsystem_i/gen_spi_slave.obi_spi_slave_i/u_syncro/rdwr_reg_reg[*]/D}]
#set_false_path -setup -hold -to [get_cells -hierarchical -filter {NAME =~ *i_rstgen_bypass/synch_regs_q_reg[*]}]
# set_false_path -hold -from [get_pins {xilinx_ps_wizard_wrapper_i/xilinx_ps_wizard_i/axi_gpio/U0/gpio_core_1/Dual.gpio_Data_Out_reg[1]/C}]
