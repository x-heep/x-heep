# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Command-line access to a technology description, for shell scripts:
#   tclsh query.tcl <tech> sim-models   functional Verilog models, one per line
#   tclsh query.tcl <tech> sim-flags    vlog flags for those models
#   tclsh query.tcl <tech> check        resolve (and print) everything each
#                                       flow needs; exit 1 if anything is missing
# Errors (e.g. unset kit root, missing file) go to stderr with exit code 1.

if {[llength $argv] != 2} {
  puts stderr "usage: tclsh query.tcl <tech> sim-models|sim-flags|check"
  exit 2
}
lassign $argv tech what

set tech_file [file join [file dirname [info script]] $tech.tcl]
if {![file exists $tech_file]} {
  puts stderr "\[asic] unknown technology '$tech' (no $tech_file)"
  exit 2
}
source $tech_file

switch -- $what {
  sim-models {
    if {[catch {tech_sim_models} res]} { puts stderr $res; exit 1 }
    puts [join $res "\n"]
  }
  sim-flags {
    puts $TECH_SIM_VLOG_FLAGS
  }
  check {
    set ok 1
    puts "Technology $TECH_NAME (root: \$$TECH_ROOT_VAR = '[asic_env $TECH_ROOT_VAR]')"
    foreach {label cmd} {
      "yosys: std-cell Liberty"        tech_stdcell_libs
      "yosys: hard-cell Liberty"       tech_yosys_macro_libs
      "sim: Verilog models"            tech_sim_models
    } {
      if {[catch {$cmd} res]} {
        puts "\n\[MISSING] $label\n  $res"
        set ok 0
      } else {
        puts "\n\[OK] $label"
        foreach f $res { puts "  $f" }
      }
    }
    puts "\nsim: vlog flags: $TECH_SIM_VLOG_FLAGS +nospecify +notimingcheck"
    if {[info exists TECH_ABC_DRIVING_CELL] && [info exists TECH_ABC_LOAD_FF]} {
      puts "yosys: ABC driving cell $TECH_ABC_DRIVING_CELL, output load $TECH_ABC_LOAD_FF fF"
    }
    exit [expr {$ok ? 0 : 1}]
  }
  default {
    puts stderr "unknown query '$what'"
    exit 2
  }
}
