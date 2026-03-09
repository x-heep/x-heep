# -------------------------------------------------------------------------
# 1. SPI Slave Clock
# -------------------------------------------------------------------------
#create_clock -add -name jtag_clk_pin -period 320.00 -waveform {0 5} [get_ports {jtag_tck_i}];
# Overwrite the IP's generated clock with a new divider
create_generated_clock -name jtag_tck \
    -source [get_pins axi_jtag_bridge_wrapper_i/axi_jtag_bridge_i/axi_jtag_0/inst/u_jtag_proc/tck_i_reg/C] \    
    -divide_by 16 \
    [get_pins axi_jtag_bridge_wrapper_i/axi_jtag_bridge_i/axi_jtag_0/inst/u_jtag_proc/tck_i_reg/Q]

# 2. Cut the paths between the system and this new clock
#set_clock_groups -asynchronous \
#    -group [get_clocks -of_objects [get_pins axi_jtag_bridge_wrapper_i/axi_jtag_bridge_i/axi_jtag_0/inst/u_jtag_proc/tck_i_reg/Q]] \
#    -group [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0]
set_clock_groups -asynchronous -group [get_clocks clk_pl_0] -group [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0]
set_clock_groups -asynchronous \
    -group [get_clocks jtag_tck] \
    -group [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0]
### Reset Constraints
set_false_path -from x_heep_system_i/core_v_mini_mcu_i/debug_subsystem_i/dm_obi_top_i/i_dm_top/i_dm_csrs/dmcontrol_q_reg\[ndmreset\]/C
set_false_path -from x_heep_system_i/rstgen_i/i_rstgen_bypass/synch_regs_q_reg[3]/C

#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_pins -hier *u_jtag_proc/tck_i_reg/Q]]
set_false_path -through [get_pins -hier -filter {NAME =~ *u_jtag_proc/tck_i_reg/Q}]