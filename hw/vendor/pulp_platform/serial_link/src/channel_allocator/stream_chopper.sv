// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Manuel Eggimann <meggimann@iis.ee.ethz.ch>

/// The stream chopper module chops a stream of <Width> elements  into a new
/// stream with at-runtime configurable <OutWidth> < Width. The output stream will
/// only have the first <Outwidth> elements valid. This module is required as a
/// building block for the channel allocator ip within the Serial Link. This
/// first implementation uses simple but area hungry barrel shifter to perform
/// the chopping in at most 2 cycles. The module has an auto-flush feature: If
/// enabled, the stream_chopper will wait at most cfg_auto_flush_count clock
/// cycles before starting a flush operation with a partial (less than
/// cfg_chopsize_i) valid elements. This feature prefents lookup if there are
/// only sporadic transmissions in the input stream where we could end up waiting
/// forever for input stream to send another word to fill the next output word
/// (i.e. <nr input words>*<Width>%cfg_chopsize_i != 0).
module stream_chopper #(
  parameter type element_t = logic[15:0],
  parameter int signed Width = -1,
  parameter int unsigned FlushCounterWidth = 6,
  localparam int Log2Width = $clog2(Width)
)(
  input logic                         clk_i,
  input logic                         rst_ni,
  input logic                         clear_i,
  input logic                         bypass_en_i,
  input logic                         flush_i,
  input logic                         cfg_auto_flush_en_i,
  input logic [FlushCounterWidth-1:0] cfg_auto_flush_count_i,
  input logic [Log2Width-1:0]         cfg_chopsize_i,
  input                               element_t[Width-1:0] data_i,
  input logic                         valid_i,
  output logic                        ready_o,
  output                              element_t[Width-1:0] data_o,
  output logic [Width-1:0]            valid_o,
  input logic                         ready_i
);

  logic [Log2Width-1:0] out_buffer_fill_count_d, out_buffer_fill_count_q;
  logic [Log2Width-1:0] input_consumed_count_d, input_consumed_count_q;
  element_t [Width-1:0] s_shifted_input;

  logic [Width-1:0]     s_out_buffer_en;
  logic                 s_out_buffer_clear;
  element_t [Width-1:0] out_buffer_d, out_buffer_q;
  logic                 s_fetch_next_word;

  logic [Width-1:0]     output_valid_d, output_valid_q;
  logic [Log2Width-1:0] s_input_consumed_increase;
  logic signed [Log2Width:0] s_shift_amount;

  logic [FlushCounterWidth-1:0] auto_flush_counter_d, auto_flush_counter_q;

  logic                 s_stall;

  assign s_shift_amount = out_buffer_fill_count_q - input_consumed_count_q;

  assign s_out_buffer_clear = output_valid_q;


  // Input Barrel Shifter
  always_comb begin
    s_shifted_input = data_i;
    foreach(data_i[i]) begin
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
    output_valid_d            = '0;
    auto_flush_counter_d      = '0;

    if (clear_i) begin
      out_buffer_fill_count_d = '0;
      input_consumed_count_d  = '0;
      output_valid_d          = '0;
      auto_flush_counter_d    = '0;
    end else begin
      if (!bypass_en_i) begin
        // First check if the input is valid
        if (valid_i) begin
          // Now we consume min(cfg_chopsize_i -
          // out_buffer_fill_count_q, Width - input_consumed_count_q) from the input. I.e. we
          // consume either as many elements as we need to assemble the next
          // output word or as many as are left in the current input word and
          // store it in the output buffer. The barrel shifter rotates the input
          // to the right location. We just need to assert the right enable
          // signals of the output buffer.
          s_input_consumed_increase =
            ((cfg_chopsize_i-out_buffer_fill_count_q) < (Width-input_consumed_count_q))?
            cfg_chopsize_i-out_buffer_fill_count_q : (Width-input_consumed_count_q);
          for (int i = 0; i < Width; i++) begin
            if (i >= out_buffer_fill_count_q &&
                i < out_buffer_fill_count_q+s_input_consumed_increase) begin
              s_out_buffer_en[i] = 1'b1;
            end
          end
          // Also we have to update the counters:

          // If the out_buffer fill counter overflows, we have a complete word to
          // send downstream.
          if (out_buffer_fill_count_q + s_input_consumed_increase == cfg_chopsize_i) begin
            out_buffer_fill_count_d = '0;
            for (int i = 0; i < Width; i++) begin
              if (i < cfg_chopsize_i) begin
                output_valid_d[i] = 1'b1;
              end
            end
          end else begin
            out_buffer_fill_count_d = out_buffer_fill_count_q + s_input_consumed_increase;
          end

          // If the input was fully consumed, fetch the next input word
          if (input_consumed_count_q + s_input_consumed_increase == Width) begin
            input_consumed_count_d = '0;
            s_fetch_next_word      = 1'b1;
          end else begin
            input_consumed_count_d = input_consumed_count_q + s_input_consumed_increase;
          end

          // check if the auto-flush feature is enabled and we have a partially
          // filled output buffer
        end else if(out_buffer_fill_count_q > 0 && (cfg_auto_flush_en_i | flush_i )) begin
          // If it is, check if the counter is expired
          if (flush_i | auto_flush_counter_q == cfg_auto_flush_count_i) begin
            // Flush the module by sending a partial output word and resetting the counters
            auto_flush_counter_d = '0;
            for (int i = 0; i < Width; i++) begin
              if (i < out_buffer_fill_count_q) begin
                output_valid_d[i] = 1'b1;
              end
            end
            input_consumed_count_d = '0;
            out_buffer_fill_count_d = '0;
          end else begin
            // If it is not, just count upwards
            auto_flush_counter_d = auto_flush_counter_q+1;
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
      output_valid_q          <= '0;
      auto_flush_counter_q    <= '0;
    end else begin
      if (!s_stall) begin
        out_buffer_q            <= out_buffer_d;
        input_consumed_count_q  <= input_consumed_count_d;
        out_buffer_fill_count_q <= out_buffer_fill_count_d;
        output_valid_q          <= output_valid_d;
        auto_flush_counter_q    <= auto_flush_counter_d;
      end
    end
  end

  //-------------------- Output Assignments --------------------
  // always_comb begin
  //   if (bypass_en_i) begin
  //     data_o = data_i;
  //   end else begin
  //     // Mirror the output
  //     for (int i = 0; i < Width; i++) begin
  //       data_o[i] = out_buffer_q[Width-i-1];
  //     end
  //   end
  // end

  assign data_o = bypass_en_i? data_i : out_buffer_q;
  always_comb begin
    if (bypass_en_i) begin
      if (valid_i) begin
        valid_o = '1;
      end else begin
        valid_o = '0;
      end
    end else begin
      valid_o = output_valid_q;
    end
  end
  assign ready_o = bypass_en_i? ready_i: s_fetch_next_word && !s_stall;

endmodule
