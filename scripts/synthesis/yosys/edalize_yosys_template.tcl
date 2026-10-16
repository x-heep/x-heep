# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

yosys plugin -i slang.so

yosys -import

echo on

source edalize_yosys_procs.tcl

set ASIC_TECH ihp-sg13g2

if {[file exists asic_tech.tcl]} { source asic_tech.tcl }
source ../../../scripts/asic/tech/$ASIC_TECH.tcl
puts "\[x-heep] target technology: $ASIC_TECH"

if {[asic_env $TECH_ROOT_VAR] eq ""} {
	error "\[x-heep] \$$TECH_ROOT_VAR is not set: the $ASIC_TECH flow needs its design kit (see scripts/asic/tech/$ASIC_TECH.tcl)."
}

set synth_top x_heep_system

# PDK cells (std cells, IO pads, SRAM macros) as blackboxes, read before the
# RTL so that read_slang resolves the cells the wrappers instantiate
set stdcell_libs [tech_stdcell_libs]
set stdcell_lib [lindex $stdcell_libs 0]
if {[llength $stdcell_libs] > 1} {
	puts "\[x-heep] WARNING: several std-cell Liberty files, mapping onto the first: $stdcell_lib"
}
puts "\[x-heep] std-cell Liberty: $stdcell_lib"
yosys read_liberty -lib -overwrite $stdcell_lib

foreach macro_lib [tech_yosys_macro_libs] {
	puts "\[x-heep] hard-cell Liberty: $macro_lib"
	yosys read_liberty -lib -overwrite $macro_lib
}

read_slang --top $synth_top \
	--define-macro SYNTHESIS=true \
	--define-macro XHEEP_STANDALONE_SYNTHESIS \
	--define-macro REMOVE_OBI_FIFO \
	--define-macro ASSERTS_OFF \
	--define-macro COMMON_CELLS_ASSERTS_OFF \
	--compat-mode \
	--keep-hierarchy \
	--allow-use-before-declare \
	--error-limit=100 \
	-Wno-implicit-port-type-mismatch \
	-Wno-duplicate-definition \
	-Wno-implicit-conv \
	-Wno-redef-macro \
	-Wno-unconnected-port \
	-f "files.flist"

yosys chformal -remove

# Reports and netlist go to report/; `make asic-yosys` copies them, with the log,
# to implementation/synthesis/ (as the design_compiler flow does)
file delete -force report
file mkdir report

# The elaborated design (before any optimization)
yosys tee -o report/check_design_elaborate.rpt check

proc sdc_clocks {sdc} {
	set i [interp create]
	$i eval {
		set ::clocks {}
		proc create_clock {args} {
			set name ""
			set period ""
			set targets {}
			for {set k 0} {$k < [llength $args]} {incr k} {
				switch -- [lindex $args $k] {
					-name     { set name [lindex $args [incr k]] }
					-period   { set period [lindex $args [incr k]] }
					-waveform -
					-comment  { incr k }
					-add      {}
					default   { lappend targets {*}[lindex $args $k] }
				}
			}
			if {$name eq ""} { set name [lindex $targets 0] }
			lappend ::clocks [list $name $period $targets]
		}
		foreach cmd {get_ports get_pins get_nets get_clocks} {
			proc $cmd {args} { return [lindex $args end] }
		}
		proc unknown {args} { return "" }
	}
	if {[catch {$i eval [list source $sdc]} err]} {
		interp delete $i
		error "\[x-heep] cannot read $sdc: $err"
	}
	set clocks [$i eval {set ::clocks}]
	interp delete $i
	return $clocks
}

set sdc_file [file normalize ../../../scripts/synthesis/yosys/constraints.sdc]
puts "\[x-heep] clock constraints: $sdc_file"
set abc_delay ""
set rpt [open report/clocks.rpt w]
puts $rpt "SDC: $sdc_file\n"
puts $rpt [format "%-20s %-12s %s" Clock "Period (ns)" Sources]
foreach clk [sdc_clocks $sdc_file] {
	lassign $clk clk_name clk_period clk_targets
	if {![string is double -strict $clk_period] || $clk_period <= 0} {
		error "\[x-heep] clock $clk_name: invalid period '$clk_period' in $sdc_file"
	}
	puts $rpt [format "%-20s %-12s %s" $clk_name $clk_period $clk_targets]
	puts "\[x-heep] clock $clk_name: period $clk_period ns on $clk_targets"
	set clk_ps [expr {round($clk_period * 1000)}]
	if {$abc_delay eq "" || $clk_ps < $abc_delay} { set abc_delay $clk_ps }
}
if {$abc_delay eq ""} {
	puts $rpt "\nNo clock: ABC maps without delay target."
	puts "\[x-heep] WARNING: no create_clock in $sdc_file, ABC maps without delay target"
} else {
	puts $rpt "\nABC delay target: $abc_delay ps"
}
close $rpt
# Next to the netlist, for a later STA
file copy -force $sdc_file report/constraints.sdc

set abc_args [list -liberty $stdcell_lib]
if {$abc_delay ne ""} { lappend abc_args -D $abc_delay }
# Input driver and output load of ABC's buffering and gate sizing (tech file)
if {[info exists TECH_ABC_DRIVING_CELL] && [info exists TECH_ABC_LOAD_FF]} {
	set constr [open abc.constr w]
	puts $constr "set_driving_cell $TECH_ABC_DRIVING_CELL"
	puts $constr "set_load $TECH_ABC_LOAD_FF"
	close $constr
	lappend abc_args -constr [file normalize abc.constr]
}

yosys synth -top $synth_top -run :fine
# Word-level operators (adders, multipliers, comparators, ...) before their
# mapping to gates, as Design Compiler's report_resources
yosys tee -o report/resources.rpt stat -width
yosys synth -top $synth_top -run fine:
yosys dfflibmap -liberty $stdcell_lib
yosys abc {*}$abc_args
yosys clean
# The mapped design
yosys tee -o report/check_design_compile.rpt check

set stat_libs {}
foreach lib [concat [list $stdcell_lib] [tech_yosys_macro_libs]] { lappend stat_libs -liberty $lib }
yosys tee -o report/area.rpt stat {*}$stat_libs

yosys write_verilog -noattr report/netlist.v

# The names the edalize `yosys` backend may expect as its Make target
yosys write_verilog -noattr $name.v
yosys write_verilog -noattr $name.verilog
