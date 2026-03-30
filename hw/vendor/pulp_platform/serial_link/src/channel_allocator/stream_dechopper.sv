// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Manuel Eggimann <meggimann@iis.ee.ethz.ch>

`ifndef SERIAL_LINK_MIN_EXPR
  `define SERIAL_LINK_MIN_EXPR(a,b) (((a)<(b))?(a):(b))
`endif

/// This module receives a stream of width <Width> elements where the first
/// (starting from LSB) k elements, with 0 <= k < Width are valid and
/// reassemebles them into a full width output stream. This module is the counter
/// part of the stream_chopper module.
module stream_dechopper #(
  parameter type element_t = logic [15:0],
  parameter int signed Width = -1,
  parameter int unsigned FlushCounterWidth = 6,
  localparam int unsigned Log2Width = $clog2(Width)
)(
  input logic             clk_i,
  input logic             rst_ni,
  input logic             clear_i,
  input logic             bypass_en_i,
  input logic [Width-1:0] valid_i,
  output logic            ready_o,
  input                   element_t [Width-1:0] data_i,
  output logic            valid_o,
  input logic             ready_i,
  output                  element_t [Width-1:0] data_o
);

  logic [Log2Width-1:0]   s_chopsize;

  logic [Log2Width-1:0]   out_buffer_fill_count_d, out_buffer_fill_count_q;
  logic [Log2Width-1:0]   input_consumed_count_d, input_consumed_count_q;
  element_t [Width-1:0] s_shifted_input;

  logic [Width-1:0]       s_out_buffer_en;
  logic                   s_out_buffer_clear;
  element_t [Width-1:0] out_buffer_d, out_buffer_q;
  logic                   s_fetch_next_word;

  logic                   output_valid_d, output_valid_q;
  logic [Log2Width-1:0]   s_input_consumed_increase;
  logic signed [Log2Width:0] s_shift_amount;

  logic                         s_stall;

  logic                         s_bypass_en;
  logic                         s_all_valid;

  assign s_shift_amount = out_buffer_fill_count_q - input_consumed_count_q;

  assign s_out_buffer_clear = output_valid_q;

  // Count trailing 1s
  lzc #(
    .WIDTH(Width),
    .MODE(0)
  ) i_lzc(
    .in_i(~valid_i),
    .cnt_o(s_chopsize),
    .empty_o(s_all_valid)
  );

  // If the lzc counter recognizes that all elements are valid, automaticaly
  // assert the bypass signals since no dechoping is necessary.
  assign s_bypass_en = s_all_valid || bypass_en_i;

  // Input Barrel Shifter
  always_comb begin
    s_shifted_input = data_i;
    for (int signed i = 0; i < Width; i++) begin
      if (i+s_shift_amount >= Width) begin
        s_shifted_input[i+s_shift_amount-Width] = data_i[i];
      end else if (i+s_shift_amount < 0) begin
        s_shifted_input[i+s_shift_amount+Width] = data_i[i];
      end else begin
        s_shifted_input[i+s_shift_amount] = data_i[i];
      end
    end
  end

  // Output Register Logic
  always_comb begin
    out_buffer_d = out_buffer_q;
    if (clear_i) begin
      out_buffer_d = '0;
    end else begin
      for (int i = 0; i < Width; i++) begin
        if (s_out_buffer_en[i]) begin
          out_buffer_d[i] = s_shifted_input[i];
        end else if (s_out_buffer_clear) begin
          out_buffer_d[i] = '0;
        end
      end
    end
  end

  always_comb begin
    s_out_buffer_en           = '0;
    out_buffer_fill_count_d   = out_buffer_fill_count_q;
    input_consumed_count_d    = input_consumed_count_q;
    s_input_consumed_increase = '0;
    s_fetch_next_word         = 1'b0;
    output_valid_d            = 1'b0;

    if (clear_i) begin
      out_buffer_fill_count_d = '0;
      input_consumed_count_d  = '0;
      output_valid_d          = '0;
    end else begin
      if (!s_bypass_en) begin
        // First check if the input is valid
        if (valid_i) begin
          // Now we consume min(Width -
          // out_buffer_fill_count_q, s_chopsize - input_consumed_count_q) from the input. I.e. we
          // consume either as many elements as we need to assemble the next
          // output word or as many as are left in the current input word and
          // store it in the output buffer. The barrel shifter rotates the input
          // to the right location. We just need to assert the right enable
          // signals of the output buffer.
          s_input_consumed_increase = `SERIAL_LINK_MIN_EXPR(Width-out_buffer_fill_count_q,
                                                            s_chopsize-input_consumed_count_q);
          for (int i = 0; i < Width; i++) begin
            if (i >= out_buffer_fill_count_q
                && i < out_buffer_fill_count_q+s_input_consumed_increase) begin
              s_out_buffer_en[i] = 1'b1;
            end
          end
          // Also we have to update the counters:

          // If the out_buffer fill counter overflows, we have a complete word to
          // send downstream.
          if (out_buffer_fill_count_q + s_input_consumed_increase == Width) begin
            out_buffer_fill_count_d = '0;
            output_valid_d = 1'b1;
          end else begin
            out_buffer_fill_count_d = out_buffer_fill_count_q + s_input_consumed_increase;
          end

          // If the input was fully consumed, fetch the next input word
          if (input_consumed_count_q + s_input_consumed_increase == s_chopsize) begin
            input_consumed_count_d = '0;
            s_fetch_next_word      = 1'b1;
          end else begin
            input_consumed_count_d = input_consumed_count_q + s_input_consumed_increase;
          end
        end
      end
    end
  end

  // If we try to send an output word downstream while downstream is not ready,
  // stall the whole circuit

  assign s_stall = output_valid_q & !ready_i;

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      out_buffer_q            <= '0;
      input_consumed_count_q  <= '0;
      out_buffer_fill_count_q <= '0;
      output_valid_q          <= 1'b0;
    end else begin
      if (!s_stall) begin
        out_buffer_q            <= out_buffer_d;
        input_consumed_count_q  <= input_consumed_count_d;
        out_buffer_fill_count_q <= out_buffer_fill_count_d;
        output_valid_q          <= output_valid_d;
      end
    end
  end

  assign data_o = s_bypass_en? data_i : out_buffer_q;
  always_comb begin
    if (s_bypass_en) begin
      valid_o = valid_i;
    end else begin
      for (int i = 0; i < Width; i++) begin
        valid_o = output_valid_q;
      end
    end
  end
  assign ready_o = s_bypass_en? ready_i: s_fetch_next_word && !s_stall;

endmodule
