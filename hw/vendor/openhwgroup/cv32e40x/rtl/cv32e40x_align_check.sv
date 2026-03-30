// Copyright 2022 Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License");
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Authors:        Oystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Description:    Alignment checker for mret pointers and atomics            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_align_check import cv32e40x_pkg::*;
  #(  parameter bit          IF_STAGE          = 1,
      parameter type         CORE_REQ_TYPE     = obi_inst_req_t,
      parameter type         CORE_RESP_TYPE    = inst_resp_t,
      parameter type         BUS_RESP_TYPE     = inst_resp_t

  )
  (
   input logic  clk,
   input logic  rst_n,

   // Enable signal, active for atomics and pointers
   input  logic           align_check_en_i,
   input  logic           misaligned_access_i,

   // Interface towards bus interface
   input  logic           bus_trans_ready_i,
   output logic           bus_trans_valid_o,
   output CORE_REQ_TYPE   bus_trans_o,

   input  logic           bus_resp_valid_i,
   input  BUS_RESP_TYPE   bus_resp_i,

   // Interface towards core (MPU)
   input  logic           core_trans_valid_i,
   output logic           core_trans_ready_o,
   input  CORE_REQ_TYPE   core_trans_i,

   output logic           core_resp_valid_o,
   output CORE_RESP_TYPE  core_resp_o,

   // Indication from the core that there will be one pending transaction in the next cycle
   input logic            core_one_txn_pend_n,

   // Indication from the core that an alignment error should be reported after all in flight transactions
   // are complete (default behavior for main core requests, but not used for XIF requests)
   input logic            core_align_err_wait_i,

   // Report alignment errors to the core immediatly (used in case core_align_wait_i is not asserted)
   output logic           core_align_err_o
   );

  logic          align_block_core;
  logic          align_block_bus;
  logic          align_trans_valid;
  logic          align_trans_ready;
  logic          align_err;
  logic          core_trans_we;
  align_status_e align_status;
  align_state_e  state_q, state_n;

  // FSM that will "consume" transfers which violates alignment requirement for atomics or pointers.
  // Upon an error, this FSM will prevent the transfer from going out on the bus
  // and wait for all in flight bus transactions to complete while blocking new transfers.
  // When all in flight transactions are complete, it will respond with the correct status before
  // allowing new transfers to go through.
  // The input signal core_one_txn_pend_n indicates that there, from the core's point of view,
  // will be one pending transaction in the next cycle. Upon an error, this transaction
  // will be completed by this FSM
  always_comb begin

    state_n           = state_q;
    align_block_core  = 1'b0;
    align_block_bus   = 1'b0;
    align_trans_valid = 1'b0;
    align_trans_ready = 1'b0;
    align_status      = ALIGN_OK;

    case(state_q)
      ALIGN_IDLE: begin
        if (align_err && core_trans_valid_i) begin

          // Block transfer from going out on the bus.
          align_block_bus  = 1'b1;

          // Signal to the core that the transfer was accepted (but will be consumed by the align)
          align_trans_ready = 1'b1;

          if (core_align_err_wait_i) begin
            if (core_trans_we) begin
              state_n = core_one_txn_pend_n ? ALIGN_WR_ERR_RESP : ALIGN_WR_ERR_WAIT;
            end else begin
              state_n = core_one_txn_pend_n ? ALIGN_RE_ERR_RESP : ALIGN_RE_ERR_WAIT;
            end
          end

        end
      end
      ALIGN_WR_ERR_WAIT,
      ALIGN_RE_ERR_WAIT: begin

        // Block new transfers while waiting for in flight transfers to complete
        align_block_bus  = 1'b1;
        align_block_core = 1'b1;

        if (core_one_txn_pend_n) begin
          state_n = (state_q == ALIGN_WR_ERR_WAIT) ? ALIGN_WR_ERR_RESP : ALIGN_RE_ERR_RESP;
        end
      end
      ALIGN_WR_ERR_RESP,
      ALIGN_RE_ERR_RESP: begin

        // Keep blocking new transfers
        align_block_bus  = 1'b1;
        align_block_core = 1'b1;

        // Set up align response towards the core
        align_trans_valid = 1'b1;
        align_status      = (state_q == ALIGN_WR_ERR_RESP) ? ALIGN_WR_ERR : ALIGN_RE_ERR;

        // Go back to IDLE uncoditionally.
        // The core is expected to always be ready for the response
        state_n = ALIGN_IDLE;

      end
      default: ;
    endcase
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      state_q     <= ALIGN_IDLE;
    end
    else begin
      state_q <= state_n;
    end
  end

  // Forward transaction request towards MPU
  assign bus_trans_valid_o   = core_trans_valid_i && !align_block_bus;
  assign bus_trans_o         = core_trans_i;


  // Forward transaction response towards core
  assign core_resp_valid_o        = bus_resp_valid_i || align_trans_valid;
  assign core_resp_o.bus_resp     = bus_resp_i;
  assign core_resp_o.align_status = align_status;
  assign core_resp_o.mpu_status   = MPU_OK;  // Assigned in the MPU (upstream), tied off to MPU_OK here.

  // Detect alignment error
  assign align_err = align_check_en_i && misaligned_access_i;

  // Report align matches to the core immediately
  assign core_align_err_o = align_err;

  // Signal ready towards core
  assign core_trans_ready_o     = (bus_trans_ready_i && !align_block_core) || align_trans_ready;

  generate
    if (IF_STAGE) begin: alcheck_if
      assign core_trans_we = 1'b0;
    end
    else begin: alcheck_lsu
      assign core_trans_we = core_trans_i.we;
    end
  endgenerate

endmodule
