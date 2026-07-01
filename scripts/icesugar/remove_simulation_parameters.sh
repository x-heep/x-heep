#!/bin/bash
# This script change the fpga wrapper for fpga implementation after it was use for simulation
# It effectively comment two parameters given to the x_heep_system instance

pushd ../../../hw/fpga/

sed -i 's/      .EXT_XBAR_NMASTER(8),/     \/\/.EXT_XBAR_NMASTER(8),/g' fpga_core_v_mini_mcu_wrapper.sv 
sed -i 's/      .AO_SPC_NUM(1)/      \/\/.AO_SPC_NUM(1)/g' fpga_core_v_mini_mcu_wrapper.sv

popd
