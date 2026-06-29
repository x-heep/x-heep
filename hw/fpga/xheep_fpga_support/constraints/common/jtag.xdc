# Copyright 2026 X-HEEP contibutors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

### JTAG Constraints
set_max_delay -through [get_nets -filter {NAME=~"*async*"} -of_objects [get_cells -hier -filter {REF_NAME =~ cdc_2phase_src* || ORIG_REF_NAME =~ cdc_2phase_src*}]] 20.000
set_false_path -hold -through [get_nets -filter {NAME=~"*async*"} -of_objects [get_cells -hier -filter {REF_NAME =~ cdc_2phase_src* || ORIG_REF_NAME =~ cdc_2phase_src*}]]

# Hold and max delay on 4 phases

set all_cdc4pahse_srcs [get_cells -hier -filter {REF_NAME == cdc_4phase_src || ORIG_REF_NAME == cdc_4phase_src}]

foreach cell $all_cdc4pahse_srcs {
    set_max_delay -through [get_nets -filter {NAME=~"*data_src_q*"} $cell/*] 20.000
    set_false_path -hold -through [get_nets -filter {NAME=~"*data_src_q*"} $cell/*]
    set_max_delay -through [get_nets -filter {NAME=~"*req_src_q*"} $cell/*] 20.000
    set_false_path -hold -through [get_nets -filter {NAME=~"*req_src_q*"} $cell/*]
}
