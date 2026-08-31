# Copyright 2026 EPFL
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# VPK180 pin plan for the PS-enabled flow.
# - Use the real LPDDR4 clock pins from AMD's VPK180 master XDC.
# - Route all PL-side user I/O to the FMCP1 LA bank so the design can be wired
#   out through the FMC+ connector without touching board-management nets.
# - FMCP1 LA banks on VPK180 use VADJ_FMC, so the matching I/O standard from the
#   master XDC is LVCMOS15.

# -----------------------------------------------------------------------------
# LPDDR4 clocks
# Master XDC:
#   LPDDR4_CLK1_P -> BK6   (NoC LPDDR4 reference)
#   LPDDR4_CLK1_N -> BK5
#   LPDDR4_CLK3_P -> BV32  (X-HEEP system clock reference)
#   LPDDR4_CLK3_N -> BW33
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN BK6 IOSTANDARD DIFF_LVSTL_11} [get_ports {lpddr4_clk1_clk_p}]
set_property -dict {PACKAGE_PIN BK5 IOSTANDARD DIFF_LVSTL_11} [get_ports {lpddr4_clk1_clk_n}]
set_property -dict {PACKAGE_PIN BV32 IOSTANDARD DIFF_LVSTL_11} [get_ports {lpddr4_clk3_clk_p}]
set_property -dict {PACKAGE_PIN BW33 IOSTANDARD DIFF_LVSTL_11} [get_ports {lpddr4_clk3_clk_n}]

# -----------------------------------------------------------------------------
# NoC LPDDR4 memory channels
# Pins are copied from AMD's VPK180 master XDC. The generated BD wrapper exposes
# scalar CS/CKE pins, so these are mapped to rank-0 CS/CKE pins from the board.
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN BJ2 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_a[0]}]
set_property -dict {PACKAGE_PIN BJ3 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_a[1]}]
set_property -dict {PACKAGE_PIN BJ1 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_a[2]}]
set_property -dict {PACKAGE_PIN BL1 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_a[3]}]
set_property -dict {PACKAGE_PIN BM2 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_a[4]}]
set_property -dict {PACKAGE_PIN BM1 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_a[5]}]
set_property -dict {PACKAGE_PIN BM6 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_b[0]}]
set_property -dict {PACKAGE_PIN BP5 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_b[1]}]
set_property -dict {PACKAGE_PIN BM4 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_b[2]}]
set_property -dict {PACKAGE_PIN BN5 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_b[3]}]
set_property -dict {PACKAGE_PIN BP3 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_b[4]}]
set_property -dict {PACKAGE_PIN BN4 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_ca_b[5]}]
set_property -dict {PACKAGE_PIN BK3 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_ck_c_a}]
set_property -dict {PACKAGE_PIN BP2 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_ck_c_b}]
set_property -dict {PACKAGE_PIN BK4 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_ck_t_a}]
set_property -dict {PACKAGE_PIN BN3 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_ck_t_b}]
set_property -dict {PACKAGE_PIN BN2 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_cke_a}]
set_property -dict {PACKAGE_PIN BP6 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_cke_b}]
set_property -dict {PACKAGE_PIN BL2 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_cs_a}]
set_property -dict {PACKAGE_PIN BP12 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_cs_b}]
set_property -dict {PACKAGE_PIN BG2 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dmi_a[0]}]
set_property -dict {PACKAGE_PIN BM9 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dmi_a[1]}]
set_property -dict {PACKAGE_PIN BG11 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dmi_b[0]}]
set_property -dict {PACKAGE_PIN BN12 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dmi_b[1]}]
set_property -dict {PACKAGE_PIN BG6 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[0]}]
set_property -dict {PACKAGE_PIN BH7 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[1]}]
set_property -dict {PACKAGE_PIN BH5 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[2]}]
set_property -dict {PACKAGE_PIN BG4 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[3]}]
set_property -dict {PACKAGE_PIN BJ7 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[4]}]
set_property -dict {PACKAGE_PIN BH2 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[5]}]
set_property -dict {PACKAGE_PIN BJ6 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[6]}]
set_property -dict {PACKAGE_PIN BH3 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[7]}]
set_property -dict {PACKAGE_PIN BN9 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[8]}]
set_property -dict {PACKAGE_PIN BN8 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[9]}]
set_property -dict {PACKAGE_PIN BM11 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[10]}]
set_property -dict {PACKAGE_PIN BL10 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[11]}]
set_property -dict {PACKAGE_PIN BK10 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[12]}]
set_property -dict {PACKAGE_PIN BN11 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[13]}]
set_property -dict {PACKAGE_PIN BL9 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[14]}]
set_property -dict {PACKAGE_PIN BN10 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_a[15]}]
set_property -dict {PACKAGE_PIN BJ14 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[0]}]
set_property -dict {PACKAGE_PIN BJ12 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[1]}]
set_property -dict {PACKAGE_PIN BJ13 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[2]}]
set_property -dict {PACKAGE_PIN BH13 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[3]}]
set_property -dict {PACKAGE_PIN BH17 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[4]}]
set_property -dict {PACKAGE_PIN BH16 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[5]}]
set_property -dict {PACKAGE_PIN BH11 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[6]}]
set_property -dict {PACKAGE_PIN BG10 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[7]}]
set_property -dict {PACKAGE_PIN BN13 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[8]}]
set_property -dict {PACKAGE_PIN BP14 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[9]}]
set_property -dict {PACKAGE_PIN BN15 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[10]}]
set_property -dict {PACKAGE_PIN BM15 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[11]}]
set_property -dict {PACKAGE_PIN BK14 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[12]}]
set_property -dict {PACKAGE_PIN BL15 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[13]}]
set_property -dict {PACKAGE_PIN BL14 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[14]}]
set_property -dict {PACKAGE_PIN BN14 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_dq_b[15]}]
set_property -dict {PACKAGE_PIN BH4 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_dqs_c_a[0]}]
set_property -dict {PACKAGE_PIN BP7 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_dqs_c_a[1]}]
set_property -dict {PACKAGE_PIN BJ15 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_dqs_c_b[0]}]
set_property -dict {PACKAGE_PIN BM13 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_dqs_c_b[1]}]
set_property -dict {PACKAGE_PIN BJ5 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_dqs_t_a[0]}]
set_property -dict {PACKAGE_PIN BN7 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_dqs_t_a[1]}]
set_property -dict {PACKAGE_PIN BH15 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_dqs_t_b[0]}]
set_property -dict {PACKAGE_PIN BL13 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch0_lpddr4_trip1_dqs_t_b[1]}]
set_property -dict {PACKAGE_PIN BM7 IOSTANDARD LVSTL_11} [get_ports {ch0_lpddr4_trip1_reset_n}]

set_property -dict {PACKAGE_PIN BB17 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_a[0]}]
set_property -dict {PACKAGE_PIN BA18 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_a[1]}]
set_property -dict {PACKAGE_PIN BD18 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_a[2]}]
set_property -dict {PACKAGE_PIN BC17 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_a[3]}]
set_property -dict {PACKAGE_PIN BC20 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_a[4]}]
set_property -dict {PACKAGE_PIN BD21 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_a[5]}]
set_property -dict {PACKAGE_PIN AU23 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_b[0]}]
set_property -dict {PACKAGE_PIN AV22 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_b[1]}]
set_property -dict {PACKAGE_PIN AV19 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_b[2]}]
set_property -dict {PACKAGE_PIN AU21 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_b[3]}]
set_property -dict {PACKAGE_PIN AT22 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_b[4]}]
set_property -dict {PACKAGE_PIN AU18 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_ca_b[5]}]
set_property -dict {PACKAGE_PIN BD19 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_ck_c_a}]
set_property -dict {PACKAGE_PIN AV21 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_ck_c_b}]
set_property -dict {PACKAGE_PIN BC18 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_ck_t_a}]
set_property -dict {PACKAGE_PIN AU20 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_ck_t_b}]
set_property -dict {PACKAGE_PIN BC21 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_cke_a}]
set_property -dict {PACKAGE_PIN AV16 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_cke_b}]
set_property -dict {PACKAGE_PIN BA15 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_cs_a}]
set_property -dict {PACKAGE_PIN BB19 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_cs_b}]
set_property -dict {PACKAGE_PIN BA19 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dmi_a[0]}]
set_property -dict {PACKAGE_PIN BF7 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dmi_a[1]}]
set_property -dict {PACKAGE_PIN AN16 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dmi_b[0]}]
set_property -dict {PACKAGE_PIN BE14 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dmi_b[1]}]
set_property -dict {PACKAGE_PIN AW20 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[0]}]
set_property -dict {PACKAGE_PIN AY20 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[1]}]
set_property -dict {PACKAGE_PIN BA22 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[2]}]
set_property -dict {PACKAGE_PIN BB22 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[3]}]
set_property -dict {PACKAGE_PIN BA21 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[4]}]
set_property -dict {PACKAGE_PIN BB20 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[5]}]
set_property -dict {PACKAGE_PIN AW22 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[6]}]
set_property -dict {PACKAGE_PIN AY21 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[7]}]
set_property -dict {PACKAGE_PIN BG9 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[8]}]
set_property -dict {PACKAGE_PIN BF3 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[9]}]
set_property -dict {PACKAGE_PIN BF2 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[10]}]
set_property -dict {PACKAGE_PIN BF8 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[11]}]
set_property -dict {PACKAGE_PIN BG7 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[12]}]
set_property -dict {PACKAGE_PIN BF6 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[13]}]
set_property -dict {PACKAGE_PIN BF4 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[14]}]
set_property -dict {PACKAGE_PIN BG5 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_a[15]}]
set_property -dict {PACKAGE_PIN AR19 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[0]}]
set_property -dict {PACKAGE_PIN AN17 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[1]}]
set_property -dict {PACKAGE_PIN AR15 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[2]}]
set_property -dict {PACKAGE_PIN AT19 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[3]}]
set_property -dict {PACKAGE_PIN AR18 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[4]}]
set_property -dict {PACKAGE_PIN AT16 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[5]}]
set_property -dict {PACKAGE_PIN AP17 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[6]}]
set_property -dict {PACKAGE_PIN AT20 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[7]}]
set_property -dict {PACKAGE_PIN BG14 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[8]}]
set_property -dict {PACKAGE_PIN BG15 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[9]}]
set_property -dict {PACKAGE_PIN BF17 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[10]}]
set_property -dict {PACKAGE_PIN BF14 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[11]}]
set_property -dict {PACKAGE_PIN BE13 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[12]}]
set_property -dict {PACKAGE_PIN BG16 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[13]}]
set_property -dict {PACKAGE_PIN BE16 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[14]}]
set_property -dict {PACKAGE_PIN BE15 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_dq_b[15]}]
set_property -dict {PACKAGE_PIN AY18 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_dqs_c_a[0]}]
set_property -dict {PACKAGE_PIN BF1 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_dqs_c_a[1]}]
set_property -dict {PACKAGE_PIN AT17 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_dqs_c_b[0]}]
set_property -dict {PACKAGE_PIN BG12 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_dqs_c_b[1]}]
set_property -dict {PACKAGE_PIN AW19 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_dqs_t_a[0]}]
set_property -dict {PACKAGE_PIN BE1 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_dqs_t_a[1]}]
set_property -dict {PACKAGE_PIN AR16 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_dqs_t_b[0]}]
set_property -dict {PACKAGE_PIN BG13 IOSTANDARD DIFF_LVSTL_11} [get_ports {ch1_lpddr4_trip1_dqs_t_b[1]}]
set_property -dict {PACKAGE_PIN BL6 IOSTANDARD LVSTL_11} [get_ports {ch1_lpddr4_trip1_reset_n}]

# -----------------------------------------------------------------------------
# Status, low-speed I/O, and shared wrapper ports
# -----------------------------------------------------------------------------
# set_property -dict {PACKAGE_PIN BV49 IOSTANDARD LVCMOS15} [get_ports {rst_i}]        ; # FMCP1_LA00_CC_P
set_property -dict {PACKAGE_PIN BT48 IOSTANDARD LVCMOS15} [get_ports {rst_i}]
set_property -dict {PACKAGE_PIN BA49 IOSTANDARD LVCMOS15} [get_ports {rst_led_o}] ; # GPIO_LED_0_LS
set_property -dict {PACKAGE_PIN AY50 IOSTANDARD LVCMOS15} [get_ports {clk_led_o}] ; # GPIO_LED_1_LS
set_property -dict {PACKAGE_PIN BW52 IOSTANDARD LVCMOS15} [get_ports {exit_valid_o}] ; # FMCP1_LA01_CC_N
set_property -dict {PACKAGE_PIN CB46 IOSTANDARD LVCMOS15} [get_ports {exit_value_o}] ; # FMCP1_LA02_P

set_property -dict {PACKAGE_PIN CC47 IOSTANDARD LVCMOS15} [get_ports {i2c_scl_io}]     ; # FMCP1_LA02_N
set_property -dict {PACKAGE_PIN CD47 IOSTANDARD LVCMOS15} [get_ports {i2c_sda_io}]     ; # FMCP1_LA03_P
set_property -dict {PACKAGE_PIN CD48 IOSTANDARD LVCMOS15} [get_ports {pdm2pcm_clk_io}] ; # FMCP1_LA03_N
set_property -dict {PACKAGE_PIN CA49 IOSTANDARD LVCMOS15} [get_ports {pdm2pcm_pdm_io}] ; # FMCP1_LA04_P
set_property -dict {PACKAGE_PIN CB50 IOSTANDARD LVCMOS15} [get_ports {i2s_sck_io}]     ; # FMCP1_LA04_N
set_property -dict {PACKAGE_PIN CC43 IOSTANDARD LVCMOS15} [get_ports {i2s_ws_io}]      ; # FMCP1_LA05_P
set_property -dict {PACKAGE_PIN CB44 IOSTANDARD LVCMOS15} [get_ports {i2s_sd_io}]      ; # FMCP1_LA05_N

# -----------------------------------------------------------------------------
# GPIO bank
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN CA44 IOSTANDARD LVCMOS15} [get_ports {gpio_io[0]}]   ; # FMCP1_LA06_P
set_property -dict {PACKAGE_PIN CB45 IOSTANDARD LVCMOS15} [get_ports {gpio_io[1]}]   ; # FMCP1_LA06_N
set_property -dict {PACKAGE_PIN CB49 IOSTANDARD LVCMOS15} [get_ports {gpio_io[2]}]   ; # FMCP1_LA07_P
set_property -dict {PACKAGE_PIN CC50 IOSTANDARD LVCMOS15} [get_ports {gpio_io[3]}]   ; # FMCP1_LA07_N
set_property -dict {PACKAGE_PIN BY49 IOSTANDARD LVCMOS15} [get_ports {gpio_io[4]}]   ; # FMCP1_LA08_P
set_property -dict {PACKAGE_PIN BY50 IOSTANDARD LVCMOS15} [get_ports {gpio_io[5]}]   ; # FMCP1_LA08_N
set_property -dict {PACKAGE_PIN CC45 IOSTANDARD LVCMOS15} [get_ports {gpio_io[6]}]   ; # FMCP1_LA09_P
set_property -dict {PACKAGE_PIN CD46 IOSTANDARD LVCMOS15} [get_ports {gpio_io[7]}]   ; # FMCP1_LA09_N
set_property -dict {PACKAGE_PIN CC44 IOSTANDARD LVCMOS15} [get_ports {gpio_io[8]}]   ; # FMCP1_LA10_P
set_property -dict {PACKAGE_PIN CD45 IOSTANDARD LVCMOS15} [get_ports {gpio_io[9]}]   ; # FMCP1_LA10_N
set_property -dict {PACKAGE_PIN CB51 IOSTANDARD LVCMOS15} [get_ports {gpio_io[10]}]  ; # FMCP1_LA11_P
set_property -dict {PACKAGE_PIN CC52 IOSTANDARD LVCMOS15} [get_ports {gpio_io[11]}]  ; # FMCP1_LA11_N
set_property -dict {PACKAGE_PIN BW49 IOSTANDARD LVCMOS15} [get_ports {gpio_io[12]}]  ; # FMCP1_LA12_P
set_property -dict {PACKAGE_PIN BW50 IOSTANDARD LVCMOS15} [get_ports {gpio_io[13]}]  ; # FMCP1_LA12_N

# -----------------------------------------------------------------------------
# SPI master from x-heep_system
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN CC49 IOSTANDARD LVCMOS15} [get_ports {spi_sd_io[0]}] ; # FMCP1_LA13_P
set_property -dict {PACKAGE_PIN CD50 IOSTANDARD LVCMOS15} [get_ports {spi_sd_io[1]}] ; # FMCP1_LA13_N
set_property -dict {PACKAGE_PIN BY51 IOSTANDARD LVCMOS15} [get_ports {spi_sd_io[2]}] ; # FMCP1_LA14_P
set_property -dict {PACKAGE_PIN CA52 IOSTANDARD LVCMOS15} [get_ports {spi_sd_io[3]}] ; # FMCP1_LA14_N
set_property -dict {PACKAGE_PIN CD51 IOSTANDARD LVCMOS15} [get_ports {spi_csb_o}]     ; # FMCP1_LA15_P
set_property -dict {PACKAGE_PIN CD52 IOSTANDARD LVCMOS15} [get_ports {spi_sck_o}]     ; # FMCP1_LA15_N

# -----------------------------------------------------------------------------
# SPI slave/debug port
# Use clock-capable FMC LA pins for the externally-driven clock domain.
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN BU41 IOSTANDARD LVCMOS15} [get_ports {spi_slave_sck_io}]  ; # FMCP1_LA17_CC_P
set_property -dict {PACKAGE_PIN BU42 IOSTANDARD LVCMOS15} [get_ports {spi_slave_cs_io}]   ; # FMCP1_LA17_CC_N
set_property -dict {PACKAGE_PIN BW39 IOSTANDARD LVCMOS15} [get_ports {spi_slave_mosi_io}] ; # FMCP1_LA18_CC_P
set_property -dict {PACKAGE_PIN BY39 IOSTANDARD LVCMOS15} [get_ports {spi_slave_miso_io}] ; # FMCP1_LA18_CC_N

# -----------------------------------------------------------------------------
# SPI2
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN CA51 IOSTANDARD LVCMOS15} [get_ports {spi2_sd_io[0]}]  ; # FMCP1_LA16_P
set_property -dict {PACKAGE_PIN CB52 IOSTANDARD LVCMOS15} [get_ports {spi2_sd_io[1]}]  ; # FMCP1_LA16_N
set_property -dict {PACKAGE_PIN BN40 IOSTANDARD LVCMOS15} [get_ports {spi2_sd_io[2]}]  ; # FMCP1_LA19_P
set_property -dict {PACKAGE_PIN BP40 IOSTANDARD LVCMOS15} [get_ports {spi2_sd_io[3]}]  ; # FMCP1_LA19_N
set_property -dict {PACKAGE_PIN BR42 IOSTANDARD LVCMOS15} [get_ports {spi2_csb_o[0]}]  ; # FMCP1_LA20_P
set_property -dict {PACKAGE_PIN BT41 IOSTANDARD LVCMOS15} [get_ports {spi2_csb_o[1]}]  ; # FMCP1_LA20_N
set_property -dict {PACKAGE_PIN CD40 IOSTANDARD LVCMOS15} [get_ports {spi2_sck_o}]      ; # FMCP1_LA21_P

# -----------------------------------------------------------------------------
# Shared external flash pins used by x-heep_system and then muxed against PS
# QuadSPI by the ECO hook.
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN CD41 IOSTANDARD LVCMOS15} [get_ports {spi_flash_sd_io[0]}] ; # FMCP1_LA21_N
set_property -dict {PACKAGE_PIN CD42 IOSTANDARD LVCMOS15} [get_ports {spi_flash_sd_io[1]}] ; # FMCP1_LA22_P
set_property -dict {PACKAGE_PIN CD43 IOSTANDARD LVCMOS15} [get_ports {spi_flash_sd_io[2]}] ; # FMCP1_LA22_N
set_property -dict {PACKAGE_PIN CB40 IOSTANDARD LVCMOS15} [get_ports {spi_flash_sd_io[3]}] ; # FMCP1_LA23_P
set_property -dict {PACKAGE_PIN CC40 IOSTANDARD LVCMOS15} [get_ports {spi_flash_csb_o}]     ; # FMCP1_LA23_N
set_property -dict {PACKAGE_PIN BY40 IOSTANDARD LVCMOS15} [get_ports {spi_flash_sck_o}]     ; # FMCP1_LA24_P
