# import yosys plugin
yosys plugin -i slang.so

# import yosys commands
yosys -import

log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 00\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"
# turning echoing back of commands ON
echo on

log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 01\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

#proc set_defines {} {
#set defines {}

#foreach d ${defines} {
#  set key [lindex $d 0]
#  set val [lindex $d 1]
#  verilog_defines "-D$key=$val"
#}}

#proc set_incdirs {} {
#verilog_defaults -add -I../../../hw/vendor/openhwgroup_cv32e20/vendor/lowrisc_ip/dv/sv/dv_utils -I../../../hw/vendor/lowrisc_opentitan/hw/ip/prim/rtl -I../../../hw/vendor/pulp_platform_common_cells/include -I../../../hw/vendor/pulp_platform_register_interface/include -I../../../hw/vendor/openhwgroup_cv32e20/rtl -I../../../hw/vendor/pulp_platform_axi/include -I../../../hw/vendor/xheep_dma/data -I../../../hw/vendor/pulp_platform_serial_link/src/axis/include}

#proc set_params {} {
#}

proc synth {top} {
synth_ecp5 -top $top
}

# if i add -noflatten it makes the utilization way higher
# without it i have :
#Info: Logic utilisation before packing:
#Info:     Total LUT4s:     18795/24288    77%
#Info:         logic LUTs:  17381/24288    71%
#Info:         carry LUTs:   1414/24288     5%
#Info:           RAM LUTs:      0/ 3036     0%
#Info:          RAMW LUTs:      0/ 6072     0%
#Info:      Total DFFs:     10714/24288    44%
# with it i have:
#Info: Logic utilisation before packing:
#Info:     Total LUT4s:     31371/24288   129%
#Info:         logic LUTs:  28757/24288   118%
#Info:         carry LUTs:   2614/24288    10%
#Info:           RAM LUTs:      0/ 3036     0%
#Info:          RAMW LUTs:      0/ 6072     0%
#Info:      Total DFFs:     11232/24288    46%




proc synth_lat {top} {
synth_lattice -top $top -family ecp5
}

#testing -noflatten to keep it from flattening


set top lattice_core_v_mini_mcu_wrapper
set name openhwgroup.org_systems_core-v-mini-mcu_1.0.5



log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 02\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"


log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 03\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

#source "../../../hw/fpga/scripts/generate_sram.tcl"
#this one is ignored for now as it cause issues
#ERROR: ERROR: TCL interpreter returned an error: invalid command name "create_ip"
# we manually create memory for now, need to automate later


log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 04\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

#source "../../../scripts/yosys/edalize_yosys_procs.tcl"

log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 05\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

#theses are not needed as they only affect `read_verilog`

#verilog_defaults -push
#verilog_defaults -add -defer
#set_defines
#set_incdirs

log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 06\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

#this needs to be added with the -f files
#read_slang -I ../../../hw/vendor/openhwgroup_cv32e20/vendor/lowrisc_ip/dv/sv/dv_utils -I ../../../hw/vendor/lowrisc_opentitan/hw/ip/prim/rtl -I ../../../hw/vendor/pulp_platform_common_cells/include -I ../../../hw/vendor/pulp_platform_register_interface/include -I ../../../hw/vendor/openhwgroup_cv32e20/rtl -I ../../../hw/vendor/pulp_platform_axi/include -I ../../../hw/vendor/xheep_dma/data -I ../../../hw/vendor/pulp_platform_serial_link/src/axis/include}

#================= Version 1
#read_verilog -lib +/lattice/cells_bb_ecp5.v 
# THIS IS NEEDED TO YOSYS RECOGNIZE DCSC MACRO
#read_verilog -lib +/lattice/cells_io.vh 
# THIS IS NEEDED TO YOSYS RECOGNIZE DCSC MACRO

#================= Version 2
#read_verilog -lib -specify +/ecp5/cells_sim.v +/ecp5/cells_bb.v
#this is needed so yosys recognize the DCSC macro ?

#================= Version 3
read_verilog -lib -specify +/lattice/cells_sim_ecp5.v +/lattice/cells_bb_ecp5.v
# THIS IS NEEDED TO YOSYS RECOGNIZE DCSC & BB MACRO


#read_verilog ../../../hw/vendor/yosyshq_picorv32/picosoc/spimemio.v
#files.flist line 199
#i get the warnings but it is actually not raised as an error :)

log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 07\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

#read_slang -f "../../../scripts/yosys/files.flist" -I ../../../hw/vendor/openhwgroup_cv32e20/vendor/lowrisc_ip/dv/sv/dv_utils -I ../../../hw/vendor/lowrisc_opentitan/hw/ip/prim/rtl -I ../../../hw/vendor/pulp_platform_common_cells/include -I ../../../hw/vendor/pulp_platform_register_interface/include -I ../../../hw/vendor/openhwgroup_cv32e20/rtl -I ../../../hw/vendor/pulp_platform_axi/include -I ../../../hw/vendor/xheep_dma/data -I ../../../hw/vendor/pulp_platform_serial_link/src/axis/include --error-limit=5 -Wno-implicit-port-type-mismatch -Wno-duplicate-definition   --ignore-unknown-modules --top $top --best-effort-hierarchy --single-unit  --libraries-inherit-macro

#read_slang -f "../../../scripts/yosys/files.flist" -I ../../../hw/vendor/openhwgroup_cv32e20/vendor/lowrisc_ip/dv/sv/dv_utils -I ../../../hw/vendor/lowrisc_opentitan/hw/ip/prim/rtl -I ../../../hw/vendor/pulp_platform_common_cells/include -I ../../../hw/vendor/pulp_platform_register_interface/include -I ../../../hw/vendor/openhwgroup_cv32e20/rtl -I ../../../hw/vendor/pulp_platform_axi/include -I ../../../hw/vendor/xheep_dma/data -I ../../../hw/vendor/pulp_platform_serial_link/src/axis/include --error-limit=5 -Wno-implicit-port-type-mismatch -Wno-duplicate-definition --top $top  --allow-use-before-declare --keep-hierarchy --allow-hierarchical-const --compat-mode --single-unit

# i migrated the includes to files.flist


read_slang --top $top \
	--error-limit=100 \
	-Wno-implicit-port-type-mismatch \
	-Wno-duplicate-definition \
	-Wno-implicit-conv \
	-Wno-redef-macro \
	-Wno-unconnected-port \
	--keep-hierarchy \
	--allow-use-before-declare \
	-f "../../../scripts/yosys/files.flist"

# -libfile plutot que la ligne 71 ??????????????????????????????????????????????????????????????



#	--single-unit \
#	--allow-hierarchical-const \
#	--compat-mode \


#	--ignore-initial
#	-D SYNTHESIS -D REMOVE_OBI_FIFO -D FPGA_SYNTHESIS
#	--libraries-inherit-macros
#	-Wno-error=implicit-port-type-mismatch -Wno-error=duplicate-definition 
#	-Wno-error=conversion -Wno-error=extra -Wno-error=parentheses -Wno-error=pedantic -Wno-error=unconnected-port -Wno-error=unused

#--error-limit=5			
# 	Set limit on number of errors printed
#-Wno-implicit-port-type-mismatch
#	disable warning for implicit-port-type-mismatch
#-Wno-duplicate-definition
#	disable warning for duplicate-definition
#--allow-use-before-declare
#	Don't issue error if an identifier is used before its declaration
#--keep-hierarchy
#	--keep-hierarchy		Keep hierarchy (experimental; may crash)
#  	--best-effort-hierarchy		Keep hierarchy in a 'best effort' mode	
#--allow-hierarchical-const		
#	Allow hierarchical references in constant expressions
#--compat-mode
#	Be relaxed about the synthesis semantics of some language constructs
#--single-unit
#	Treat all input files as a single compilation unit


log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 08\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

# this one is not defined anymore
#read_files  
#set_params

#verilog_defaults -pop

#synth_lat $top
# synth cv32e40p_top

synth_lattice -top $top -family ecp5 
#-json openhwgroup.org_systems_core-v-mini-mcu_1.0.5_synth.json
#synth_ecp5 -top $top -json openhwgroup.org_systems_core-v-mini-mcu_1.0.4_synth.json

# TODO try without the -json option as i write_json after

#async2sync
# seems to have no effect
#-asyncprld
# seems to have no effect

log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 09\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

#write_json openhwgroup.org_systems_core-v-mini-mcu_1.0.5.json
#write_verilog openhwgroup.org_systems_core-v-mini-mcu_1.0.5.v
write_json $name.json
write_verilog $name.v

log "\n\n=-=-=-=-=-=-=-=-=-=-=-=-=-=>\t   Checkpoint 10\t<=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

