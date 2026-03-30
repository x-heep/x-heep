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
// Description:    WPT                                                        //
//                 Module blocks any trans to the MPU if a watchpoint trigger //
//                 fires for the current address. Trigger match is reported   //
//                 with WB timing similar to how the MPU reports status.      //
//                 cv32e40x_wpt is inherited from cv32e40x_mpu and adataped   //
//                 for watchpoint triggers.                                   //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_wpt import cv32e40x_pkg::*;
  (
   input logic  clk,
   input logic  rst_n,

   // Input from debug_triggers module
   input  logic           trigger_match_i,

   // Interface towards mpu interface
   input  logic           mpu_trans_ready_i,
   output logic           mpu_trans_valid_o,
   output logic           mpu_trans_pushpop_o,
   output obi_data_req_t  mpu_trans_o,

   input  logic           mpu_resp_valid_i,
   input  data_resp_t     mpu_resp_i,

   // Interface towards core
   input  logic           core_trans_valid_i,
   output logic           core_trans_ready_o,
   input  logic           core_trans_pushpop_i,
   input  obi_data_req_t  core_trans_i,

   output logic           core_resp_valid_o,
   output data_resp_t     core_resp_o,

   // Indication from the core that there will be one pending transaction in the next cycle
   input logic            core_one_txn_pend_n,

   // Indication from the core that watchpoint triggers should be reported after all in flight transactions
   // are complete (default behavior for main core requests, but not used for XIF requests)
   input logic            core_wpt_wait_i,

   // Report watchpoint triggers to the core immediatly (used in case core_wpt_wait_i is not asserted)
   output logic           core_wpt_match_o
   );

  logic        wpt_block_core;
  logic        wpt_block_bus;
  logic        wpt_trans_valid;
  logic        wpt_trans_ready;
  logic        wpt_match;
  wpt_state_e  state_q, state_n;

  // FSM that will "consume" transfers with firing watchpoint triggers.
  // Upon trigger match, this FSM will prevent the transfer from going out on the bus
  // and wait for all in flight bus transactions to complete while blocking new transfers.
  // When all in flight transactions are complete, it will respond with the correct status before
  // allowing new transfers to go through.
  // The input signal core_one_txn_pend_n indicates that there, from the core's point of view,
  // will be one pending transaction in the next cycle. Upon watchpoint match, this transaction
  // will be completed by this FSM
  always_comb begin

    state_n         = state_q;
    wpt_block_core  = 1'b0;
    wpt_block_bus   = 1'b0;
    wpt_trans_valid = 1'b0;
    wpt_trans_ready = 1'b0;
    wpt_match       = 1'b0;

    case(state_q)
      WPT_IDLE: begin
        if (trigger_match_i && core_trans_valid_i) begin

          // Block transfer from going out on the bus.
          wpt_block_bus  = 1'b1;

          // Signal to the core that the transfer was accepted (but will be consumed by the WPT)
          wpt_trans_ready = 1'b1;

          if (core_wpt_wait_i) begin
            state_n = core_one_txn_pend_n ? WPT_MATCH_RESP : WPT_MATCH_WAIT;
          end

        end
      end
      WPT_MATCH_WAIT: begin

        // Block new transfers while waiting for in flight transfers to complete
        wpt_block_bus  = 1'b1;
        wpt_block_core = 1'b1;

        if (core_one_txn_pend_n) begin
          state_n = WPT_MATCH_RESP;
        end
      end
      WPT_MATCH_RESP: begin

        // Keep blocking new transfers
        wpt_block_bus  = 1'b1;
        wpt_block_core = 1'b1;

        // Set up WPT response towards the core
        wpt_trans_valid = 1'b1;
        wpt_match       = 1'b1;

        // Go back to IDLE uncoditionally.
        // The core is expected to always be ready for the response
        state_n = WPT_IDLE;

      end
      default: ;
    endcase
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      state_q     <= WPT_IDLE;
    end
    else begin
      state_q <= state_n;
    end
  end

  // Forward transaction request towards MPU
  assign mpu_trans_valid_o   = core_trans_valid_i && !wpt_block_bus;
  assign mpu_trans_o         = core_trans_i;
  assign mpu_trans_pushpop_o = core_trans_pushpop_i;


  // Forward transaction response towards core
  assign core_resp_valid_o        = mpu_resp_valid_i || wpt_trans_valid;
  assign core_resp_o.bus_resp     = mpu_resp_i.bus_resp;
  assign core_resp_o.mpu_status   = mpu_resp_i.mpu_status;
  assign core_resp_o.align_status = mpu_resp_i.align_status;
  assign core_resp_o.wpt_match    = wpt_match;


  // Report WPT matches to the core immediately
  assign core_wpt_match_o = trigger_match_i;

  // Signal ready towards core
  assign core_trans_ready_o = (mpu_trans_ready_i && !wpt_block_core) || wpt_trans_ready;



endmodule
