### Sync Cell Constraints

# Generic synchronizers should be constrained only to their first stage.
set sync_first_stage_pins [get_pins -hier -filter { \
  NAME =~ "*/i_sync/reg_q_reg[0]/D" && \
  NAME !~ "*dmi_jtag_i/*" \
}]

set_max_delay 20.000 \
  -to $sync_first_stage_pins

set_false_path -hold \
  -to $sync_first_stage_pins
