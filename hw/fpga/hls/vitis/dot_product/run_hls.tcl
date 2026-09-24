# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Standalone Vitis HLS build for the dot_product streaming engine.
# Run with:
#   vitis_hls -f run_hls.tcl
#
# Part / clock period match the pynq-z2 Zynq-7020 target and the 8ns
# (125MHz) sys_clk used in hw/fpga/xheep_fpga_support/constraints/pynq-z2.

open_project -reset dot_product_proj
set_top dot_product

add_files dot_product.cpp
add_files -tb dot_product_tb.cpp

open_solution -reset "solution1"
set_part {xc7z020clg400-1}
create_clock -period 8 -name default

# csim_design is skipped here: this host's Vitis HLS 2021.1 install links
# the native testbench executable with its bundled binutils-2.26 'ld',
# which cannot parse the RELR relocation sections in this system's
# libm.so.6/libmvec.so.1 (Ubuntu 24.04 glibc). Run csim_design manually
# with a newer 'ld' ahead of it in PATH if you need C-level verification.
csynth_design

# export_design (IP-catalog packaging) is intentionally skipped: Vivado
# 2021.1's IP packager derives an integer core_revision from today's date,
# which overflows its 32-bit field once the year is 2026+. We don't need
# the packaged IP-XACT anyway -- X-HEEP integration uses a hand-written
# wrapper (rtl/dot_product_xheep_wrapper.sv) directly against the plain
# RTL produced by csynth_design under solution1/syn/verilog/.

exit
