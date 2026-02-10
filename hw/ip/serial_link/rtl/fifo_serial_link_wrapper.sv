/*
 * Copyright 2025 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *  
 * Info: Wrapper for the Serial Link D2D IP to receive the data 
 *       as an array saved into the fifo and not as a master request to the bus
 */
module fifo_serial_link_wrapper #(

    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic,

    // Parameters of Axi Slave Bus Interface S00_AXI
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter FIFO_DEPTH = 8

) (


    input logic testmode_i,

    input  logic                  reader_req_i,
    output logic                  reader_gnt_o,
    output logic                  reader_rvalid_o,
    input  logic [ADDR_WIDTH-1:0] reader_addr_i,    //
    input  logic                  reader_we_i,
    input  logic [           3:0] reader_be_i,
    output logic [DATA_WIDTH-1:0] reader_rdata_o,
    input  logic [DATA_WIDTH-1:0] reader_wdata_i,

    input axi_req_t writer_axi_req,
    output axi_rsp_t writer_axi_rsp,
    output logic fifo_empty_o,
    output logic fifo_full_o,

    input logic clk_i,
    input logic rst_ni
);

  logic push, pop, full, empty;
  logic reader_req_q;
  logic reader_req_rising;
  logic [DATA_WIDTH-1:0] reader_rdata_n;

  assign reader_gnt_o = ~empty;

  assign push = writer_axi_req.w_valid & writer_axi_rsp.w_ready;
  assign reader_req_rising = reader_req_i & ~reader_req_q;
  assign pop = (~empty) & reader_req_rising & (~reader_we_i);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      reader_rvalid_o <= 0;
      reader_rdata_o  <= 0;
      reader_req_q    <= 0;
    end else begin
      reader_rvalid_o <= pop;
      reader_rdata_o  <= reader_rdata_n;
      reader_req_q    <= reader_req_i;
    end
  end

  enum logic [1:0] {
    IDLE,    // AW READY
    WAIT,
    WREADY,
    BVALID
  }
      state, n_state;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state <= IDLE;
    end else begin
      state <= n_state;
    end
  end

  always_comb begin
    case (state)
      IDLE:    n_state = writer_axi_req.aw_valid ? (full ? WAIT : WREADY) : IDLE;
      WAIT:    n_state = full ? WAIT : WREADY;
      WREADY:  n_state = writer_axi_req.w_valid ? BVALID : WREADY;
      BVALID:  n_state = writer_axi_req.b_ready ? IDLE : BVALID;
      default: n_state = IDLE;
    endcase
  end

  assign writer_axi_rsp.aw_ready = (state == IDLE);
  assign writer_axi_rsp.w_ready = (state == WREADY);
  assign writer_axi_rsp.b_valid = (state == BVALID);

  assign writer_axi_rsp.ar_ready = 1;
  assign writer_axi_rsp.r_valid = 0;
  assign writer_axi_rsp.b.id = '0;
  assign writer_axi_rsp.b.resp = '0;
  assign writer_axi_rsp.b.user = '0;
  assign writer_axi_rsp.r.data = '0;
  assign writer_axi_rsp.r.id = '0;
  assign writer_axi_rsp.r.last = 0;
  assign writer_axi_rsp.r.resp = '0;
  assign writer_axi_rsp.r.user = '0;

  fifo_v3 #(
      .DATA_WIDTH(DATA_WIDTH),
      .DEPTH(FIFO_DEPTH)
  ) fifo_i (
      .clk_i     (clk_i),                  // Clock
      .rst_ni    (rst_ni),                 // Asynchronous reset active low
      .flush_i   ('0),                     // flush the queue
      .testmode_i('0),                     // test_mode to bypass clock gating
      // status flags
      .full_o    (full),                   // queue is full
      .empty_o   (empty),                  // queue is empty
      .usage_o   (),                       // fill pointer
      // as long as the queue is not full we can push new data
      .data_i    (writer_axi_req.w.data),  // data to push into the queue
      .push_i    (push),                   // data is valid and can be pushed to the queue
      // as long as the queue is not empty we can pop new elements
      .data_o    (reader_rdata_n),         // output data
      .pop_i     (pop)                     // pop head from queue
  );


  assign fifo_empty_o = empty;
  assign fifo_full_o  = full;

endmodule


