// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module i2s_tx_sink #(
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,
    parameter int unsigned WordWidth = 32,
    parameter int unsigned FifoLogDepth = 4
) (
    input logic clk_i,
    input logic rst_ni,

    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    input logic i2s_sck_i,
    input logic i2s_ws_i,
    input logic i2s_sd_i
);

  import i2s_tx_sink_reg_pkg::*;

  i2s_tx_sink_reg2hw_t                 reg2hw;
  i2s_tx_sink_hw2reg_t                 hw2reg;
  reg_req_t                            reg_req;
  reg_rsp_t                            reg_rsp;

  logic                                sink_en_sck;
  logic                                sample_valid_sck;
  logic                                sample_ready_sck;
  logic                [WordWidth-1:0] sample_sck;
  logic                                overflow_sck;
  logic                                overflow;
  logic                                rx_valid;
  logic                [WordWidth-1:0] rx_data;
  logic                                rxdata_read_wait;

  assign hw2reg.rxdata.d = rx_data;
  assign hw2reg.status.empty.de = 1'b1;
  assign hw2reg.status.empty.d = ~rx_valid;
  assign hw2reg.status.available.de = 1'b1;
  assign hw2reg.status.available.d = rx_valid;
  assign hw2reg.status.overflow.de = 1'b1;
  assign hw2reg.status.overflow.d = overflow;

  assign rxdata_read_wait =
      reg_req_i.valid && !reg_req_i.write &&
      (reg_req_i.addr[BlockAw-1:0] == I2S_TX_SINK_RXDATA_OFFSET) && !rx_valid;

  always_comb begin
    reg_req = reg_req_i;
    reg_req.valid = reg_req_i.valid && !rxdata_read_wait;

    reg_rsp_o = reg_rsp;
    if (rxdata_read_wait) begin
      reg_rsp_o.ready = 1'b0;
      reg_rsp_o.rdata = '0;
      reg_rsp_o.error = 1'b0;
    end
  end

  i2s_tx_sink_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) i2s_tx_sink_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg_req_i(reg_req),
      .reg_rsp_o(reg_rsp),
      .reg2hw,
      .hw2reg,
      .devmode_i(1'b1)
  );

  sync #(
      .STAGES(2),
      .ResetValue(1'b0)
  ) sink_en_sync_i (
      .clk_i(i2s_sck_i),
      .rst_ni,
      .serial_i(reg2hw.control.q[0]),
      .serial_o(sink_en_sck)
  );

  i2s_tx_sink_deserializer #(
      .WordWidth(WordWidth)
  ) deserializer_i (
      .sck_i(i2s_sck_i),
      .rst_ni(rst_ni),
      .en_i(sink_en_sck),
      .ws_i(i2s_ws_i),
      .sd_i(i2s_sd_i),
      .data_o(sample_sck),
      .data_valid_o(sample_valid_sck)
  );

  // RXDATA reads assert reg2hw.rxdata.re, so each read pops one FIFO entry.
  cdc_fifo_gray #(
      .T(logic [WordWidth-1:0]),
      .LOG_DEPTH(FifoLogDepth)
  ) sample_cdc_i (
      .src_clk_i  (i2s_sck_i),
      .src_rst_ni (rst_ni),
      .src_ready_o(sample_ready_sck),
      .src_data_i (sample_sck),
      .src_valid_i(sample_valid_sck),

      .dst_rst_ni (rst_ni),
      .dst_clk_i  (clk_i),
      .dst_data_o (rx_data),
      .dst_valid_o(rx_valid),
      .dst_ready_i(reg2hw.rxdata.re)
  );

  always_ff @(posedge i2s_sck_i or negedge rst_ni) begin
    if (~rst_ni) begin
      overflow_sck <= 1'b0;
    end else if (sample_valid_sck && !sample_ready_sck) begin
      overflow_sck <= 1'b1;
    end
  end

  sync #(
      .STAGES(2),
      .ResetValue(1'b0)
  ) overflow_sync_i (
      .clk_i,
      .rst_ni,
      .serial_i(overflow_sck),
      .serial_o(overflow)
  );

endmodule : i2s_tx_sink
