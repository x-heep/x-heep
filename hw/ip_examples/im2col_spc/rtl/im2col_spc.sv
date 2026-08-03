/*
 * Copyright 2024 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <tommaso.terzano@epfl.ch>
 *                         <tommaso.terzano@gmail.com>
 *  
 * Info: Im2col accelerator implemented as a Smart Peripheral Controller. 
 *       It accesses the DMA channels to perform the matrix manipulation operation known as 
 *       "image to column" (im2col), which enables efficient CNN inference by transforming 
 *       the input tensor to use the GEMM library.
 */

module im2col_spc #(
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    input  reg_rsp_t aopb2im2col_resp_i,
    output reg_req_t im2col2aopb_req_o,

    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_done_i,
    output logic im2col_spc_done_int_o
);

  import core_v_mini_mcu_pkg::*;
  import dma_if_pkg::*;
  import im2col_spc_reg_pkg::*;
  import dma_reg_pkg::*;
  `include "dma_conf.svh"

`ifdef ZERO_PADDING_EN
  /*_________________________________________________________________________________________________________________________________ */

  /* Parameter definition */

  /* FIFO dimension */
  localparam FIFO_DEPTH = 8;

  /*_________________________________________________________________________________________________________________________________ */

  /* Signals declaration */

  /* General status signal */
  enum {
    READY,
    BUSY
  } im2col_status;

  /* Control Unit signals */
  logic im2col_start;
  logic im2col_fsms_done;
  logic im2col_done;

  /* Interrupt management signals */
  logic im2col_spc_ifr;

  /* DMA FIFO signals */
  logic fifo_flush;
  logic fifo_full;
  logic fifo_empty;
  dma_if_t fifo_input;
  logic fifo_push;
  dma_if_t fifo_output;
  logic fifo_pop;
  logic [$clog2(FIFO_DEPTH)-1:0] fifo_usage;

  /* DMA interface unit signals */
  logic im2col_param_done;
  logic dma_ch_free;
  logic dma_ch_first_write;
  logic [31:0] dma_ch_en_mask;
  logic [31:0] dma_ch_offset;
  logic [31:0] dma_addr;
  logic [31:0] dma_wdata;
  logic dma_if_loaded;
  logic dma_regintfc_start;
  logic dma_regintfc_done;

  /* Regtool signals */
  im2col_spc_reg2hw_t reg2hw;
  im2col_spc_hw2reg_t hw2reg;

  enum {
    READY_IF_CU,
    IDLE_IF_CU,
    GET_TRANSACTION,
    LOAD_TRANSACTION
  }
      dma_if_cu_q, dma_if_cu_d;

  enum {
    IDLE_IF_LOAD,
    WRITE_DIMENSIONALITY,
    WRITE_SLOTS,
    WRITE_SRC_DATATYPE,
    WRITE_DST_DATATYPE,
    WRITE_TOP_PAD,
    WRITE_BOTTOM_PAD,
    WRITE_LEFT_PAD,
    WRITE_RIGHT_PAD,
    WRITE_INPUT_PTR,
    WRITE_OUTPUT_PTR,
    WRITE_INC_SRC_D1,
    WRITE_INC_SRC_D2,
    WRITE_INC_DST_D1,
    WRITE_INC_DST_D2,
    WRITE_SIZE_D2,
    WRITE_SIZE_D1,
    DONE
  }
      dma_if_cu_load_q, dma_if_cu_load_d;

  /*_________________________________________________________________________________________________________________________________ */

  /* Module instantiation */

  /* Regtool top module */
  im2col_spc_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) im2col_spc_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg_req_i,
      .reg_rsp_o,
      .reg2hw,
      .hw2reg,
      .devmode_i(1'b1)
  );

  /* DMA FIFO */
  fifo_v3 #(
      .DEPTH(FIFO_DEPTH),
      .FALL_THROUGH(1'b0),
      .dtype(dma_if_t)
  ) dma_fifo_i (
      .clk_i,
      .rst_ni,
      .flush_i(fifo_flush),
      .testmode_i(1'b0),
      // status flags
      .full_o(fifo_full),
      .empty_o(fifo_empty),
      .usage_o(fifo_usage),
      // as long as the queue is not full we can push new data
      .data_i(fifo_input),
      .push_i(fifo_push),
      // as long as the queue is not empty we can pop new elements
      .data_o(fifo_output),
      .pop_i(fifo_pop)
  );

  /* Parameter FSM */
  im2col_spc_param_fsm im2col_spc_param_fsm_i (
      .clk_i,
      .rst_ni,
      .reg2hw_i(reg2hw),
      .im2col_done_i(im2col_done),
      .im2col_start_i(im2col_start),
      .fifo_full_i(fifo_full),
      .fifo_push_o(fifo_push),
      .im2col_param_done_o(im2col_param_done),
      .fifo_input_o(fifo_input)
  );

  /* Register interface control FSM */
  im2col_spc_regintfc_controller #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) im2col_spc_regintfc_controller_i (
      .clk_i,
      .rst_ni,
      .addr_i(dma_addr),
      .wdata_i(dma_wdata),
      .start_i(dma_regintfc_start),
      .aopb_resp_i(aopb2im2col_resp_i),
      .aopb_req_o(im2col2aopb_req_o),
      .done_o(dma_regintfc_done)
  );

  /*_________________________________________________________________________________________________________________________________ */

  /* FSMs instantiation */

  /* General status */
  always_ff @(posedge clk_i, negedge rst_ni) begin : proc_ff_im2col_status
    if (!rst_ni) begin
      im2col_status <= READY;
    end else begin
      if (im2col_done == 1'b1) begin
        im2col_status <= READY;
      end else if (im2col_start == 1'b1) begin
        im2col_status <= BUSY;
      end
    end
  end

  /* DMA interface unit state transition logic */
  always_comb begin : proc_comb_dma_if_fsm

    unique case (dma_if_cu_d)
      IDLE_IF_CU: begin
        if (fifo_empty == 1'b0 && im2col_fsms_done == 1'b0 && dma_ch_free == 1'b1) begin
          dma_if_cu_q = GET_TRANSACTION;
        end else begin
          dma_if_cu_q = IDLE_IF_CU;
        end
      end

      GET_TRANSACTION: begin
        if (fifo_empty == 1'b0 && dma_ch_free == 1'b1) begin
          dma_if_cu_q = LOAD_TRANSACTION;
        end else begin
          dma_if_cu_q = IDLE_IF_CU;
        end
      end

      LOAD_TRANSACTION: begin
        if (dma_if_loaded == 1'b1) begin
          if (im2col_fsms_done == 1'b0 && dma_ch_free == 1'b1) begin
            dma_if_cu_q = GET_TRANSACTION;
          end else begin
            dma_if_cu_q = IDLE_IF_CU;
          end
        end else begin
          dma_if_cu_q = LOAD_TRANSACTION;
        end
      end

      default: begin
        dma_if_cu_q = IDLE_IF_CU;
      end
    endcase
  end

  /* DMA interface unit state transition ff */
  always_ff @(posedge clk_i, negedge rst_ni) begin : proc_ff_dma_if_fsm
    if (!rst_ni) begin
      dma_if_cu_d <= IDLE_IF_CU;
    end else begin
      dma_if_cu_d <= dma_if_cu_q;
    end
  end

  /* DMA interface unit transaction loading state transition logic */
  always_comb begin : proc_comb_dma_if_trans_load_fsm
    unique case (dma_if_cu_load_d)
      IDLE_IF_LOAD: begin
        if (dma_if_cu_d == GET_TRANSACTION && im2col_fsms_done == 1'b0 && dma_ch_free == 1'b1) begin
          if (dma_ch_first_write == 1'b0) begin
            dma_if_cu_load_q = WRITE_DIMENSIONALITY;
          end else begin
            dma_if_cu_load_q = WRITE_TOP_PAD;
          end
        end else begin
          dma_if_cu_load_q = IDLE_IF_LOAD;
        end
      end

      WRITE_DIMENSIONALITY: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_SLOTS;
        end else if (dma_if_cu_d == IDLE_IF_CU) begin
          dma_if_cu_load_q = IDLE_IF_LOAD;
        end else begin
          dma_if_cu_load_q = WRITE_DIMENSIONALITY;
        end
      end

      WRITE_SLOTS: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_SRC_DATATYPE;
        end else if (dma_if_cu_d == IDLE_IF_CU) begin
          dma_if_cu_load_q = IDLE_IF_LOAD;
        end else begin
          dma_if_cu_load_q = WRITE_SLOTS;
        end
      end

      WRITE_SRC_DATATYPE: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_DST_DATATYPE;
        end else begin
          dma_if_cu_load_q = WRITE_SRC_DATATYPE;
        end
      end

      WRITE_DST_DATATYPE: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_TOP_PAD;
        end else begin
          dma_if_cu_load_q = WRITE_DST_DATATYPE;
        end
      end

      WRITE_TOP_PAD: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_BOTTOM_PAD;
        end else begin
          dma_if_cu_load_q = WRITE_TOP_PAD;
        end
      end

      WRITE_BOTTOM_PAD: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_LEFT_PAD;
        end else begin
          dma_if_cu_load_q = WRITE_BOTTOM_PAD;
        end
      end

      WRITE_LEFT_PAD: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_RIGHT_PAD;
        end else begin
          dma_if_cu_load_q = WRITE_LEFT_PAD;
        end
      end

      WRITE_RIGHT_PAD: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_INPUT_PTR;
        end else begin
          dma_if_cu_load_q = WRITE_RIGHT_PAD;
        end
      end

      WRITE_INPUT_PTR: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_OUTPUT_PTR;
        end else begin
          dma_if_cu_load_q = WRITE_INPUT_PTR;
        end
      end

      WRITE_OUTPUT_PTR: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_INC_SRC_D1;
        end else begin
          dma_if_cu_load_q = WRITE_OUTPUT_PTR;
        end
      end

      WRITE_INC_SRC_D1: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_INC_SRC_D2;
        end else begin
          dma_if_cu_load_q = WRITE_INC_SRC_D1;
        end
      end

      WRITE_INC_SRC_D2: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_INC_DST_D1;
        end else begin
          dma_if_cu_load_q = WRITE_INC_SRC_D2;
        end
      end

      WRITE_INC_DST_D1: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_INC_DST_D2;
        end else begin
          dma_if_cu_load_q = WRITE_INC_DST_D1;
        end
      end

      WRITE_INC_DST_D2: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_SIZE_D2;
        end else begin
          dma_if_cu_load_q = WRITE_INC_DST_D2;
        end
      end

      WRITE_SIZE_D2: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = WRITE_SIZE_D1;
        end else begin
          dma_if_cu_load_q = WRITE_SIZE_D2;
        end
      end

      WRITE_SIZE_D1: begin
        if (dma_regintfc_done == 1'b1) begin
          dma_if_cu_load_q = DONE;
        end else begin
          dma_if_cu_load_q = WRITE_SIZE_D1;
        end
      end

      DONE: begin
        dma_if_cu_load_q = IDLE_IF_LOAD;
      end

      default: begin
        dma_if_cu_load_q = IDLE_IF_LOAD;
      end

    endcase
  end

  always_comb begin : proc_comb_dma_if_trans_load_fsm_regintfc
    dma_if_loaded = 1'b0;
    dma_regintfc_start = 1'b0;
    fifo_pop = 1'b0;
    dma_wdata = '0;
    dma_addr = '0;

    unique case (dma_if_cu_load_d)
      IDLE_IF_LOAD: begin
      end

      WRITE_DIMENSIONALITY: begin
        dma_wdata = 32'h1;
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_DIM_CONFIG_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_SLOTS: begin
        dma_wdata = {reg2hw.slot.tx_trigger_slot.q, reg2hw.slot.rx_trigger_slot.q};
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_SLOT_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_SRC_DATATYPE: begin
        dma_wdata = {30'h0, reg2hw.data_type.q} & 32'h3;
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_SRC_DATA_TYPE_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_DST_DATATYPE: begin
        dma_wdata = {30'h0, reg2hw.data_type.q} & 32'h3;
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_DST_DATA_TYPE_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_TOP_PAD: begin
        dma_wdata = {24'h0, fifo_output.n_zeros_top};
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_PAD_TOP_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_BOTTOM_PAD: begin
        dma_wdata = {24'h0, fifo_output.n_zeros_bottom};
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_PAD_BOTTOM_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_LEFT_PAD: begin
        dma_wdata = {24'h0, fifo_output.n_zeros_left};
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_PAD_LEFT_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_RIGHT_PAD: begin
        dma_wdata = {24'h0, fifo_output.n_zeros_right};
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_PAD_RIGHT_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_INPUT_PTR: begin
        dma_wdata = fifo_output.input_ptr;
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_SRC_PTR_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_OUTPUT_PTR: begin
        dma_wdata = fifo_output.output_ptr;
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_DST_PTR_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_INC_SRC_D1: begin
        dma_wdata = (1 << {28'h0, reg2hw.log_strides_d1.q}) << (2 - reg2hw.data_type.q) & 32'h3f;
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_SRC_PTR_INC_D1_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_INC_SRC_D2: begin
        dma_wdata = {9'h0, fifo_output.in_inc_d2} << (2 - reg2hw.data_type.q) & 32'h7fffff;
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_SRC_PTR_INC_D2_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_INC_DST_D1: begin
        dma_wdata = (4 >> reg2hw.data_type.q) & 32'h3f;
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_DST_PTR_INC_D1_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_INC_DST_D2: begin
        dma_wdata = (4 >> reg2hw.data_type.q) & 32'h7fffff;
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_DST_PTR_INC_D2_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_SIZE_D2: begin
        dma_wdata = {16'h0, fifo_output.size_du_d2};
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_SIZE_D2_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      WRITE_SIZE_D1: begin
        dma_wdata = {16'h0, fifo_output.size_du_d1};
        dma_addr = dma_ch_offset + {25'h0, dma_reg_pkg::DMA_SIZE_D1_OFFSET};
        dma_regintfc_start = 1'b1;
      end

      DONE: begin
        dma_if_loaded = 1'b1;
        fifo_pop = 1'b1;
      end
    endcase
  end

  /* DMA interface unit transaction loading state transition ff */
  always_ff @(posedge clk_i, negedge rst_ni) begin : proc_ff_dma_if_trans_load_dq
    if (!rst_ni) begin
      dma_if_cu_load_d <= IDLE_IF_LOAD;
    end else begin
      dma_if_cu_load_d <= dma_if_cu_load_q;
    end
  end

  /* Channel tracker */
  always_ff @(posedge clk_i, negedge rst_ni) begin : proc_ff_control_unit
    if (!rst_ni) begin
      dma_ch_free <= 1'b1;
      dma_ch_first_write <= 1'b0;
    end else begin
      /* Set the dma_ch_free when im2col starts or when a transaction is finished */
      if (im2col_start == 1'b1) begin
        dma_ch_first_write <= 1'b0;
        dma_ch_free <= 1'b1;
      end

      if (|(dma_ch_en_mask[core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] & dma_done_i) == 1'b1) begin
        dma_ch_free <= 1'b1;
      end

      /* Clear the ch free flag only if the next state won't be the IDLE state */
      if (dma_if_cu_d == GET_TRANSACTION && dma_if_cu_q != IDLE_IF_CU) begin
        dma_ch_first_write <= 1'b1;
        dma_ch_free <= 1'b0;
      end
    end
  end

  /* FIFO reset */
  always_ff @(posedge clk_i, negedge rst_ni) begin : proc_ff_fifo_reset
    if (!rst_ni) begin
      fifo_flush <= 1'b1;
    end else begin
      fifo_flush <= 1'b0;
    end
  end

  /* Transaction IFR update */
  always_ff @(posedge clk_i, negedge rst_ni) begin : proc_ff_spc_ifr
    if (~rst_ni) begin
      im2col_spc_ifr <= '0;
    end else if (reg2hw.interrupt_en.q == 1'b1) begin
      // Enter here only if the im2col_done interrupt is enabled
      if (im2col_done == 1'b1) begin
        im2col_spc_ifr <= 1'b1;
      end else if (reg2hw.spc_ifr.re == 1'b1) begin
        // If the IFR bit is read, we must clear the transaction_ifr
        im2col_spc_ifr <= 1'b0;
      end
    end
  end

  /* Global fsm done signal update logic */
  always_ff @(posedge clk_i, negedge rst_ni) begin : proc_ff_spc_done
    if (!rst_ni) begin
      im2col_fsms_done <= 1'b0;
    end else begin
      if (im2col_done == 1'b1) begin
        im2col_fsms_done <= 1'b0;
      end else if (dma_if_cu_load_d == DONE && im2col_param_done == 1'b1 && fifo_usage == 1) begin
        im2col_fsms_done <= 1'b1;
      end
    end
  end

  /* Global done signal update logic */
  always_ff @(posedge clk_i, negedge rst_ni) begin : proc_ff_done
    if (!rst_ni) begin
      im2col_done <= 1'b0;
    end else begin
      if (im2col_fsms_done == 1'b1 && dma_ch_free == 1'b1) begin
        im2col_done <= 1'b1;
      end else begin
        im2col_done <= 1'b0;
      end
    end
  end

  /*_________________________________________________________________________________________________________________________________ */

  /* Signal assignments */

  /* Start signal assignment */
  assign im2col_start = (reg2hw.num_ch.qe == 1'b1);

  /* Transaction loading process */
  assign hw2reg.status.d = im2col_status == READY;

  /* Interrupt management */
  assign hw2reg.spc_ifr.d = im2col_spc_ifr;
  assign im2col_spc_done_int_o = im2col_spc_ifr;

  /* DMA channels mask register */
  assign dma_ch_en_mask = reg2hw.spc_ch_mask.q;

  /* DMA channel offset */
  assign dma_ch_offset = reg2hw.spc_ch_offset.q;

`endif
endmodule
