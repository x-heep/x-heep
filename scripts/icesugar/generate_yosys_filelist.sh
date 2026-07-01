#!/bin/bash
# This script creates a file list, from edalize_yosys_procs.tcl, that can be processed by Slang plugin in Yosys.
# This is done from edalize_yosys_procs.tcl as core-deps.mk also includes non SV files (.core, .py)
# Leonardo Vega

# First create a list of include folders
sed '/proc set_incdirs {} {/,/proc set_params {} {/!d' edalize_yosys_procs.tcl > includes.txt
sed -i '2!d' includes.txt
sed -i 's/}//g' includes.txt
sed -i 's/verilog_defaults -add //g' includes.txt
sed -i 's/-I/+incdir+/g' includes.txt
sed -i 's/\s/\n/g' includes.txt


# Then create the list of source files (SystemVerilog / Verilog)
sed '/proc read_files {} {/,/proc set_defines {} {/!d' edalize_yosys_procs.tcl > source_files.txt
sed -i '1d' source_files.txt
sed -i '$d' source_files.txt
sed -i '$d' source_files.txt
sed -i '$d' source_files.txt
sed -i 's/}//g' source_files.txt
sed -i 's/read_verilog -sv {//g' source_files.txt
sed -i 's/read_verilog {//g' source_files.txt

# Then combine them into a single file
cat includes.txt source_files.txt > files.flist


