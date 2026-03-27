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
// Authors:        Pasquale Davide Schiavone - pschiavo@iis.ee.ethz.ch        //
//                 Igor Loi - igor.loi@greenwaves-technologies.com            //
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                                                                            //
// Description:    RTL assertions for the alignment_buffer module             //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_alignment_buffer_sva
  import cv32e40x_pkg::*, uvm_pkg::*;
  (
   input logic                     clk,
   input logic                     rst_n,
   input logic [0:2]               valid_q,
   input ctrl_fsm_t                ctrl_fsm_i,
   input logic [31:0]              branch_addr_i,
   input logic                     fetch_branch_o,
   input logic [31:0]              fetch_branch_addr_o,
   input logic                     fetch_valid_o,
   input logic                     fetch_ready_i,
   input logic [2:0] instr_cnt_n,
   input logic [2:0] instr_cnt_q,
   input logic                     instr_valid_o,
   input logic                     instr_ready_i,
   input logic [31:0]              instr_addr_o,
   input logic                     instr_is_clic_ptr_o,
   input logic                     instr_is_mret_ptr_o,
   input logic                     instr_is_tbljmp_ptr_o,
   input logic                     resp_valid_i,
   input logic                     resp_valid_gated,
   input logic [1:0]               outstanding_cnt_q,
   input logic [1:0]               n_flush_q,
   input inst_resp_t               resp_i,
   input logic [1:0]               wptr,
   input logic [1:0]               rptr,
   input logic [1:0]               rptr2,
   input logic                     pop_q,
   input logic                     ptr_fetch_accepted_q
   );


  logic branch_check;
  logic expect_response;
  assign expect_response = (instr_cnt_q == 'd0) && (outstanding_cnt_q == 'd1) ||
                           (instr_cnt_q == 'd0) && (outstanding_cnt_q == 'd2) ||
                           (instr_cnt_q == 'd1) && (outstanding_cnt_q == 'd1) ||
                           (instr_cnt_q == 'd2) && (outstanding_cnt_q == 'd1);



  // Capture branch address to check that the next instructions get the correct address
  logic [31:0] next_branch_addr;
  always_ff @(posedge clk, negedge rst_n) begin
    if(rst_n == 1'b0) begin
      next_branch_addr <= 32'd0;
    end else begin
      if(ctrl_fsm_i.pc_set) begin
        next_branch_addr <= branch_addr_i;
      end
    end
  end


  // Check FIFO overflow
  property p_fifo_overflow;
    @(posedge clk) disable iff (!rst_n) (resp_valid_i) |-> (valid_q[wptr] == 1'b0);
  endproperty

    a_fifo_overflow:
      assert property(p_fifo_overflow)
      else
        `uvm_error("Alignment buffer SVA",
                  $sformatf("FIFO overflow"))


  // Check that FIFO is cleared the cycle after a branch
  property p_fifo_clear;
    @(posedge clk) disable iff (!rst_n) (ctrl_fsm_i.pc_set) |=> (valid_q == 'b0);
  endproperty

    a_fifo_clear:
      assert property(p_fifo_clear)
      else
        `uvm_error("Alignment buffer SVA",
                  $sformatf("Fifo not cleared after branch"))


    // Check that FIFO is signaled empty the cycle during a branch
  property p_fifo_empty_branch;
    @(posedge clk) disable iff (!rst_n) (ctrl_fsm_i.pc_set) |-> (instr_cnt_n == 'b0);
  endproperty

    a_fifo_empty_branch:
      assert property(p_fifo_empty_branch)
      else
        `uvm_error("Alignment buffer SVA",
                  $sformatf("Fifo not empty during branch cycle"))



    // Check that instr_valid_o is zero when a branch is requested
  property p_branch_instr_valid;
    @(posedge clk) disable iff (!rst_n) (ctrl_fsm_i.pc_set) |-> (instr_valid_o == 1'b0);
  endproperty

    a_branch_instr_valid:
      assert property(p_branch_instr_valid)
      else
        `uvm_error("Alignment buffer SVA",
                  $sformatf("instr_valid_o active when branch_i=1"))


  // Check that no transactions are requested when not supposed to
  // Not including branches
  property p_trans_ok;
    @(posedge clk) disable iff (!rst_n)
    (((instr_cnt_q - pop_q) > 'd1) || ((instr_cnt_q - pop_q) == 'd0 && outstanding_cnt_q == 'd2)) &&
    !ctrl_fsm_i.pc_set
    |-> (fetch_valid_o == 1'b0);
  endproperty

    a_trans_ok:
      assert property(p_trans_ok)
      else
        `uvm_error("Alignment buffer SVA",
                  $sformatf("trans_valid_o active when not supposed to"))


    // Check that we don't get responses where not supposed to
  property p_resp_ok;
    @(posedge clk) disable iff (!rst_n) (!expect_response) |-> (resp_valid_gated == 1'b0);
  endproperty

    a_resp_ok:
      assert property(p_resp_ok)
      else
        `uvm_error("Alignment buffer SVA",
                  $sformatf("resp_valid_gated active when not supposed to"))



  // Check that we change branch_addr to prefetcher correctly
  property p_prefetcher_branch;
    @(posedge clk) disable iff (!rst_n) (ctrl_fsm_i.pc_set) |-> (fetch_branch_addr_o == {branch_addr_i[31:1], 1'b0});
  endproperty

    a_prefetcher_branch:
      assert property(p_prefetcher_branch)
      else
        `uvm_error("Alignment buffer SVA",
                  $sformatf("fetch_branch_addr_o not correctly set"))


  // Helper logic to avoid unbounded expressions in p_pc_after_branch property
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      branch_check <= 1'b0;
    end
    else begin
      if (ctrl_fsm_i.pc_set) begin
        branch_check <= 1'b1;
      end
      else if (instr_valid_o) begin
        branch_check <= 1'b0;
      end
    end
  end

  // Check that we output correct pc for the first instruction after a branch
  property p_pc_after_branch;
    @(posedge clk) disable iff (!rst_n) branch_check && instr_valid_o |-> instr_addr_o == next_branch_addr;
  endproperty

    a_pc_after_branch:
      assert property(p_pc_after_branch)
      else
        `uvm_error("Alignment buffer SVA",
                  $sformatf("Wrong PC after branch"))


  // Check that we never exceed two outstanding transactions
  property p_max_outstanding;
    @(posedge clk) disable iff (!rst_n) (outstanding_cnt_q <= 2'd2);
  endproperty

  a_max_outstanding:
    assert property(p_max_outstanding)
    else
      `uvm_error("Alignment buffer SVA",
                $sformatf("Number of outstanding transactions exceeds 2!"))

  // Check that mpu_status can only be MPU_OK or MPU_RE_FAULT
  property p_legal_mpu_status;
    @(posedge clk) disable iff (!rst_n) ((resp_i.mpu_status == MPU_OK) || (resp_i.mpu_status == MPU_RE_FAULT));
  endproperty

  a_legal_mpu_status:
    assert property(p_legal_mpu_status)
    else
      `uvm_error("Alignment buffer SVA",
                $sformatf("Illegal resp_i.mpu_status"))

  // Check that read/write pointers never exceeds max size of FIFO.
  property p_wptr_range;
    @(posedge clk) disable iff (!rst_n) (wptr < 2'd3);
  endproperty

  a_wptr_range:
    assert property(p_wptr_range)
    else
      `uvm_error("Alignment buffer SVA", "Write pointer illegal value")

  property p_rptr_range;
    @(posedge clk) disable iff (!rst_n) (rptr < 2'd3);
  endproperty

  a_rptr_range:
    assert property(p_rptr_range)
    else
      `uvm_error("Alignment buffer SVA", "Read pointer illegal value")

    property p_rptr2_range;
      @(posedge clk) disable iff (!rst_n) (rptr2 < 2'd3);
    endproperty

    a_rptr2_range:
      assert property(p_rptr2_range)
      else
        `uvm_error("Alignment buffer SVA", "Read pointer(2) illegal value")

  // Check that the alignment buffer is empty when a pointer is received.
  property p_pointer_fetch_empty;
    @(posedge clk) disable iff (!rst_n)
      ptr_fetch_accepted_q && resp_valid_i
      |->
      !(|valid_q);
  endproperty

  a_pointer_fetch_empty:
    assert property(p_pointer_fetch_empty)
    else
      `uvm_error("Alignment buffer SVA", "Buffer not empty when requested pointer arrives.")

  // Check that a pointer is only emitted once.
  // Pointers that look like two compressed instructions could cause two instr_rvalid_o's
  property p_single_pointer_valid;
    @(posedge clk) disable iff (!rst_n)
      (instr_valid_o && instr_ready_i) &&
      (instr_is_clic_ptr_o || instr_is_mret_ptr_o || instr_is_tbljmp_ptr_o)
      |=>
      !instr_valid_o until_with(ctrl_fsm_i.pc_set);
  endproperty

  a_single_pointer_valid:
    assert property(p_single_pointer_valid)
    else
      `uvm_error("Alignment buffer SVA", "Multiple instr_valid_o for one pointer")

  // Check that we signal instr_valid_o when we have no outstanding transactions or ongoing requests.
  // Unless we already signaled a valid pointer (then further fetches are blocked)
  logic ptr_flagged;
  always_ff @(posedge clk, negedge rst_n) begin
    if(rst_n == 1'b0) begin
      ptr_flagged <= 1'b0;
    end else begin
      if(ctrl_fsm_i.pc_set) begin
        ptr_flagged <= 1'b0;
      end else begin
        if (instr_valid_o && instr_ready_i && (instr_is_clic_ptr_o || instr_is_mret_ptr_o || instr_is_tbljmp_ptr_o)) begin
          ptr_flagged <= 1'b1;
        end
      end
    end
  end

  property p_no_outstanding_instr_valid;
    @(posedge clk) disable iff (!rst_n)
      ctrl_fsm_i.instr_req &&  // We are commanded to prefetch
      !(|outstanding_cnt_q) && // There are no outstanding transactions
      !fetch_valid_o           // We are not requesting anything
      |->
      instr_valid_o            // There must be a valid entry in the buffer
      or
      ptr_flagged;             // Or a pointer has already been sent out
  endproperty

a_no_outstanding_instr_valid:
  assert property(p_no_outstanding_instr_valid)
  else
    `uvm_error("Alignment buffer SVA", "No instr_valid when expected")

endmodule // cv32e40x_alignment_buffer_sva

