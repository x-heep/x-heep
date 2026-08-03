// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

//This module relies on the fact that the variable latency XBAR does not rise a new REQ if the previous one has not been granted


module xheep_obi_fifo #(
    // OBI data types
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    input  obi_req_t producer_req_i,
    output obi_rsp_t producer_resp_o,

    output obi_req_t consumer_req_o,
    input  obi_rsp_t consumer_resp_i
);

  typedef enum logic {
    CONSUMER_REQUEST,
    CONSUMER_WAIT_FOR_GNT
  } consumer_obi_req_fsm_e;

  consumer_obi_req_fsm_e consumer_state_n, consumer_state_q;

  typedef enum logic {
    PRODUCER_REQUEST,
    PRODUCER_WAIT_FOR_VALID
  } producer_obi_req_fsm_e;

  producer_obi_req_fsm_e producer_state_n, producer_state_q;

  typedef struct packed {
    logic        we;
    logic [3:0]  be;
    logic [31:0] addr;
    logic [31:0] wdata;
  } obi_data_req_t;

  obi_data_req_t producer_data_req, consumer_data_req, consumer_data_req_q;

  // remove .req from here if not it stays at 1
  assign {producer_data_req.we, producer_data_req.be, producer_data_req.addr, producer_data_req.wdata} =
          {
    producer_req_i.we, producer_req_i.be, producer_req_i.addr, producer_req_i.wdata
  };

  logic fifo_req_full, fifo_req_empty, fifo_req_push, fifo_req_pop;
  logic fifo_resp_full, fifo_resp_empty, fifo_resp_push, fifo_resp_pop;
  logic save_request;

  assign fifo_req_pop = !fifo_req_empty;

  //block consumer outstanding transactions
  always_comb begin
    consumer_state_n = consumer_state_q;
    consumer_req_o.req = ~fifo_req_empty;
    save_request = 1'b0;
    {consumer_req_o.we, consumer_req_o.be, consumer_req_o.addr, consumer_req_o.wdata} = {
      consumer_data_req.we, consumer_data_req.be, consumer_data_req.addr, consumer_data_req.wdata
    };

    case (consumer_state_q)

      CONSUMER_REQUEST: begin
        if (!consumer_resp_i.gnt && consumer_req_o.req) begin
          consumer_state_n = CONSUMER_WAIT_FOR_GNT;
          save_request = 1'b1;
        end
      end

      CONSUMER_WAIT_FOR_GNT: begin
        consumer_req_o.req = 1'b1;
        {consumer_req_o.we, consumer_req_o.be, consumer_req_o.addr, consumer_req_o.wdata} = {
          consumer_data_req_q.we,
          consumer_data_req_q.be,
          consumer_data_req_q.addr,
          consumer_data_req_q.wdata
        };
        if (consumer_resp_i.gnt) begin
          save_request = 1'b0;
          consumer_state_n = CONSUMER_REQUEST;
        end
      end
    endcase
  end

  //block producer outstanding transactions, the FIFO in theory can support more request at a time
  //but the bus won't dispatch the results depending on ID issues, so OBI slaves that have longer gnt/rvalid latency cannot support
  //back to back requests
  always_comb begin
    producer_state_n    = producer_state_q;
    producer_resp_o.gnt = !fifo_req_full;
    fifo_req_push       = producer_req_i.req && !fifo_req_full;

    case (producer_state_q)

      PRODUCER_REQUEST: begin
        if (producer_req_i.req && !fifo_req_full) begin
          producer_state_n = PRODUCER_WAIT_FOR_VALID;
        end
      end

      PRODUCER_WAIT_FOR_VALID: begin
        fifo_req_push       = 1'b0;
        producer_resp_o.gnt = 1'b0;
        if (producer_resp_o.rvalid) begin
          fifo_req_push = producer_req_i.req && !fifo_req_full;
          producer_resp_o.gnt = !fifo_req_full;
          if (producer_req_i.req && producer_resp_o.gnt) begin
            producer_state_n = PRODUCER_WAIT_FOR_VALID;
          end else begin
            producer_state_n = PRODUCER_REQUEST;
          end
        end
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      consumer_state_q <= CONSUMER_REQUEST;
      producer_state_q <= PRODUCER_REQUEST;
      consumer_data_req_q <= '0;
    end else begin
      consumer_state_q <= consumer_state_n;
      producer_state_q <= producer_state_n;
      if (save_request) consumer_data_req_q <= consumer_data_req;
    end
  end


  fifo_v3 #(
      .DEPTH(1),
      .dtype(obi_data_req_t)
  ) obi_req_fifo_i (
      .clk_i,
      .rst_ni,
      .flush_i(1'b0),
      .testmode_i(1'b0),
      .full_o(fifo_req_full),
      .empty_o(fifo_req_empty),
      .usage_o(),
      .data_i(producer_data_req),
      .push_i(fifo_req_push),
      .data_o(consumer_data_req),
      .pop_i(fifo_req_pop)
  );

  //todo add asserts - it cannot be full as we are popping all the time
  assign fifo_resp_push = consumer_resp_i.rvalid & !fifo_resp_full;
  assign fifo_resp_pop = !fifo_resp_empty;
  assign producer_resp_o.rvalid = fifo_resp_pop;

  fifo_v3 #(
      .DEPTH(1),
      .dtype(logic [31:0])
  ) obi_resp_fifo_i (
      .clk_i,
      .rst_ni,
      .flush_i(1'b0),
      .testmode_i(1'b0),
      .full_o(fifo_resp_full),
      .empty_o(fifo_resp_empty),
      .usage_o(),
      .data_i(consumer_resp_i.rdata),
      .push_i(fifo_resp_push),
      // grant is given above
      .data_o(producer_resp_o.rdata),
      .pop_i(fifo_resp_pop)
  );

endmodule
