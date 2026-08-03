// Copyright 2022 EPFL and Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: xbar_varlat_n_to_one.sv
// Author: Michele Caon
// Date: 18/05/2023
// Description: N-to-1 crossbar

module xbar_varlat_n_to_one #(
    parameter int unsigned XBAR_NMASTER = 2,
    parameter type         obi_req_t    = logic,
    parameter type         obi_rsp_t    = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // Master ports
    input  obi_req_t [XBAR_NMASTER-1:0] master_req_i,
    output obi_rsp_t [XBAR_NMASTER-1:0] master_resp_o,

    // Slave port
    output obi_req_t slave_req_o,
    input  obi_rsp_t slave_resp_i
);
  // ARCHITECTURE
  // ------------
  //              MASTER[0] ----.
  //            MASTER[...] --- XBAR <--> SLAVE
  // MASTER[XBAR_NMASTER-1] ----'

  // PARAMETERS
  // ----------
  // Request width: we + be[3:0] + addr[31:0] + wdata[31:0]
  localparam int unsigned ReqDataWidth = 32'd1 + 32'd4 + 32'd32 + 32'd32;
  // Response width: rdata[31:0]
  localparam int unsigned RspDataWidth = 32'd32;

  // INTERNAL SIGNALS
  // ----------------
  // Crossbar input and output data
  logic [XBAR_NMASTER-1:0]                   master_xbar_req_req;
  logic [XBAR_NMASTER-1:0]                   xbar_master_rsp_gnt;
  logic [XBAR_NMASTER-1:0]                   xbar_master_rsp_rvalid;
  logic [XBAR_NMASTER-1:0][ReqDataWidth-1:0] master_xbar_req_data;
  logic [XBAR_NMASTER-1:0][RspDataWidth-1:0] xbar_master_rsp_data;
  logic [             0:0]                   xbar_slave_req_req;
  logic [             0:0]                   slave_xbar_rsp_gnt;
  logic [             0:0]                   slave_xbar_rsp_rvalid;
  logic [             0:0][ReqDataWidth-1:0] xbar_slave_req_data;
  logic [             0:0][RspDataWidth-1:0] slave_xbar_rsp_data;
  logic xbar_slave_req_req_outstanding, slave_xbar_rsp_gnt_outstanding;

  // --------
  // CROSSBAR
  // --------
  // Unroll OBI master signals
  generate
    for (genvar i = 0; unsigned'(i) < XBAR_NMASTER; i++) begin : gen_master_unroll
      assign master_xbar_req_req[i] = master_req_i[i].req;
      assign master_xbar_req_data[i] = {
        master_req_i[i].we, master_req_i[i].be, master_req_i[i].addr, master_req_i[i].wdata
      };
      assign master_resp_o[i] = '{
              gnt: xbar_master_rsp_gnt[i],
              rvalid: xbar_master_rsp_rvalid[i],
              rdata: xbar_master_rsp_data[i]
          };
    end
  endgenerate

  // Unroll OBI slave signals
  assign slave_req_o.req = xbar_slave_req_req_outstanding;
  assign {
    slave_req_o.we,
    slave_req_o.be,
    slave_req_o.addr,
    slave_req_o.wdata
  } = xbar_slave_req_data[0];
  assign {slave_xbar_rsp_gnt[0], slave_xbar_rsp_rvalid[0], slave_xbar_rsp_data[0]} = slave_resp_i;

  // Instantiate crossbar
  xbar_varlat #(
      .AggregateGnt(32'd0),  // all the masters from X-HEEP do not aggregate multiple masters
      .NumIn(XBAR_NMASTER),
      .NumOut(32'd1),
      .ReqDataWidth(ReqDataWidth),
      .RespDataWidth(RspDataWidth),
      .ExtPrio(1'b0)  // do not use external arbiter priority
  ) u_xbar_varlat (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .rr_i   ('0),
      .req_i  (master_xbar_req_req),
      .add_i  ('0),
      .wdata_i(master_xbar_req_data),
      .gnt_o  (xbar_master_rsp_gnt),
      .vld_o  (xbar_master_rsp_rvalid),
      .rdata_o(xbar_master_rsp_data),
      .gnt_i  (slave_xbar_rsp_gnt_outstanding),
      .req_o  (xbar_slave_req_req),
      .vld_i  (slave_xbar_rsp_rvalid),
      .wdata_o(xbar_slave_req_data),
      .rdata_i(slave_xbar_rsp_data)
  );

  //block outstanding transactions
  typedef enum logic {
    OUTSTANDING_REQ,
    OUTSTANDING_WAITFOR_VALID
  } outstanding_req_fsm_e;

  outstanding_req_fsm_e state_n, state_q;

  /* block outstanding transactions
    The Master M1 may get a GNT at cycle 1, then the Master M2
    gets a GNT at cycle 2 (from the same or different slaves)
    As outstanding transactions are not supported (neither in-order nor out-of-order)
    we need to block the transaction.

    The addr_dec_resp_mux_varlat gates the second request of a master until the valid of the first request returns
    However, when different masters collides into the 1toM bus, the second part of the xbar sees a single master (the neck) issueing multiple requests (although
    these 2 reqeusts can actually come from 2 different masters M1 and M2)
    The second neck.req is gated by the addr_dec_resp_mux_varlat, but not its grant, thus the following FSM gates the gnt as the original master (i.e. the one before the neck)
    The reason why we have to gate the grant is that the M2 issued a request, although the neck.req is gated by the valid of the M1 request, the grant is propagated
    to M2, which gets its request granted without begin correct.
  */
  always_comb begin
    state_n = state_q;
    xbar_slave_req_req_outstanding = xbar_slave_req_req[0];
    slave_xbar_rsp_gnt_outstanding = slave_xbar_rsp_gnt[0];

    case (state_q)

      OUTSTANDING_REQ: begin
        if (xbar_slave_req_req_outstanding && slave_xbar_rsp_gnt_outstanding) begin
          state_n = OUTSTANDING_WAITFOR_VALID;
        end
      end

      OUTSTANDING_WAITFOR_VALID: begin
        xbar_slave_req_req_outstanding = 1'b0;
        slave_xbar_rsp_gnt_outstanding = 1'b0;
        if (slave_xbar_rsp_rvalid[0]) begin
          xbar_slave_req_req_outstanding = xbar_slave_req_req[0];
          slave_xbar_rsp_gnt_outstanding = slave_xbar_rsp_gnt[0];
          if (xbar_slave_req_req_outstanding && slave_xbar_rsp_gnt_outstanding) begin
            state_n = OUTSTANDING_WAITFOR_VALID;
          end else begin
            state_n = OUTSTANDING_REQ;
          end
        end
      end
    endcase

  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q <= OUTSTANDING_REQ;
    end else begin
      state_q <= state_n;
    end
  end


endmodule
