#!/bin/bash
# This script change the module for SRAM when using ICESUGAR board

pushd hw/fpga/xheep_fpga_support/rtl/

sed -i 's/xilinx_mem_gen_8192/ssdp_wf_8192/g' sram_wrapper.sv
sed -i "s/if (NumWords == 32'd8192) begin/if (NumWords == 32'd8192) begin : sram_wrap_gen/g" sram_wrapper.sv


popd
