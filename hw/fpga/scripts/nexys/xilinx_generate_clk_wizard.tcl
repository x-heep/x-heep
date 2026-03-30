# Copyright 2022 EPFL
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
# Define design macros

source [file join [file dirname [info script]] .. common xilinx_generate_core_clk_period_xdc.tcl]

set design_name      xilinx_clk_wizard
set in_clk_freq_MHz  100
set out_clk_freq_MHz 15
if {[info exists ::env(FPGA_CORE_CLK)]} {
  set out_clk_freq_MHz $::env(FPGA_CORE_CLK)
}


# Create block design
create_bd_design $design_name

# Create instance and set properties
set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
set_property -dict [ list \
 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $out_clk_freq_MHz \
 CONFIG.CLK_IN1_BOARD_INTERFACE {sys_clock} \
 CONFIG.USE_LOCKED {false} \
 CONFIG.USE_RESET {false} \
] $clk_wiz_0

# Create ports
make_bd_pins_external [get_bd_cells clk_wiz_0]
set_property CONFIG.FREQ_HZ [expr {$in_clk_freq_MHz * 1000000}] [get_bd_ports clk_in1_0]

# Save and close block design
save_bd_design
close_bd_design $design_name

# create wrapper
set wrapper_path [ make_wrapper -fileset sources_1 -files [ get_files -norecurse xilinx_clk_wizard.bd ] -top ]
add_files -norecurse -fileset sources_1 $wrapper_path

xheep_generate_core_clk_period_xdc $out_clk_freq_MHz [info script]
