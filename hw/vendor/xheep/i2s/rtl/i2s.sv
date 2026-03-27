// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Author: Tim Frey <tim.frey@epfl.ch>, EPFL, STI-SEL
// Date: 07.02.2023
// Description: I2s peripheral top level module
//              Interfacing the bus <-> registers <-> peripheral core logic

module i2s #(
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // Register interface
    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    // I2s interface
    output logic i2s_sck_o,
    output logic i2s_sck_oe_o,
    input  logic i2s_sck_i,
    output logic i2s_ws_o,
    output logic i2s_ws_oe_o,
    input  logic i2s_ws_i,
    output logic i2s_sd_o,
    output logic i2s_sd_oe_o,
    input  logic i2s_sd_i,

    // Interrupt
    output logic intr_i2s_event_o,

    // DMA signal
    output logic i2s_rx_valid_o
);

  import i2s_reg_pkg::*;


  // Interface signals
  // /* verilator lint_off UNUSED */
  i2s_reg2hw_t reg2hw;
  // /* verilator lint_on UNUSED */
  i2s_hw2reg_t hw2reg;

  logic [MaxWordWidth-1:0] data_rx;
  logic data_rx_valid;
  logic data_rx_ready;
  logic data_rx_overflow;

  logic event_i2s_event;

  logic [$clog2(MaxWordWidth)-1:0] word_width;
  assign word_width = {reg2hw.control.data_width.q, 3'h7};


  // I2s RX -> Bus
  assign data_rx_ready = reg2hw.rxdata.re;  // bus read signal
  assign hw2reg.rxdata.d = data_rx;

  // DMA signal
  assign i2s_rx_valid_o = data_rx_valid;

  // STATUS signal
  assign hw2reg.status.rx_data_ready.d = data_rx_valid;
  assign hw2reg.status.rx_overflow.d = data_rx_overflow;

  // IO
  assign i2s_sd_oe_o = 1'b0;
  assign i2s_sd_o = 1'b0;
  assign i2s_sck_oe_o = reg2hw.control.en_io.q;
  assign i2s_ws_oe_o = reg2hw.control.en_io.q;
  unread _sck_i (i2s_sck_i);
  unread _ws_i (i2s_ws_i);

  // CONTROL 
  assign hw2reg.control.reset_watermark.de = reg2hw.control.reset_watermark.q;
  assign hw2reg.control.reset_watermark.d = 1'b0;
  assign hw2reg.control.reset_rx_overflow.de = ~data_rx_overflow;
  assign hw2reg.control.reset_rx_overflow.d = 1'b0;



  // Register logic
  i2s_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) i2s_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg_req_i,
      .reg_rsp_o,
      .reg2hw,
      .hw2reg,
      .devmode_i(1'b1)
  );



  // Core logic
  i2s_core #(
      .MaxWordWidth(MaxWordWidth),
      .ClkDividerWidth(ClkDividerWidth)
  ) i2s_core_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .en_i(reg2hw.control.en.q),
      .en_ws_i(reg2hw.control.en_ws.q),
      .en_rx_left_i(reg2hw.control.en_rx.q[0]),
      .en_rx_right_i(reg2hw.control.en_rx.q[1]),

      .sck_o(i2s_sck_o),
      .ws_o (i2s_ws_o),
      .sd_i (i2s_sd_i),

      .cfg_clock_div_i(reg2hw.clkdividx.q),
      .cfg_word_width_i(word_width),
      .cfg_rx_start_channel_i(reg2hw.control.rx_start_channel.q),

      .data_rx_o(data_rx),
      .data_rx_valid_o(data_rx_valid),
      .data_rx_ready_i(data_rx_ready),

      .clear_rx_overflow_i(reg2hw.control.reset_rx_overflow.q),

      .running_o(hw2reg.status.running.d),
      .data_rx_overflow_o(data_rx_overflow)
  );


  // watermark counter
  // count bus reads and trigger interrupt 
  event_counter #(
      .WIDTH(WatermarkWidth)
  ) watermark_counter (
      .clk_i,
      .rst_ni,
      .clear_i(reg2hw.control.reset_watermark.q),  // synchronous clear
      .en_i(data_rx_ready & data_rx_valid & (|reg2hw.watermark.q) && reg2hw.control.en_watermark.q),    // enable the counter
      .limit_i(reg2hw.watermark.q),
      .q_o(hw2reg.waterlevel.d),
      .overflow_o(event_i2s_event)
  );

  assign intr_i2s_event_o = event_i2s_event & reg2hw.control.intr_en.q;


endmodule : i2s
