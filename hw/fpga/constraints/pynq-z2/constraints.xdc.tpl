<%
  user_peripheral_domain = xheep.get_user_peripheral_domain()
%>
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports {clk_i}];
create_clock -add -name jtag_clk_pin -period 100.00 -waveform {0 50} [get_ports {jtag_tck_i}];
create_clock -add -name spi_slave_clk_pin -period 16.00 -waveform {0 8} [get_ports {spi_slave_sck_io}];

### Reset Constraints
set_false_path -from x_heep_system_i/core_v_mini_mcu_i/debug_subsystem_i/dm_obi_top_i/i_dm_top/i_dm_csrs/dmcontrol_q_reg\[ndmreset\]/C
set_false_path -from x_heep_system_i/rstgen_i/i_rstgen_bypass/synch_regs_q_reg[3]/C
% if user_peripheral_domain.contains_peripheral('serial_link'):
### Serial Link 
# Derived clock period and phase settings
set T_CLK 66.667              ;# Period of clk_gen in ns.
set FWD_CLK_DIV 8             ;# Divider for forward clock
set T_FWD_CLK [expr $T_CLK * $FWD_CLK_DIV] ;# Forward clock period

# Rising edge is at 270 degree, falling edge at 450 (resp. 90) degrees
#set ddr_edge_list [list [expr $FWD_CLK_DIV / 4 * 3] [expr $FWD_CLK_DIV / 4 * 5]]
set ddr_edge_list [list [expr $T_FWD_CLK / 4 * 3] [expr $T_FWD_CLK / 4 * 5]]
create_clock -name vir_clk_ddr_in -period $T_FWD_CLK
create_clock -name clk_ddr_in -period $T_FWD_CLK -waveform $ddr_edge_list [get_ports ddr_rcv_clk_i]


# The data launching clock with 0 degree clock phase
create_generated_clock -name clk_slow -source [get_pins xilinx_clk_wizard_wrapper_i/clk_out1_0] -divide_by $FWD_CLK_DIV \
    [get_pins -hierarchical clk_slow_reg/Q]

# this is the "forwarded clock", we are assuming it is shifted by -90 or +270 degrees (or +90 degrees and inverted)
set ddr_edge_list [list [expr 1 + $FWD_CLK_DIV / 2 * 3] [expr 1 + $FWD_CLK_DIV / 2 * 5] [expr 1 + $FWD_CLK_DIV / 2 * 7]]
create_generated_clock -name clk_ddr_out -source [get_pins xilinx_clk_wizard_wrapper_i/clk_out1_0] -edges $ddr_edge_list \
    [get_pins -hierarchical ddr_rcv_clk_o_reg/Q]
# create_generated_clock -name clk_ddr_out -source [get_pins -hierarchical "*clk_slow_reg/Q*"] -edges {1 2 3} -edge_shift {-133.334 -133.334 -133.334} [get_pins -hierarchical "*ddr_rcv_clk_o_reg/Q*"]
# Input
set_false_path -setup -rise_from [get_clocks vir_clk_ddr_in] -rise_to [get_clocks clk_ddr_in]
set_false_path -setup -fall_from [get_clocks vir_clk_ddr_in] -fall_to [get_clocks clk_ddr_in]
# Output
set_false_path -setup -rise_from [get_clocks clk_slow] -rise_to [get_clocks clk_ddr_out]
set_false_path -setup -fall_from [get_clocks clk_slow] -fall_to [get_clocks clk_ddr_out]

# Input
set_false_path -hold  -rise_from [get_clocks vir_clk_ddr_in] -fall_to [get_clocks clk_ddr_in]
set_false_path -hold  -fall_from [get_clocks vir_clk_ddr_in] -rise_to [get_clocks clk_ddr_in]
# Output
set_false_path -hold  -rise_from [get_clocks clk_slow] -fall_to [get_clocks clk_ddr_out]
set_false_path -hold  -fall_from [get_clocks clk_slow] -rise_to [get_clocks clk_ddr_out]

set_false_path -from [get_clocks sys_clk_pin] -to [get_clocks clk_ddr_out]
# set_false_path -from [get_clocks clk_gen] -to [get_clocks clk_ddr_out]
set_false_path -from [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0] -to [get_clocks clk_ddr_out]
set_false_path -from [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0_1] -to [get_clocks clk_ddr_out]

set_false_path -from [get_clocks sys_clk_pin] -to [get_clocks clk_ddr_in]
set_false_path -from [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0] -to [get_clocks clk_ddr_in]
set_false_path -from [get_clocks clk_out1_xilinx_clk_wizard_clk_wiz_0_0_1] -to [get_clocks clk_ddr_in]

# Window has a margin on both side of 5% of a quarter of the clock period
set MARGIN              [expr $T_FWD_CLK / 4 * 0.05]

# Input delays
set_input_delay -max -clock [get_clocks vir_clk_ddr_in] [expr $MARGIN] [get_ports ddr_i]
set_input_delay -add_delay -min -clock [get_clocks vir_clk_ddr_in] [expr -$MARGIN] [get_ports ddr_i]
set_input_delay -add_delay -max -clock_fall -clock [get_clocks vir_clk_ddr_in] [expr $MARGIN] [get_ports ddr_i]
set_input_delay -add_delay -min -clock_fall -clock [get_clocks vir_clk_ddr_in] [expr -$MARGIN] [get_ports ddr_i]

# Output delays
set_output_delay -max -clock [get_clocks clk_ddr_out] [expr $T_FWD_CLK / 4 - $MARGIN] -reference_pin [get_ports ddr_rcv_clk_o] [get_ports ddr_o]
set_output_delay -add_delay -min -clock [get_clocks clk_ddr_out] [expr $MARGIN - $T_FWD_CLK / 4] -reference_pin [get_ports ddr_rcv_clk_o] [get_ports ddr_o]
set_output_delay -add_delay -max -clock_fall -clock [get_clocks clk_ddr_out] [expr $T_FWD_CLK / 4 - $MARGIN] -reference_pin [get_ports ddr_rcv_clk_o] [get_ports ddr_o]
set_output_delay -add_delay -min -clock_fall -clock [get_clocks clk_ddr_out] [expr $MARGIN - $T_FWD_CLK / 4] -reference_pin [get_ports ddr_rcv_clk_o] [get_ports ddr_o]
% endif