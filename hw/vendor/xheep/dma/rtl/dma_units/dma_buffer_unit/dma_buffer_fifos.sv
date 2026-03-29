/*
 * Copyright 2025 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <tommaso.terzano@gmail.com>
 *  
 * Info: This module contains all the FIFOs needed by the DMA. It also implements the logic that enables the HW FIFO mode,
 *       which can be used to implement tighly-coupled DMA-based accelerators. In this mode, the write FIFO is substituted by
 *       the external accelerator, which receives data in its own read FIFO, process it, and then push it into its own write FIFO.
 *       Following the design principle of full-modularity, only this module "knows" of the existence of this mode. The write unit
 *       will behave as usual, as well as the processing unit.
 */

module dma_buffer_fifos
  import fifo_pkg::*;
#(
    parameter int FIFO_DEPTH = 4
) (
    input logic clk_i,
    input logic rst_ni,

    input logic hw_fifo_mode_i,

    input logic [3:0] read_fifo_pop_i,

    input fifo_req_t read_fifo_req_i,
    input fifo_req_t read_addr_fifo_req_i,
    input fifo_req_t write_fifo_req_i,

    output fifo_resp_t read_fifo_resp_o,
    output fifo_resp_t read_addr_fifo_resp_o,
    output fifo_resp_t write_fifo_resp_o,

    input  fifo_resp_t hw_fifo_resp_i,
    output fifo_req_t  hw_fifo_req_o
);
  `include "dma_conf.svh"
  localparam int unsigned LastFifoUsage = FIFO_DEPTH - 1;
  localparam int unsigned AddrFifoDepth = (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1;

  fifo_req_t write_fifo_req;
  fifo_resp_t write_fifo_resp;

  logic read_bundle_full;
  logic read_bundle_empty;
  logic read_bundle_alm_full;
  logic [3:0] read_fifo_full;
  logic [3:0] read_fifo_empty;
  logic [3:0] read_fifo_pop;
  logic read_bundle_push;
  logic read_fifo_flush;

  logic hw_fifo_mode;

  logic [AddrFifoDepth-1:0] read_addr_fifo_usage;
  logic [3:0][AddrFifoDepth-1:0] read_fifo_usage;
  logic [AddrFifoDepth-1:0] write_fifo_usage;

  logic [31:0] read_bundle_input;

  logic [31:0] read_bundle_output;

  /* Generate Read FIFOs */
  generate
    genvar i;

    for (i = 0; i < 4; i++) begin : FIFO_GEN
      /* Read FIFO */
      fifo_v3 #(
          .DEPTH(FIFO_DEPTH),
          .FALL_THROUGH(1'b0),
          .DATA_WIDTH(8)
      ) dma_read_fifo_i (
          .clk_i,
          .rst_ni,
          .flush_i(read_fifo_flush),
          .testmode_i(1'b0),
          .full_o(read_fifo_full[i]),
          .empty_o(read_fifo_empty[i]),
          .usage_o(read_fifo_usage[i]),
          .data_i(read_bundle_input[(8*(i+1)-1):8*i]),
          .push_i(read_bundle_push),
          .data_o(read_bundle_output[(8*(i+1)-1):8*i]),
          .pop_i(read_fifo_pop[i])
      );
    end

    assign read_bundle_full = |(read_fifo_full);
    assign read_bundle_empty = &(read_fifo_empty);
    assign read_bundle_alm_full = (read_fifo_usage[0] == LastFifoUsage[AddrFifoDepth-1:0]) & 
                                (read_fifo_usage[1] == LastFifoUsage[AddrFifoDepth-1:0]) &
                                (read_fifo_usage[2] == LastFifoUsage[AddrFifoDepth-1:0]) &
                                (read_fifo_usage[3] == LastFifoUsage[AddrFifoDepth-1:0]);
  endgenerate

  /* Generate Read Address Mode FIFOs */
`ifdef ADDR_MODE_EN

  /* Read address mode FIFO */
  fifo_v3 #(
      .DEPTH(FIFO_DEPTH),
      .FALL_THROUGH(1'b0)
  ) dma_read_addr_fifo_i (
      .clk_i,
      .rst_ni,
      .flush_i(read_addr_fifo_req_i.flush),
      .testmode_i(1'b0),
      .full_o(read_addr_fifo_resp_o.full),
      .empty_o(read_addr_fifo_resp_o.empty),
      .usage_o(read_addr_fifo_usage),
      .data_o(read_addr_fifo_resp_o.data),
      .data_i(read_addr_fifo_req_i.data),
      .push_i(read_addr_fifo_req_i.push),
      .pop_i(read_addr_fifo_req_i.pop)
  );

  assign read_addr_fifo_resp_o.alm_full = (read_addr_fifo_usage == LastFifoUsage[AddrFifoDepth-1:0]);

`else

  /* Tie to 0s the Address mode signals */
  assign read_addr_fifo_resp_o.full     = 0;
  assign read_addr_fifo_resp_o.empty    = 0;
  assign read_addr_fifo_resp_o.alm_full = 0;
  assign read_addr_fifo_resp_o.data     = '0;

`endif

  /* Write FIFO */
  fifo_v3 #(
      .DEPTH(FIFO_DEPTH),
      .FALL_THROUGH(1'b0)
  ) dma_write_fifo_i (
      .clk_i,
      .rst_ni,
      .flush_i(write_fifo_req.flush),
      .testmode_i(1'b0),
      .full_o(write_fifo_resp.full),
      .empty_o(write_fifo_resp.empty),
      .usage_o(write_fifo_usage),
      .data_o(write_fifo_resp.data),
      .data_i(write_fifo_req.data),
      .push_i(write_fifo_req.push),
      .pop_i(write_fifo_req.pop)
  );

  /* HW FIFO connection, which can substitute the write FIFO when that mode is on */
  assign write_fifo_resp.alm_full = (write_fifo_usage == LastFifoUsage[AddrFifoDepth-1:0]);

`ifdef HW_FIFO_MODE_EN

  always_comb begin
    if (hw_fifo_mode) begin
      hw_fifo_req_o        = write_fifo_req_i;
      write_fifo_resp_o    = hw_fifo_resp_i;

      write_fifo_req.flush = 1'b0;
      write_fifo_req.data  = '0;
      write_fifo_req.push  = 1'b0;
      write_fifo_req.pop   = 1'b0;
    end else begin
      write_fifo_req      = write_fifo_req_i;
      write_fifo_resp_o   = write_fifo_resp;

      hw_fifo_req_o.flush = 1'b0;
      hw_fifo_req_o.data  = '0;
      hw_fifo_req_o.push  = 1'b0;
      hw_fifo_req_o.pop   = 1'b0;
    end
  end

`else

  assign write_fifo_req      = write_fifo_req_i;
  assign write_fifo_resp_o   = write_fifo_resp;

  /* Tie to 0s the HW FIFO mode signals */
  assign hw_fifo_req_o.flush = 1'b0;
  assign hw_fifo_req_o.data  = '0;
  assign hw_fifo_req_o.push  = 1'b0;
  assign hw_fifo_req_o.pop   = 1'b0;

`endif

  assign read_fifo_pop = read_fifo_pop_i;
  assign read_bundle_push = read_fifo_req_i.push;
  assign read_fifo_flush = read_fifo_req_i.flush;
  assign read_bundle_input = read_fifo_req_i.data;

  assign read_fifo_resp_o.data = read_bundle_output;
  assign read_fifo_resp_o.full = read_bundle_full;
  assign read_fifo_resp_o.alm_full = read_bundle_alm_full;
  assign read_fifo_resp_o.empty = read_bundle_empty;

  assign hw_fifo_mode = hw_fifo_mode_i;

endmodule
