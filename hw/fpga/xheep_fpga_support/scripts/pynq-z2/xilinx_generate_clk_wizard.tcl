# Copyright 2026 X-HEEP contibutors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
# Define design macros

set design_name      xilinx_clk_wizard
set in_clk_freq_MHz  125
set out_clk_freq_MHz 15

# HDMI output clocks. 640x480@60 nominally wants 25.175 MHz; 25.000 MHz gives
# 59.5 Hz, which monitors accept, and divides exactly from the same VCO as the
# system clock. The serialiser clock must be exactly 5x the pixel clock.
#
# Only the requested frequencies are set here. The wizard picks the VCO and the
# dividers itself, and rejects any attempt to force MMCM_* on top of that with
# "attempt to modify the value of disabled parameter ... has been ignored".
# It settles on 125 MHz x 9 = 1125 MHz, then /75 = 15, /45 = 25, /9 = 125.
#
# What matters is that all three come off one MMCM: OSERDESE2 requires CLK and
# CLKDIV to be phase aligned.
set pix_clk_freq_MHz    25
set pix_clk_5x_freq_MHz 125


# Create block design
create_bd_design $design_name

# Create ports
set clk_125MHz [ create_bd_port -dir I -type clk -freq_hz [ expr $in_clk_freq_MHz * 1000000 ] clk_125MHz ]
set clk_out1_0 [ create_bd_port -dir O -type clk clk_out1_0 ]
set_property -dict [ list CONFIG.FREQ_HZ [ expr $out_clk_freq_MHz * 1000000 ] ] $clk_out1_0
set clk_out2_0 [ create_bd_port -dir O -type clk clk_out2_0 ]
set_property -dict [ list CONFIG.FREQ_HZ [ expr $pix_clk_freq_MHz * 1000000 ] ] $clk_out2_0
set clk_out3_0 [ create_bd_port -dir O -type clk clk_out3_0 ]
set_property -dict [ list CONFIG.FREQ_HZ [ expr $pix_clk_5x_freq_MHz * 1000000 ] ] $clk_out3_0

# Create instance and set properties
set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
set_property -dict [ list \
 CONFIG.CLKIN1_JITTER_PS {80.0} \
 CONFIG.NUM_OUT_CLKS {3} \
 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $out_clk_freq_MHz \
 CONFIG.CLKOUT2_USED {true} \
 CONFIG.CLKOUT2_REQUESTED_OUT_FREQ $pix_clk_freq_MHz \
 CONFIG.CLKOUT3_USED {true} \
 CONFIG.CLKOUT3_REQUESTED_OUT_FREQ $pix_clk_5x_freq_MHz \
 CONFIG.MMCM_CLKIN1_PERIOD {8.000} \
 CONFIG.PRIM_IN_FREQ $in_clk_freq_MHz \
 CONFIG.USE_LOCKED {false} \
 CONFIG.USE_RESET {false} \
] $clk_wiz_0

# Create port connections
connect_bd_net -net clk_in1_0_1 [ get_bd_ports clk_125MHz ] [ get_bd_pins clk_wiz_0/clk_in1 ]
connect_bd_net -net clk_wiz_0_clk_out1 [ get_bd_ports clk_out1_0 ] [ get_bd_pins clk_wiz_0/clk_out1 ]
connect_bd_net -net clk_wiz_0_clk_out2 [ get_bd_ports clk_out2_0 ] [ get_bd_pins clk_wiz_0/clk_out2 ]
connect_bd_net -net clk_wiz_0_clk_out3 [ get_bd_ports clk_out3_0 ] [ get_bd_pins clk_wiz_0/clk_out3 ]

# Save and close block design
save_bd_design
close_bd_design $design_name

# create wrapper
set wrapper_path [ make_wrapper -fileset sources_1 -files [ get_files -norecurse xilinx_clk_wizard.bd ] -top ]
add_files -norecurse -fileset sources_1 $wrapper_path
