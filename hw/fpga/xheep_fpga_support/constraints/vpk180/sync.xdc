# Copyright 2026 EPFL
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

### VPK180 sync cell constraints

# Vivado rejects Tcl control flow in XDC files in this flow. Match all first
# sync-stage D pins directly instead.
set_max_delay -quiet -through [get_pins -quiet -hierarchical -filter \
  {NAME =~ "*/reg_q_reg[0]/D"}] 20.000
set_false_path -quiet -hold -through [get_pins -quiet -hierarchical -filter \
  {NAME =~ "*/reg_q_reg[0]/D"}]
