// Copyright 2021 Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License").
//
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
//
// You may obtain a copy of the License at:
//
//     https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof distributed under the License
// is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
//
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Halfdan Bechmann  -  halfdan.bechmann@silabs.com           //
//                                                                            //
// Design Name:    Write Buffer                                               //
// Project Name:   CV32E40X                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Single word write buffer                                   //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_write_buffer import cv32e40x_pkg::*;
#(
  parameter int          PMA_NUM_REGIONS = 0,
  parameter pma_cfg_t    PMA_CFG[PMA_NUM_REGIONS-1:0] = '{default:PMA_R_DEFAULT}
)
  (
   // clock and reset
   input logic           clk,
   input logic           rst_n,

   // inputs
   input  logic          valid_i,
   input  obi_data_req_t trans_i,
   input  logic          ready_i,

   // outputs
   output logic          valid_o,
   output obi_data_req_t trans_o,
   output logic          ready_o
  );

  // local signals
  write_buffer_state_e        state, next_state;
  obi_data_req_t              trans_q;
  logic                       push;
  logic                       bufferable;

  assign bufferable = trans_i.memtype[0];

  ///////////////////////////////////////////
  // FSM
  ///////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      state <= WBUF_EMPTY;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    next_state = state;
    push       = 1'b0;

    case(state)
      WBUF_EMPTY: begin // buffer is empty
        if(bufferable && valid_i && !ready_i) begin
          next_state = WBUF_FULL;
          push       = 1'b1; // push incoming data into the buffer
        end
      end
      WBUF_FULL: begin // buffer is full
        if(ready_i) begin
          if (bufferable && valid_i) begin
            next_state = WBUF_FULL;
            push       = 1'b1; // push incoming data into the buffer
          end else begin
            next_state = WBUF_EMPTY;
          end
        end
      end

      default:;
    endcase // case (state)
  end

  ///////////////////////////////////////////
  // Buffer
  ///////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      trans_q <= '0;
    end else if (push) begin
      trans_q <= trans_i;
    end
  end

  ///////////////////////////////////////////
  // Outputs
  ///////////////////////////////////////////
  assign ready_o = (state == WBUF_FULL) ?
                   (bufferable && ready_i) : // A downstream ready will free up the buffer for a new bufferable transfer
                   (bufferable || ready_i);  // Ready for bufferable transfer, accept any transfer if downstream is ready
  assign valid_o = (state == WBUF_FULL) || valid_i;
  assign trans_o = (state == WBUF_FULL) ? trans_q : trans_i;

endmodule
