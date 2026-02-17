# -------------------------------------------------------------------------
# Implementation-only: AXI JTAG Bridge Clock Domain Crossing
# -------------------------------------------------------------------------
# This file MUST be marked USED_IN_IMPLEMENTATION only, because the
# tck_i_reg/Q generated clock does not exist until after synthesis.
#
# Three clock domains:
#   - clk_out1_xilinx_clk_wizard_clk_wiz_0_0  (system clock, from board 300MHz)
#   - clk_pl_0                                  (PS pl_clk0, 100MHz)
#   - tck_i_reg/Q                               (generated from clk_pl_0 by axi_jtag IP)
#
# clk_pl_0 and tck_i_reg/Q are synchronous (same domain).
# clk_out1_xilinx* is asynchronous to both.
# Assume clk_pl_0 is your AXI clock (100 MHz)
# tck_i_reg/Q is toggled every 8 cycles BUT you want TCK's "period" to be 16 cycles (160ns).
# You must override the toggle-inferred clock with the true TCK clock.


##
## Create Clock Constraints on BSCAN ports DRCK & UPDATE
##
set_property USED_IN_IMPLEMENTATION false [get_files  /users/gguedes/Documents/x-heep/build/openhwgroup.org_systems_core-v-mini-mcu_1.0.4/zcu104-vivado/openhwgroup.org_systems_core-v-mini-mcu_1.0.4.gen/sources_1/bd/axi_jtag_bridge/ip/axi_jtag_bridge_axi_jtag_0_0/constraints/axi_jtag.xdc]
# Disable for synthesis if needed
set_property USED_IN_SYNTHESIS false [get_files /users/gguedes/Documents/x-heep/build/openhwgroup.org_systems_core-v-mini-mcu_1.0.4/zcu104-vivado/openhwgroup.org_systems_core-v-mini-mcu_1.0.4.gen/sources_1/bd/axi_jtag_bridge/ip/axi_jtag_bridge_axi_jtag_0_0/constraints/axi_jtag.xdc]

create_clock -period 5.0 [get_ports s_axi_aclk]
set clk_period [get_property PERIOD [get_clocks -of_objects [get_ports -scoped_to_current_instance s_axi_aclk]]]
set tck_period [expr $clk_period * 32]
set max_delay [expr $tck_period/2]
create_generated_clock -source [get_pins -filter {REF_PIN_NAME=~C} -of_objects [get_cells -hierarchical -filter {NAME =~ "*/u_jtag_proc/tck_i_reg*"}]] -divide_by 32 [get_pins -filter {REF_PIN_NAME=~Q} -of_objects [get_cells -hierarchical -filter {NAME =~ "*/u_jtag_proc/tck_i_reg*"}]]
#create_clock -period $tck_period [get_ports -scoped_to_current_instance tck]

set_max_delay $max_delay -from [get_cells -hierarchical -filter {NAME =~ "*u_jtag_proc/tdi_output_reg[0]"}] -datapath_only
set_max_delay $max_delay -from [get_cells -hierarchical -filter {NAME =~ "*u_jtag_proc/tms_output_reg[0]"}] -datapath_only
#set_max_delay $max_delay -through [get_ports -scoped_to_current_instance tdo] -to [get_cells -hierarchical -filter {NAME =~ "*u_jtag_proc/tdo_buffer_reg[*][0]"}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ "*sync_reg1_reg*"}]

create_waiver -internal -scope -type CDC -id CDC-1 -from [get_pins -filter {REF_PIN_NAME=~C} -of_objects [get_cells -hierarchical -filter {NAME =~ "*u_jtag_proc/tdi_output_reg[0]*"}]]  -tags "1025927" -user "axi_jtag" -description {CDC is handled through handshake process}
create_waiver -internal -scope -type CDC -id CDC-1 -from [get_pins -filter {REF_PIN_NAME=~C} -of_objects [get_cells -hierarchical -filter {NAME =~ "*u_jtag_proc/tms_output_reg[0]*"}]]  -tags "1025927" -user "axi_jtag" -description {CDC is handled through handshake process}
create_waiver -internal -scope -type CDC -id CDC-15 -from [get_pins -filter {REF_PIN_NAME=~C} -of_objects [get_cells -hierarchical -filter {NAME =~ "*u_jtag_proc/tdi_output_reg[0]*"}]]  -tags "1025927" -user "axi_jtag" -description {CDC is handled through handshake process}

set_clock_groups -asynchronous \
    -group [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0] \
    -group [get_clocks clk_pl_0 axi_jtag_bridge_wrapper_i/axi_jtag_bridge_i/axi_jtag_0/inst/u_jtag_proc/tck_i_reg/Q]
#create_generated_clock \
    -name "tck_jtag" \
    -source [get_pins axi_jtag_bridge_wrapper_i/axi_jtag_bridge_i/zynq_ultra_ps_e_0/inst/PS8_i/PLCLK[0]] \
    -divide_by 32 \
    [get_nets axi_jtag_bridge_wrapper_i/axi_jtag_bridge_i/axi_jtag_0/inst/u_jtag_proc/tck]

#create_generated_clock \
    -name "tck_jtag_reg_q" \
    -source [get_pins axi_jtag_bridge_wrapper_i/axi_jtag_bridge_i/zynq_ultra_ps_e_0/inst/PS8_i/PLCLK[0]] \
    -divide_by 32 \
    [get_pins axi_jtag_bridge_wrapper_i/axi_jtag_bridge_i/axi_jtag_0/inst/u_jtag_proc/tck_i_reg/Q]

#set_clock_groups -asynchronous \
    -group [get_clocks {clk_out1_xilinx_clk_wizard_clk_wiz_0_0}] \
    -group [get_clocks {clk_pl_0 }]

#set_clock_groups -asynchronous \
    -group [get_clocks {clk_out1_xilinx_clk_wizard_clk_wiz_0_0}] \
    -group [get_clocks {tck_jtag}]

#set_clock_groups -asynchronous \
    -group [get_clocks {clk_out1_xilinx_clk_wizard_clk_wiz_0_0}] \
    -group [get_clocks {tck_jtag_reg_q}]



#set_false_path -from [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0] -to [get_clocks tck_jtag]
#set_false_path -from [get_clocks tck_jtag] -to [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0]
#set_false_path -from [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0] -to [get_clocks axi_jtag_bridge_wrapper_i/axi_jtag_bridge_i/axi_jtag_0/inst/u_jtag_proc/tck_i_reg/Q]
#set_false_path -from [get_clocks axi_jtag_bridge_wrapper_i/axi_jtag_bridge_i/axi_jtag_0/inst/u_jtag_proc/tck_i_reg/Q] -to [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0]
#set_false_path -through [get_pins "*data_src_q_reg*"]
#set_false_path -from [get_clocks "*wiz*"] -to [get_clocks "*tck*"]
#set_false_path -from [get_clocks "*tck*"] -to [get_clocks "*wiz*"]
