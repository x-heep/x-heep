# Copyright 2022 EPFL
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
# Define design macros

# Set macros
set design_name xilinx_clk_wizard

# Create block design
create_bd_design $design_name

# Create instance and set properties
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0

set_property -dict [list \
  CONFIG.CLKIN1_JITTER_PS {50.0} \
  CONFIG.CLKOUT1_JITTER {323.556} \
  CONFIG.CLKOUT1_PHASE_ERROR {293.793} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {15} \
  CONFIG.CLK_IN1_BOARD_INTERFACE {sys_diff_clock} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {49.875} \
  CONFIG.MMCM_CLKIN1_PERIOD {5.000} \
  CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {66.500} \
  CONFIG.MMCM_DIVCLK_DIVIDE {10} \
  CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
  CONFIG.USE_LOCKED {false} \
  CONFIG.USE_RESET {false} \
] [get_bd_cells clk_wiz_0]

# Create ports
make_bd_pins_external [get_bd_cells clk_wiz_0]
make_bd_intf_pins_external [get_bd_cells clk_wiz_0]

# Save and close block design
save_bd_design
close_bd_design $design_name

# create wrapper
set wrapper_path [ make_wrapper -fileset sources_1 -files [ get_files -norecurse xilinx_clk_wizard.bd ] -top ]
add_files -norecurse -fileset sources_1 $wrapper_path
