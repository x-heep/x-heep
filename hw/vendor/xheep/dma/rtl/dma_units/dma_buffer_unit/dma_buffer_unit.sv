/*
 * Copyright 2025 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <tommaso.terzano@gmail.com>
 *  
 * Info: This module instantiates the DMA FIFOs and the logic that drives them. 
 */

module dma_buffer_unit
  import dma_reg_pkg::*;
  import fifo_pkg::*;
#(
    parameter int FIFO_DEPTH = 4
) (
    input logic clk_i,
    input logic rst_ni,

    input logic dma_start_i,

    input dma_reg2hw_t reg2hw_i,

    input fifo_req_t read_buffer_req_i,
    input fifo_req_t read_addr_buffer_req_i,
    input fifo_req_t write_buffer_req_i,

    output fifo_resp_t read_buffer_resp_o,
    output fifo_resp_t read_addr_buffer_resp_o,
    output fifo_resp_t write_buffer_resp_o,

    input  fifo_resp_t hw_fifo_resp_i,
    output fifo_req_t  hw_fifo_req_o
);
  `include "dma_conf.svh"

  logic hw_fifo_mode;

  fifo_req_t read_fifo_req;
  fifo_resp_t read_fifo_resp;

  logic read_buffer_pop;

  logic [3:0] read_fifo_pop;

  logic [31:0] read_fifo_output;
  logic [31:0] read_buffer_output;

  dma_buffer_fifos #(
      .FIFO_DEPTH(FIFO_DEPTH)
  ) dma_buffer_fifos_i (
      .clk_i,
      .rst_ni,

      .hw_fifo_mode_i(hw_fifo_mode),

      .read_fifo_pop_i(read_fifo_pop),

      .read_fifo_req_i(read_fifo_req),
      .read_addr_fifo_req_i(read_addr_buffer_req_i),
      .write_fifo_req_i(write_buffer_req_i),

      .read_fifo_resp_o(read_fifo_resp),
      .read_addr_fifo_resp_o(read_addr_buffer_resp_o),
      .write_fifo_resp_o(write_buffer_resp_o),

      .hw_fifo_resp_i,
      .hw_fifo_req_o
  );

  dma_buffer_control dma_buffer_control_i (
      .clk_i,
      .rst_ni,
      .reg2hw_i,

      .dma_start_i,

      .read_buffer_pop_i(read_buffer_pop),

      .read_fifo_output_i(read_fifo_output),

      .read_fifo_pop_o(read_fifo_pop),

      .read_buffer_output_o(read_buffer_output)
  );

  assign hw_fifo_mode = reg2hw_i.hw_fifo_en.q;

  /* Due to the read FIFOs structure, thie pop signal is actually overridden by read_fifo_pop */
  assign read_fifo_req.pop = 1'b0;
  assign read_buffer_pop = read_buffer_req_i.pop;
  assign read_fifo_req.push = read_buffer_req_i.push;
  assign read_fifo_req.flush = read_buffer_req_i.flush;
  assign read_fifo_req.data = read_buffer_req_i.data;

  assign read_buffer_resp_o.empty = read_fifo_resp.empty;
  assign read_buffer_resp_o.full = read_fifo_resp.full;
  assign read_buffer_resp_o.alm_full = read_fifo_resp.alm_full;
  assign read_buffer_resp_o.data = read_buffer_output;
  assign read_fifo_output = read_fifo_resp.data;

endmodule
