# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# IHP-SG13G2 technology description for the X-HEEP ASIC flows.
#
# Input: $PDK_XHEEP = IHP Open PDK root (the directory containing libs.ref/, or
# its parent). Each resource can be overridden with the variable named in
# its asic_find call below (e.g. IHP_SG13G2_STDCELL_LIB).
#
#   TECH_NAME, TECH_ROOT_VAR     technology name, env variable of its root
#   TECH_SIM_VLOG_FLAGS          vlog flags for the simulation models
#   TECH_ABC_DRIVING_CELL        cell ABC assumes drives the inputs
#   TECH_ABC_LOAD_FF             load ABC assumes on the outputs, in fF
#   TECH_CLOCK_GATE_CELLS        glob patterns of the integrated clock-gating cells (STA reports)
#   tech_stdcell_libs            std-cell Liberty used for mapping (yosys)
#   tech_yosys_macro_libs        Liberty of the hard cells the RTL instantiates (SRAM, IO)
#   tech_sim_models              functional Verilog models (gate-level sim)
#   tech_sim_macro_models        the same, IO pads and SRAM macros only

source [file join [file dirname [info script]] common.tcl]

set TECH_NAME ihp-sg13g2
set TECH_ROOT_VAR PDK_XHEEP

# FUNCTIONAL: wire the SRAM macros' behavioral core to their undelayed pins
# (otherwise to A_*_DELAY nets driven only by specify-block timing checks).
set TECH_SIM_VLOG_FLAGS {+define+FUNCTIONAL}

set TECH_ABC_DRIVING_CELL sg13g2_buf_4
set TECH_ABC_LOAD_FF 6.0
set TECH_CLOCK_GATE_CELLS {sg13g2_lgcp_* sg13g2_slgcp_*}

proc _ihp_sg13g2_ref {} {
  set root [asic_root PDK_XHEEP "IHP-SG13G2 PDK"]
  foreach cand [list $root/libs.ref $root/ihp-sg13g2/libs.ref] {
    if {[file isdirectory $cand]} { return $cand }
  }
  error "\[asic] \$PDK_XHEEP=$root: no libs.ref/ directory under it."
}

proc tech_stdcell_libs {} {
  set ref [_ihp_sg13g2_ref]
  return [asic_find "IHP std-cell Liberty" IHP_SG13G2_STDCELL_LIB \
    [list $ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib]]
}

proc _ihp_sg13g2_sram_libs {} {
  set ref [_ihp_sg13g2_ref]
  return [asic_find "IHP SRAM Liberty" IHP_SG13G2_SRAM_LIBS \
    [list "$ref/sg13g2_sram/lib/*_typ_1p20V_25C.lib"]]
}

proc _ihp_sg13g2_io_libs {} {
  set ref [_ihp_sg13g2_ref]
  return [asic_find "IHP IO Liberty" IHP_SG13G2_IO_LIB \
    [list $ref/sg13g2_io/lib/sg13g2_io_typ_1p2V_3p3V_25C.lib]]
}

proc tech_yosys_macro_libs {} { return [concat [_ihp_sg13g2_sram_libs] [_ihp_sg13g2_io_libs]] }

proc tech_sim_models {} {
  set ref [_ihp_sg13g2_ref]
  return [concat \
    [asic_find "IHP std-cell Verilog models" IHP_SG13G2_STDCELL_V [list "$ref/sg13g2_stdcell/verilog/*.v"]] \
    [tech_sim_macro_models]]
}

proc tech_sim_macro_models {} {
  set ref [_ihp_sg13g2_ref]
  return [concat \
    [asic_find "IHP IO Verilog models" IHP_SG13G2_IO_V [list "$ref/sg13g2_io/verilog/*.v"]] \
    [asic_find "IHP SRAM Verilog models" IHP_SG13G2_SRAM_V [list "$ref/sg13g2_sram/verilog/*.v"]]]
}
