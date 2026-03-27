// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Author: Tim Frey <tim.frey@epfl.ch>, EPFL, STI-SEL
// Date: 13.02.2023
// Description: I2s core logic 

module i2s_core #(
    parameter MaxWordWidth = 32,
    parameter ClkDividerWidth = 8
) (
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic en_ws_i,
    input logic en_rx_left_i,
    input logic en_rx_right_i,

    // IO interface
    output logic sck_o,
    output logic ws_o,
    input  logic sd_i,

    // config
    input logic [     ClkDividerWidth-1:0] cfg_clock_div_i,
    input logic [$clog2(MaxWordWidth)-1:0] cfg_word_width_i,
    input logic                            cfg_rx_start_channel_i,

    // FIFO
    output logic [MaxWordWidth-1:0] data_rx_o,
    output logic                    data_rx_valid_o,
    input  logic                    data_rx_ready_i,

    input logic clear_rx_overflow_i,

    output logic running_o,
    output logic data_rx_overflow_o
);

  logic                    ws;
  logic                    sck;

  logic [MaxWordWidth-1:0] data_rx_dc;
  logic                    data_rx_dc_valid;
  logic                    data_rx_dc_ready;

  logic                    data_rx_overflow_async;

  assign ws_o  = ws;
  assign sck_o = sck;

  clk_int_div #(
      .DIV_VALUE_WIDTH(ClkDividerWidth),
      .DEFAULT_DIV_VALUE(2)  // HAS TO BE BIGGER THAN ONE TO GET THE START RIGHT
  ) i2s_clk_gen_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .en_i(en_i),
      .test_mode_en_i(1'b0),
      .clk_o(sck),
      .div_i(cfg_clock_div_i),
      .div_valid_i(1'b1),
      .div_ready_o(),
      .cycl_count_o()
  );

  i2s_ws_gen #(
      .MaxWordWidth(MaxWordWidth)
  ) i2s_ws_gen_i (
      .sck_i(sck),
      .rst_ni(rst_ni),
      .en_i(en_ws_i),
      .ws_o(ws),
      .word_width_i(cfg_word_width_i)
  );

  i2s_rx_channel #(
      .MaxWordWidth(MaxWordWidth)
  ) i2s_rx_channel_i (
      .sck_i(sck),
      .rst_ni(rst_ni),
      .en_left_i(en_rx_left_i),
      .en_right_i(en_rx_right_i),
      .ws_i(ws),
      .sd_i(sd_i),

      .word_width_i(cfg_word_width_i),
      .start_channel_i(cfg_rx_start_channel_i),

      .data_o(data_rx_dc),
      .data_valid_o(data_rx_dc_valid),
      .data_ready_i(data_rx_dc_ready),
      .overflow_o(data_rx_overflow_async),
      .clear_overflow_i(clear_rx_overflow_i)
  );

  // cdc
  cdc_fifo_gray #(
      .T(logic [31:0]),
      .LOG_DEPTH(2)
  ) rx_cdc_i (
      .src_clk_i  (sck),
      .src_rst_ni (rst_ni),
      .src_ready_o(data_rx_dc_ready),
      .src_data_i (data_rx_dc),
      .src_valid_i(data_rx_dc_valid),

      .dst_rst_ni (rst_ni),
      .dst_clk_i  (clk_i),
      .dst_data_o (data_rx_o),
      .dst_valid_o(data_rx_valid_o),
      .dst_ready_i(data_rx_ready_i)
  );

  // SYNC rx overflow signal
  sync #(
      .STAGES(2),
      .ResetValue(1'b0)
  ) data_rx_overflow_sync_i (
      .clk_i,
      .rst_ni,
      .serial_i(data_rx_overflow_async),
      .serial_o(data_rx_overflow_o)
  );


  logic en_q;
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      en_q <= 1'b0;
    end else begin
      en_q <= en_i;
    end
  end

  logic enabled_req;  // send enable event to I2S clock domain
  logic enabled_sck;
  logic enabled_ack;  // acknowledge enable from I2S clock domain

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      enabled_req <= 1'b0;
    end else begin
      if (en_i == 1'b1 && en_q == 1'b0) begin
        // turned on
        enabled_req <= ~enabled_req;
      end
    end
  end


  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      running_o <= 1'b0;
    end else begin
      running_o <= en_q && (enabled_ack == enabled_req);
    end
  end

  // enabled_req
  sync #(
      .STAGES(2),
      .ResetValue(1'b0)
  ) data_en_req_sync_i (
      .clk_i(sck),
      .rst_ni,
      .serial_i(enabled_req),
      .serial_o(enabled_sck)
  );

  // enabled_ack
  sync #(
      .STAGES(2),
      .ResetValue(1'b0)
  ) data_en_ack_sync_i (
      .clk_i,
      .rst_ni,
      .serial_i(enabled_sck),
      .serial_o(enabled_ack)
  );


endmodule : i2s_core
