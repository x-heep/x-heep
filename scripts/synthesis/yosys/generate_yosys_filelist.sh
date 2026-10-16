#!/bin/bash
# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# This script creates a file list, from edalize_yosys_procs.tcl, that can be processed by the Slang plugin in Yosys.
# This is done from edalize_yosys_procs.tcl as core-deps.mk also includes non SV files (.core, .py).
# The procs file is Tcl: it is sourced with stub commands that print the include
# folders (as +incdir+) and the source files, one per line.
# TODO : modify edalize to directly generate the correct file when using Yosys.

tclsh > files.flist <<'TCL'
proc verilog_defaults {args} {
  foreach a $args { if {[string match -I* $a]} { puts "+incdir+[string range $a 2 end]" } }
}
proc read_verilog {args} { puts [lindex $args end] }
source edalize_yosys_procs.tcl
set_incdirs
read_files
TCL
