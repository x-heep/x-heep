// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module simple_accelerator #(
    parameter int unsigned FIFO_DEPTH = 4,
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    output obi_req_t acc_read_ch0_req_o,
    input  obi_rsp_t acc_read_ch0_resp_i,

    output obi_req_t acc_write_ch0_req_o,
    input  obi_rsp_t acc_write_ch0_resp_i

);



  logic status_ready_d, status_ready_q, status_start_q;
  logic [31:0] address_read_q, address_write_q;
  logic [31:0] threshold_q;
  logic [ 9:0] size_q;

  localparam int unsigned LastFifoUsage = FIFO_DEPTH - 1;
  localparam int unsigned Addr_Fifo_Depth = (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1;


  logic [               31:0] read_ptr_reg;
  logic [               31:0] read_ptr_valid_reg;
  logic [               31:0] write_ptr_reg;
  logic [               31:0] write_address;
  logic [                9:0] dma_cnt;
  logic                       dma_start;
  logic                       dma_done;


  logic [Addr_Fifo_Depth-1:0] fifo_usage;
  logic                       fifo_alm_full;

  logic                       data_in_req;
  logic                       data_in_we;
  logic [                3:0] data_in_be;
  logic [               31:0] data_in_addr;
  logic                       data_in_gnt;
  logic                       data_in_rvalid;
  logic [               31:0] data_in_rdata;

  logic                       data_out_req;
  logic                       data_out_we;
  logic [                3:0] data_out_be;
  logic [               31:0] data_out_addr;
  logic [               31:0] data_out_wdata;
  logic                       data_out_gnt;

  logic                       fifo_flush;
  logic                       fifo_full;
  logic                       fifo_empty;


  logic [               31:0] fifo_input;
  logic [               31:0] fifo_output;

  logic [                3:0] byte_enable_out;

  logic                       dma_start_pending;

  enum {
    DMA_READY,
    DMA_STARTING,
    DMA_RUNNING
  }
      dma_state_q, dma_state_d;

  logic [Addr_Fifo_Depth-1:0] outstanding_req;

  enum logic {
    DMA_READ_FSM_IDLE,
    DMA_READ_FSM_ON
  }
      dma_read_fsm_state, dma_read_fsm_n_state;

  enum logic {
    DMA_WRITE_FSM_IDLE,
    DMA_WRITE_FSM_ON
  }
      dma_write_fsm_state, dma_write_fsm_n_state;

  assign acc_read_ch0_req_o.req = data_in_req;
  assign acc_read_ch0_req_o.we = data_in_we;
  assign acc_read_ch0_req_o.be = data_in_be;
  assign acc_read_ch0_req_o.addr = data_in_addr;
  assign acc_read_ch0_req_o.wdata = 32'h0;

  assign data_in_gnt = acc_read_ch0_resp_i.gnt;
  assign data_in_rvalid = acc_read_ch0_resp_i.rvalid;
  assign data_in_rdata = acc_read_ch0_resp_i.rdata;

  assign acc_write_ch0_req_o.req = data_out_req;
  assign acc_write_ch0_req_o.we = data_out_we;
  assign acc_write_ch0_req_o.be = data_out_be;
  assign acc_write_ch0_req_o.addr = data_out_addr;

  //complete the function
  assign acc_write_ch0_req_o.wdata = data_out_wdata > threshold_q ? data_out_wdata : threshold_q;
  //assign acc_write_ch0_req_o.wdata = data_out_wdata;

  assign data_out_gnt = acc_write_ch0_resp_i.gnt;

  assign status_ready_d = (dma_state_q == DMA_READY);

  assign write_address = write_ptr_reg;

  assign fifo_alm_full = (fifo_usage == LastFifoUsage[Addr_Fifo_Depth-1:0]);

  assign dma_start = (dma_state_q == DMA_STARTING);

  //decoder

  //0 READ ADDRESS
  //4 WRITE ADDRESS
  //8 THRESHOLD
  //C READY
  //10 SIZE
  //14 START
  always_comb begin
    reg_rsp_o.rdata = '0;
    reg_rsp_o.error = 1'b0;
    reg_rsp_o.ready = 1'b1;

    if (reg_req_i.valid) begin
      if (reg_req_i.addr[7:0] == 8'h14) begin
        reg_rsp_o.rdata = {31'h0, status_start_q};
      end
      if (reg_req_i.addr[7:0] == 8'h10) begin
        reg_rsp_o.rdata = {22'h0, size_q};
      end
      if (reg_req_i.addr[7:0] == 8'hC) begin
        reg_rsp_o.rdata = {31'h0, status_ready_q};
      end
      if (reg_req_i.addr[7:0] == 8'h8) begin
        reg_rsp_o.rdata = threshold_q;
      end
      if (reg_req_i.addr[7:0] == 8'h4) begin
        reg_rsp_o.rdata = address_write_q;
      end
      if (reg_req_i.addr[7:0] == 8'h0) begin
        reg_rsp_o.rdata = address_read_q;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      status_start_q <= '0;
      size_q <= '0;
      status_ready_q <= '0;
      threshold_q <= '0;
      address_write_q <= '0;
      address_read_q <= '0;
    end else begin
      if (reg_req_i.valid && reg_req_i.write) begin
        if (reg_req_i.addr[7:0] == 8'h14) begin
          status_start_q <= reg_req_i.wdata[0];
        end
        if (reg_req_i.addr[7:0] == 8'h10) begin
          size_q <= reg_req_i.wdata[9:0];
        end
        if (reg_req_i.addr[7:0] == 8'hC) begin
          status_ready_q <= reg_req_i.wdata[0];
        end
        if (reg_req_i.addr[7:0] == 8'h8) begin
          threshold_q <= reg_req_i.wdata;
        end
        if (reg_req_i.addr[7:0] == 8'h4) begin
          address_write_q <= reg_req_i.wdata;
        end
        if (reg_req_i.addr[7:0] == 8'h0) begin
          address_read_q <= reg_req_i.wdata;
        end
      end else begin
        if (dma_done) status_ready_q <= 1'b1;
        status_start_q <= '0;
      end
    end
  end


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
          dma_state_d = DMA_READY;
        end
      end
    endcase
  end

  // update state
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      dma_state_q <= DMA_READY;
    end else begin
      dma_state_q <= dma_state_d;
    end
  end


  // DMA pulse start when dma_start register is written
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_dma_start
    if (~rst_ni) begin
      dma_start_pending <= 1'b0;
    end else begin
      if (dma_start == 1'b1) begin
        dma_start_pending <= 1'b0;
      end else if (status_start_q && size_q != '0) begin
        dma_start_pending <= 1'b1;
      end
    end
  end

  // Store input data pointer and increment everytime read request is granted
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ptr_in_reg
    if (~rst_ni) begin
      read_ptr_reg <= '0;
    end else begin
      if (dma_start == 1'b1) begin
        read_ptr_reg <= address_read_q;
      end else if (data_in_gnt == 1'b1) begin
        read_ptr_reg <= read_ptr_reg + 32'h4;
      end
    end
  end

  // Only update read_ptr_valid_reg when the data is stored in the fifo
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ptr_valid_in_reg
    if (~rst_ni) begin
      read_ptr_valid_reg <= '0;
    end else begin
      if (dma_start == 1'b1) begin
        read_ptr_valid_reg <= address_read_q;
      end else if (data_in_rvalid == 1'b1) begin
        read_ptr_valid_reg <= read_ptr_valid_reg + 32'h4;
      end
    end
  end

  // Store output data pointer and increment everytime write request is granted
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ptr_out_reg
    if (~rst_ni) begin
      write_ptr_reg <= '0;
    end else begin
      if (dma_start == 1'b1) begin
        write_ptr_reg <= address_write_q;
      end else if (data_out_gnt == 1'b1) begin
        write_ptr_reg <= write_ptr_reg + 32'h4;
      end
    end
  end

  // Store dma transfer size and decrement it everytime input data rvalid is asserted
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_dma_cnt_reg
    if (~rst_ni) begin
      dma_cnt <= '0;
    end else begin
      if (dma_start == 1'b1) begin
        dma_cnt <= size_q;
      end else if (data_in_gnt == 1'b1) begin
        dma_cnt <= dma_cnt - 10'h1;
      end
    end
  end

  assign byte_enable_out = 4'b1111;

  assign data_out_wdata = fifo_output;

  assign fifo_input = data_in_rdata;

  // FSM state update
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_fsm_state
    if (~rst_ni) begin
      dma_read_fsm_state <= DMA_READ_FSM_IDLE;
      dma_write_fsm_state <= DMA_WRITE_FSM_IDLE;
      outstanding_req <= '0;
    end else begin
      dma_read_fsm_state <= dma_read_fsm_n_state;
      dma_write_fsm_state <= dma_write_fsm_n_state;
      outstanding_req <= outstanding_req + (data_in_req && data_in_gnt) - data_in_rvalid;
    end
  end

  // Read master FSM
  always_comb begin : proc_dma_read_fsm_logic

    dma_read_fsm_n_state = DMA_READ_FSM_IDLE;

    data_in_req = '0;
    data_in_we = '0;
    data_in_be = '0;
    data_in_addr = '0;

    fifo_flush = 1'b0;

    unique case (dma_read_fsm_state)

      DMA_READ_FSM_IDLE: begin
        // Wait for start signal
        if (dma_start == 1'b1) begin
          dma_read_fsm_n_state = DMA_READ_FSM_ON;
          fifo_flush = 1'b1;
        end else begin
          dma_read_fsm_n_state = DMA_READ_FSM_IDLE;
        end
      end
      // Read one word
      DMA_READ_FSM_ON: begin
        // If all input data read exit
        if (|dma_cnt == 1'b0) begin
          dma_read_fsm_n_state = DMA_READ_FSM_IDLE;
        end else begin
          dma_read_fsm_n_state = DMA_READ_FSM_ON;
          // Wait if fifo is full, almost full (last data)
          if (fifo_full == 1'b0 && fifo_alm_full == 1'b0) begin
            data_in_req  = 1'b1;
            data_in_we   = 1'b0;
            data_in_be   = 4'b1111;  // always read all bytes
            data_in_addr = read_ptr_reg;
          end
        end
      end
    endcase
  end

  // Write master FSM
  always_comb begin : proc_dma_write_fsm_logic

    dma_write_fsm_n_state = DMA_WRITE_FSM_IDLE;
    dma_done = 1'b0;

    data_out_req = '0;
    data_out_we = '0;
    data_out_be = '0;
    data_out_addr = '0;

    unique case (dma_write_fsm_state)

      DMA_WRITE_FSM_IDLE: begin
        // Wait for start signal
        if (dma_start == 1'b1) begin
          dma_write_fsm_n_state = DMA_WRITE_FSM_ON;
        end else begin
          dma_write_fsm_n_state = DMA_WRITE_FSM_IDLE;
        end
      end
      // Read one word
      DMA_WRITE_FSM_ON: begin
        // If all input data read exit
        if (fifo_empty == 1'b1 && dma_read_fsm_state == DMA_READ_FSM_IDLE) begin
          dma_done = outstanding_req == '0;
          dma_write_fsm_n_state = dma_done ? DMA_WRITE_FSM_IDLE : DMA_WRITE_FSM_ON;
        end else begin
          dma_write_fsm_n_state = DMA_WRITE_FSM_ON;
          // Wait if fifo is empty
          if (fifo_empty == 1'b0) begin
            data_out_req  = 1'b1;
            data_out_we   = 1'b1;
            data_out_be   = byte_enable_out;
            data_out_addr = write_address;
          end
        end
      end
    endcase
  end

  fifo_v3 #(
      .DEPTH(FIFO_DEPTH)
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
      .push_i(data_in_rvalid),
      // as long as the queue is not empty we can pop new elements
      .data_o(fifo_output),
      .pop_i(data_out_gnt)
  );


endmodule
