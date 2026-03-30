// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Authors:        Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                                                                            //
// Description:    RTL assertions for the prefetch_buffer module              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////


module cv32e40x_prefetch_unit_sva import cv32e40x_pkg::*;
  import uvm_pkg::*;
  #(
        parameter bit CLIC = 1'b0
  )
  (
   input logic        clk,
   input logic        rst_n,
   input ctrl_fsm_t   ctrl_fsm_i,
   input logic        fetch_valid,
   input logic [31:0] branch_addr_i,
   input logic        prefetch_ready_i,
   input logic        trans_valid_o,
   input logic        trans_ready_i,
   input logic        fetch_ptr_resp,
   input ctrl_state_e ctrl_fsm_cs,
   input logic        debug_req_i

  );


  // Check that branch target address is half-word aligned (RV32-C)
  property p_branch_halfword_aligned;
    @(posedge clk) (ctrl_fsm_i.pc_set) |-> (branch_addr_i[0] == 1'b0);
  endproperty

  a_branch_halfword_aligned : assert property(p_branch_halfword_aligned)
    else `uvm_error("prefetch_buffer", "Assertion a_branch_halfword_aligned failed")

  // Check that a taken branch can only occur if fetching is requested
  // Exception while in RESET state and debug_request_i is high - in that case we want to
  // do a pc_set to update the IF stage PC without actually fetching anything. This is to ensure
  // that dpc gets the correct (boot) address when going from reset to debug.
  property p_branch_implies_req;
      @(posedge clk) (ctrl_fsm_i.pc_set) && !((ctrl_fsm_cs == RESET) && debug_req_i) |-> (ctrl_fsm_i.instr_req);
    endproperty

  a_branch_implies_req : assert property(p_branch_implies_req)
    else `uvm_error("prefetch_buffer", "Assertion a_branch_implies_req failed")

if (CLIC) begin
  // Shall not fetch anything between pointer fetch and the actual instruction fetch
  // based on the pointer.
  property p_single_ptr_fetch;
    @(posedge clk) disable iff (!rst_n)
    (trans_valid_o && trans_ready_i && fetch_ptr_resp) |=> !trans_valid_o until ctrl_fsm_i.pc_set;
  endproperty

  a_single_ptr_fetch:
    assert property(p_single_ptr_fetch)
    else
      `uvm_error("Alignment buffer SVA", "Multiple fetches for CLIC/Zc pointer")
end // CLIC


endmodule // cv32e40x_prefetch_unit

