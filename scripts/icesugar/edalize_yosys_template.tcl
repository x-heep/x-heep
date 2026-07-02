# import yosys plugin
yosys plugin -i slang.so

# import yosys commands
yosys -import

# turning echoing back of commands ON
echo on

# set parameters
set top fpga_core_v_mini_mcu_wrapper
set name openhwgroup.org_systems_core-v-mini-mcu_1.0.5

# used to recognize Lattice primitives (unused at the moment)
read_verilog -lib -specify +/lattice/cells_sim_ecp5.v +/lattice/cells_bb_ecp5.v

# reads all the source files
# macros are note passed automatically from fusesoc so they are redefined here
read_slang --top $top \
	--define-macro SYNTHESIS=true \
	--define-macro FPGA_SYNTHESIS=true \
	--define-macro FPGA_ICESUGARPRO=true \
	--define-macro NO_DDR_CLK_PORTS=true \
	--error-limit=100 \
	-Wno-implicit-port-type-mismatch \
	-Wno-duplicate-definition \
	-Wno-implicit-conv \
	-Wno-redef-macro \
	-Wno-unconnected-port \
	--keep-hierarchy \
	--allow-use-before-declare \
	-f "files.flist"

# does the synthesis (specifically for lattice boards)
synth_lattice -top $top -family ecp5 

# write the output as .json (to use with nextpnr)
write_json $name.json

# write the output as verilog (to be more human readable, for debugging)
write_verilog $name.v

