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
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
// Design Name:    Prefetcher Controller                                      //
// Project Name:   CV32E40P                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Prefetch Controller which receives control flow            //
//                 information (req_i, branch_*) from the Fetch stage         //
//                 and based on that performs transactions requests to the    //
//                 bus interface adapter instructions. Prefetching based on   //
//                 incrementing addressed is performed when no new control    //
//                 flow change is requested. New transaction requests are     //
//                 only performed if it can be guaranteed that the fetch FIFO //
//                 will not overflow (resulting in a maximum of DEPTH         //
//                 outstanding transactions.                                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_prefetcher import cv32e40x_pkg::*;
#(
    parameter bit CLIC = 1'b0
)
(
  input  logic                     clk,
  input  logic                     rst_n,

  // Interface to alignment_buffer
  input  logic                     fetch_branch_i,                // Taken branch
  input  logic [31:0]              fetch_branch_addr_i,           // Taken branch address (only valid when fetch_branch_i = 1), word aligned
  input  logic                     fetch_valid_i,
  output logic                     fetch_ready_o,
  input  logic                     fetch_ptr_access_i,            // Access is data access (CLIC) // todo: add similar for table jump
  output logic                     fetch_ptr_access_o,            // Handshake is for a pointer access (CLIC and Zc)
  input  privlvl_t                 fetch_priv_lvl_access_i,       // Priv level of access
  output privlvl_t                 fetch_priv_lvl_access_o,       // Priv level for the (fetch_valid_i && fetch_ready_o) handshake, indicating privilege level of the requested instruction.

  // Transaction request interface
  output logic                     trans_valid_o,           // Transaction request valid (to bus interface adapter)
  input  logic                     trans_ready_i,           // Transaction request ready (transaction gets accepted when trans_valid_o and trans_ready_i are both 1)
  output logic [31:0]              trans_addr_o,            // Transaction address (only valid when trans_valid_o = 1). No stability requirements.
  output logic                     trans_ptr_o              // Transaction is fetching a pointer
);


  prefetch_state_e state_q, next_state;

  // Transaction address
  logic [31:0]                   trans_addr_q, trans_addr_incr;
  logic                          trans_ptr_access_q;
  privlvl_t                      trans_priv_lvl_q;

  // Increment address (address will be made word aligned at core level)
  assign trans_addr_incr = {trans_addr_q[31:1], 1'b0} + 32'd4;

  // Transaction request generation
  // alignment_buffer will request a transaction when it needs it.
  // Alignment buffer controls number of outstanding transactions
  // and will always be ready to accept responses.
  assign trans_valid_o = fetch_valid_i;

  assign trans_ptr_o = fetch_ptr_access_o;

  assign fetch_ready_o = trans_valid_o && trans_ready_i;

  // FSM (state_q, next_state) to control trans_addr_o
  always_comb
  begin
    next_state = state_q;
    trans_addr_o = trans_addr_q;
    fetch_ptr_access_o = trans_ptr_access_q;
    fetch_priv_lvl_access_o = trans_priv_lvl_q;

    case(state_q)
      // Default state (pass on branch target address or transaction with incremented address)
      IDLE:
      begin
        begin
          // Select branch address on branch, otherwise incremented address
          if (fetch_branch_i) begin
            trans_addr_o = fetch_branch_addr_i;
            fetch_ptr_access_o = fetch_ptr_access_i;
            fetch_priv_lvl_access_o = fetch_priv_lvl_access_i;
          end else begin
            trans_addr_o = trans_addr_incr;
            fetch_ptr_access_o = 1'b0; // No incremental pointer fetches
            fetch_priv_lvl_access_o = fetch_priv_lvl_access_i;
          end
        end
        if ((fetch_branch_i) && !(trans_valid_o && trans_ready_i)) begin
          // Taken branch, but transaction not yet accepted by bus interface adapter.
          next_state = BRANCH_WAIT;
        end
      end // case: IDLE

      BRANCH_WAIT:
      begin
        // Replay previous branch target address (trans_addr_q) or new branch address (this can
        // occur if for example an interrupt is taken right after a taken jump which did not
        // yet have its target address accepted by the bus interface adapter.
        trans_addr_o = fetch_branch_i ? fetch_branch_addr_i : trans_addr_q;
        fetch_ptr_access_o = fetch_branch_i ? fetch_ptr_access_i : trans_ptr_access_q;
        fetch_priv_lvl_access_o = fetch_branch_i ? fetch_priv_lvl_access_i : trans_priv_lvl_q;
        if (trans_valid_o && trans_ready_i) begin
          // Transaction with branch target address has been accepted. Start regular prefetch again.
          next_state = IDLE;
        end
      end // case: BRANCH_WAIT

      default:;
    endcase
  end


  //////////////////////////////////////////////////////////////////////////////
  // Registers
  //////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk, negedge rst_n)
  begin
    if(rst_n == 1'b0)
    begin
      state_q        <= IDLE;
      trans_addr_q   <= '0;
      trans_ptr_access_q <= 1'b0;
    end
    else
    begin
      state_q        <= next_state;
      if (fetch_branch_i || (trans_valid_o && trans_ready_i)) begin
        trans_addr_q <= trans_addr_o;
        trans_ptr_access_q <= fetch_ptr_access_o;
        trans_priv_lvl_q <= fetch_priv_lvl_access_o;
      end
    end
  end

endmodule
