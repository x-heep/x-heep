#!/bin/bash
# This script change the module for SRAM when using lattice-fpga target (or sim-icesugar)
# 	This is nescessary as we can not change how the file is generated during mcu-gen as target is not yet specified
# Some of the lines are there in case the script is launched multiple times (to revert previous changes)
#	This could happen when doing multiple `make verilator-build-lattice` or `make lattice-fpga` calls
# Theses lines should do nothing in case the sram_wrapper.sv is not yet modified 
#	i.e. on first `make verilator-build-lattice` or `make lattice-fpga` call

pushd ../../../hw/fpga/xheep_fpga_support/rtl/

# This change the module to use from the xilinx one to the custome one
sed -i 's/ssdp_rf_8192/xilinx_mem_gen_8192/g' sram_wrapper.sv # revert change of next line
sed -i 's/xilinx_mem_gen_8192/ssdp_wf_8192/g' sram_wrapper.sv

# This adds the sram_wrap_gen label to the block, needed for simulation
sed -i "s/if (NumWords == 32'd8192) begin : sram_wrap_gen/if (NumWords == 32'd8192) begin/g" sram_wrapper.sv # revert change of next line
sed -i "s/if (NumWords == 32'd8192) begin/if (NumWords == 32'd8192) begin : sram_wrap_gen/g" sram_wrapper.sv

# This change the previous condition for enabling writing, separating the byte enable
sed -i "s/req_i &  we_i/{4{req_i \& we_i}} \& be_i/g" sram_wrapper.sv # revert change of next line
sed -i "s/{4{req_i & we_i}} & be_i/req_i \&  we_i/g" sram_wrapper.sv

# This adds the byte enable input
sed -i "/        .be_i (be_i),/d" sram_wrapper.sv # revert change of next line
sed -i "s/        .addra(addr_i),/        .be_i (be_i),\n&/g" sram_wrapper.sv

# in case we want to create a new file to keep the old one intact, we would not need to rever changes and we could use :
#sed  's/xilinx_mem_gen_8192/ssdp_wf_8192/g' sram_wrapper.sv > sram_wrapper_icesugar.sv
#sed -i "s/if (NumWords == 32'd8192) begin/if (NumWords == 32'd8192) begin : sram_wrap_gen/g" sram_wrapper_icesugar.sv
#sed -i "s/{4{req_i & we_i}} & be_i/req_i \& we_i/g" sram_wrapper_icesugar.sv
#sed -i "s/        .addra(addr_i),/        .be_i (be_i),\n&/g" sram_wrapper_icesugar.sv
# but this means we need to change .core files to use sram_wrapper_icesugar.sv and not sram_wrapper.sv for specific targets

popd
