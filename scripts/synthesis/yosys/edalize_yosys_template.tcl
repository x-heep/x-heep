# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

yosys plugin -i slang.so

yosys -import

echo on

source edalize_yosys_procs.tcl

set ASIC_TECH ihp130

if {[file exists asic_tech.tcl]} { source asic_tech.tcl }
source ../../../scripts/asic/tech/$ASIC_TECH.tcl
puts "\[x-heep] target technology: $ASIC_TECH"

if {[asic_env $TECH_ROOT_VAR] eq ""} {
	error "\[x-heep] \$$TECH_ROOT_VAR is not set: the $ASIC_TECH flow needs its design kit (see scripts/asic/tech/$ASIC_TECH.tcl)."
}

set synth_top x_heep_system_synth_top

read_slang --top $synth_top \
	--define-macro SYNTHESIS=true \
	--define-macro REMOVE_OBI_FIFO \
	--define-macro ASSERTS_OFF \
	--define-macro COMMON_CELLS_ASSERTS_OFF \
	--compat-mode \
	--keep-hierarchy \
	--allow-use-before-declare \
	--ignore-unknown-modules \
	--error-limit=100 \
	-Wno-implicit-port-type-mismatch \
	-Wno-duplicate-definition \
	-Wno-implicit-conv \
	-Wno-redef-macro \
	-Wno-unconnected-port \
	-f "files.flist" \
	x_heep_system_synth_top.sv

yosys chformal -remove

set stdcell_libs [tech_stdcell_libs]
set stdcell_lib [lindex $stdcell_libs 0]
if {[llength $stdcell_libs] > 1} {
	puts "\[x-heep] WARNING: several std-cell Liberty files, mapping onto the first: $stdcell_lib"
}
puts "\[x-heep] std-cell Liberty: $stdcell_lib"
yosys read_liberty -lib -overwrite $stdcell_lib

# Hard cells instantiated by the RTL (blackbox, timing only).
foreach macro_lib [tech_yosys_macro_libs] {
	puts "\[x-heep] hard-cell Liberty: $macro_lib"
	yosys read_liberty -lib -overwrite $macro_lib
}

# Reports and netlist go to report/; `make asic-yosys` copies them, with the log,
# to implementation/synthesis/ (as the design_compiler flow does)
file delete -force report
file mkdir report

yosys synth -top $synth_top
yosys tee -o report/check_design.rpt check
yosys dfflibmap -liberty $stdcell_lib
yosys abc -liberty $stdcell_lib
yosys clean

set stat_libs {}
foreach lib [concat [list $stdcell_lib] [tech_yosys_macro_libs]] { lappend stat_libs -liberty $lib }
yosys tee -o report/area.rpt stat {*}$stat_libs

yosys write_verilog -noattr report/netlist.v

# The names the edalize `yosys` backend may expect as its Make target
yosys write_verilog -noattr $name.v
yosys write_verilog -noattr $name.verilog
