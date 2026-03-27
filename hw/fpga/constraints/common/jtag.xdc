### JTAG Constraints

set xheep_core_clk_period_ns [expr {1000.0 / double($::env(FPGA_CORE_CLK_MHZ))}]
set jtag_clk_period_ns [get_property PERIOD [get_clocks jtag_clk_pin]]
set jtag_cdc_max_delay_ns [expr {min($xheep_core_clk_period_ns, $jtag_clk_period_ns)}]

# Name the key CDC objects once, then express the constraints in terms of "boundary registers"
set cdc2_req_src_pins [get_pins -hier -filter {NAME =~ "*i_dmi_cdc/i_cdc_*/i_src/req_src_q_reg/C"}]
set cdc2_data_src_pins [get_pins -hier -filter {NAME =~ "*i_dmi_cdc/i_cdc_*/i_src/data_src_q_reg*/C"}]
set cdc2_req_boundary_pins [get_pins -hier -filter {NAME =~ "*i_dmi_cdc/i_cdc_*/i_dst/i_sync/reg_q_reg[0]/D"}]
set cdc2_data_boundary_pins [get_pins -hier -filter {NAME =~ "*i_dmi_cdc/i_cdc_*/i_dst/data_dst_q_reg*/D"}]
set cdc2_ack_src_pins [get_pins -hier -filter {NAME =~ "*i_dmi_cdc/i_cdc_*/i_dst/ack_dst_q_reg/C"}]
set cdc2_ack_boundary_pins [get_pins -hier -filter {NAME =~ "*i_dmi_cdc/i_cdc_*/i_src/i_sync/reg_q_reg[0]/D"}]

set reset_ctrlr_req_src_pins [get_pins -hier -filter {NAME =~ "*i_cdc_reset_ctrlr_half_*/i_state_transition_cdc_src/req_src_q_reg/C"}]
set reset_ctrlr_data_src_pins [get_pins -hier -filter {NAME =~ "*i_cdc_reset_ctrlr_half_*/i_state_transition_cdc_src/data_src_q_reg*/C"}]
set reset_ctrlr_ack_src_pins [get_pins -hier -filter {NAME =~ "*i_cdc_reset_ctrlr_half_*/i_state_transition_cdc_dst/ack_dst_q_reg/C"}]
set reset_ctrlr_ack_boundary_pins [get_pins -hier -filter {NAME =~ "*i_cdc_reset_ctrlr_half_*/i_state_transition_cdc_src/i_sync/reg_q_reg[0]/D"}]

# Any sequential pin driven by the receiver side of the 4-phase reset controller is part of the CDC boundary.
set reset_ctrlr_boundary_pins [get_pins -hier -filter { \
  NAME =~ "*i_cdc_reset_ctrlr_half_*/receiver_phase_q_reg*/D" || \
  NAME =~ "*i_cdc_reset_ctrlr_half_*/receiver_phase_q_reg*/CE" || \
  NAME =~ "*i_cdc_reset_ctrlr_half_*/i_state_transition_cdc_src/i_sync/reg_q_reg[0]/D" || \
  NAME =~ "*i_cdc_reset_ctrlr_half_*/i_state_transition_cdc_dst/*_reg*/D" || \
  NAME =~ "*i_cdc_reset_ctrlr_half_*/i_state_transition_cdc_dst/*_reg*/CE" \
}]

set clearable_local_boundary_pins [get_pins -hier -filter { \
  NAME =~ "*i_dmi_cdc/i_cdc_*/i_src/*_reg*/D" || \
  NAME =~ "*i_dmi_cdc/i_cdc_*/i_src/*_reg*/CE" || \
  NAME =~ "*i_dmi_cdc/i_cdc_*/i_dst/*_reg*/D" || \
  NAME =~ "*i_dmi_cdc/i_cdc_*/i_dst/*_reg*/CE" || \
  NAME =~ "*i_dmi_cdc/i_cdc_*/s_*_ack_q_reg/D" || \
  NAME =~ "*i_dmi_cdc/i_cdc_*/s_*_ack_q_reg/CE" \
}]

# Anything beyond i_dmi_cdc is consumer logic, not CDC boundary.
set dmi_jtag_consumer_pins [get_pins -hier -filter { \
  (NAME =~ "*dmi_jtag_i/*/D" || NAME =~ "*dmi_jtag_i/*/CE") && \
  NAME !~ "*dmi_jtag_i/i_dmi_cdc/*" \
}]

# 2-phase CDC request/data crossings.
set_max_delay -datapath_only $jtag_cdc_max_delay_ns -from $cdc2_req_src_pins -to $cdc2_req_boundary_pins
set_false_path -hold -from $cdc2_req_src_pins -to $cdc2_req_boundary_pins

set_max_delay -datapath_only $jtag_cdc_max_delay_ns -from $cdc2_data_src_pins -to $cdc2_data_boundary_pins
set_false_path -hold -from $cdc2_data_src_pins -to $cdc2_data_boundary_pins

set_max_delay -datapath_only $jtag_cdc_max_delay_ns -from $cdc2_ack_src_pins -to $cdc2_ack_boundary_pins
set_false_path -hold -from $cdc2_ack_src_pins -to $cdc2_ack_boundary_pins

# 4-phase reset-controller request/data crossings.
set_max_delay -datapath_only $jtag_cdc_max_delay_ns -from $reset_ctrlr_req_src_pins \
  -to [get_pins -hier -filter {NAME =~ "*i_cdc_reset_ctrlr_half_*/i_state_transition_cdc_dst/i_sync/reg_q_reg[0]/D"}]
set_false_path -hold -from $reset_ctrlr_req_src_pins \
  -to [get_pins -hier -filter {NAME =~ "*i_cdc_reset_ctrlr_half_*/i_state_transition_cdc_dst/i_sync/reg_q_reg[0]/D"}]

set_max_delay -datapath_only $jtag_cdc_max_delay_ns -from $reset_ctrlr_ack_src_pins -to $reset_ctrlr_ack_boundary_pins
set_false_path -hold -from $reset_ctrlr_ack_src_pins -to $reset_ctrlr_ack_boundary_pins

set_max_delay -datapath_only $jtag_cdc_max_delay_ns -from $reset_ctrlr_data_src_pins -to $reset_ctrlr_boundary_pins
set_false_path -hold -from $reset_ctrlr_data_src_pins -to $reset_ctrlr_boundary_pins

set_max_delay -datapath_only $jtag_cdc_max_delay_ns -from $reset_ctrlr_data_src_pins -to $clearable_local_boundary_pins
set_false_path -hold -from $reset_ctrlr_data_src_pins -to $clearable_local_boundary_pins

set_false_path -from $reset_ctrlr_data_src_pins -to $dmi_jtag_consumer_pins
