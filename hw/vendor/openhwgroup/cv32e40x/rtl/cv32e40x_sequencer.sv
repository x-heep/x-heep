// Copyright 2022 Silicon Labs, Inc.
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
// Engineer:       Oystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Design Name:    Sequencer                                                  //
// Project Name:   CV32E40X                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Sequencer for Zc push/pop and double move instructions     //
//                 Inherited from CV32E41P PR#24 and updated to support       //
//                 Zc spec 0.70.4.
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_sequencer import cv32e40x_pkg::*;
 #(
   parameter rv32_e    RV32 = RV32I
 )
 (
    input  logic       clk,
    input  logic       rst_n,

    input  logic [5:0] jvt_mode_i,
    input  inst_resp_t instr_i,               // Instruction from prefetch unit
    input  logic       instr_is_clic_ptr_i,   // CLIC pointer flag, instr_i does not contain an instruction
    input  logic       instr_is_mret_ptr_i,   // mret pointer flag, instr_i does not contain an instruction
    input  logic       instr_is_tbljmp_ptr_i, // Tablejump pointer flag, instr_i does not contain an instruction

    input  logic       valid_i,               // valid input from if stage
    input  logic       ready_i,               // Downstream is ready (ID stage)
    input  logic       halt_i,                // Halt, not ready for new input, no output valid. Keep state
    input  logic       kill_i,                // Kill. Ready for inputs, no output valid. Reset state

    output inst_resp_t instr_o,               // Output sequenced (32-bit) instruction
    output logic       valid_o,               // Output is valid - input is valid AND we decode a valid seq instruction
    output logic       ready_o,               // Sequencer is ready for new inputs
    output logic       seq_first_o,           // First operation is being output
    output logic       seq_last_o,            // Last operation is being output,
    output logic       seq_tbljmp_o,          // Instruction is a table jump (jt/jalt)
    output logic       seq_pushpop_o          // Instruction is a PUSH or POP
  );

  seq_t                instr_cnt_q;        // Count number of emitted uncompressed instructions
  pushpop_decode_s     decode;             // Struct holding metatdata for current decoded instruction
  seq_instr_e          seq_instr;          // Type of current decoded instruction

  logic [31:0]         instr;              // Instruction word from prefetcher
  logic [3:0]          rlist;              // rlist for push/pop*

  // Helper signals to indicate type of instruction
  logic                seq_load;
  logic                seq_store;
  logic                seq_move_a2s;
  logic                seq_move_s2a;

  // FSM state
  seq_state_e          seq_state_n;
  seq_state_e          seq_state_q;

  logic                seq_first_fsm;
  logic                seq_last_fsm;

  logic                instr_is_pointer;

  logic                ready_fsm;

  logic                dmove_legal_dest;
  logic                pushpop_legal_rlist;

  assign instr = instr_i.bus_resp.rdata;
  assign rlist = instr[7:4];

  assign instr_is_pointer = instr_is_clic_ptr_i || instr_is_mret_ptr_i || instr_is_tbljmp_ptr_i;

  // Count number of instructions emitted and set next state for FSM.
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      instr_cnt_q <= '0;
      seq_state_q <= S_IDLE;
    end else begin
      if (valid_o && ready_i) begin
        // Exclude tablejumps and tablejump pointers from increasing the counter.
        // To remain SEC clean, the prefetcher is ack'ed on a tablejump. If the tablejump
        // has a bus error or mpu error, the instruction after the tablejump may reach EX before the pipeline is killed.
        // If this next instruction is a load or store, the starting value for the stack adjustment will be wrong and the LSU
        // outputs may get affected. If one changes to not ack the prefetcher on table jumps, this exclusion can likely be removed.
        if (!seq_last_o && !seq_tbljmp_o && !instr_is_tbljmp_ptr_i) begin
          instr_cnt_q <= instr_cnt_q + 1'd1;
        end else begin
          instr_cnt_q <= '0;
        end

        seq_state_q <= seq_state_n;
      end

      if ((!valid_o && !halt_i) || kill_i) begin
        // Whenever we have no valid outputs and are not halted, reset counter to 0.
        // In case both halt_i and kill_i are high, kill_i takes precedence.
        // Not resetting if halted, as we might have to continue the sequence after being unhalted.
        instr_cnt_q <= '0;
        seq_state_q <= seq_state_n;
      end
    end
  end // always_ff

  ///////////////////////////////////
  // Decode sequenced instructions //
  ///////////////////////////////////

  // rlist values 0 to 3 are reserved for a future EABI variant called cm.popret.e
  // For RV32E, S2-S11 are not present (i.e. rlist must be < 7)
  assign pushpop_legal_rlist = (RV32 == RV32I) ? (rlist > 4'h3) :
                               (rlist < 4'h7) && (rlist > 4'h3);

  // rs1 must be different from rs2
  // For RV32E, S2-S11 are not present
  assign dmove_legal_dest = (RV32 == RV32I) ? (instr[9:7] != instr[4:2]) :
                            (instr[9:7] != instr[4:2]) && (instr[9:7] < 3'h2) && (instr[4:2] < 3'h2);

  always_comb
  begin
    seq_instr     = INVALID_INST;
    seq_load      = 1'b0;
    seq_store     = 1'b0;
    seq_move_a2s  = 1'b0;
    seq_move_s2a  = 1'b0;
    seq_tbljmp_o  = 1'b0;
    seq_pushpop_o = 1'b0;
    // Disregard all pointers, they do not contain instructions.
    if (!instr_is_pointer) begin
      // All sequenced instructions are within C2
      if (instr[1:0] == 2'b10) begin
        if (instr[15:13] == 3'b101) begin
          unique case (instr[12:10])
            3'b000: begin
              if (!(|jvt_mode_i)) begin
                seq_tbljmp_o = 1'b1;
                seq_instr = TBLJMP;
              end
            end

            3'b011: begin
              if (dmove_legal_dest) begin
                if (instr[6:5] == 2'b11) begin
                  // cm.mva01s
                  seq_instr = MVA01S;
                  seq_move_s2a = 1'b1;
                end else if (instr[6:5] == 2'b01) begin
                  // cm.mvsa01
                  seq_instr = MVSA01;
                  seq_move_a2s = 1'b1;
                end
              end
            end
            3'b110: begin
              if (instr[9:8] == 2'b00) begin
                // cm.push
                if (pushpop_legal_rlist) begin
                  seq_instr = PUSH;
                  seq_store = 1'b1;
                  seq_pushpop_o = 1'b1;
                end
              end else if (instr[9:8] == 2'b10) begin
                // cm.pop
                if (pushpop_legal_rlist) begin
                  seq_instr = POP;
                  seq_load = 1'b1;
                  seq_pushpop_o = 1'b1;
                end
              end
            end
            3'b111: begin
              if (instr[9:8] == 2'b00) begin
                // cm.popretz
                if (pushpop_legal_rlist) begin
                  seq_instr = POPRETZ;
                  seq_load = 1'b1;
                  seq_pushpop_o = 1'b1;
                end
              end else if (instr[9:8] == 2'b10) begin
                // cm.popret
                if (pushpop_legal_rlist) begin
                  seq_instr = POPRET;
                  seq_load = 1'b1;
                  seq_pushpop_o = 1'b1;
                end
              end
            end
            default: begin
              seq_instr = INVALID_INST;
            end
          endcase
        end // instr[15:13]
      end // C2
    end // instr_is_pointer
  end // always_comb

  // Local valid
  // In principle this is the same as "seq_en && valid_i"
  //   as the output of the above decode logic is equivalent to seq_en
  // We have valid outputs for any correctly decoded instruction, or when we are handling a tablejump pointer.
  // todo: halting IF stage would imply !valid, can this be an issue?
  assign valid_o = ((seq_instr != INVALID_INST) || instr_is_tbljmp_ptr_i) && valid_i && !halt_i && !kill_i;


  // Calculate number of S* registers needed in sequence (push/pop* only)
  assign decode.registers_saved = pushpop_reg_length(rlist);

  // Calculate stack space needed for the push/pop* registers (including ra)
  // 16-bit aligned
  assign decode.stack_adj_base = get_stack_adj_base(rlist);

  // Compute total stack adjustment based on saved registers and additional 16 byte blocks from immediate
  assign decode.total_stack_adj = decode.stack_adj_base + (instr[3:2] << 4);

  // Calculate the current stack address used for push/pop*
  always_comb begin : current_stack_adj
    case (seq_instr)
      PUSH: begin
        // Start pushing to -4(SP)
        decode.current_stack_adj = -{{instr_cnt_q+12'b1}<<2};
      end
      POP,POPRET, POPRETZ: begin
        // Need to account for any extra allocated stack space during cm.push
        // Rewind with decode.total_stack_adj and then start by popping from -4
        decode.current_stack_adj = decode.total_stack_adj-12'({instr_cnt_q+5'b1}<<2);
      end
      default:
        decode.current_stack_adj = '0;
    endcase
  end

  // Set current sreg number based on sequence counter
  assign decode.sreg = decode.registers_saved - instr_cnt_q - 4'd1;

  // Generate 32-bit instructions for all sequenced operations
  always_comb begin : sequencer_state_machine
    instr_o = instr_i;
    seq_state_n = seq_state_q;
    seq_last_fsm = 1'b0;
    // default to 1, set to zero in non-first states.
    seq_first_fsm = 1'b1;
    ready_fsm = 1'b0;

    unique case (seq_state_q)
      S_IDLE: begin
        // First instruction is output here
        if (seq_load) begin
          if (decode.registers_saved == 'd1) begin
            // Exactly one S register popped
            // lw rd, decode.current_stack_adj(SP)
            instr_o.bus_resp.rdata = {decode.current_stack_adj,REG_SP,3'b010,sn_to_regnum(decode.sreg),OPCODE_LOAD};
            // Finished loading the single Sreg, ra next
            seq_state_n = S_RA;
          end else if (decode.registers_saved > 'd1) begin
            // More than one S register popped
            // lw rd, decode.current_stack_adj(SP)
            instr_o.bus_resp.rdata = {decode.current_stack_adj,REG_SP,3'b010,sn_to_regnum(decode.sreg),OPCODE_LOAD};
            // Continue popping Sregs
            seq_state_n = S_POP;
          end else begin
            // No S register popped, pop ra
            // lw ra, decode.current_stack_adj(SP)
            instr_o.bus_resp.rdata = {decode.current_stack_adj,REG_SP,3'b010,REG_RA,OPCODE_LOAD};
            // Finished popping, stack pointer next
            seq_state_n = S_SP;
          end
        end else if (seq_store) begin
          // Current stack adjustment for the first stores are always -4
          if (decode.registers_saved == 'd1) begin
            // Exactly one S register pushed
            // sw, rs2, -4(sp)
            instr_o.bus_resp.rdata = {7'b1111111,sn_to_regnum(decode.sreg),5'd2,3'b010,5'b11100,OPCODE_STORE};
            // Finished pushing, ra next
            seq_state_n = S_RA;
          end else if (decode.registers_saved > 'd1) begin
            // More than one S register pushed
            // sw, rs2, -4(sp)
            instr_o.bus_resp.rdata = {7'b1111111,sn_to_regnum(decode.sreg),5'd2,3'b010,5'b11100,OPCODE_STORE};
            // Continue pushing
            seq_state_n = S_PUSH;
          end else begin
            // No S register pushed
            // sw, ra, -4(sp)
            instr_o.bus_resp.rdata = {7'b1111111,REG_RA,5'd2,3'b010,5'b11100,OPCODE_STORE};
            // Finished pushing, stack pointer next
            seq_state_n = S_SP;
          end
        end else if (seq_move_a2s) begin
          // addi s*, a0, 0
          instr_o.bus_resp.rdata = {12'h000, 5'd10, 3'b000, sn_to_regnum(5'(instr[9:7])), OPCODE_OPIMM};
          seq_state_n = S_DMOVE;
        end else if (seq_tbljmp_o) begin
          if (instr[9:7] == 3'b000) begin
            // cm.jt -> JAL x0, index
            instr_o.bus_resp.rdata = {15'b000000000000000, instr[6:2], 5'b00000, OPCODE_JAL};
          end else begin
            // cm.jalt -> JAL, x1, index
            instr_o.bus_resp.rdata = {12'b000000000000, instr[9:2], 5'b00001, OPCODE_JAL};
          end
          // The second half of tablejumps (pointer) will not use the FSM (the jump will kill the sequencer anyway).
          // Signalling ready here will acknowledge the prefetcher.
          ready_fsm = ready_i && !halt_i;
        end else if (seq_move_s2a) begin
          // move s to a
          // addi a0, s*, 0
          instr_o.bus_resp.rdata = {12'h000, sn_to_regnum(5'(instr[9:7])), 3'b000, 5'd10, OPCODE_OPIMM};
          seq_state_n = S_DMOVE;
        end

      end
      // todo: Any instruction output while not in S_IDLE should not combinatorially depend on instr_rdata_i
      S_PUSH: begin
        seq_first_fsm = 1'b0;
        // sw rs2, current_stack_adj(sp)
        instr_o.bus_resp.rdata = {decode.current_stack_adj[11:5],sn_to_regnum(decode.sreg),REG_SP,3'b010,decode.current_stack_adj[4:0],OPCODE_STORE};
        // Advance FSM when we have saved all s* registers
        if (instr_cnt_q == decode.registers_saved - 1) begin
          seq_state_n = S_RA;
        end
      end
      S_POP: begin
        seq_first_fsm = 1'b0;
        // lw rd, current_stack_adj(sp)
        instr_o.bus_resp.rdata = {decode.current_stack_adj,REG_SP,3'b010,sn_to_regnum(decode.sreg),OPCODE_LOAD};
        // Advance FSM when we have loaded all s* registers
        if (instr_cnt_q == decode.registers_saved - 1) begin
          seq_state_n = S_RA;
        end
      end
      S_DMOVE: begin
        seq_first_fsm = 1'b0;
        // Second half of double moves
        if (seq_move_a2s) begin
          // addi s*, a1, 0
          instr_o.bus_resp.rdata = {12'h000, 5'd11, 3'b000, sn_to_regnum(5'(instr[4:2])), OPCODE_OPIMM};
        end else begin
          // addi a1, s*, 0
          instr_o.bus_resp.rdata = {12'h000, sn_to_regnum(5'(instr[4:2])), 3'b000, 5'd11, OPCODE_OPIMM};
        end

        seq_state_n = S_IDLE;
        ready_fsm = ready_i && !halt_i;
        seq_last_fsm = 1'b1;
      end
      S_RA: begin
        seq_first_fsm = 1'b0;
        // push pop ra register
        if (seq_load) begin
          // lw ra, current_stack_adj(sp)
          instr_o.bus_resp.rdata = {decode.current_stack_adj,REG_SP,3'b010,REG_RA,OPCODE_LOAD};
        end else begin
          // sw ra, current_stack_adj(sp)
          instr_o.bus_resp.rdata = {decode.current_stack_adj[11:5],REG_RA,REG_SP,3'b010,decode.current_stack_adj[4:0],OPCODE_STORE};
        end

        seq_state_n = S_SP;
      end
      S_SP: begin
        seq_first_fsm = 1'b0;
        // Adjust stack pointer
        if (seq_load) begin
          // addi sp, sp, total_stack_adj
          instr_o.bus_resp.rdata = {decode.total_stack_adj,REG_SP,3'b0,REG_SP,OPCODE_OPIMM};
        end else begin
          // addi sp, sp, -total_stack_adj
          instr_o.bus_resp.rdata = {-decode.total_stack_adj,REG_SP,3'b0,REG_SP,OPCODE_OPIMM};
        end


        if (seq_instr == POPRETZ) begin
          seq_state_n = S_A0;
        end else if (seq_instr == POPRET) begin
          seq_state_n = S_RET;
        end else begin
          seq_state_n = S_IDLE;
          ready_fsm = ready_i && !halt_i;
          seq_last_fsm = 1'b1;
        end
      end
      S_A0: begin
        seq_first_fsm = 1'b0;
        // Clear a0 for popretz
        // addi ra, x0, 0
        instr_o.bus_resp.rdata = {12'h000,5'd0,3'b0,5'd10,OPCODE_OPIMM};

        seq_state_n = S_RET;
      end
      S_RET: begin
        seq_first_fsm = 1'b0;
        // return for popret/popretz
        // jalr x0, 0(ra)
        instr_o.bus_resp.rdata = {12'b0,REG_RA,3'b0,5'b0,OPCODE_JALR};

        seq_state_n = S_IDLE;
        ready_fsm = ready_i && !halt_i;
        seq_last_fsm = 1'b1;
      end

      default: begin
        // Should not happen
        ready_fsm = 1'b1;
        seq_state_n = S_IDLE;
      end
    endcase

    // If there is no valid output or we are killed: default to ready_fsm and set state to IDLE.
    // No reset if !valid while halted, as we may need to continue the sequence after being unhalted.
    if ((!valid_o && !halt_i) || kill_i) begin
      ready_fsm = 1'b1;
      seq_state_n = S_IDLE;
    end
  end

  // Bypass the sequencer FSM when there is an incoming tablejump pointer.
  // Tablejump pointers are the last/non-first of a sequence.
  // While waiting for a tablejump pointer, we still need to obey halt/kill inputs for the ready_o.
  assign seq_last_o  = instr_is_tbljmp_ptr_i ? 1'b1 : seq_last_fsm;
  assign seq_first_o = instr_is_tbljmp_ptr_i ? 1'b0 : seq_first_fsm;
  assign ready_o     = instr_is_tbljmp_ptr_i ? (ready_i && !halt_i) || kill_i : ready_fsm;


endmodule
