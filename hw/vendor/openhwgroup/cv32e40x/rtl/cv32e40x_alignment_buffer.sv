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
// Engineer:       Pasquale Davide Schiavone - pschiavo@iis.ee.ethz.ch        //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@greenwaves-technologies.com            //
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Design Name:    cv32e40x_alignment_buffer                                  //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_alignment_buffer import cv32e40x_pkg::*;
#(
  parameter int unsigned ALBUF_DEPTH     = 3,
  parameter int unsigned ALBUF_CNT_WIDTH = $clog2(ALBUF_DEPTH)
)
(
  input  logic           clk,
  input  logic           rst_n,

  // Controller fsm inputs
  input  ctrl_fsm_t      ctrl_fsm_i,

  // Branch control
  input  logic [31:0]    branch_addr_i,
  output logic           prefetch_busy_o,
  output logic           one_txn_pend_n,

  // Interface to prefetcher
  output logic           fetch_valid_o,
  input  logic           fetch_ready_i,
  output logic           fetch_branch_o,
  output logic [31:0]    fetch_branch_addr_o,
  output logic           fetch_ptr_access_o,
  input  logic           fetch_ptr_access_i,
  output privlvl_t       fetch_priv_lvl_o,
  input  privlvl_t       fetch_priv_lvl_i,

  // Resp interface
  input  logic           resp_valid_i,
  input  inst_resp_t     resp_i,


  // Interface to if_stage
  output logic                       instr_valid_o,
  input  logic                       instr_ready_i,
  output inst_resp_t                 instr_instr_o,
  output logic [31:0]                instr_addr_o,
  output privlvl_t                   instr_priv_lvl_o,
  output logic                       instr_is_clic_ptr_o, // True CLIC pointer after taking a CLIC SHV interrupt
  output logic                       instr_is_mret_ptr_o, // CLIC pointer due to restarting pointer fetch during mret
  output logic                       instr_is_tbljmp_ptr_o,
  output logic [ALBUF_CNT_WIDTH-1:0] outstnd_cnt_q_o
);

  // Counter for number of instructions in the FIFO
  // ALBUF_CNT_WIDTH defines number of words
  // We must count number of instructions, thus
  // using the value without subtracting
  logic [ALBUF_CNT_WIDTH:0] instr_cnt_n, instr_cnt_q;

  // Counter for number of outstanding transactions
  logic [ALBUF_CNT_WIDTH-1:0] outstanding_cnt_n, outstanding_cnt_q;
  logic outstanding_count_up;
  logic outstanding_count_down;

  // number of complete instructions in resp_data
  logic [1:0] n_incoming_ins;

  // Indicates that we consumed one instruction last cycle
  logic pop_q;

  // Number of instructions pushed to fifo
  // special encoding 2'b11 means pop (-1 instruction)
  // Other values are unsigned
  logic [1:0] n_pushed_ins;

  // Flags to indicate aligned address and complete instructions
  // in the write side of the buffer. This is used in the tracking
  // of number of complete instructions (compressed and uncompressed)
  // in the buffer. Updated on branches and whenever we get a valid response.
  logic aligned_n, aligned_q;
  logic complete_n, complete_q;

  // Store number of responses to flush when get get a branch
  logic [1:0] n_flush_n, n_flush_q, n_flush_branch;

  // Error propagation signals for bus, mpu and alignment checker (pointers)
  logic bus_err_unaligned, bus_err;
  mpu_status_e mpu_status_unaligned, mpu_status;
  align_status_e align_status_unaligned, align_status;

  // resp_valid gated while flushing
  logic resp_valid_gated;

  // CLIC vectoring
  // Flag for signalling that results is a CLIC function pointer
  logic is_clic_ptr_q;
  logic is_mret_ptr_q;

  // Flag for table jump pointer
  logic is_tbljmp_ptr_q;
  logic ptr_fetch_accepted_q;

  assign resp_valid_gated = (n_flush_q > 0) ? 1'b0 : resp_valid_i;

  // Assume we always push all instructions to FIFO
  // We may directly consume it, but accounting for that gives
  // bad timing paths to instr_cnt_q
  assign n_pushed_ins = n_incoming_ins;

  // Request a transfer when needed, or we do a branch, iff outstanding_cnt_q is less than 2
  // Adjust instruction count with 'pop_q', which tells if we consumed an instruction
  // during the last cycle
  // For CLIC vector loads we want to stop prefetching between an accepted pointer load and
  // the next pc_set (to the target address).
  assign fetch_valid_o = (ctrl_fsm_i.instr_req )                                     &&
                         (outstanding_cnt_q < 2)                                     &&
                         !(ptr_fetch_accepted_q && !ctrl_fsm_i.pc_set)               && // No fetch until next pc_set after accepted pointer fetches
                         (((instr_cnt_q - pop_q) == 'd0)                             ||
                         ((instr_cnt_q - pop_q) == 'd1 && outstanding_cnt_q == 2'd0) ||
                         ctrl_fsm_i.pc_set);


  // Busy if we expect any responses, or we have an active fetch_valid_o
  assign prefetch_busy_o = (outstanding_cnt_q != 3'b000)|| fetch_valid_o;

  // Indicate that there will be one pending transaction in the next cycle
  assign one_txn_pend_n = outstanding_cnt_n == ALBUF_CNT_WIDTH'(1);

  // Signal aligned branch to the prefetcher
  assign fetch_branch_o = ctrl_fsm_i.pc_set;
  assign fetch_branch_addr_o = {branch_addr_i[31:1], 1'b0};

  //////////////////
  // FIFO signals //
  //////////////////
  inst_resp_t [0:ALBUF_DEPTH-1]  resp_q;
  logic [0:ALBUF_DEPTH-1]        valid_n,   valid_int,   valid_q;
  inst_resp_t resp_n;

  // Read/write pointer for FIFO
  logic [ALBUF_CNT_WIDTH-1:0] rptr, rptr_n;
  logic [ALBUF_CNT_WIDTH-1:0] rptr2;
  logic [ALBUF_CNT_WIDTH-1:0] wptr, wptr_n;

  logic             [31:0]  addr_n, addr_q, addr_incr;
  logic             [31:0]  instr, instr_unaligned;
  logic                     valid, valid_unaligned_uncompressed;

  logic                     aligned_is_compressed, unaligned_is_compressed;

  // Aligned instructions will either be fully in index 0 or incoming data
  // This also applies for the bus_error and mpu_status
  assign instr        = (valid_q[rptr]) ? resp_q[rptr].bus_resp.rdata : resp_i.bus_resp.rdata;
  assign bus_err      = (valid_q[rptr]) ? resp_q[rptr].bus_resp.err   : resp_i.bus_resp.err;
  assign mpu_status   = (valid_q[rptr]) ? resp_q[rptr].mpu_status     : resp_i.mpu_status;
  assign align_status = (valid_q[rptr]) ? resp_q[rptr].align_status   : resp_i.align_status;


  // Unaligned instructions will either be split across index 0 and 1, or index 0 and incoming data
  assign instr_unaligned = (valid_q[rptr2]) ? {resp_q[rptr2].bus_resp.rdata[15:0], instr[31:16]} : {resp_i.bus_resp.rdata[15:0], instr[31:16]};


  // Unaligned uncompressed instructions are valid if index 1 is valid (index 0 will always be valid if 1 is)
  // or if we have data in index 0 AND we get a new incoming instruction
  // All other cases are valid if we have data in q0 or we get a response
  assign valid_unaligned_uncompressed = (valid_q[rptr2] || (valid_q[rptr] && resp_valid_gated));
  assign valid = valid_q[rptr] || resp_valid_gated;

  // unaligned_is_compressed and aligned_is_compressed are only defined when valid = 1 (which implies that instr_valid_o will be 1)
  // Never flag a compressed instruction (aligned or misaligned) for pointers. Otherwise one could signal instr_valid_o twice for one pointer
  // if the pointer itself looks like two compressed instructions.
  assign unaligned_is_compressed = (instr[17:16] != 2'b11) &&
                                   !(instr_is_clic_ptr_o || instr_is_mret_ptr_o || instr_is_tbljmp_ptr_o);

  assign aligned_is_compressed   = (instr[1:0] != 2'b11) &&
                                   !(instr_is_clic_ptr_o || instr_is_mret_ptr_o || instr_is_tbljmp_ptr_o);


  // Set mpu_status, align_status and bus error for unaligned instructions
  always_comb begin
    mpu_status_unaligned = MPU_OK;
    align_status_unaligned = ALIGN_OK;
    bus_err_unaligned = 1'b0;
    // There is valid data in q1 (valid q0 is implied)
    if(valid_q[rptr2]) begin
      // Not compressed, need two sources
      if(!unaligned_is_compressed) begin
        // If any entry is not ok, we have an instr_fault
        if((resp_q[rptr2].mpu_status != MPU_OK) || (resp_q[rptr].mpu_status != MPU_OK)) begin
          mpu_status_unaligned = MPU_RE_FAULT;
        end

        if((resp_q[rptr2].align_status != ALIGN_OK) || (resp_q[rptr].align_status != ALIGN_OK)) begin
          align_status_unaligned = ALIGN_RE_ERR;
        end

        // Bus error from either entry
        bus_err_unaligned = (resp_q[rptr2].bus_resp.err || resp_q[rptr].bus_resp.err);
      end else begin
        // Compressed, use only mpu_status from q0
        mpu_status_unaligned = resp_q[rptr].mpu_status;

        align_status_unaligned = resp_q[rptr].align_status;

        // bus error from q0
        bus_err_unaligned    = resp_q[rptr].bus_resp.err;
      end
    end else begin
      // There is no data in q1, check q0
      if(valid_q[rptr]) begin
        if(!unaligned_is_compressed) begin
          // There is unaligned data in q0 and is it not compressed
          // use q0 and incoming data
          if((resp_q[rptr].mpu_status != MPU_OK) || (resp_i.mpu_status != MPU_OK)) begin
            mpu_status_unaligned = MPU_RE_FAULT;
          end

          if((resp_q[rptr].align_status != ALIGN_OK) || (resp_i.align_status != ALIGN_OK)) begin
            align_status_unaligned = ALIGN_RE_ERR;
          end

          // Bus error from q0 and resp_i
          bus_err_unaligned = (resp_q[rptr].bus_resp.err || resp_i.bus_resp.err);
        end else begin
          // There is unaligned data in q0 and it is compressed
          mpu_status_unaligned = resp_q[rptr].mpu_status;
          align_status_unaligned = resp_q[rptr].align_status;
          // Bus error from q0
          bus_err_unaligned = resp_q[rptr].bus_resp.err;
        end
      end else begin
        // There is no data in the buffer, use input
        mpu_status_unaligned   = resp_i.mpu_status;
        bus_err_unaligned      = resp_i.bus_resp.err;
        align_status_unaligned = resp_i.align_status;
      end
    end
  end


  // Output instructions to the if stage
  always_comb
  begin
    instr_instr_o.bus_resp.rdata = instr;
    instr_instr_o.bus_resp.err   = bus_err;
    instr_instr_o.mpu_status     = mpu_status;
    instr_instr_o.align_status   = align_status;
    instr_valid_o = 1'b0;

    // Invalidate output if we get killed
    if (ctrl_fsm_i.kill_if) begin
      instr_valid_o = 1'b0;
    end else if (instr_addr_o[1]) begin
      // unaligned instruction
      instr_instr_o.bus_resp.rdata = instr_unaligned;
      instr_instr_o.bus_resp.err   = bus_err_unaligned;
      instr_instr_o.mpu_status     = mpu_status_unaligned;
      instr_instr_o.align_status   = align_status_unaligned;

      if (!valid) begin
        // No instruction valid
        instr_valid_o = 1'b0;
      end else if (instr_is_clic_ptr_o || instr_is_mret_ptr_o || instr_is_tbljmp_ptr_o) begin
        // currently outputting a pointer, valid whenever the response arrives or we have
        // the pointer within index 0 of the buffer.
        instr_valid_o = valid;
      end else if (unaligned_is_compressed) begin
        // Unaligned instruction is compressed, we only need 16 upper bits from index 0
        instr_valid_o = valid;
      end else begin
        // Unaligned is not compressed, we need data from either index 0 and 1, or 0 and input
        instr_valid_o = valid_unaligned_uncompressed;
      end
    end else begin
      // aligned case, contained in index 0
      instr_valid_o = valid;
    end
  end


  //////////////////////////////////////////////////////////////////////////////
  // FIFO management
  //////////////////////////////////////////////////////////////////////////////

  always_comb
  begin
    resp_n     = resp_q[wptr];
    valid_int  = valid_q;
    wptr_n     = wptr;
    // Write response and update valid bit and write pointer
    if (resp_valid_gated) begin
      // Increase write pointer, wrap to zero if at last entry
      wptr_n   = wptr < (ALBUF_DEPTH-1) ? wptr + ALBUF_CNT_WIDTH'(1) : ALBUF_CNT_WIDTH'(0);
      // Set fifo and valid write data
      resp_n   = resp_i;
      valid_int[wptr] = 1'b1;
    end // resp_valid_gated
  end // always_comb

  // Calculate address increment
  assign addr_incr = {addr_q[31:2], 2'b00} + 32'h4;

  // Update address, read pointer and valid bits
  always_comb
  begin
    addr_n     = addr_q;
    valid_n    = valid_int;
    rptr_n     = rptr;
    // Next values for address, valid bits and read pointer
    if (addr_q[1]) begin
      // unaligned case
      // Set next address based on instr being compressed or not
      if (unaligned_is_compressed) begin
        addr_n = {addr_incr[31:2], 2'b00};
      end else begin
        addr_n = {addr_incr[31:2], 2'b10};
      end

      // Advance FIFO one step, wrap if at last entry
      rptr_n = rptr < (ALBUF_DEPTH-1) ? rptr + ALBUF_CNT_WIDTH'(1) : ALBUF_CNT_WIDTH'(0);
    end else begin
      // aligned case
      if (aligned_is_compressed) begin
        // just increase address, do not move to next entry in FIFO
        addr_n = {addr_q[31:2], 2'b10};
      end else begin
        // move to next entry in FIFO
        // Uncompressed instruction, use addr_incr without offset
        addr_n = {addr_incr[31:2], 2'b00};

        // Advance FIFO one step, wrap if at last entry
        rptr_n = rptr < (ALBUF_DEPTH-1) ? rptr + ALBUF_CNT_WIDTH'(1) : ALBUF_CNT_WIDTH'(0);
      end
    end

    // Only clear valid[rptr] if we actually emit an instruction
    if (instr_valid_o && instr_ready_i) begin
      if (addr_q[1] || (!addr_q[1] && (!aligned_is_compressed))) begin
        valid_n[rptr] = 1'b0;
      end
    end
  end

  // rptr2 will always be one higher than rptr
  assign rptr2 = (rptr < (ALBUF_DEPTH-1)) ? rptr + ALBUF_CNT_WIDTH'(1) : ALBUF_CNT_WIDTH'(0);

  // Counting instructions in FIFO
  always_comb begin
    instr_cnt_n = instr_cnt_q;
    n_flush_branch = outstanding_cnt_q;

    if(ctrl_fsm_i.kill_if) begin
      // FIFO content is invalidated when IF is killed
      instr_cnt_n = 'd0;

      if(resp_valid_i) begin
        n_flush_branch = outstanding_cnt_q - 2'd1;
      end
    end else begin
      // Update number of instructions
      // Subracting emitted instructions lags behind by 1 cycle
      // to break timing paths from instr_ready_i to instr_cnt_q;
      instr_cnt_n = instr_cnt_q + n_pushed_ins - (pop_q ? ALBUF_CNT_WIDTH'(1) : ALBUF_CNT_WIDTH'(0));
    end
  end

  // Counting number of outstanding transactions
  assign outstanding_count_up   = fetch_valid_o && fetch_ready_i;    // Increment upon accepted transfer request
  assign outstanding_count_down = resp_valid_i;                   // Decrement upon accepted transfer response

  always_comb begin
    outstanding_cnt_n = outstanding_cnt_q;
    case ({outstanding_count_up, outstanding_count_down})
      2'b00 : begin
        outstanding_cnt_n = outstanding_cnt_q;
      end
      2'b01 : begin
        outstanding_cnt_n = outstanding_cnt_q - 1'b1;
      end
      2'b10 : begin
        outstanding_cnt_n = outstanding_cnt_q + 1'b1;
      end
      2'b11 : begin
        outstanding_cnt_n = outstanding_cnt_q;
      end
      default;
    endcase
  end


  // Count number of incoming instructions in resp_data
  // This can also be done by inspecting the fifo content
  always_comb begin
    // Set default values
    aligned_n = aligned_q;
    complete_n = complete_q;
    n_incoming_ins = 2'd0;

    // On a branch we need to know if it is aligned or not
    // the complete flag will be special cased for unaligned branches
    // as aligned=0 and complete=1 can only happen in that case
    if(ctrl_fsm_i.pc_set) begin
      aligned_n = !branch_addr_i[1];
      complete_n = branch_addr_i[1];
    end else begin
      // Valid response
      if(resp_valid_gated) begin
        // We are on an aligned address
        if(aligned_q) begin
          // uncompressed in rdata
          if(resp_i.bus_resp.rdata[1:0] == 2'b11) begin
            n_incoming_ins = 2'd1;
            // Still aligned and complete, no need to update
          end else begin
            // compressed in lower part, check next halfword
            if(resp_i.bus_resp.rdata[17:16] == 2'b11) begin
              // Upper half is uncompressed, not complete
              // 1 complete insn
              n_incoming_ins = 2'd1;
              // Not aligned nor complete, as upper 16 bits are uncompressed
              aligned_n = 1'b0;
              complete_n = 1'b0;
            end else begin
              // Another compressed in upper half
              // two complete insn in word, still aligned and complete
              n_incoming_ins = 2'd2;
              aligned_n = 1'b1;
              complete_n = 1'b1;
            end
          end
        // We are on ann unaligned address
        end else begin
          // Unaligned and complete_q==1 can only happen
          // for unaligned branches, signalling that lower
          // 16 bits can be discarded
          if(complete_q) begin
            // Uncompressed unaligned
            if(resp_i.bus_resp.rdata[17:16] == 2'b11) begin
              // No complete ins in data
              n_incoming_ins = 2'd0;
              // Still unaligned
              aligned_n = 1'b0;
              // Not a complete instruction
              complete_n = 1'b0;
            end else begin
              // Compressed unaligned
              // We have one insn in upper 16 bits
              n_incoming_ins = 2'd1;
              // We become aligned
              aligned_n = 1'b1;
              // Complete instruction
              complete_n = 1'b1;
            end
          end else begin
            // Incomplete. Check upper 16 bits for content
            // Implied that lower 16 bits contain the MSBs
            // of an uncompressed instruction
            if(resp_i.bus_resp.rdata[17:16] == 2'b11) begin
              // Upper 16 is uncompressed
              // 1 complete insn in word
              n_incoming_ins = 2'd1;
              // Unaligned and not complete
              aligned_n = 1'b0;
              complete_n = 1'b0;
            end else begin
              // Compressed unaligned
              // Two complete insn in word
              // Aligned and complete
              n_incoming_ins = 2'd2;
              aligned_n = 1'b1;
              complete_n = 1'b1;
            end // rdata[17:16]
          end // complete_q
        end // aligned_q
      end // resp_valid_gated
    end // branch
  end // comb


  // number of resps to flush
  always_comb
  begin
    // Default value
    n_flush_n = n_flush_q;

    // On a branch, the counter logic will calculate
    // the number of words to flush
    if(ctrl_fsm_i.pc_set) begin
      n_flush_n = n_flush_branch;
    end else begin
      // Decrement flush counter on valid inputs
      if(resp_valid_i && (n_flush_q > 0)) begin
        n_flush_n = n_flush_q - 2'b01;
      end
    end
  end
  //////////////////////////////////////////////////////////////////////////////
  // registers
  //////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk, negedge rst_n)
  begin
    if(rst_n == 1'b0)
    begin
      addr_q            <= '0;
      resp_q            <= INST_RESP_RESET_VAL;
      valid_q           <= '0;
      aligned_q         <= 1'b0;
      complete_q        <= 1'b0;
      n_flush_q         <= 'd0;
      instr_cnt_q       <= 'd0;
      outstanding_cnt_q <= 'd0;
      rptr              <= 'd0;
      wptr              <= 'd0;
      pop_q             <= 1'b0;
      is_clic_ptr_q     <= 1'b0;
      is_mret_ptr_q     <= 1'b0;
      is_tbljmp_ptr_q   <= 1'b0;
      ptr_fetch_accepted_q  <= 1'b0;
    end
    else
    begin
      // on a kill signal from outside we invalidate the content of the FIFO
      // completely and start from an empty state
      if (ctrl_fsm_i.kill_if) begin
        valid_q <= '0;
      end else begin
        // Update FIFO content on a valid response
        if (resp_valid_gated) begin
          resp_q[wptr] <= resp_n;
        end

        // Update valid bits on both bus resp and instruction output
        if((instr_valid_o && instr_ready_i) || resp_valid_gated) begin
          valid_q <= valid_n;
        end
      end

      // Update address and read/write pointers on a requested branch
      // Incoming pointers for CLIC and Zc may cause the pointers to get wrong values
      // We do however prevent further fetches after a pointer fetch, and the pointers
      // will be reset on the next pc_set (jump to target)
      if (ctrl_fsm_i.pc_set) begin
        addr_q  <= branch_addr_i;       // Branch target address will correspond to first instruction received after this.
        // Reset pointers on branch
        wptr <= 'd0;
        rptr <= 'd0;
        is_clic_ptr_q <= ctrl_fsm_i.pc_set_clicv && (ctrl_fsm_i.pc_mux == PC_TRAP_CLICV);
        is_mret_ptr_q <= ctrl_fsm_i.pc_set_clicv && (ctrl_fsm_i.pc_mux == PC_MRET); // Only set when an mret restarts pointer fetch. Used to manipulate first_op/last_op
        is_tbljmp_ptr_q <= ctrl_fsm_i.pc_set_tbljmp;
      end else begin
        // Update write pointer on a valid response
        if (resp_valid_gated) begin
          wptr <= wptr_n;
        end

        // Update address and read pointer when we emit an instruction
        if(instr_valid_o && instr_ready_i) begin
          addr_q <= addr_n;
          rptr   <= rptr_n;

          // Clear pointer flags when pointers are consumed.
          is_clic_ptr_q     <= 1'b0;
          is_mret_ptr_q     <= 1'b0;
          is_tbljmp_ptr_q   <= 1'b0;
        end
      end

      if(fetch_valid_o && fetch_ready_i && fetch_ptr_access_i) begin
        ptr_fetch_accepted_q <= 1'b1;
      end else begin
        if(ctrl_fsm_i.pc_set) begin
          ptr_fetch_accepted_q <= 1'b0;
        end
      end
      // Set pop-bit when instruction is emitted.
      pop_q <= (instr_valid_o && instr_ready_i);

      aligned_q <= aligned_n;
      complete_q <= complete_n;
      n_flush_q <= n_flush_n;
      instr_cnt_q <= instr_cnt_n;
      outstanding_cnt_q <= outstanding_cnt_n;
    end
  end

  // Output outstanding transaction counter to if_stage
  assign outstnd_cnt_q_o = outstanding_cnt_q;

  // Output instruction address to if_stage
  assign instr_addr_o = addr_q;

  // Signal that result is a CLIC pointer
  assign instr_is_clic_ptr_o   = is_clic_ptr_q;

  // Signal that result is an mret pointer
  assign instr_is_mret_ptr_o   = is_mret_ptr_q;

  // Signal that result is a table jump pointer
  assign instr_is_tbljmp_ptr_o = is_tbljmp_ptr_q;

  // Signal that a pointer is about to be fetched
  assign fetch_ptr_access_o = (ctrl_fsm_i.pc_set && (ctrl_fsm_i.pc_set_clicv || ctrl_fsm_i.pc_set_tbljmp));

  // Set privilege level to prefetcher
  assign fetch_priv_lvl_o = PRIV_LVL_M;

  // Set privilege level to IF stage
  assign instr_priv_lvl_o = fetch_priv_lvl_i;
endmodule
