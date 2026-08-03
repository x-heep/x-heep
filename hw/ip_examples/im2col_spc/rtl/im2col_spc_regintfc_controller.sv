/*
 * Copyright 2024 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <tommaso.terzano@epfl.ch>
 *                         <tommaso.terzano@gmail.com>
 *  
 * Info: Register interface ontroller to comunicate with the AOPB.
 */

module im2col_spc_regintfc_controller #(
    // Register interface data types
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,
    input logic [31:0] addr_i,
    input logic [31:0] wdata_i,
    input logic start_i,
    input reg_rsp_t aopb_resp_i,
    output reg_req_t aopb_req_o,
    output logic done_o
);

  /* General status signal */
  enum {
    IDLE,
    WAITING_READY,
    SENDING,
    DONE
  }
      im2col_status_q, im2col_status_d;

  always_comb begin
    unique case (im2col_status_d)
      IDLE: begin
        if (start_i == 1'b1) begin
          im2col_status_q = SENDING;
        end else begin
          im2col_status_q = IDLE;
        end
      end

      SENDING: begin
        im2col_status_q = WAITING_READY;
      end

      WAITING_READY: begin
        if (aopb_resp_i.ready == 1'b1) begin
          im2col_status_q = DONE;
        end else begin
          im2col_status_q = WAITING_READY;
        end
      end

      DONE: begin
        im2col_status_q = IDLE;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      im2col_status_d <= IDLE;
    end else begin
      im2col_status_d <= im2col_status_q;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aopb_req_o.valid <= 1'b0;
      aopb_req_o.write <= 1'b0;
      aopb_req_o.wstrb <= 4'b1111;
      aopb_req_o.addr  <= '0;
      aopb_req_o.wdata <= '0;
    end else begin
      if (im2col_status_d == SENDING) begin
        aopb_req_o.valid <= 1'b1;
        aopb_req_o.write <= 1'b1;
        aopb_req_o.wstrb <= 4'b1111;
        aopb_req_o.addr  <= addr_i;
        aopb_req_o.wdata <= wdata_i;
      end else if (im2col_status_q == DONE) begin
        aopb_req_o.valid <= 1'b0;
      end
    end
  end

  assign done_o = (im2col_status_d == DONE);

endmodule
