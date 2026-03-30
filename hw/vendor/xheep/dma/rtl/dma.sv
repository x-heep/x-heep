/*
 * Copyright 2024 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *  
 * Info: Direct Memory Access (DMA) channel module.
 */

module dma
  import fifo_pkg::*;
  import dma_reg_pkg::*;
#(
    parameter int FIFO_DEPTH = 4,
    parameter int RVALID_FIFO_DEPTH = 1,
    parameter int unsigned SLOT_NUM = 0,
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,
    parameter type obi_req_t = logic,
    parameter type obi_resp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,
    input logic clk_gate_en_ni,

    input logic ext_dma_stop_i,
    input logic hw_fifo_done_i,

    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    output obi_req_t  dma_read_req_o,
    input  obi_resp_t dma_read_resp_i,

    output obi_req_t  dma_write_req_o,
    input  obi_resp_t dma_write_resp_i,

    output obi_req_t  dma_addr_req_o,
    input  obi_resp_t dma_addr_resp_i,

    input  fifo_resp_t hw_fifo_resp_i,
    output fifo_req_t  hw_fifo_req_o,

    input logic [SLOT_NUM-1:0] trigger_slot_i,

    input dma_hw2reg_t external_hw2reg_i,

    output logic dma_done_intr_o,
    output logic dma_window_intr_o,

    output logic dma_ready_o,
    output logic dma_done_o
);

  `include "dma_conf.svh"

  /*_________________________________________________________________________________________________________________________________ */

  /* Signals declaration */

  /* Gated clock */
  logic clk_cg;

  /* Registers */
  dma_reg2hw_t reg2hw;
  dma_hw2reg_t hw2reg;

  /* General signals */
  logic dma_processing_unit_on;

  logic dma_start;
  logic dma_start_pending;
  logic dma_done;
  logic dma_write_done_override;
  logic dma_read_done_override;

  logic window_event;
  logic [31:0] window_counter;

  logic circular_mode;
  logic address_mode;
  logic hw_fifo_mode;

  /* Buffer signals */
  fifo_req_t read_buffer_req;
  fifo_req_t read_addr_buffer_req;
  fifo_req_t write_buffer_req;

  fifo_resp_t read_buffer_resp;
  fifo_resp_t read_addr_buffer_resp;
  fifo_resp_t write_buffer_resp;

  logic data_in_req;
  logic data_in_we;
  logic [3:0] data_in_be;
  logic [31:0] data_in_addr;
  logic data_in_gnt;
  logic data_in_rvalid;
  logic [31:0] data_in_rdata;

  logic data_addr_in_req;
  logic data_addr_in_we;
  logic [3:0] data_addr_in_be;
  logic [31:0] data_addr_in_addr;
  logic data_addr_in_gnt;
  logic data_addr_in_rvalid;
  logic [31:0] data_addr_in_rdata;

  logic data_out_req;
  logic data_out_we;
  logic [3:0] data_out_be;
  logic [31:0] data_out_addr;
  logic [31:0] data_out_wdata;
  logic data_out_gnt;
  logic data_out_rvalid;
  logic [31:0] data_out_rdata;

  /* Interrupt Flag Register signals */
  logic transaction_ifr;
  logic dma_done_intr_n;
  logic dma_done_intr;
  logic window_ifr;
  logic dma_window_intr;
  logic dma_window_intr_n;

  /* Buffer unit signals */
  logic general_buffer_flush;

  logic read_buffer_full;
  logic read_buffer_empty;
  logic read_buffer_alm_full;
  logic read_buffer_pop;
  logic [31:0] read_buffer_input;
  logic [31:0] read_buffer_output;

  logic read_addr_buffer_full;
  logic read_addr_buffer_empty;
  logic read_addr_buffer_alm_full;
  logic [31:0] read_addr_buffer_output;

  logic write_buffer_full;
  logic write_buffer_empty;
  logic write_buffer_alm_full;
  logic write_buffer_push;
  logic [31:0] write_buffer_output;
  logic [31:0] write_buffer_input;

  /* Trigger signals */
  logic wait_for_rx;
  logic wait_for_tx;
  logic enable_wait_for_rx;
  logic enable_wait_for_tx;

  /* FSM states */
  enum {
    DMA_READY,
    DMA_STARTING,
    DMA_RUNNING
  }
      dma_state_q, dma_state_d;

  /*_________________________________________________________________________________________________________________________________ */

  /* Module instantiation */

  /* Clock gating cell */

`ifndef FPGA_SYNTHESIS
`ifndef VERILATOR
  tc_clk_gating clk_gating_cell (
      .clk_i,
      .en_i(clk_gate_en_ni),
      .test_en_i(1'b0),
      .clk_o(clk_cg)
  );

`else
  assign clk_cg = clk_i & clk_gate_en_ni;
`endif

`else
  assign clk_cg = clk_i & clk_gate_en_ni;
`endif

  /* Registers */
  dma_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) dma_reg_top_i (
      .clk_i(clk_cg),
      .rst_ni,
      .reg_req_i,
      .reg_rsp_o,
      .reg2hw,
      .hw2reg,
      .devmode_i(1'b1)
  );

  assign dma_ready_o = hw2reg.status.ready.d;

  /* Buffer unit */
  dma_buffer_unit #(
      .FIFO_DEPTH(FIFO_DEPTH)
  ) dma_buffer_unit_i (
      .clk_i(clk_cg),
      .rst_ni,

      .dma_start_i(dma_start),

      .reg2hw_i(reg2hw),

      .read_buffer_req_i(read_buffer_req),
      .read_addr_buffer_req_i(read_addr_buffer_req),
      .write_buffer_req_i(write_buffer_req),

      .read_buffer_resp_o(read_buffer_resp),
      .read_addr_buffer_resp_o(read_addr_buffer_resp),
      .write_buffer_resp_o(write_buffer_resp),

      .hw_fifo_resp_i,
      .hw_fifo_req_o
  );

  /* Read unit */
  dma_read_unit #(
      .RVALID_FIFO_DEPTH(RVALID_FIFO_DEPTH)
  ) dma_read_unit_i (
      .clk_i(clk_cg),
      .rst_ni,

      .reg2hw_i(reg2hw),

      .dma_start_i(dma_start),
      .dma_done_i(dma_done),
      .dma_done_override_i(dma_read_done_override),

      .wait_for_rx_i(wait_for_rx),
      .enable_wait_for_rx_i(enable_wait_for_rx),
      .slot_wait_counter_i(reg2hw.slot_wait_counter.q),

      .read_buffer_full_i(read_buffer_full),
      .read_buffer_alm_full_i(read_buffer_alm_full),

      .read_buffer_input_o(read_buffer_input),

      .data_in_gnt_i(data_in_gnt),
      .data_in_rvalid_i(data_in_rvalid),
      .data_in_rdata_i(data_in_rdata),

      .data_in_req_o(data_in_req),
      .data_in_we_o(data_in_we),
      .data_in_be_o(data_in_be),
      .data_in_addr_o(data_in_addr),
      .general_buffer_flush_o(general_buffer_flush)
  );

  /* Read address unit */
`ifdef ADDR_MODE_EN
  dma_read_addr_unit dma_read_addr_unit_i (
      .clk_i(clk_cg),
      .rst_ni,

      .reg2hw_i(reg2hw),

      .dma_start_i(dma_start),
      .dma_done_override_i(dma_write_done_override),

      .read_addr_buffer_full_i(read_addr_buffer_full),
      .read_addr_buffer_alm_full_i(read_addr_buffer_alm_full),

      .data_addr_in_gnt_i (data_addr_in_gnt),
      .data_addr_in_req_o (data_addr_in_req),
      .data_addr_in_we_o  (data_addr_in_we),
      .data_addr_in_be_o  (data_addr_in_be),
      .data_addr_in_addr_o(data_addr_in_addr)
  );
`else
  assign data_addr_in_req  = '0;
  assign data_addr_in_we   = '0;
  assign data_addr_in_be   = '0;
  assign data_addr_in_addr = '0;
`endif


  /* DMA processing unit */
`ifdef ZERO_PADDING_EN
  dma_processing_unit dma_processing_unit_i (
      .clk_i(clk_cg),
      .rst_ni,

      .reg2hw_i(reg2hw),

      .dma_processing_unit_on_i(dma_processing_unit_on),
      .dma_start_i(dma_start),

      .read_buffer_empty_i(read_buffer_empty),
      .write_buffer_full_i(write_buffer_full),
      .write_buffer_alm_full_i(write_buffer_alm_full),

      .read_buffer_output_i(read_buffer_output),

      .write_buffer_push_o(write_buffer_push),
      .read_buffer_pop_o  (read_buffer_pop),

      .write_buffer_input_o(write_buffer_input)
  );
`else
  logic read_buffer_en;
  logic write_buffer_en;

  /* Read FIFO pop enable */
  assign read_buffer_en  = (read_buffer_empty == 1'b0);

  /* Write FIFO push enable */
  assign write_buffer_en = (write_buffer_full == 1'b0 && write_buffer_alm_full == 1'b0);

  always_comb begin
    if (read_buffer_en && write_buffer_en && dma_processing_unit_on == 1'b1) begin
      write_buffer_input = read_buffer_output;
      write_buffer_push  = 1'b1;
      read_buffer_pop    = 1'b1;
    end else begin
      write_buffer_input = '0;
      write_buffer_push  = 1'b0;
      read_buffer_pop    = 1'b0;
    end
  end
`endif


  /* Write unit */
  dma_write_unit dma_write_unit_i (
      .clk_i(clk_cg),
      .rst_ni,

      .reg2hw_i(reg2hw),

      .dma_start_i(dma_start),
      .wait_for_tx_i(wait_for_tx),
      .enable_wait_for_tx_i(enable_wait_for_tx),
      .slot_wait_counter_i(reg2hw.slot_wait_counter.q),

      .dma_done_o(dma_done),
      .dma_done_override_i(dma_write_done_override),

      .write_buffer_empty_i(write_buffer_empty),
      .read_addr_buffer_empty_i(read_addr_buffer_empty),

      .write_buffer_output_i(write_buffer_output),
      .read_addr_buffer_output_i(read_addr_buffer_output),

      .data_out_gnt_i(data_out_gnt),
      .data_out_rvalid_i(data_out_rvalid),

      .data_out_req_o(data_out_req),
      .data_out_we_o(data_out_we),
      .data_out_be_o(data_out_be),
      .data_out_addr_o(data_out_addr),
      .data_out_wdata_o(data_out_wdata)
  );

  /*_________________________________________________________________________________________________________________________________ */

  /* FSMs instantiation */

  //
  // Main DMA state machine
  //
  // READY   : idle, waiting for a write pulse to size registered in `dma_start_pending`
  // STARTING: load transaction data
  // RUNNING : waiting for transaction finish
  //           when `dma_done` rises either enter ready or restart in circular mode
  //

  always_comb begin
    dma_state_d = dma_state_q;
    case (dma_state_q)
      DMA_READY: begin
        if (dma_start_pending) begin
          dma_state_d = DMA_STARTING;
        end
      end
      DMA_STARTING: begin
        dma_state_d = DMA_RUNNING;
      end
      DMA_RUNNING: begin
        if (dma_done) begin
          if (circular_mode) dma_state_d = DMA_STARTING;
          else dma_state_d = DMA_READY;
        end
      end
    endcase
  end

  /* Update DMA state */
  always_ff @(posedge clk_cg, negedge rst_ni) begin
    if (~rst_ni) begin
      dma_state_q <= DMA_READY;
    end else begin
      dma_state_q <= dma_state_d;
    end
  end

  /* DMA pulse start when dma_start register is written */
  always_ff @(posedge clk_cg or negedge rst_ni) begin : proc_dma_start
    if (~rst_ni) begin
      dma_start_pending <= 1'b0;
    end else begin
      if (dma_start == 1'b1) begin
        dma_start_pending <= 1'b0;
      end else if ((reg2hw.size_d1.qe & |reg2hw.size_d1.q) || (reg2hw.hw_config_mode.q && external_hw2reg_i.size_d1.de && (external_hw2reg_i.size_d1.d > '0))) begin
        dma_start_pending <= 1'b1;
      end
    end
  end

  /* Transaction IFR update */
  always_ff @(posedge clk_cg, negedge rst_ni) begin : proc_ff_transaction_ifr
    if (~rst_ni) begin
      transaction_ifr <= '0;
    end else if (reg2hw.interrupt_en.transaction_done.q == 1'b1) begin
      // Enter here only if the transaction_done interrupt is enabled
      if (dma_done == 1'b1) begin
        transaction_ifr <= 1'b1;
      end else if (reg2hw.transaction_ifr.re == 1'b1) begin
        // If the IFR bit is read, we must clear the transaction_ifr
        transaction_ifr <= 1'b0;
      end
    end
  end

  /* Delayed transaction interrupt signals */
  always_ff @(posedge clk_cg, negedge rst_ni) begin : proc_ff_intr
    if (~rst_ni) begin
      dma_done_intr_n <= '0;
    end else begin
      dma_done_intr_n <= dma_done_intr;
    end
  end

  /* Window IFR update */
  always_ff @(posedge clk_cg, negedge rst_ni) begin : proc_ff_window_ifr
    if (~rst_ni) begin
      window_ifr <= '0;
    end else if (reg2hw.interrupt_en.window_done.q == 1'b1) begin
      // Enter here only if the window_done interrupt is enabled
      if (window_event == 1'b1) begin
        window_ifr <= 1'b1;
      end else if (reg2hw.window_ifr.re == 1'b1) begin
        // If the IFR bit is read, we must clear the window_ifr
        window_ifr <= 1'b0;
      end
    end
  end

  /* Delayed window interrupt signals */
  always_ff @(posedge clk_cg, negedge rst_ni) begin : proc_ff_window_intr
    if (~rst_ni) begin
      dma_window_intr_n <= '0;
    end else begin
      dma_window_intr_n <= dma_window_intr;
    end
  end

  /* Window event counter */
  always_ff @(posedge clk_cg, negedge rst_ni) begin : proc_dma_window_cnt
    if (~rst_ni) begin
      window_counter <= '0;
    end else begin
      if (|reg2hw.window_size.q) begin
        if ( (circular_mode && reg2hw.window_size.qe) || (~circular_mode && (dma_start | dma_done))) begin
          window_counter <= '0;
        end else if (data_out_gnt) begin
          if (window_event) begin
            window_counter <= '0;
          end else begin
            window_counter <= window_counter + 'h1;
          end
        end
      end
    end
  end

  /* Update Processing Unit start signal */
  always_ff @(posedge clk_cg, negedge rst_ni) begin
    if (~rst_ni) begin
      dma_processing_unit_on <= 1'b0;
    end else begin
      if (dma_start == 1'b1) begin
        dma_processing_unit_on <= 1'b1;
      end else if (dma_done == 1'b1) begin
        dma_processing_unit_on <= 1'b0;
      end
    end
  end

  /* HW FIFO done signal override logic */
`ifdef HW_FIFO_MODE_EN
  assign dma_write_done_override = (write_buffer_empty & hw_fifo_done_i & hw_fifo_mode) || ext_dma_stop_i;
`else
  assign dma_write_done_override = ext_dma_stop_i;
`endif

  assign dma_read_done_override = ext_dma_stop_i;


  /*_________________________________________________________________________________________________________________________________ */

  /* Signal assignments */

  /* General signals */
  assign dma_done_o = dma_done;
  assign dma_start = (dma_state_q == DMA_STARTING);

  /* OBI signals */
  assign dma_read_req_o.req = data_in_req;
  assign dma_read_req_o.we = data_in_we;
  assign dma_read_req_o.be = data_in_be;
  assign dma_read_req_o.addr = data_in_addr;
  assign dma_read_req_o.wdata = 32'h0;

  assign data_in_gnt = dma_read_resp_i.gnt;
  assign data_in_rvalid = dma_read_resp_i.rvalid;
  assign data_in_rdata = dma_read_resp_i.rdata;

  assign dma_addr_req_o.req = data_addr_in_req;
  assign dma_addr_req_o.we = data_addr_in_we;
  assign dma_addr_req_o.be = data_addr_in_be;
  assign dma_addr_req_o.addr = data_addr_in_addr;
  assign dma_addr_req_o.wdata = 32'h0;

  assign data_addr_in_gnt = dma_addr_resp_i.gnt;
  assign data_addr_in_rvalid = dma_addr_resp_i.rvalid;
  assign data_addr_in_rdata = dma_addr_resp_i.rdata;

  assign dma_write_req_o.req = data_out_req;
  assign dma_write_req_o.we = data_out_we;
  assign dma_write_req_o.be = data_out_be;
  assign dma_write_req_o.addr = data_out_addr;
  assign dma_write_req_o.wdata = data_out_wdata;

  assign data_out_gnt = dma_write_resp_i.gnt;
  assign data_out_rvalid = dma_write_resp_i.rvalid;
  assign data_out_rdata = dma_write_resp_i.rdata;

  /* FIFO signals */
  assign read_buffer_req.push = data_in_rvalid;
  assign read_buffer_req.pop = read_buffer_pop;
  assign read_buffer_req.flush = general_buffer_flush;
  assign read_buffer_req.data = read_buffer_input;

  assign read_buffer_empty = read_buffer_resp.empty;
  assign read_buffer_full = read_buffer_resp.full;
  assign read_buffer_alm_full = read_buffer_resp.alm_full;
  assign read_buffer_output = read_buffer_resp.data;

  assign read_addr_buffer_req.push = data_addr_in_rvalid;
  assign read_addr_buffer_req.pop = data_out_gnt && address_mode;
  assign read_addr_buffer_req.flush = general_buffer_flush;
  assign read_addr_buffer_req.data = data_addr_in_rdata;

  assign read_addr_buffer_empty = read_addr_buffer_resp.empty;
  assign read_addr_buffer_full = read_addr_buffer_resp.full;
  assign read_addr_buffer_alm_full = read_addr_buffer_resp.alm_full;
  assign read_addr_buffer_output = read_addr_buffer_resp.data;

  assign write_buffer_req.push = write_buffer_push;
  assign write_buffer_req.pop = (dma_state_q == DMA_RUNNING) & data_out_gnt;
  assign write_buffer_req.flush = general_buffer_flush;
  assign write_buffer_req.data = write_buffer_input;

  assign write_buffer_empty = write_buffer_resp.empty;
  assign write_buffer_full = write_buffer_resp.full;
  assign write_buffer_alm_full = write_buffer_resp.alm_full;
  assign write_buffer_output = write_buffer_resp.data;

  assign dma_done_intr = transaction_ifr;
  assign dma_done_intr_o = dma_done_intr_n;
  assign dma_window_intr = window_ifr;
  assign dma_window_intr_o = dma_window_intr_n;

  always_comb begin
    hw2reg = '0;

    if (reg2hw.hw_config_mode.q) begin
      hw2reg = external_hw2reg_i;
    end
    //these registers are controlled only by the DMA and never externally
    //thus, they are overwritten
    hw2reg.transaction_ifr.d = transaction_ifr;
    hw2reg.window_ifr.d = window_ifr;
    hw2reg.status.ready.d = (dma_state_q == DMA_READY);
    hw2reg.status.window_done.d = window_event;
    hw2reg.window_count.d = window_counter[7:0];
  end


  assign circular_mode = reg2hw.mode.q == 1;
  assign address_mode = reg2hw.mode.q == 2;
  assign hw_fifo_mode = reg2hw.hw_fifo_en.q;

  assign wait_for_rx = |(reg2hw.slot.rx_trigger_slot.q[SLOT_NUM-1:0] & (~trigger_slot_i));
  assign wait_for_tx = |(reg2hw.slot.tx_trigger_slot.q[SLOT_NUM-1:0] & (~trigger_slot_i));
  assign enable_wait_for_rx = |(reg2hw.slot.rx_trigger_slot.q[SLOT_NUM-1:0]);
  assign enable_wait_for_tx = |(reg2hw.slot.tx_trigger_slot.q[SLOT_NUM-1:0]);

  /* Logic for window counter */
  //TODO: is it really necessary? Do we need to write into a register how many events are done?
  //      Or do we need only the window donw signal?
  assign window_event = |reg2hw.window_size.q & data_out_gnt & (window_counter == {19'h0, reg2hw.window_size.q});

endmodule : dma
