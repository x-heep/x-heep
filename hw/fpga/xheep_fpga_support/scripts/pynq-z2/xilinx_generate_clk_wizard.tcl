# Copyright 2026 X-HEEP contibutors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
# Define design macros

set design_name      xilinx_clk_wizard
set in_clk_freq_MHz  125
set out_clk_freq_MHz 15


# Create block design
create_bd_design $design_name

# Create ports
set clk_125MHz [ create_bd_port -dir I -type clk -freq_hz [ expr $in_clk_freq_MHz * 1000000 ] clk_125MHz ]
set clk_out1_0 [ create_bd_port -dir O -type clk clk_out1_0 ]
set_property -dict [ list CONFIG.FREQ_HZ [ expr $out_clk_freq_MHz * 1000000 ] ] $clk_out1_0

# Create instance and set properties
set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
set_property -dict [ list \
 CONFIG.CLKIN1_JITTER_PS {80.0} \
 CONFIG.CLKOUT1_JITTER {172.798} \
 CONFIG.CLKOUT1_PHASE_ERROR {96.948} \
 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {15} \
 CONFIG.MMCM_CLKFBOUT_MULT_F {8.000} \
 CONFIG.MMCM_CLKIN1_PERIOD {8.000} \
 CONFIG.MMCM_CLKOUT0_DIVIDE_F {50.000} \
 CONFIG.PRIM_IN_FREQ $in_clk_freq_MHz \
 CONFIG.USE_LOCKED {false} \
 CONFIG.USE_RESET {false} \
] $clk_wiz_0

# Create port connections
connect_bd_net -net clk_in1_0_1 [ get_bd_ports clk_125MHz ] [ get_bd_pins clk_wiz_0/clk_in1 ]
connect_bd_net -net clk_wiz_0_clk_out1 [ get_bd_ports clk_out1_0 ] [ get_bd_pins clk_wiz_0/clk_out1 ]

# Save and close block design
save_bd_design
close_bd_design $design_name

# create wrapper
set wrapper_path [ make_wrapper -fileset sources_1 -files [ get_files -norecurse xilinx_clk_wizard.bd ] -top ]
add_files -norecurse -fileset sources_1 $wrapper_path
