set clk_period 20.0
if {[info exists ::env(ASIC_CLK_PERIOD)] && $::env(ASIC_CLK_PERIOD) ne ""} {
  set clk_period $::env(ASIC_CLK_PERIOD)
}

create_clock -name clk_i -period $clk_period [get_ports clk_i]