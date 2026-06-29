# Copyright 2026 X-HEEP contibutors
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

open_project openhwgroup.org_systems_core-v-mini-mcu_0.xpr
open_run synth_1 -name synth_1
write_verilog -mode funcsim -include_xilinx_libs -force x_heep_system_xiling_postsynth.v

set questa_dir [file dirname [which vsim]]

compile_simlib -simulator questasim -simulator_exec_path {$questa_dir} -family all -language all -library all -dir {./openhwgroup.org_systems_core-v-mini-mcu_0.cache/compile_simlib/modelsim}

launch_simulation -mode post-synthesis -type functional -scripts_only