# Copyright 2026 X-HEEP contributors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# The 300 MHz system clock is constrained by the clock wizard IP.
create_clock -add -name jtag_clk_pin -period 100.00 -waveform {0 5} [get_ports {jtag_tck_i}];
create_clock -add -name spi_slave_clk_pin -period 16.00 -waveform {0 5} [get_ports {spi_slave_sck_io}];

### Reset Constraints
set_false_path -from x_heep_system_i/core_v_mini_mcu_i/debug_subsystem_i/dm_obi_top_i/i_dm_top/i_dm_csrs/dmcontrol_q_reg\[ndmreset\]/C
set_false_path -from x_heep_system_i/rstgen_i/i_rstgen_bypass/synch_regs_q_reg[3]/C

### JTAG clock and system clock
# The two clocks are unrelated. Every path between them goes through the handshakes and
# synchronizers of the debug transport (dmi_cdc), so only the data path is bounded.
set sys_clk [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0]
set_max_delay -datapath_only -from $sys_clk -to [get_clocks jtag_clk_pin] 20.000
set_max_delay -datapath_only -from [get_clocks jtag_clk_pin] -to $sys_clk 20.000
