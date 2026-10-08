# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# OpenSTA reports of the `make asic-yosys` netlist: the reports of the Design
# Compiler flow (scripts/synthesis/dc_shell/dc_script.tcl) that Yosys cannot
# produce. Run by run_sta.sh.
#
# Input: $XHEEP_SYNTH_OUT, a synthesis output folder with netlist.v,
# constraints.sdc, asic_tech (technology) and asic_clk_period ($ASIC_CLK_PERIOD
# of the synthesis, empty for the SDC default). Reports written there:
#   clocks.rpt                 clock properties and skew (after the Yosys section)
#   timing_loop.rpt            combinational loops
#   check_timing_compile.rpt   unclocked registers, unconstrained endpoints, ...
#   timing.rpt                 worst setup (max) and hold (min) paths
#   constraints.rpt            worst slack, slew, capacitance and fanout, then the violators
#   clock_gating.rpt           integrated clock-gating cells and their checks
#   power.rpt                  vectorless power estimate
#   qor.rpt                    summary
#   netlist.sdc                the constraints as applied to the netlist

set root [file normalize [file join [file dirname [info script]] .. .. ..]]
if {![info exists ::env(XHEEP_SYNTH_OUT)]} {
  error "\[x-heep] \$XHEEP_SYNTH_OUT is not set: the synthesis output folder to analyse"
}
set out [file normalize $::env(XHEEP_SYNTH_OUT)]
set top x_heep_system

proc xh_read {path} {
  set f [open $path]
  set s [string trim [read $f]]
  close $f
  return $s
}

# Output of the OpenSTA commands in $body, as a string. An error stops $body but
# not the other reports: it is appended to the output and logged (run_sta.sh
# then fails)
proc xh_capture {body} {
  sta::redirect_string_begin
  set rc [catch {uplevel #0 $body} err]
  set text [sta::redirect_string_end]
  if {$rc} {
    puts "\[x-heep] ERROR: $err"
    append text "\n\[x-heep] ERROR: $err\n"
  }
  return $text
}

# Writes report $file (mode w) or appends to it (mode a): a header, then $text
proc xh_report {file title text {mode w}} {
  if {[catch {sta::version} version]} { set version "" }
  set f [open $::out/$file $mode]
  puts $f "****************************************"
  puts $f "Report : $title"
  puts $f "Design : $::top"
  puts $f "Tool   : OpenSTA $version"
  puts $f "Date   : [clock format [clock seconds]]"
  puts $f "****************************************\n"
  puts $f $text
  close $f
  puts "\[x-heep] $::out/$file"
}

set tech [xh_read $out/asic_tech]
source $root/scripts/asic/tech/$tech.tcl

# The SDC reads $ASIC_CLK_PERIOD: use the value of the synthesis
if {[file exists $out/asic_clk_period]} {
  set clk_period [xh_read $out/asic_clk_period]
  if {$clk_period ne ""} {
    set ::env(ASIC_CLK_PERIOD) $clk_period
  } else {
    unset -nocomplain ::env(ASIC_CLK_PERIOD)
  }
}

# The libraries Yosys mapped onto (std cells) and the hard cells (SRAM, IO)
read_liberty [lindex [tech_stdcell_libs] 0]
foreach lib [tech_yosys_macro_libs] { read_liberty $lib }
read_verilog $out/netlist.v
link_design $top
read_sdc $out/constraints.sdc

# No simulation activity: every input toggles with probability 0.1 per cycle
set power_activity 0.1
if {[catch {set_power_activity -input -activity $power_activity} err]} {
  puts "\[x-heep] WARNING: set_power_activity: $err (OpenSTA default activity)"
}

# Leaf cells and integrated clock gates (ICG)
set n_cells 0
set icgs {}
set clock_gate_cells [expr {[info exists TECH_CLOCK_GATE_CELLS] ? $TECH_CLOCK_GATE_CELLS : {}}]
foreach cell [get_cells -hierarchical *] {
  if {[catch {get_property $cell liberty_cell} lib_cell] || $lib_cell eq ""} { continue }
  incr n_cells
  set ref [get_property $cell ref_name]
  foreach pattern $clock_gate_cells {
    if {[string match $pattern $ref]} {
      lappend icgs [list [get_full_name $cell] $ref]
      break
    }
  }
}
set n_registers [llength [all_registers]]

# Clocks
set text [xh_capture {
  report_clock_properties
  report_clock_skew -digits 3
}]
xh_report clocks.rpt "clocks (OpenSTA, ideal clocks before CTS)" $text a

# Combinational loops
xh_report timing_loop.rpt "timing loops" [xh_capture { check_setup -verbose -loops }]

# Timing checks of the constraints: unclocked registers, unconstrained endpoints, ...
xh_report check_timing_compile.rpt "check timing" [xh_capture { check_setup -verbose }]

# Worst paths
set text [xh_capture {
  report_checks -path_delay max -format full_clock_expanded \
    -fields {capacitance slew input_pins fanout} -digits 3
  report_checks -path_delay min -format full_clock_expanded \
    -fields {capacitance slew input_pins fanout} -digits 3
}]
xh_report timing.rpt "timing -path_delay max/min" $text

# Constraints: worst values, then the violators
set checks {-max_delay -min_delay -max_slew -max_capacitance -max_fanout}
set text [xh_capture {
  report_worst_slack -max -digits 3
  report_worst_slack -min -digits 3
  report_tns -max -digits 3
  report_tns -min -digits 3
  report_check_types {*}$checks -digits 3
}]
append text "\n---- Violators ----\n\n"
append text [xh_capture { report_check_types {*}$checks -violators -digits 3 }]
xh_report constraints.rpt "constraints" $text

# Clock gating: Yosys does not insert clock gates (no -gate_clock), these are
# the ones the RTL instantiates
set text "Integrated clock-gating cells ($clock_gate_cells): [llength $icgs]\n"
append text "Registers: $n_registers\n\n"
set by_type [dict create]
foreach icg $icgs { dict incr by_type [lindex $icg 1] }
dict for {ref n} $by_type { append text [format "  %-24s %d\n" $ref $n] }
append text "\n"
append text [xh_capture { report_check_types -clock_gating_setup -clock_gating_hold -digits 3 }]
append text "\nInstances:\n"
foreach icg $icgs { append text "  [lindex $icg 0] ([lindex $icg 1])\n" }
xh_report clock_gating.rpt "clock gating" $text

# Power
set text "Vectorless estimate: input activity $power_activity, no wires (before place and route)\n\n"
append text [xh_capture { report_power -digits 3 }]
xh_report power.rpt "power" $text

# Quality of results
set text ""
foreach clk [all_clocks] {
  append text "Clock [get_full_name $clk]: period [get_property $clk period] ns\n"
}
append text "\n"
append text [xh_capture {
  report_clock_min_period
  report_wns -max -digits 3
  report_tns -max -digits 3
  report_wns -min -digits 3
  report_tns -min -digits 3
}]
append text "\nLeaf cells: $n_cells\n"
append text "Registers: $n_registers\n"
append text "Integrated clock gates: [llength $icgs]\n"
if {[file exists $out/area.rpt] && [regexp {Chip area for top module[^\n]*} [xh_read $out/area.rpt] area]} {
  append text "$area (Yosys, area.rpt)\n"
}
xh_report qor.rpt "qor" $text

write_sdc $out/netlist.sdc
puts "\[x-heep] $out/netlist.sdc"

# run_sta.sh checks for this line
puts "\[x-heep] OpenSTA reports done"
