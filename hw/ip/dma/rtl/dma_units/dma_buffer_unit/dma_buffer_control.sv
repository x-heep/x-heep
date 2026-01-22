/*
 * Copyright 2025 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <tommaso.terzano@gmail.com>
 *  
 * Info: This module contains all the logic that governs the FIFOs, specifically the read FIFOs. 
 *       More specifically, this unit implements the logic behind the subaddressing mode, enabling the optional
 *       sign extension within that mode.
 *       
 */

module dma_buffer_control
  import dma_reg_pkg::*;
#(
) (
    input logic clk_i,
    input logic rst_ni,

    input dma_reg2hw_t reg2hw_i,

    input logic dma_start_i,
    input logic read_buffer_pop_i,

    input logic [31:0] read_fifo_output_i,

    output logic [3:0] read_fifo_pop_o,

    output logic [31:0] read_buffer_output_o
);


  import dma_pkg::*;
  `include "dma_conf.svh"

dma_reg2hw_t reg2hw;

  logic dma_start;
  logic read_buffer_pop;
  logic subaddr_mode;
  logic sign_ext;
  logic [3:0] read_data_mask;
  logic [3:0] read_fifo_pop;

  logic [31:0] read_buffer_output;
  logic [31:0] read_fifo_output;

  dma_pkg::dma_data_type_t src_data_type;

  /* This logic enables Subaddressing Mode, when enabled */
`ifdef SUBADDR_MODE_EN
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      read_data_mask <= 4'b0000;
    end else if (subaddr_mode) begin
      case (src_data_type)
        DMA_DATA_TYPE_HALF_WORD: begin
          if (dma_start) begin
            read_data_mask <= 4'b0011;
          end else if (read_buffer_pop) begin
            if (read_data_mask == 4'b1100) read_data_mask <= 4'b0011;
            else read_data_mask <= 4'b1100;
          end
        end
        DMA_DATA_TYPE_BYTE: begin
          if (dma_start) begin
            read_data_mask <= 4'b0001;
          end else if (read_buffer_pop) begin
            if (read_data_mask == 4'b1000) read_data_mask <= 4'b0001;
            else read_data_mask <= read_data_mask << 1;
          end
        end
        default: read_data_mask <= 4'b1111;
      endcase
    end else begin
      read_data_mask <= 4'b1111;
    end
  end
`endif

  /* This logic generates the correct pop signal for the read FIFO, depending on the subaddressing mode */
`ifdef SUBADDR_MODE_EN

  always_comb begin
    read_fifo_pop = {4{read_buffer_pop}};

    if (subaddr_mode) begin
      if (read_data_mask == 4'b0011 || read_data_mask == 4'b0001 ||
          read_data_mask == 4'b0010 || read_data_mask == 4'b0100) begin
        read_fifo_pop = '0;
      end
    end
  end

`else

  assign read_fifo_pop = {4{read_buffer_pop}};

`endif

  /* This logic enables the correct selection of data with subaddressing mode, using optional sign extension */
  /* By default, sign extension is performed by the read unit */
`ifdef SUBADDR_MODE_EN

  always_comb begin
    read_buffer_output = read_fifo_output;

    if (subaddr_mode == 1'b1) begin
      if (read_buffer_pop == 1'b1) begin
        unique case (src_data_type)

          DMA_DATA_TYPE_HALF_WORD: begin
            if (read_data_mask == 4'b1100) begin
              read_buffer_output = {{16{sign_ext & read_fifo_output[31]}}, read_fifo_output[31:16]};
            end else begin
              read_buffer_output = {{16{sign_ext & read_fifo_output[15]}}, read_fifo_output[15:0]};
            end
          end

          DMA_DATA_TYPE_BYTE: begin
            if (read_data_mask == 4'b1000) begin
              read_buffer_output = {{24{sign_ext & read_fifo_output[31]}}, read_fifo_output[31:24]};
            end else if (read_data_mask == 4'b0100) begin
              read_buffer_output = {{24{sign_ext & read_fifo_output[23]}}, read_fifo_output[23:16]};
            end else if (read_data_mask == 4'b0010) begin
              read_buffer_output = {{24{sign_ext & read_fifo_output[15]}}, read_fifo_output[15:8]};
            end else if (read_data_mask == 4'b0001) begin
              read_buffer_output = {{24{sign_ext & read_fifo_output[7]}}, read_fifo_output[7:0]};
            end
          end

          default: ;  // do nothing

        endcase
      end
    end
  end

`else

  assign read_buffer_output = read_fifo_output;

`endif

  assign dma_start = dma_start_i;
  assign reg2hw = reg2hw_i;
  assign sign_ext = reg2hw.sign_ext.q;

  assign read_buffer_pop = read_buffer_pop_i;
  assign read_fifo_pop_o = read_fifo_pop;

  assign read_fifo_output = read_fifo_output_i;
  assign read_buffer_output_o = read_buffer_output;

  assign subaddr_mode = reg2hw.mode.q == 3;
  assign src_data_type = dma_data_type_t'(reg2hw.src_data_type.q);

endmodule
