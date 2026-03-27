// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Manuel Eggimann <meggimann@iis.ee.ethz.ch>


/// This module receives input words of which K out of N subelements are valid.
/// The despread shift register compacts the input word such that the first K out
/// of N subelements in the output word are valid (shifts all subwords to the
/// right until there are no more holes of invalid data within the valid data
/// section).
module channel_despread_sfr #(
  parameter type element_t = logic[15:0],
  parameter int unsigned Width = -1,
  localparam int Log2Width = $clog2(Width)
)(
  input logic              clk_i,
  input logic              rst_ni,
  input logic              clear_i,
  input logic [Width-1:0]  valid_i,
  output logic             ready_o,
  input                    element_t [Width-1:0] data_i,
  output logic [Width-1:0] valid_o,
  input logic              ready_i,
  output                   element_t [Width-1:0] data_o
);

  typedef enum                logic[1:0] {IDLE, DESPREADING, WAIT_READY} state_e;

  state_e state_d, state_q;

  element_t [Width-1:0] out_buffer_d, out_buffer_q;
  logic [Width-1:0]           element_valid_buffer_d, element_valid_buffer_q;
  logic                       s_load_en;
  logic                       s_shift_en;

  logic [Width-1:0]           s_shift_mask;
  // This register stores the target valid bit pattern, i.e. a bitmask where the
  // first k out Width bits are asserted with k = popcount(valid_i during last
  // handshake).

  logic [Log2Width:0]         s_valid_pocount;
  logic [Width-1:0]           despreaded_mask_d, despreaded_mask_q;

  // logic for despread mask
  always_comb begin
    s_valid_pocount = '0;
    despreaded_mask_d = despreaded_mask_q;
    foreach(valid_i[i]) begin
      s_valid_pocount += valid_i[i];
    end
    if (s_load_en) begin
      // This generates the required bit pattern (popcount(valid_i) LSBs set)
      despreaded_mask_d = (1<<s_valid_pocount)-1;
    end
  end


  // FSM that controls how long to shift
  always_comb begin
    state_d    = state_q;
    ready_o    = 1'b0;
    valid_o    = '0;
    s_load_en  = 1'b0;
    s_shift_en = 1'b0;

    if (clear_i) begin
      state_d = IDLE;
    end else begin
      case (state_q)
        IDLE: begin
          ready_o = 1'b1;
          if (|valid_i) begin
            s_load_en = 1'b1;
            state_d = DESPREADING;
          end
        end

        DESPREADING: begin
          ready_o = 1'b0;
          if (element_valid_buffer_q == despreaded_mask_q) begin
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
            // Shift until all element are properly despread and there are no more
            // holes between valid elements
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
              state_d = DESPREADING;
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
    // Enable shift for index i if despread mask contains 1 (i.e. it should
    // contain valid data) but the buffer currently contains invalid data or if
    // the right-hand side is already shifting
    for (int i = 0; i < Width; i++) begin
      if (i == 0) begin
        s_shift_mask[i] = despreaded_mask_q[0] &&  !element_valid_buffer_q[0];
      end else begin
        s_shift_mask[i] = s_shift_mask[i-1] || despreaded_mask_q[i] && !element_valid_buffer_q[i];
      end
    end
  end


  // Spread Register Logic
  always_comb begin
    out_buffer_d           = out_buffer_q;
    element_valid_buffer_d = element_valid_buffer_q;

    if (clear_i) begin
      out_buffer_d           = '0;
      element_valid_buffer_d = '0;
    end else begin
      if (s_load_en) begin
        out_buffer_d = data_i;
        element_valid_buffer_d = valid_i;
      end else if (s_shift_en) begin
        for (int i = 0; i < Width; i++) begin
          if (i == Width-1) begin
            // Load invalid data (all zero) into last element if channel Width-1 is shifting.
            if (s_shift_mask[i]) begin
              out_buffer_d[i] = '0;
              element_valid_buffer_d[i] = 1'b0;
            end
          end else begin
            if (s_shift_mask[i]) begin
              out_buffer_d[i]           = out_buffer_q[i+1];
              element_valid_buffer_d[i] = element_valid_buffer_q[i+1];
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
      despreaded_mask_q      <= '0;
    end else begin
      state_q                <= state_d;
      out_buffer_q           <= out_buffer_d;
      element_valid_buffer_q <= element_valid_buffer_d;
      despreaded_mask_q      <= despreaded_mask_d;
    end
  end

  assign data_o = out_buffer_q;

endmodule
