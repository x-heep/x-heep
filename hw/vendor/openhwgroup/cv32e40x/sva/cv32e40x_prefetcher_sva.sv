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
// Design Name:    Prefetcher Controller SVA                                  //
// Project Name:   CV32E40P                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    SV Properties, Assertions, etc, for the CV32E40P           //
//                 Prefetch Controller.                                       //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_prefetcher_sva import cv32e40x_pkg::*;
#(
    parameter bit CLIC = 1'b0
)
(
  input  logic        clk,
  input  logic        rst_n,

  // Fetch stage interface
  input  logic        fetch_branch_i,                 // Taken branch
  input  logic [31:0] fetch_branch_addr_i,            // Taken branch address (only valid when branch_i = 1)

  // Transaction request interface
  input  logic        trans_valid_o,            // Transaction request valid (to bus interface adapter)
  input  logic        trans_ready_i,            // Transaction request ready (transaction gets accepted when trans_valid_o and trans_ready_i are both 1)
  input  logic [31:0] trans_addr_o,             // Transaction address (only valid when trans_valid_o = 1). No stability requirements.

  input  logic        trans_ptr_access_q,

  // Fetch interface is ready/valid
  input  logic        fetch_ready_o,
  input  logic        fetch_valid_i,

  input  prefetch_state_e  state_q,
  input  logic        prefetch_is_clic_ptr


);

  import uvm_pkg::*; // needed for the UVM messaging service (`uvm_error(), etc.)

  logic [31:0] previous_addr;
  logic branch_fetch_done;
  logic first_fetch;
  always_ff @(posedge clk, negedge rst_n) begin
    if(rst_n == 1'b0) begin
      previous_addr <= 32'd0;
      branch_fetch_done <= 1'b0;
      first_fetch <= 1'b1;
    end else begin

      if(fetch_branch_i) begin
        previous_addr <= fetch_branch_addr_i;
        if(trans_valid_o && trans_ready_i) begin
          branch_fetch_done <= 1'b1;
        end else begin
          branch_fetch_done <= 1'b0;
        end
      end else begin

        if(trans_valid_o && trans_ready_i) begin
          previous_addr <= trans_addr_o;
        end
      end

      if(branch_fetch_done == 1'b0) begin
        if(trans_ready_i == 1'b1) begin
          branch_fetch_done <= 1'b1;
        end
      end

      // Clear first_fetch flag on first transaction
      if(trans_valid_o && trans_ready_i) begin
        first_fetch <= 1'b0;
      end
    end
  end

  // Check that we only assert trans_valid when fetch_valid is high
  property p_trans_valid;
     @(posedge clk) disable iff (!rst_n) (trans_valid_o) |-> (fetch_valid_i);
  endproperty

  a_trans_valid:
    assert property(p_trans_valid)
    else
      `uvm_error("Prefetcher SVA",
                 $sformatf("trans_valid_o active when fetch_valid_i is not"))

  // Check that we output branch address correctly
  property p_branch_addr;
    @(posedge clk) disable iff (!rst_n) (fetch_branch_i) |-> (trans_addr_o == fetch_branch_addr_i);
  endproperty

  a_branch_addr:
    assert property(p_branch_addr)
    else
      `uvm_error("Prefetcher SVA",
                $sformatf("branch address not propagated to trans_addr_o correctly"))

  // Check that fetch_branch_addr_i is halfword aligned
  property p_fetch_branch_addr_aligned;
    @(posedge clk) disable iff (!rst_n) (fetch_branch_addr_i[0] == 1'b0);
  endproperty

  a_fetch_branch_addr_aligned:
    assert property(p_fetch_branch_addr_aligned)
    else
      `uvm_error("Prefetcher SVA",
                $sformatf("fetch_branch_addr_i is not halfword aligned."))

  // Check that trans_addr_o is halfword aligned
  property p_trans_addr_aligned;
    @(posedge clk) disable iff (!rst_n) (trans_addr_o[0] == 1'b0);
  endproperty

  a_trans_addr_aligned:
    assert property(p_trans_addr_aligned)
    else
      `uvm_error("Prefetcher SVA",
                $sformatf("trans_addr_o is not halfword aligned."))

  // Check that we acknowledge a fetch_valid when trans_ready high
  property p_fetch_ready;
    @(posedge clk) disable iff (!rst_n) (trans_ready_i && trans_valid_o) |-> (fetch_ready_o == 1'b1);
  endproperty

  a_fetch_ready:
    assert property(p_fetch_ready)
    else
      `uvm_error("Prefetcher SVA",
                $sformatf("fetch_ready_o not set when trans_ready_i && trans_valid_o."))

  // Check that we output previous address +4 when not doing a branch
  property p_addr_incr;
    @(posedge clk) disable iff (!rst_n) (!fetch_branch_i && branch_fetch_done && state_q == IDLE) |-> (trans_addr_o == (previous_addr + 32'h4));
  endproperty

  a_addr_incr:
    assert property(p_addr_incr)
    else
      `uvm_error("Prefetcher SVA",
                $sformatf("Address increment not 4."))

  // Check first fetch after reset it always a branch
  property p_first_fetch;
    @(posedge clk) disable iff (!rst_n) (first_fetch && fetch_valid_i) |-> fetch_branch_i;
  endproperty

  a_first_fetch:
    assert property(p_first_fetch)
    else
      `uvm_error("Prefetcher SVA",
                $sformatf("First fetch after reset is not a branch"))

if (CLIC) begin
  // We cannot have a new fetch_branch when a CLIC pointer fetch is outstanding. If that happens, the core will lose track of
  // which which address to return to (mepc, dpc) as the pointer is not associated with an actual instruction.
  // For Zc pointer fetches, we can allow this (for instance debug entry or exception while the pointer is outstanding).
  //   For this case, the PC of the tablejump instruction is available in the pipeline.

  property p_data_q_no_branch;
    @(posedge clk) disable iff (!rst_n) (((state_q == BRANCH_WAIT) && trans_ptr_access_q) && prefetch_is_clic_ptr |-> !fetch_branch_i);
  endproperty

  a_p_data_q_no_branch:
    assert property(p_data_q_no_branch)
    else
      `uvm_error("Prefetcher SVA", "data_q is set on branch.")
end // CLIC
endmodule: cv32e40x_prefetcher_sva
