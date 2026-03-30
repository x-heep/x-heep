// Copyright 2020 Silicon Labs, Inc.
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
// Engineer:       Arjan Bink - arjan.bink@silabs.com                         //
//                                                                            //
// Design Name:    OBI (Open Bus Interface)                                   //
// Project Name:   CV32E40P                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Open Bus Interface adapter. Translates transaction request //
//                 on the trans_* interface into an OBI A channel transfer.   //
//                 The OBI R channel transfer translated (i.e. passed on) as  //
//                 a transaction response on the resp_* interface.            //
//                                                                            //
//                 This adapter does not limit the number of outstanding      //
//                 OBI transactions in any way.                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_instr_obi_interface import cv32e40x_pkg::*;
(
  input  logic           clk,
  input  logic           rst_n,

  // Transaction request interface
  input  logic           trans_valid_i,
  output logic           trans_ready_o,
  input  obi_inst_req_t  trans_i,

  // Transaction response interface
  output logic           resp_valid_o,             // Note: Consumer is assumed to be 'ready' whenever resp_valid_o = 1
  output obi_inst_resp_t resp_o,

  // OBI interface
  if_c_obi.master     m_c_obi_instr_if

);

  obi_if_state_e state_q, next_state;

  //////////////////////////////////////////////////////////////////////////////
  // OBI R Channel
  //////////////////////////////////////////////////////////////////////////////

  // The OBI R channel signals are passed on directly on the transaction response
  // interface (resp_*). It is assumed that the consumer of the transaction response
  // is always receptive when resp_valid_o = 1 (otherwise a response would get dropped)

  assign resp_valid_o = m_c_obi_instr_if.s_rvalid.rvalid;
  assign resp_o       = m_c_obi_instr_if.resp_payload;
  


  //////////////////////////////////////////////////////////////////////////////
  // OBI A Channel
  //////////////////////////////////////////////////////////////////////////////

  
  // OBI A channel registers (to keep A channel stable)
  obi_inst_req_t        obi_a_req_q;

  // If the incoming transaction itself is not stable; use an FSM to make sure that
  // the OBI address phase signals are kept stable during non-granted requests.

  //////////////////////////////////////////////////////////////////////////////
  // OBI FSM
  //////////////////////////////////////////////////////////////////////////////

  // FSM (state_q, next_state) to control OBI A channel signals.

  always_comb
  begin
    next_state = state_q;

    case(state_q)

      // Default (transparent) state. Transaction requests are passed directly onto the OBI A channel.
      TRANSPARENT:
      begin
        if (m_c_obi_instr_if.s_req.req && !m_c_obi_instr_if.s_gnt.gnt) begin
          // OBI request not immediately granted. Move to REGISTERED state such that OBI address phase
          // signals can be kept stable while the transaction request (trans_*) can possibly change.
          next_state = REGISTERED;
        end
      end // case: TRANSPARENT

      // Registered state. OBI address phase signals are kept stable (driven from registers).
      REGISTERED:
      begin
        if (m_c_obi_instr_if.s_gnt.gnt) begin
          // Received grant. Move back to TRANSPARENT state such that next transaction request can be passed on.
          next_state = TRANSPARENT;
        end
      end // case: REGISTERED
      default: ;
    endcase
  end

  always_comb
  begin
    if (state_q == TRANSPARENT) begin
      m_c_obi_instr_if.s_req.req   = trans_valid_i;              // Do not limit number of outstanding transactions
      m_c_obi_instr_if.req_payload = trans_i;
    end else begin
      // state_q == REGISTERED
      m_c_obi_instr_if.s_req.req   = 1'b1;                       // Never retract request
      m_c_obi_instr_if.req_payload = obi_a_req_q;
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // Registers
  //////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk, negedge rst_n)
  begin
    if(rst_n == 1'b0)
    begin
      state_q       <= TRANSPARENT;
      obi_a_req_q   <= OBI_INST_REQ_RESET_VAL;
    end
    else
    begin
      state_q       <= next_state;
      if ((state_q == TRANSPARENT) && (next_state == REGISTERED)) begin
        // Keep OBI A channel signals stable throughout REGISTERED state
        obi_a_req_q <= m_c_obi_instr_if.req_payload;
      end
    end
  end

  // Always ready to accept a new transfer requests when previous A channel
  // transfer has been granted. Note that cv32e40x_obi_interface does not limit
  // the number of outstanding transactions in any way.
  assign trans_ready_o = (state_q == TRANSPARENT);

endmodule
