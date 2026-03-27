// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Manuel Eggimann <meggimann@iis.ee.ethz.ch>

/// This module receives a channel enable bit mask and a <Width> element input
/// stream where always the first x out of <Width> elements are valid (indicated
/// by the individual valid signals). The shift register sequentially shifts each
/// element such that only enabled channels are used and sends the result
/// downstream.
module channel_spread_sfr #(
  parameter type element_t = logic[15:0],
  parameter int unsigned Width = -1,
  localparam int Log2Width = $clog2(Width)
)(
  input logic              clk_i,
  input logic              rst_ni,
  input logic              clear_i,
  input logic [Width-1:0]  cfg_channel_en_i,
  input                    element_t [Width-1:0] data_i,
  input logic [Width-1:0]  valid_i,
  output logic             ready_o,
  output                   element_t [Width-1:0] data_o,
  output logic [Width-1:0] valid_o,
  input logic              ready_i
);

  typedef enum logic[1:0] {IDLE, SPREADING, WAIT_READY} state_e;

  state_e state_d, state_q;

  element_t [Width-1:0] out_buffer_d, out_buffer_q;
  logic [Width-1:0]        element_valid_buffer_d, element_valid_buffer_q;
  logic                    s_load_en;
  logic                    s_shift_en;

  logic [Width-1:0]        s_shift_mask;


  always_comb begin
    state_d   = state_q;
    ready_o   = 1'b0;
    valid_o   = '0;
    s_load_en = 1'b0;
    s_shift_en = 1'b0;

    if (clear_i) begin
      state_d = IDLE;
    end else begin
      case (state_q)
        IDLE: begin
          ready_o = 1'b1;
          if (|valid_i) begin
            s_load_en = 1'b1;
            state_d = SPREADING;
          end
        end

        SPREADING: begin
          ready_o = 1'b0;
          // Check if all valid elements reside only on enabled channels
          if ((element_valid_buffer_q & cfg_channel_en_i) == element_valid_buffer_q) begin
            // We are done with spreading, assert output valid and fetch next element
            valid_o = element_valid_buffer_q;
            // And check if output is ready
            if (ready_i) begin
              // If it is, assert ready_o and check if there is already a new item
              // available.
              ready_o = 1'b1;
              if (|valid_i) begin
                // load it into the shift register and stay in spreading state
                s_load_en = 1'b1;
              end else begin
                // Switch to idle state
                state_d = IDLE;
              end
            end else begin
              // Output is not ready, switch to wait state
              state_d = WAIT_READY;
            end
          end else begin
            // Shift until all element are properly spread
            s_shift_en = 1'b1;
          end
        end

        WAIT_READY: begin
          valid_o = element_valid_buffer_q;
          // Wait until output is ready
          if (ready_i) begin
            // If it is, assert ready_o and check if there is already a new item
            // available.
            ready_o = 1'b1;
            if (|valid_i) begin
              // load it into the shift register and switch to spreading state
              s_load_en = 1'b1;
              state_d = SPREADING;
            end else begin
              // Switch to idle state
              state_d = IDLE;
            end
          end
        end

        default: begin
          state_d = IDLE;
        end
      endcase
    end
  end

  // Generate Spread Maks Logic
  always_comb begin
    s_shift_mask = '0;
    // Enable shift for index i if valid data is on disabled channel or if
    // index-1 (right-hand side neighbour) is already shifting.
    for (int i = 0; i < Width; i++) begin
      if (i == 0) begin
        s_shift_mask[i] = element_valid_buffer_q[i] && !cfg_channel_en_i[i];
      end else begin
        s_shift_mask[i] = s_shift_mask[i-1] || element_valid_buffer_q[i] && !cfg_channel_en_i[i];
      end
    end
  end


  // Spread Register Logic
  always_comb begin
    out_buffer_d           = out_buffer_q;
    element_valid_buffer_d = element_valid_buffer_q;

    if (clear_i) begin
      out_buffer_d = '0;
      element_valid_buffer_d = '0;
    end else begin
      if (s_load_en) begin
        out_buffer_d = data_i;
        element_valid_buffer_d = valid_i;
      end else if (s_shift_en) begin
        for (int i = 0; i < Width; i++) begin
          if (i == 0) begin
            // Load invalid data (all zero) into first element if channel 0 is disabled.
            if (s_shift_mask[0]) begin
              out_buffer_d[0] = '0;
              element_valid_buffer_d[0] = 1'b0;
            end
          end else begin
            // If right hand side neighbour is shifting, shift its value into this register
            if (s_shift_mask[i-1]) begin
              out_buffer_d[i]           = out_buffer_q[i-1];
              element_valid_buffer_d[i] = element_valid_buffer_q[i-1];
            end else if(s_shift_mask[i]) begin
              // If right hand side is not shifting but we are, load invalid (all
              // zero) data into the register and mark it as invalid.
              out_buffer_d[i] = '0; // Load with all zeros
              element_valid_buffer_d[i] = 1'b0; // Mark element as invalid
            end
          end
        end
      end
    end
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      state_q                <= IDLE;
      out_buffer_q           <= '0;
      element_valid_buffer_q <= '0;
    end else begin
      state_q                <= state_d;
      out_buffer_q           <= out_buffer_d;
      element_valid_buffer_q <= element_valid_buffer_d;
    end
  end

  assign data_o = out_buffer_q;

endmodule
