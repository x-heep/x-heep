/*
 * Copyright 2024 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <tommaso.terzano@epfl.ch>
 *                         <tommaso.terzano@gmail.com>
 *  
 * Info: Write unit for DMA channel, process data coming out of the output FIFO. Performs the sign extension if needed.
 */

module dma_write_unit
  import dma_reg_pkg::*;
#(
) (
    input logic clk_i,
    input logic rst_ni,

    input dma_reg2hw_t reg2hw_i,

    input logic dma_start_i,
    input logic wait_for_tx_i,
    input logic enable_wait_for_tx_i,
    input logic [7:0] slot_wait_counter_i,

    input logic dma_done_override_i,

    input logic write_buffer_empty_i,
    input logic read_addr_buffer_empty_i,

    input logic [31:0] write_buffer_output_i,
    input logic [31:0] read_addr_buffer_output_i,

    input logic data_out_gnt_i,
    input logic data_out_rvalid_i,

    output logic data_out_req_o,
    output logic data_out_we_o,
    output logic [3:0] data_out_be_o,
    output logic [31:0] data_out_addr_o,
    output logic [31:0] data_out_wdata_o,

    output logic dma_done_o
);

  /*_________________________________________________________________________________________________________________________________ */

  /* Parameter definition */

  import dma_reg_pkg::*;
  import dma_pkg::*;
  `include "dma_conf.svh"

  /*_________________________________________________________________________________________________________________________________ */

  /* Signals declaration */

  /* Registers */
  dma_reg2hw_t reg2hw;

  logic dma_conf_1d;
  logic dma_conf_2d;
  logic dma_done;
  logic address_mode;
  logic dma_start;

  enum logic {
    DMA_WRITE_UNIT_IDLE,
    DMA_WRITE_UNIT_ON
  }
      dma_write_unit_state, dma_write_unit_n_state;

  dma_pkg::dma_data_type_t dst_data_type;

  logic data_req_cond, data_req_cond_preobi;
  logic dma_done_override;

  logic data_out_req;
  logic data_out_we;
  logic data_out_gnt;
  logic data_out_rvalid;
  logic [31:0] data_out_addr;
  logic [31:0] data_out_wdata;
  logic [31:0] write_address;
  logic [31:0] write_ptr_reg;
  logic [3:0] byte_enable_out;

  logic [31:0] dma_dst_d1_inc;
  logic [31:0] dma_dst_d2_inc;
  logic [16:0] dma_dst_cnt_d1;
  logic [16:0] dma_dst_cnt_d2;

  logic [16:0] dma_size_d1;
  logic [16:0] dma_size_d2;

  logic wait_for_tx;

  /* FIFO signals */
  logic write_buffer_empty;
  logic read_addr_buffer_empty;
  logic [31:0] write_buffer_data;

  dma_pkg::dma_obi_state_type_t obi_data_req_q, obi_data_req_d;

  dma_pkg::dma_wait_for_state_type_t wait_for_tx_state_q, wait_for_tx_state_d;

  logic [7:0] slot_wait_counter_d, slot_wait_counter_q;

  /*_________________________________________________________________________________________________________________________________ */

  /* FSMs instantiation */

  /* Sign extension of the increments */
  always_comb begin
    dma_dst_d1_inc = {{26{reg2hw.dst_ptr_inc_d1.q[5]}}, reg2hw.dst_ptr_inc_d1.q};
    dma_dst_d2_inc = {{9{reg2hw.dst_ptr_inc_d2.q[22]}}, reg2hw.dst_ptr_inc_d2.q};
  end

  /* Request signal logic */
  always_comb begin : proc_req_signal_logic
    data_out_req = 0;

    if (dma_write_unit_state == DMA_WRITE_UNIT_ON && dma_done == 1'b0) begin
      if (data_req_cond == 1'b1) begin
        data_out_req = 1;
      end
    end
  end

  /* Counters for the writing fsm */
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_dma_dst_cnt_reg
    if (~rst_ni) begin
      dma_dst_cnt_d1 <= '0;
      dma_dst_cnt_d2 <= '0;
      obi_data_req_q <= OBI_DATA_REQ;
      wait_for_tx_state_q <= WAIT_FOR_OUTSTANDING_IDLE;
      slot_wait_counter_q <= '0;
    end else begin
      obi_data_req_q <= obi_data_req_d;
      wait_for_tx_state_q <= wait_for_tx_state_d;
      slot_wait_counter_q <= slot_wait_counter_d;
      if (dma_start == 1'b1) begin
        dma_dst_cnt_d1 <= dma_size_d1;
        dma_dst_cnt_d2 <= dma_size_d2;
      end else if (dma_done == 1'b1 || dma_done_override == 1'b1) begin
        dma_dst_cnt_d1 <= '0;
        dma_dst_cnt_d2 <= '0;
      end else if ((data_out_gnt && data_out_req)) begin
        if (dma_conf_1d == 1'b1) begin
          // 1D case
          dma_dst_cnt_d1 <= dma_dst_cnt_d1 - 1;
        end else if (dma_conf_2d == 1'b1) begin
          // 2D case
          if (dma_dst_cnt_d1 == 1) begin
            // In this case, the d1 is finished, so we need to reset the d2 size
            dma_dst_cnt_d1 <= dma_size_d1;
            dma_dst_cnt_d2 <= dma_dst_cnt_d2 - 1;
          end else begin
            // In this case, the d1 isn't finished, so we need to decrement the d1 size
            dma_dst_cnt_d1 <= dma_dst_cnt_d1 - 1;
          end
        end
      end
    end
  end

  /* Determine the byte enable depending on the datatype */
  always_comb begin : proc_byte_enable_out
    case (dst_data_type)  // Data type 00 Word, 01 Half word, 11,10 byte
      DMA_DATA_TYPE_WORD: byte_enable_out = 4'b1111;  // Writing a word (32 bits)

      DMA_DATA_TYPE_HALF_WORD: begin  // Writing a half-word (16 bits)
        case (write_ptr_reg[1])
          1'b0: byte_enable_out = 4'b0011;
          1'b1: byte_enable_out = 4'b1100;
        endcase
        ;  // case(write_ptr_reg[1:0])
      end

      DMA_DATA_TYPE_BYTE, DMA_DATA_TYPE_BYTE_: begin  // Writing a byte (8 bits)
        case (write_ptr_reg[1:0])
          2'b00: byte_enable_out = 4'b0001;
          2'b01: byte_enable_out = 4'b0010;
          2'b10: byte_enable_out = 4'b0100;
          2'b11: byte_enable_out = 4'b1000;
        endcase
        ;  // case(write_ptr_reg[1:0])
      end
    endcase
    ;  // case (dst_data_type)
  end

  /* Store output data pointer and increment everytime write request is granted */
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ptr_out_reg
    if (~rst_ni) begin
      write_ptr_reg <= '0;
    end else begin
      if (dma_start == 1'b1) begin
        write_ptr_reg <= reg2hw.dst_ptr.q;
      end else if ((data_out_gnt && data_out_req)) begin
        if (dma_conf_1d == 1'b1) begin
          write_ptr_reg <= write_ptr_reg + dma_dst_d1_inc;
        end else if (dma_conf_2d == 1'b1) begin
          if (dma_dst_cnt_d1 == 1) begin
            // In this case, the d1 is finished, so we need to increment the pointer by sizeof(d1)*data_unit*strides
            write_ptr_reg <= write_ptr_reg + dma_dst_d2_inc;
          end else begin
            write_ptr_reg <= write_ptr_reg + dma_dst_d1_inc; // Increment just of one du, since we need to increase the 1d
          end
        end
      end
    end
  end

  /* FSM state update */
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_fsm_state
    if (~rst_ni) begin
      dma_write_unit_state <= DMA_WRITE_UNIT_IDLE;
    end else begin
      dma_write_unit_state <= dma_write_unit_n_state;
    end
  end

  /* Write master FSM */
  always_comb begin : proc_dma_write_unit_logic

    dma_write_unit_n_state = dma_write_unit_state;
    dma_done = 1'b0;

    unique case (dma_write_unit_state)

      DMA_WRITE_UNIT_IDLE: begin
        if (dma_start == 1'b1) begin
          dma_write_unit_n_state = DMA_WRITE_UNIT_ON;
        end
      end
      DMA_WRITE_UNIT_ON: begin
        // If all data has been written, exit
        if (dma_done_override == 1'b0) begin
          if (dma_conf_1d == 1'b1) begin
            // 1D DMA case
            if (|dma_dst_cnt_d1 == 1'b0) begin
              dma_write_unit_n_state = DMA_WRITE_UNIT_IDLE;
              dma_done = 1'b1;
            end
          end else if (dma_conf_2d == 1'b1) begin
            // 2D DMA case: exit only if 2d counter is 0
            if (|dma_dst_cnt_d2 == 1'b0) begin
              dma_write_unit_n_state = DMA_WRITE_UNIT_IDLE;
              dma_done = 1'b1;
            end
          end
        end else begin
          dma_write_unit_n_state = DMA_WRITE_UNIT_IDLE;
          dma_done = 1'b1;
        end
      end

      default: ;
    endcase
  end

  /* This logic performs the output data shitf to depending on the destination address, i.e. depending on BE */
  always_comb begin
    data_out_wdata = '0;

    case (byte_enable_out)
      (4'b0011): begin
        data_out_wdata[15:0] = write_buffer_data[15:0];
      end

      (4'b1100): begin
        data_out_wdata[31:16] = write_buffer_data[15:0];
      end

      (4'b0001): begin
        data_out_wdata[7:0] = write_buffer_data[7:0];
      end

      (4'b0010): begin
        data_out_wdata[15:8] = write_buffer_data[7:0];
      end

      (4'b0100): begin
        data_out_wdata[23:16] = write_buffer_data[7:0];
      end

      (4'b1000): begin
        data_out_wdata[31:24] = write_buffer_data[7:0];
      end

      (4'b1111): begin
        data_out_wdata = write_buffer_data;
      end

      default: ;
    endcase
  end

  always_comb begin
    data_req_cond  = data_req_cond_preobi;
    obi_data_req_d = obi_data_req_q;
    unique case (obi_data_req_q)

      OBI_DATA_REQ: begin
        if (data_out_req && !data_out_gnt) obi_data_req_d = OBI_WAIT_GNT;
      end

      OBI_WAIT_GNT: begin
        data_req_cond  = 1'b1;
        obi_data_req_d = data_out_gnt ? OBI_DATA_REQ : OBI_WAIT_GNT;
      end
    endcase
  end

  always_comb begin
    wait_for_tx_state_d = wait_for_tx_state_q;
    wait_for_tx = wait_for_tx_i;
    slot_wait_counter_d = slot_wait_counter_q;

    unique case (wait_for_tx_state_q)

      WAIT_FOR_OUTSTANDING_IDLE: begin
        if (enable_wait_for_tx_i) begin
          wait_for_tx_state_d = (data_out_req && data_out_gnt) ? WAIT_FOR_OUTSTANDING_WAIT : WAIT_FOR_OUTSTANDING_IDLE;
          slot_wait_counter_d = slot_wait_counter_i;
        end
      end

      WAIT_FOR_OUTSTANDING_WAIT: begin
        wait_for_tx = 1'b1;
        if (data_out_rvalid) begin
          if (slot_wait_counter_q == '0) begin
            wait_for_tx_state_d = WAIT_FOR_OUTSTANDING_IDLE;
          end else begin
            wait_for_tx_state_d = WAIT_FOR_OUTSTANDING_COUNTER;
          end
        end
      end

      WAIT_FOR_OUTSTANDING_COUNTER: begin
        wait_for_tx = 1'b1;
        if (slot_wait_counter_q == '0) begin
          wait_for_tx_state_d = WAIT_FOR_OUTSTANDING_IDLE;
        end else begin
          wait_for_tx_state_d = WAIT_FOR_OUTSTANDING_COUNTER;
          slot_wait_counter_d = slot_wait_counter_q - 1;
        end
      end

      default: ;

    endcase

  end

  /*_________________________________________________________________________________________________________________________________ */

  /* Signal assignments */
  assign data_req_cond_preobi = (write_buffer_empty == 1'b0 && wait_for_tx == 1'b0 && (read_addr_buffer_empty && address_mode) == 1'b0);
  assign data_out_we = 1'b1;
  assign data_out_addr = write_address;
  assign address_mode = reg2hw.mode.q == 2;
  assign dma_conf_1d = reg2hw.dim_config.q == 0;
  assign dma_conf_2d = reg2hw.dim_config.q == 1;

  /* Write address */
  assign write_address = address_mode ? read_addr_buffer_output_i : write_ptr_reg;

  /* DMA transaction sizes */
`ifdef ZERO_PADDING_EN
  assign dma_size_d1 = {1'h0, reg2hw.size_d1.q} +
                      {11'h0, reg2hw.pad_left.q} +
                      {11'h0, reg2hw.pad_right.q};

  assign dma_size_d2 = {1'h0, reg2hw.size_d2.q} +
                      {11'h0, reg2hw.pad_top.q} +
                      {11'h0, reg2hw.pad_bottom.q};
`else
  assign dma_size_d1 = {1'h0, reg2hw.size_d1.q};
  assign dma_size_d2 = {1'h0, reg2hw.size_d2.q};
`endif

  /* Renaming */
  assign dma_done_override = dma_done_override_i;
  assign dma_start = dma_start_i;
  assign reg2hw = reg2hw_i;
  assign data_out_gnt = data_out_gnt_i;
  assign data_out_rvalid = data_out_rvalid_i;
  assign dma_done_o = dma_done;
  assign dst_data_type = dma_data_type_t'(reg2hw.dst_data_type.q);
  assign data_out_wdata_o = data_out_wdata;
  assign write_buffer_empty = write_buffer_empty_i;
  assign write_buffer_data = write_buffer_output_i;
  assign data_out_be_o = byte_enable_out;
  assign data_out_addr_o = data_out_addr;
  assign data_out_req_o = data_out_req;
  assign data_out_we_o = data_out_we;
  assign read_addr_buffer_empty = read_addr_buffer_empty_i;

endmodule
