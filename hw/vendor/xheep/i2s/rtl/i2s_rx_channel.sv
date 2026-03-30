// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Author: Tim Frey <tim.frey@epfl.ch>, EPFL, STI-SEL
// Date: 13.02.2023
// Description: I2s rx_channel processing the SDIN signal 

// Adapted from github.com/pulp-platform/udma_i2s/blob/master/rtl/i2s_rx_channel.sv 
// by Antonio Pullini (pullinia@iis.ee.ethz.ch)

module i2s_rx_channel #(
    parameter  int unsigned MaxWordWidth = 32,
    localparam int unsigned CounterWidth = $clog2(MaxWordWidth)
) (
    input logic sck_i,
    input logic rst_ni,
    input logic en_left_i,
    input logic en_right_i,
    input logic ws_i,
    input logic sd_i,

    // config
    input logic [CounterWidth-1:0] word_width_i, // must not be changed while either channel is enabled
    // first data from channel? (0 = left, 1 = right) .wav uses left first
    input logic start_channel_i,

    // read data out (stream interface)
    output logic [MaxWordWidth-1:0] data_o,
    output logic                    data_valid_o,
    input  logic                    data_ready_i,

    output logic overflow_o,
    input  logic clear_overflow_i
);

  logic en;

  logic r_ws_old;
  logic s_ws_edge;

  logic [MaxWordWidth-1:0] r_shiftreg;
  logic [MaxWordWidth-1:0] s_shiftreg;
  logic [MaxWordWidth-1:0] r_shadow;

  logic [CounterWidth-1:0] r_count_bit;

  logic word_done;
  logic width_overflow;

  logic r_started;

  logic r_valid;

  logic last_data_ws;
  logic data_ws;

  assign en = en_left_i | en_right_i;

  assign s_ws_edge = ws_i ^ r_ws_old;
  assign data_o = r_shadow;

  // read next bit from SD
  always_comb begin
    s_shiftreg = r_shiftreg;
    if (word_done) begin
      s_shiftreg = 'h0;
    end
    if (~width_overflow) begin
      s_shiftreg[word_width_i-r_count_bit] = sd_i;
    end
  end

  // store and forward data to stream
  always_ff @(posedge sck_i, negedge rst_ni) begin
    if (~rst_ni) begin
      r_shiftreg <= 'h0;
      r_shadow <= 'h0;
      r_valid <= 1'b0;
      data_ws <= 1'b0;
    end else begin
      if (r_started) begin
        r_shiftreg <= s_shiftreg;
        if (word_done) begin
          r_shadow <= r_shiftreg;
          r_valid  <= 1'b1;
          data_ws  <= ~r_ws_old;
        end else if (data_ready_i) begin
          r_valid <= 1'b0;
        end
      end else begin
        r_shiftreg <= 'h0;
        r_shadow <= 'h0;
        r_valid <= 1'b0;
        data_ws <= 1'b0;
      end
    end
  end


  // word done after a WS edge
  always_ff @(posedge sck_i, negedge rst_ni) begin
    if (~rst_ni) begin
      word_done <= 1'b0;
    end else begin
      word_done <= r_started & s_ws_edge;
    end
  end

  // count bits up to set word width (triggers overflow)
  always_ff @(posedge sck_i, negedge rst_ni) begin
    if (~rst_ni) begin
      r_count_bit <= 'h0;
      width_overflow <= 1'b0;
    end else begin
      if (r_started) begin
        if (s_ws_edge) begin
          r_count_bit <= 'h0;
          width_overflow <= 1'b0;
        end else if (r_count_bit < word_width_i) begin
          r_count_bit <= r_count_bit + 1;
        end else begin
          width_overflow <= 1'b1;
        end
      end else begin
        r_count_bit <= 'h0;
        width_overflow <= 1'b0;
      end
    end
  end


  // latch ws
  // start only after an edge
  always_ff @(posedge sck_i, negedge rst_ni) begin
    if (~rst_ni) begin
      r_ws_old  <= 'h0;
      r_started <= 'h0;
    end else begin
      if (en) begin
        r_ws_old <= ws_i;
        if (s_ws_edge & (ws_i == start_channel_i)) begin
          r_started <= 1'b1;
        end
      end else begin
        r_started <= 1'b0;
        r_ws_old  <= 1'b0;
      end
    end
  end

  // make sure to alternate between channels
  // worst case drop even number of samples
  always_ff @(posedge sck_i, negedge rst_ni) begin
    if (~rst_ni) begin
      last_data_ws <= 1'b0;
    end else begin
      if (~en) begin
        last_data_ws <= ~start_channel_i;
      end else if (data_ready_i & data_valid_o) begin
        last_data_ws <= data_ws;
      end
    end
  end

  // only data_valid_o = r_valid if the channel is enabled
  always_comb begin
    data_valid_o = 1'b0;

    if (en_left_i & en_right_i) begin
      data_valid_o = r_valid & (data_ws ^ last_data_ws);  // make sure to drop even numbers
    end else if (en_right_i) begin
      data_valid_o = r_valid & (data_ws == 1'b1);  // only right
    end else if (en_left_i) begin
      data_valid_o = r_valid & (data_ws == 1'b0);  // only left
    end
  end


  // detect overflow
  // disable the module to reset
  always_ff @(posedge sck_i, negedge rst_ni) begin
    if (~rst_ni) begin
      overflow_o <= 1'b0;
    end else begin
      if (clear_overflow_i) begin
        overflow_o <= 1'b0;
      end else if (word_done & data_valid_o & ~data_ready_i) begin
        overflow_o <= 1'b1;
      end
    end
  end


endmodule : i2s_rx_channel
