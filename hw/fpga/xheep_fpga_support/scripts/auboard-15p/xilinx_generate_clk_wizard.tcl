# Copyright 2026 X-HEEP contributors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# Clock generator for the Avnet (Tria) AUBoard-15P: 15 MHz from the board's
# 300 MHz differential oscillator. No board files are needed: the input pins
# are assigned in constraints/auboard-15p/pin_assign.xdc.

# Define design macros
set design_name xilinx_clk_wizard

# Create block design
create_bd_design $design_name

# Create instance and set properties
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0

set_property -dict [list \
  CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
  CONFIG.PRIM_IN_FREQ {300.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {15.000} \
  CONFIG.USE_LOCKED {false} \
  CONFIG.USE_RESET {false} \
] [get_bd_cells clk_wiz_0]

# Create ports
make_bd_pins_external [get_bd_cells clk_wiz_0]
make_bd_intf_pins_external [get_bd_cells clk_wiz_0]

# Save and close block design
save_bd_design
close_bd_design $design_name

# Create wrapper
set wrapper_path [ make_wrapper -fileset sources_1 -files [ get_files -norecurse xilinx_clk_wizard.bd ] -top ]
add_files -norecurse -fileset sources_1 $wrapper_path
