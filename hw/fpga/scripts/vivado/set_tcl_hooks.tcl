# Copyright 2026 Politecnico di Torino.
#
# File: set_tcl_hooks.tcl
# Author: Christian Conti {christian.conti@polito.it}
# Date: 31/03/2026
#
# Sourced by FuseSoC/Edalize during project setup

set supported_boards [dict create \
    "aup-zu3-8gb" "../aup-zu3/xilinx_generate_ps_wizard.tcl" \
    "pynq-z2"     "../pynq-z2/xilinx_generate_ps_wizard.tcl" \
]

set board [current_board]
set vlog_defines [get_property verilog_define [current_fileset]]

# PS_ENABLE active
if {[lsearch -exact $vlog_defines "PS_ENABLE=1"] >= 0} {

    puts "INFO: PS_ENABLE is active..."

    set here [file dirname [info script]]
    set ps_script_path ""
    set matched_board ""

    # Iterate through the dictionary to find a substring match
    dict for {board_key rel_path} $supported_boards {
        if {[string match -nocase "*$board_key*" $board]} {
            set ps_script_path [file normalize [file join $here $rel_path]]
            set matched_board $board_key
            break
        }
    }

    # Source the PS wizard script if a match was found
    if {$ps_script_path != ""} {
        if {[file exists $ps_script_path]} {
            source $ps_script_path
        }
    }

    # Attach ECO to implementation run (post opt_design)
    set eco [file normalize [file join $here "eco_spi_flash_mux.tcl"]]
    set_property -name {STEPS.OPT_DESIGN.TCL.POST} -value $eco -objects [get_runs impl_1]
}
