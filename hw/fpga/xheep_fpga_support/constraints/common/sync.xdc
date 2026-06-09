# Copyright 2026 X-HEEP contibutors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

### synch cells Constraints

set all_sync_cells [get_cells -hier -filter {ORIG_REF_NAME=="sync" || REF_NAME=="sync"}]

foreach cell $all_sync_cells {
    set_max_delay -through [get_pins -filter {NAME=~"*reg_q_reg[0]/D"} -of_objects [get_cells $cell/*]] 20.000
    set_false_path -hold -through [get_pins -filter {NAME=~"*reg_q_reg[0]/D"} -of_objects [get_cells $cell/*]]
}

