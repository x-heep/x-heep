/*
 * Copyright 2024 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <tommaso.terzano@epfl.ch>
 *                         <tommaso.terzano@gmail.com>
 *  
 * Info: Processing unit for DMA channel.
 */

module dma_processing_unit
  import dma_reg_pkg::*;
#(
) (
    input logic clk_i,
    input logic rst_ni,

    input dma_reg2hw_t reg2hw_i,

    input logic dma_processing_unit_on_i,

    input logic dma_start_i,

    input logic read_buffer_empty_i,
    input logic write_buffer_full_i,
    input logic write_buffer_alm_full_i,

    input logic [31:0] read_buffer_output_i,

    output logic write_buffer_push_o,
    output logic read_buffer_pop_o,

    output logic [31:0] write_buffer_input_o
);

  /*_________________________________________________________________________________________________________________________________ */

  /* Parameter definition */

  import dma_reg_pkg::*;
  `include "dma_conf.svh"

  /*_________________________________________________________________________________________________________________________________ */

  /* Signals declaration */

  /* Registers */
  dma_reg2hw_t reg2hw;

  /* General signals */
  logic processing_unit_done;
  logic read_buffer_en;
  logic write_buffer_en;
  logic pad_on;
  logic read_buffer_empty;
  logic write_buffer_full;
  logic write_buffer_alm_full;
  logic dma_start;
  logic [16:0] dma_cnt_d1;
  logic [16:0] dma_cnt_d2;
  logic dma_conf_1d;
  logic dma_conf_2d;

  /* Padding FSM states */
  enum {
    PAD_IDLE,
    TOP_PAD_EXEC,
    LEFT_PAD_EXEC,
    RIGHT_PAD_EXEC,
    BOTTOM_PAD_EXEC,
    TOP_PAD_DONE,
    LEFT_PAD_DONE,
    RIGHT_PAD_DONE,
    BOTTOM_PAD_DONE
  }
      pad_state_q, pad_state_d;

  /* Padding FSM conditions */
  logic idle_to_left_ex;
  logic idle_to_top_ex;
  logic idle_to_right_ex;
  logic idle_to_bottom_ex;
  logic top_ex_to_top_dn;
  logic top_ex_to_left_ex;
  logic top_dn_to_right_ex;
  logic top_dn_to_bottom_ex;
  logic top_dn_to_idle;
  logic left_ex_to_left_dn;
  logic left_dn_to_left_ex;
  logic left_dn_to_right_ex;
  logic left_dn_to_bottom_ex;
  logic left_dn_to_idle;
  logic right_ex_to_right_dn;
  logic right_ex_to_left_ex;
  logic right_dn_to_right_ex;
  logic right_dn_to_idle;
  logic right_ex_to_idle;
  logic right_ex_to_bottom_ex;
  logic bottom_ex_to_idle;

  /*_________________________________________________________________________________________________________________________________ */

  /* FSMs instantiation */

  /* Padding FSM state update */
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_pad_state
    if (~rst_ni) begin
      pad_state_q <= PAD_IDLE;
    end else begin
      /* Advance in the FSM only if the write FIFO is available */
      if (write_buffer_en == 1'b1 && dma_processing_unit_on_i == 1'b1 && processing_unit_done == 1'b0) begin
        pad_state_q <= pad_state_d;
      end
    end
  end

  /* Padding FSM logic */
  always_comb begin : proc_pad_fsm_logic
    pad_state_d = pad_state_q;

    unique case (pad_state_q)
      PAD_IDLE: begin
        /* If the padding is done, stay idle */
        if (processing_unit_done == 1'b1) begin
          pad_state_d = PAD_IDLE;
        end else begin
          if (idle_to_top_ex) begin
            pad_state_d = TOP_PAD_EXEC;
          end else if (idle_to_left_ex) begin
            pad_state_d = LEFT_PAD_EXEC;
          end else if (idle_to_right_ex) begin
            pad_state_d = RIGHT_PAD_EXEC;
          end else if (idle_to_bottom_ex) begin
            pad_state_d = BOTTOM_PAD_EXEC;
          end
        end
      end

      TOP_PAD_EXEC: begin
        if (top_ex_to_left_ex) begin
          pad_state_d = LEFT_PAD_EXEC;
        end else if (top_ex_to_top_dn) begin
          pad_state_d = TOP_PAD_DONE;
        end
      end
      TOP_PAD_DONE: begin
        if (top_dn_to_right_ex) begin
          pad_state_d = RIGHT_PAD_EXEC;
        end else if (top_dn_to_bottom_ex) begin
          pad_state_d = BOTTOM_PAD_EXEC;
        end else if (top_dn_to_idle) begin
          pad_state_d = PAD_IDLE;
        end
      end
      LEFT_PAD_EXEC: begin
        if (left_ex_to_left_dn) begin
          pad_state_d = LEFT_PAD_DONE;
        end
      end
      LEFT_PAD_DONE: begin
        if (left_dn_to_right_ex) begin
          pad_state_d = RIGHT_PAD_EXEC;
        end else if (left_dn_to_bottom_ex) begin
          pad_state_d = BOTTOM_PAD_EXEC;
        end else if (left_dn_to_left_ex) begin
          pad_state_d = LEFT_PAD_EXEC;
        end else if (left_dn_to_idle) begin
          pad_state_d = PAD_IDLE;
        end
      end
      RIGHT_PAD_EXEC: begin
        if (right_ex_to_right_dn) begin
          pad_state_d = RIGHT_PAD_DONE;
        end else if (right_ex_to_left_ex) begin
          pad_state_d = LEFT_PAD_EXEC;
        end else if (right_ex_to_bottom_ex) begin
          pad_state_d = BOTTOM_PAD_EXEC;
        end else if (right_ex_to_idle) begin
          pad_state_d = PAD_IDLE;
        end
      end
      RIGHT_PAD_DONE: begin
        if (right_dn_to_idle) begin
          pad_state_d = PAD_IDLE;
        end else if (right_dn_to_right_ex) begin
          pad_state_d = RIGHT_PAD_EXEC;
        end
      end
      BOTTOM_PAD_EXEC: begin
        if (bottom_ex_to_idle) begin
          pad_state_d = PAD_IDLE;
        end
      end
    endcase
  end

  /* Data transfer */
  always_comb begin : proc_data_transfer
    write_buffer_input_o = '0;
    write_buffer_push_o = 1'b0;
    read_buffer_pop_o = 1'b0;

    if (dma_processing_unit_on_i == 1'b1 && processing_unit_done == 1'b0) begin
      /* 
       * If we need to pad, there is no need to wait for the read fifo to have some values.
       * If we don't have to pad, we need to wait for the read fifo to be not empty.
       * In both cases, we need to wait for the write fifo to have some space.
       */
      if (pad_on == 1'b1 & write_buffer_en == 1'b1) begin
        write_buffer_push_o = 1'b1;
      end else if (read_buffer_en == 1'b1 & write_buffer_en == 1'b1) begin
        write_buffer_input_o = read_buffer_output_i;
        write_buffer_push_o = 1'b1;
        read_buffer_pop_o = 1'b1;
      end
    end
  end

  /* Counters for the padding fsm */
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_cnt
    if (~rst_ni) begin
      dma_cnt_d1 <= '0;
      dma_cnt_d2 <= '0;
    end else begin
      if (dma_start == 1'b1) begin
        dma_cnt_d1 <= ({1'h0, reg2hw.size_d1.q} + {11'h0, reg2hw.pad_left.q} + {11'h0, reg2hw.pad_right.q});
        dma_cnt_d2 <= {1'h0, reg2hw.size_d2.q} + {11'h0, reg2hw.pad_top.q} + {11'h0, reg2hw.pad_bottom.q};
      end else if (processing_unit_done == 1'b1) begin
        dma_cnt_d1 <= '0;
        dma_cnt_d2 <= '0;
      end else if ((dma_processing_unit_on_i == 1'b1 && processing_unit_done == 1'b0) & 
                   ((pad_on == 1'b1 & write_buffer_en == 1'b1 ) ||
                   (read_buffer_en == 1'b1 & write_buffer_en == 1'b1))) begin
        if (dma_conf_1d == 1'b1) begin
          // 1D case
          dma_cnt_d1 <= dma_cnt_d1 - 1;
        end else if (dma_conf_2d == 1'b1) begin
          // 2D case
          if (dma_cnt_d1 == 1) begin
            // In this case, the d1 is finished, so we need to decrement the d2 size and reset the d2 size
            dma_cnt_d2 <= dma_cnt_d2 - 1;
            dma_cnt_d1 <= {1'h0, reg2hw.size_d1.q} + {11'h0, reg2hw.pad_left.q} + {11'h0, reg2hw.pad_right.q};
          end else begin
            // In this case, the d1 isn't finished, so we need to decrement the d1 size
            dma_cnt_d1 <= dma_cnt_d1 - 1;
          end
        end
      end
    end
  end

  /*_________________________________________________________________________________________________________________________________ */

  /* Signal assignments */

  /* Renaming */
  assign read_buffer_empty = read_buffer_empty_i;
  assign write_buffer_full = write_buffer_full_i;
  assign write_buffer_alm_full = write_buffer_alm_full_i;
  assign dma_start = dma_start_i;
  assign reg2hw = reg2hw_i;
  assign dma_conf_1d = reg2hw.dim_config.q == 0;
  assign dma_conf_2d = reg2hw.dim_config.q == 1;

  /* Padding flag */
  assign pad_on = (pad_state_q != PAD_IDLE && pad_state_q != TOP_PAD_DONE && pad_state_q != LEFT_PAD_DONE && pad_state_q != RIGHT_PAD_DONE && pad_state_q != BOTTOM_PAD_DONE);

  /* Read FIFO pop signal */
  assign read_buffer_en = (read_buffer_empty == 1'b0);

  /* Write FIFO push signal */
  assign write_buffer_en = (write_buffer_full == 1'b0 && write_buffer_alm_full == 1'b0);

  /* Padding done signal */
  assign processing_unit_done = ((dma_conf_2d == 1'b1 && |dma_cnt_d2 == 1'b0 && dma_processing_unit_on_i == 1'b1)
                                | (dma_conf_1d == 1'b1 && |dma_cnt_d1 == 1'b0 && dma_processing_unit_on_i == 1'b1));

  /* Padding FSM conditions assignments */
  assign idle_to_top_ex = {
    |reg2hw.pad_top.q == 1'b1 && dma_processing_unit_on_i == 1'b1 
    && !(dma_cnt_d1 == 1 && dma_cnt_d2 == 1 && !({1'h0, reg2hw.size_d1.q} == 1 && {1'h0, reg2hw.size_d2.q} == 1))
  };
  assign idle_to_left_ex = {
    |reg2hw.pad_top.q == 1'b0 && |reg2hw.pad_left.q == 1'b1 && dma_processing_unit_on_i == 1'b1 
    && !(dma_cnt_d1 == 1 && dma_cnt_d2 == 1 && !({1'h0, reg2hw.size_d1.q} == 1 && {1'h0, reg2hw.size_d2.q} == 1))
  };
  assign idle_to_right_ex = {
    write_buffer_push_o == 1'b1 && |reg2hw.pad_top.q == 1'b0 && |reg2hw.pad_left.q == 1'b0 && |reg2hw.pad_right.q == 1'b1 
                      && dma_cnt_d1 == ({11'h0, reg2hw.pad_right.q} + 1)
    && !(dma_cnt_d1 == 1 && dma_cnt_d2 == 1 && !({1'h0, reg2hw.size_d1.q} == 1 && {1'h0, reg2hw.size_d2.q} == 1))
    && !(dma_cnt_d1 == 1 && dma_cnt_d2 == 1 && !({1'h0, reg2hw.size_d1.q} == 1 && {1'h0, reg2hw.size_d2.q} == 1))
  };
  assign idle_to_bottom_ex = {
    write_buffer_push_o == 1'b1 && |reg2hw.pad_top.q == 1'b0 && |reg2hw.pad_left.q == 1'b0 && |reg2hw.pad_right.q == 1'b0 && |reg2hw.pad_bottom.q == 1'b1 
                      && dma_cnt_d2 == ({11'h0, reg2hw.pad_bottom.q} + 1) && dma_cnt_d1 == 1
    && !(dma_cnt_d1 == 1 && dma_cnt_d2 == 1 && !({1'h0, reg2hw.size_d1.q} == 1 && {1'h0, reg2hw.size_d2.q} == 1))
    && !(dma_cnt_d1 == 1 && dma_cnt_d2 == 1 && !({1'h0, reg2hw.size_d1.q} == 1 && {1'h0, reg2hw.size_d2.q} == 1))
  };
  assign top_ex_to_top_dn = {
    write_buffer_push_o == 1'b1 && dma_cnt_d2 == ( {1'h0, reg2hw.size_d2.q} + {11'h0, reg2hw.pad_bottom.q} + 1) && dma_cnt_d1 == 1 && |reg2hw.pad_left.q == 1'b0
  };
  assign top_ex_to_left_ex = {
    write_buffer_push_o == 1'b1 && dma_cnt_d2 == ({1'h0, reg2hw.size_d2.q} + {11'h0, reg2hw.pad_bottom.q} + 1) && dma_cnt_d1 == 1 && |reg2hw.pad_left.q == 1'b1
  };
  assign top_dn_to_right_ex = {
    write_buffer_push_o == 1'b1 && |reg2hw.pad_left.q == 1'b0 && |reg2hw.pad_right.q == 1'b1 && dma_cnt_d1 == ({11'h0, reg2hw.pad_right.q} + 1)
  };
  assign top_dn_to_bottom_ex = {
    write_buffer_push_o == 1'b1 && |reg2hw.pad_left.q == 1'b0 && |reg2hw.pad_right.q == 1'b0 && |reg2hw.pad_bottom.q == 1'b1 && dma_cnt_d2 == ({11'h0, reg2hw.pad_bottom.q} + 1) && dma_cnt_d1 == 1
  };
  assign top_dn_to_idle = {
    |reg2hw.pad_left.q == 1'b0 && |reg2hw.pad_right.q == 1'b0 && |reg2hw.pad_bottom.q == 1'b0 && dma_cnt_d2 == 1 && dma_cnt_d1 == 1
  };
  assign left_ex_to_left_dn = {
    write_buffer_push_o == 1'b1 && dma_cnt_d1 == ({1'h0, reg2hw.size_d1.q} + {11'h0, reg2hw.pad_right.q} + 1)
  };
  assign left_dn_to_left_ex = {
    write_buffer_push_o == 1'b1 && dma_cnt_d1 == 1 && dma_cnt_d2 != (1'b1 + {11'h0, reg2hw.pad_bottom.q}) && |reg2hw.pad_right.q == 1'b0
  };
  assign left_dn_to_right_ex = {
    write_buffer_push_o == 1'b1 && |reg2hw.pad_right.q == 1'b1 && dma_cnt_d1 == ({11'h0, reg2hw.pad_right.q} + 1)
  };
  assign left_dn_to_bottom_ex = {
    write_buffer_push_o == 1'b1 && |reg2hw.pad_right.q == 1'b0 && |reg2hw.pad_bottom.q == 1'b1 && dma_cnt_d2 == ({11'h0, reg2hw.pad_bottom.q} + 1) && dma_cnt_d1 == 1
  };
  assign left_dn_to_idle = {
    |reg2hw.pad_right.q == 1'b0 && |reg2hw.pad_bottom.q == 1'b0 && dma_cnt_d2 == 1 && dma_cnt_d1 == 1
  };
  assign right_ex_to_right_dn = {
    write_buffer_push_o == 1'b1 && dma_cnt_d1 == 1 && dma_cnt_d2 != ({11'h0, reg2hw.pad_bottom.q} + 1) && |reg2hw.pad_left.q == 1'b0
  };
  assign right_ex_to_left_ex = {
    write_buffer_push_o == 1'b1 && dma_cnt_d1 == 1 && dma_cnt_d2 != ({11'h0, reg2hw.pad_bottom.q} + 1) && |reg2hw.pad_left.q == 1'b1
  };
  assign right_ex_to_bottom_ex = {
    write_buffer_push_o == 1'b1 && |reg2hw.pad_bottom.q == 1'b1 && dma_cnt_d2 == ({11'h0, reg2hw.pad_bottom.q} + 1) && dma_cnt_d1 == 1
  };
  assign right_dn_to_right_ex = {
    write_buffer_push_o == 1'b1 && dma_cnt_d1 == ({11'h0, reg2hw.pad_right.q} + 1) && |reg2hw.pad_left.q == 1'b0
  };
  assign right_dn_to_idle = {|reg2hw.pad_bottom.q == 1'b0 && dma_cnt_d2 == 1 && dma_cnt_d1 == 1};
  assign bottom_ex_to_idle = {dma_cnt_d1 == 1 && dma_cnt_d2 == 1 && dma_cnt_d1 == 1};

  assign right_ex_to_idle = {|reg2hw.pad_bottom.q == 1'b0 && dma_cnt_d2 == 1 && dma_cnt_d1 == 1};




endmodule
