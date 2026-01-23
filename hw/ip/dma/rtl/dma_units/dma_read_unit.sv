/*
 * Copyright 2024 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <tommaso.terzano@epfl.ch>
 *                         <tommaso.terzano@gmail.com>
 *  
 * Info: Read unit for the DMA channel, controls the input FIFO.
 */

module dma_read_unit
  import dma_reg_pkg::*;
#(
    parameter int RVALID_FIFO_DEPTH = 1
) (
    input logic clk_i,
    input logic rst_ni,

    input dma_reg2hw_t reg2hw_i,

    input logic dma_start_i,
    input logic dma_done_i,
    input logic dma_done_override_i,

    input logic wait_for_rx_i,
    input logic enable_wait_for_rx_i,
    input logic [7:0] slot_wait_counter_i,

    input logic read_buffer_full_i,
    input logic read_buffer_alm_full_i,

    input logic        data_in_gnt_i,
    input logic        data_in_rvalid_i,
    input logic [31:0] data_in_rdata_i,

    output logic        data_in_req_o,
    output logic        data_in_we_o,
    output logic [ 3:0] data_in_be_o,
    output logic [31:0] data_in_addr_o,

    output logic [31:0] read_buffer_input_o,

    output logic general_buffer_flush_o
);

  /*_________________________________________________________________________________________________________________________________ */

  /* Parameter definition */

  import dma_reg_pkg::*;
  import dma_pkg::*;

  `include "dma_conf.svh"
  localparam int unsigned LastFifoUsage = RVALID_FIFO_DEPTH - 1;
  localparam int unsigned AddrFifoDepth = (RVALID_FIFO_DEPTH > 1) ? $clog2(RVALID_FIFO_DEPTH) : 1;

  /*_________________________________________________________________________________________________________________________________ */

  /* Signals declaration */

  /* Registers */
  dma_reg2hw_t reg2hw;

  enum logic {
    DMA_READ_UNIT_IDLE,
    DMA_READ_UNIT_ON
  }
      dma_read_unit_state, dma_read_unit_n_state;

  logic dma_start;
  logic dma_done_override;
  logic dma_read_done;

  logic data_in_gnt;
  logic data_in_rvalid;

  logic buffer_full;
  logic buffer_alm_full;
  logic buffer_flush;

  logic read_ptr_update_sel;

  logic dma_conf_1d;
  logic dma_conf_2d;

  logic wait_for_rx;

  logic subaddr_mode;

  logic [16:0] dma_src_cnt_d1;
  logic [16:0] dma_src_cnt_d2;

  logic [31:0] trsp_src_ptr_reg;
  logic [31:0] read_ptr_reg;

  logic data_in_req;
  logic data_in_we;
  logic [3:0] data_in_be;
  logic [31:0] data_in_addr;
  logic [31:0] data_in_rdata;

  logic data_req_cond, data_req_cond_preobi;

  logic [1:0] read_data_offset;
  logic [AddrFifoDepth-1:0] read_data_offset_usage;
  logic read_data_offset_full;
  logic read_data_offset_alm_full;

  logic [31:0] dma_src_d1_inc;
  logic [31:0] dma_src_d2_inc;

  /* FIFO signals */
  logic [31:0] read_buffer_input;

  dma_pkg::dma_data_type_t src_data_type;

  logic sign_ext;

  dma_pkg::dma_obi_state_type_t obi_data_req_q, obi_data_req_d;

  dma_pkg::dma_wait_for_state_type_t wait_for_rx_state_q, wait_for_rx_state_d;

  logic [7:0] slot_wait_counter_d, slot_wait_counter_q;

  /*_________________________________________________________________________________________________________________________________ */

  /* FSMs instantiation */

  /* Sign extension of the increments */
  always_comb begin
    dma_src_d1_inc = {{26{reg2hw.src_ptr_inc_d1.q[5]}}, reg2hw.src_ptr_inc_d1.q};
    dma_src_d2_inc = {{9{reg2hw.src_ptr_inc_d2.q[22]}}, reg2hw.src_ptr_inc_d2.q};
  end

  /* Counters for the reading fsm */
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_dma_src_cnt_reg
    if (~rst_ni) begin
      dma_src_cnt_d1 <= '0;
      dma_src_cnt_d2 <= '0;
      obi_data_req_q <= OBI_DATA_REQ;
      wait_for_rx_state_q <= WAIT_FOR_OUTSTANDING_IDLE;
      slot_wait_counter_q <= '0;
    end else begin
      obi_data_req_q <= obi_data_req_d;
      wait_for_rx_state_q <= wait_for_rx_state_d;
      slot_wait_counter_q <= slot_wait_counter_d;
      if (dma_start == 1'b1) begin
        dma_src_cnt_d1 <= {1'h0, reg2hw.size_d1.q};
        dma_src_cnt_d2 <= {1'h0, reg2hw.size_d2.q};
      end else if (dma_done_i == 1'b1 || dma_done_override == 1'b1) begin
        dma_src_cnt_d1 <= '0;
        dma_src_cnt_d2 <= '0;
      end else if (data_in_gnt && data_in_req) begin
        if (dma_conf_1d == 1'b1) begin
          // 1D case
          dma_src_cnt_d1 <= dma_src_cnt_d1 - 1;
        end else if (dma_conf_2d == 1'b1) begin
          // 2D case
          if (dma_src_cnt_d1 == 1) begin
            // In this case, the d1 is finished, so we need to decrement the d2 size and reset the d2 size
            dma_src_cnt_d2 <= dma_src_cnt_d2 - 1;
            dma_src_cnt_d1 <= {1'h0, reg2hw.size_d1.q};
          end else begin
            // In this case, the d1 isn't finished, so we need to decrement the d1 size
            dma_src_cnt_d1 <= dma_src_cnt_d1 - 1;
          end
        end
      end
    end
  end

  /* 
   * Store input data pointer in source_ptr_reg and increment it every time read request is granted, 
   * if the d1 has finished reading and the read pointer update is set to 1'b1 
   */

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_src_ptr_reg
    if (~rst_ni) begin
      trsp_src_ptr_reg <= '0;
    end else begin
      if (dma_start == 1'b1) begin
        trsp_src_ptr_reg <= reg2hw.src_ptr.q + dma_src_d1_inc;
      end else if ((data_in_gnt && data_in_req) && dma_conf_2d == 1'b1 && read_ptr_update_sel == 1'b1 &&
                    (dma_src_cnt_d1 == 1 && |dma_src_cnt_d2 == 1'b1)) begin
        trsp_src_ptr_reg <= trsp_src_ptr_reg + dma_src_d1_inc;
      end
    end
  end

  /* Store input data pointer and increment everytime read request is granted */
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ptr_in_reg
    if (~rst_ni) begin
      read_ptr_reg <= '0;
    end else begin
      if (dma_start == 1'b1) begin
        read_ptr_reg <= reg2hw.src_ptr.q;
      end else if (data_in_gnt && data_in_req) begin
        if (dma_conf_1d == 1'b1) begin
          /* Increase the pointer by the amount written in ptr_inc */
          read_ptr_reg <= read_ptr_reg + dma_src_d1_inc;
        end else if (dma_conf_2d == 1'b1) begin
          if (read_ptr_update_sel == 1'b0) begin
            if (dma_src_cnt_d1 == 1 && |dma_src_cnt_d2 == 1'b1) begin
              /* In this case, the d1 is almost finished, so we need to increment the pointer by sizeof(d1)*data_unit */
              read_ptr_reg <= read_ptr_reg + dma_src_d2_inc;
            end else begin
              read_ptr_reg <= read_ptr_reg + dma_src_d1_inc; /* Increment of the d1 increment (stride) */
            end
          end else begin
            /* In this case, perform the transposition */
            if (dma_src_cnt_d1 == 1 && |dma_src_cnt_d2 == 1'b1) begin
              /* In this case, the d1 is almost finished, so we need to increment the pointer by sizeof(d1)*data_unit */
              read_ptr_reg <= trsp_src_ptr_reg;
            end else begin
              read_ptr_reg <= read_ptr_reg + dma_src_d2_inc; /* Increment of the d2 increment (stride) */
            end
          end
        end
      end
    end
  end

  // FSM state update
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_fsm_state
    if (~rst_ni) begin
      dma_read_unit_state <= DMA_READ_UNIT_IDLE;
    end else begin
      dma_read_unit_state <= dma_read_unit_n_state;
    end
  end

  // Read master FSM
  always_comb begin : proc_dma_read_unit_logic

    dma_read_unit_n_state = dma_read_unit_state;

    buffer_flush = 1'b0;
    /* This signal is used to avoid an extra read request after the end of the transfer,
       i.e. the very cycle in which the cnt(s) reach 0 the req must be 0 */
    dma_read_done = 1'b0;

    unique case (dma_read_unit_state)

      DMA_READ_UNIT_IDLE: begin
        // Wait for start signal
        if (dma_start == 1'b1) begin
          buffer_flush = 1'b1;
          dma_read_unit_n_state = DMA_READ_UNIT_ON;
        end
      end
      // Read one word
      DMA_READ_UNIT_ON: begin
        // If all input data read exit
        if (dma_done_override == 1'b0) begin
          if (dma_conf_1d == 1'b1) begin
            // 1D DMA case
            if (|dma_src_cnt_d1 == 1'b0) begin
              dma_read_unit_n_state = DMA_READ_UNIT_IDLE;
              dma_read_done = 1'b1;
            end
          end else if (dma_conf_2d == 1'b1) begin
            // 2D DMA case: exit only if both 1d and 2d counters are at 0
            if (dma_src_cnt_d1 == {1'h0, reg2hw.size_d1.q} && |dma_src_cnt_d2 == 1'b0) begin
              dma_read_unit_n_state = DMA_READ_UNIT_IDLE;
              dma_read_done = 1'b1;
            end
          end
        end else begin
          dma_read_unit_n_state = DMA_READ_UNIT_IDLE;
        end
      end
    endcase
  end

  /* Request logic of the read FSM */
  always_comb begin : proc_req_fsm_state_logic
    data_in_req = 0;

    if (dma_read_unit_state == DMA_READ_UNIT_ON) begin
      if (data_req_cond == 1'b1) begin
        data_in_req = 1;
      end
    end
  end

  /* This small FIFO is used to hold the last 2 LSBs of the read address.
   * Each time that a GNT is received, the current address is pushed.
   * Each time that a RVALID is received, the value is popped.
   * This feature enables the DMA to support outstanding transactions, 
   * when in the future this feature will be added to X-HEEP.
   */
  fifo_v3 #(
      .DEPTH(RVALID_FIFO_DEPTH),
      .FALL_THROUGH(1'b0),
      .DATA_WIDTH(2)
  ) dma_read_data_offset_fifo_i (
      .clk_i,
      .rst_ni,
      .flush_i(buffer_flush),
      .testmode_i(1'b0),
      .full_o(read_data_offset_full),
      .empty_o(),
      .usage_o(read_data_offset_usage),
      .data_i(read_ptr_reg[1:0]),
      .push_i(data_in_gnt && data_in_req),
      .data_o(read_data_offset),
      .pop_i(data_in_rvalid)
  );

  /* This logic is used to put extract relevant data from the word read and to perform sign extension */
  always_comb begin : proc_input_data
    read_buffer_input = data_in_rdata;

    if (subaddr_mode == 1'b0) begin
      case (read_data_offset)
        2'b00: begin
          if (src_data_type == DMA_DATA_TYPE_BYTE) begin
            read_buffer_input = {{24{sign_ext & data_in_rdata[7]}}, data_in_rdata[7:0]};
          end else if (src_data_type == DMA_DATA_TYPE_HALF_WORD) begin
            read_buffer_input = {{16{sign_ext & data_in_rdata[15]}}, data_in_rdata[15:0]};
          end
        end
        // Only BYTE could cause the address to be 01
        2'b01: begin
          read_buffer_input = {{24{sign_ext & data_in_rdata[15]}}, data_in_rdata[15:8]};
        end

        2'b10: begin
          if (src_data_type == DMA_DATA_TYPE_BYTE) begin
            read_buffer_input = {{24{sign_ext & data_in_rdata[23]}}, data_in_rdata[23:16]};
          end else if (src_data_type == DMA_DATA_TYPE_HALF_WORD) begin
            read_buffer_input = {{16{sign_ext & data_in_rdata[31]}}, data_in_rdata[31:16]};
          end
        end
        // Again, only BYTE could cause the address to be 01
        2'b11: read_buffer_input = {{24{sign_ext & data_in_rdata[31]}}, data_in_rdata[31:24]};
      endcase
    end
  end

  /*_________________________________________________________________________________________________________________________________ */

  /* Signal assignments */
  assign sign_ext = reg2hw_i.sign_ext.q;
  assign data_in_we = 0;
  assign data_in_be = 4'b1111;
  assign data_in_addr = read_ptr_reg;

  generate
    if (RVALID_FIFO_DEPTH != 1) begin : gen_rvalid_fifo
      assign read_data_offset_alm_full = (read_data_offset_usage == LastFifoUsage[AddrFifoDepth-1:0]);
      assign data_req_cond_preobi = (dma_read_done == 1'b0 && buffer_full == 1'b0 && buffer_alm_full == 1'b0 && 
                          read_data_offset_full == 1'b0 && read_data_offset_alm_full == 1'b0 &&
                          wait_for_rx == 1'b0);
    end else begin : gen_no_rvalid_fifo
      assign read_data_offset_alm_full = 1'b0;
      assign data_req_cond_preobi = (dma_read_done == 1'b0 && buffer_full == 1'b0 && buffer_alm_full == 1'b0 && 
                          wait_for_rx == 1'b0);
    end
  endgenerate

  always_comb begin
    data_req_cond  = data_req_cond_preobi;
    obi_data_req_d = obi_data_req_q;
    unique case (obi_data_req_q)

      OBI_DATA_REQ: begin
        if (data_in_req && !data_in_gnt) obi_data_req_d = OBI_WAIT_GNT;
      end

      OBI_WAIT_GNT: begin
        data_req_cond  = 1'b1;
        obi_data_req_d = data_in_gnt ? OBI_DATA_REQ : OBI_WAIT_GNT;
      end
    endcase
  end

  always_comb begin
    wait_for_rx_state_d = wait_for_rx_state_q;
    wait_for_rx = wait_for_rx_i;
    slot_wait_counter_d = slot_wait_counter_q;

    unique case (wait_for_rx_state_q)

      WAIT_FOR_OUTSTANDING_IDLE: begin
        if (enable_wait_for_rx_i) begin
          wait_for_rx_state_d = (data_in_req && data_in_gnt) ? WAIT_FOR_OUTSTANDING_WAIT : WAIT_FOR_OUTSTANDING_IDLE;
          slot_wait_counter_d = slot_wait_counter_i;
        end
      end

      WAIT_FOR_OUTSTANDING_WAIT: begin
        wait_for_rx = 1'b1;
        if (data_in_rvalid) begin
          if (slot_wait_counter_q == '0) begin
            wait_for_rx_state_d = WAIT_FOR_OUTSTANDING_IDLE;
          end else begin
            wait_for_rx_state_d = WAIT_FOR_OUTSTANDING_COUNTER;
          end
        end
      end

      WAIT_FOR_OUTSTANDING_COUNTER: begin
        wait_for_rx = 1'b1;
        if (slot_wait_counter_q == '0) begin
          wait_for_rx_state_d = WAIT_FOR_OUTSTANDING_IDLE;
        end else begin
          wait_for_rx_state_d = WAIT_FOR_OUTSTANDING_COUNTER;
          slot_wait_counter_d = slot_wait_counter_q - 1;
        end
      end

      default: ;

    endcase
  end

  /* Renaming */
  assign reg2hw = reg2hw_i;
  assign data_in_gnt = data_in_gnt_i;
  assign buffer_full = read_buffer_full_i;
  assign buffer_alm_full = read_buffer_alm_full_i;
  assign dma_start = dma_start_i;
  assign dma_done_override = dma_done_override_i;
  assign read_ptr_update_sel = reg2hw.dim_inv.q;
  assign dma_conf_1d = reg2hw.dim_config.q == 0;
  assign dma_conf_2d = reg2hw.dim_config.q == 1;
  assign data_in_be_o = data_in_be;
  assign data_in_addr_o = data_in_addr;
  assign data_in_req_o = data_in_req;
  assign data_in_we_o = data_in_we;
  assign general_buffer_flush_o = buffer_flush;
  assign data_in_rvalid = data_in_rvalid_i;
  assign data_in_rdata = data_in_rdata_i;
  assign read_buffer_input_o = read_buffer_input;
  assign src_data_type = dma_data_type_t'(reg2hw.src_data_type.q);
  assign subaddr_mode = reg2hw.mode.q == 3;

endmodule
