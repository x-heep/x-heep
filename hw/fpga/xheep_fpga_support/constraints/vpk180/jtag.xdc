# Copyright 2026 EPFL
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

### VPK180 JTAG constraints

set_max_delay -quiet -through [get_nets -quiet -filter {NAME =~ "*async*"} \
  -of_objects [get_cells -quiet -hierarchical -filter \
    {REF_NAME =~ cdc_2phase_src* || ORIG_REF_NAME =~ cdc_2phase_src*}]] 20.000
set_false_path -quiet -hold -through [get_nets -quiet -filter {NAME =~ "*async*"} \
  -of_objects [get_cells -quiet -hierarchical -filter \
    {REF_NAME =~ cdc_2phase_src* || ORIG_REF_NAME =~ cdc_2phase_src*}]]

# Hold and max delay on CDC source registers. Keep this flat because Vivado
# rejects Tcl control flow when this file is parsed as XDC.
set_max_delay -quiet -through [get_pins -quiet -hierarchical -filter \
  {NAME =~ "*/data_src_q_reg*/Q"}] 20.000
set_false_path -quiet -hold -through [get_pins -quiet -hierarchical -filter \
  {NAME =~ "*/data_src_q_reg*/Q"}]
set_max_delay -quiet -through [get_pins -quiet -hierarchical -filter \
  {NAME =~ "*/req_src_q_reg*/Q"}] 20.000
set_false_path -quiet -hold -through [get_pins -quiet -hierarchical -filter \
  {NAME =~ "*/req_src_q_reg*/Q"}]
