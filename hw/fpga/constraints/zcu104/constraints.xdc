# -------------------------------------------------------------------------
# 1. SPI Slave Clock
# -------------------------------------------------------------------------
create_clock -add -name spi_slave_clk_pin -period 16.00 -waveform {0 5} [get_ports {spi_slave_sck_io}]

# -------------------------------------------------------------------------
# 2. AXI JTAG Bridge Clock Handling (BATCH-SAFE)
# -------------------------------------------------------------------------
# We define the groups directly.
# The "-quiet" flag prevents crashes during Synthesis if the clocks aren't ready yet.
# When Implementation runs, these commands run again, find the clocks, and fix the timing.

set_clock_groups -asynchronous \
    -group [get_clocks -quiet -filter {NAME =~ *tck_i_reg/Q}] \
    -group [get_clocks -quiet -filter {NAME =~ *clk_out1_xilinx*}]

# Explicit false paths to override any other max_delay rules
set_false_path -from [get_clocks -quiet -filter {NAME =~ *tck_i_reg/Q}] -to [get_clocks -quiet -filter {NAME =~ *clk_out1_xilinx*}]
set_false_path -from [get_clocks -quiet -filter {NAME =~ *clk_out1_xilinx*}] -to [get_clocks -quiet -filter {NAME =~ *tck_i_reg/Q}]

# -------------------------------------------------------------------------
# 3. Reset Constraints
# -------------------------------------------------------------------------
set_false_path -from [get_pins -quiet -hier *dmcontrol_q_reg\[ndmreset\]/C] -to [get_clocks -quiet *]
set_false_path -from [get_pins -quiet -hier *synch_regs_q_reg[3]/C] -to [get_clocks -quiet *]