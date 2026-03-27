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
// Engineer        Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                                                                            //
// Additional contributions by:                                               //
//                 Matthias Baer - baermatt@student.ethz.ch                   //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    Decoder                                                    //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decoder                                                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_decoder import cv32e40x_pkg::*;
#(
  parameter rv32_e       RV32                   = RV32I,
  parameter int unsigned REGFILE_NUM_READ_PORTS = 2,
  parameter a_ext_e      A_EXT                  = A_NONE,
  parameter b_ext_e      B_EXT                  = B_NONE,
  parameter m_ext_e      M_EXT                  = M,
  parameter bit          CLIC                   = 1
)
(
  // singals running to/from controller
  input  logic          deassert_we_i,          // deassert we and special insn (exception in IF)

  output logic          sys_en_o,               // System enable
  output logic          illegal_insn_o,         // Illegal instruction encountered
  output logic          sys_ebrk_insn_o,        // Trap instruction encountered
  output logic          sys_mret_insn_o,        // Return from exception instruction encountered (M)
  output logic          sys_dret_insn_o,        // Return from debug (M)
  output logic          sys_ecall_insn_o,       // Environment call (syscall) instruction encountered
  output logic          sys_wfi_insn_o,
  output logic          sys_wfe_insn_o,
  output logic          sys_fence_insn_o,       // fence instruction
  output logic          sys_fencei_insn_o,      // fence.i instruction

  // from IF/ID pipeline
  input  if_id_pipe_t   if_id_pipe_i,

  // ALU signals
  output logic          alu_en_o,               // ALU enable
  output logic          alu_bch_o,              // ALU branch (ALU used for comparison)
  output logic          alu_jmp_o,              // ALU jump (JALR, JALR) (ALU used to compute LR)
  output logic          alu_jmpr_o,             // ALU jump register (JALR) (ALU used to compute LR)
  output alu_opcode_e   alu_operator_o,         // ALU operation selection
  output alu_op_a_mux_e alu_op_a_mux_sel_o,     // Operand a selection: reg value, PC, immediate or zero
  output alu_op_b_mux_e alu_op_b_mux_sel_o,     // Operand b selection: reg value or immediate

  // MUL related control signals
  output mul_opcode_e   mul_operator_o,         // Multiplication operation selection
  output logic          mul_en_o,               // Perform integer multiplication
  output logic [1:0]    mul_signed_mode_o,      // Multiplication in signed mode

  // DIV related control signals
  output div_opcode_e   div_operator_o,         // Division operation selection
  output logic          div_en_o,               // Perform division

  // CSR
  output logic          csr_en_o,               // CSR enable
  output logic          csr_en_raw_o,           // CSR enable without deassert
  output csr_opcode_e   csr_op_o,               // Operation to perform on CSR

  // LSU
  output logic          lsu_en_o,               // Start transaction to data memory
  output logic          lsu_we_o,               // Data memory write enable
  output logic [1:0]    lsu_size_o,             // Data size (byte, half word or word)
  output logic          lsu_sext_o,             // Sign extension on read data from data memory
  output logic [5:0]    lsu_atop_o,             // Atomic memory access

  // Register file related signals
  output logic          rf_we_o,                // Write enable for register file
  output logic [1:0]    rf_re_o,

  input rf_addr_t                           rf_raddr_i[REGFILE_NUM_READ_PORTS],
  input rf_addr_t                           rf_waddr_i,
  output logic [REGFILE_NUM_READ_PORTS-1:0] rf_illegal_raddr_o,

  // Mux selects
  output op_c_mux_e     op_c_mux_sel_o,         // Operand c selection: reg value or jump target
  output imm_a_mux_e    imm_a_mux_sel_o,        // Immediate selection for operand a
  output imm_b_mux_e    imm_b_mux_sel_o,        // Immediate selection for operand b
  output bch_jmp_mux_e  bch_jmp_mux_sel_o,      // Branch / jump target selection

  input  ctrl_fsm_t     ctrl_fsm_i,             // Control signal from controller_fsm

  // Table jump related signals
  input  logic          tbljmp_first_i          // Currently decoding first operation of a table jump
);

  // write enable/request control
  logic       rf_we;
  logic       lsu_en;

  logic       csr_en;
  logic       alu_en;
  logic       mul_en;
  logic       div_en;
  logic       sys_en;

  logic [31:0] instr_rdata;

  logic dec_i_rf_illegal_addr;
  logic dec_a_rf_illegal_addr;
  logic dec_b_rf_illegal_addr;
  logic dec_m_rf_illegal_addr;
  logic rf_illegal_waddr;

  decoder_ctrl_t decoder_i_ctrl, decoder_i_ctrl_int;
  decoder_ctrl_t decoder_m_ctrl, decoder_m_ctrl_int;
  decoder_ctrl_t decoder_a_ctrl, decoder_a_ctrl_int;
  decoder_ctrl_t decoder_b_ctrl, decoder_b_ctrl_int;
  decoder_ctrl_t decoder_ctrl_mux;

  assign instr_rdata = if_id_pipe_i.instr.bus_resp.rdata;

  // Check for illegal GPR address if using RV32E
  genvar rf_rport_idx;
  generate
    for (rf_rport_idx = 0; rf_rport_idx < REGFILE_NUM_READ_PORTS; rf_rport_idx++) begin: gen_rf_raddr_illegal
      assign rf_illegal_raddr_o[rf_rport_idx] = (RV32 == RV32I) ? 1'b0 : rf_raddr_i[rf_rport_idx][4];
    end
  endgenerate

  assign rf_illegal_waddr = (RV32 == RV32I) ? 1'b0 : rf_waddr_i[4];

  // RV32I Base instruction set decoder
  cv32e40x_i_decoder
  #(
    .CLIC             (CLIC            )
  )
  i_decoder_i
  (
    .instr_rdata_i  ( instr_rdata                    ),
    .tbljmp_i       ( if_id_pipe_i.instr_meta.tbljmp ),
    .ctrl_fsm_i     ( ctrl_fsm_i                     ),
    .decoder_ctrl_o ( decoder_i_ctrl_int             )
  );

  assign dec_i_rf_illegal_addr = (decoder_i_ctrl_int.rf_re[0] && rf_illegal_raddr_o[0]) ||
                                 (decoder_i_ctrl_int.rf_re[1] && rf_illegal_raddr_o[1]) ||
                                 (decoder_i_ctrl_int.rf_we    && rf_illegal_waddr);

  // Take illegal compressed instruction and illegal RV32E GPR address into account
  assign decoder_i_ctrl = (dec_i_rf_illegal_addr || if_id_pipe_i.illegal_c_insn) ?
                          DECODER_CTRL_ILLEGAL_INSN :
                          decoder_i_ctrl_int;

  generate
    if (A_EXT != A_NONE) begin: a_decoder
      // RV32A extension decoder
      cv32e40x_a_decoder
      #(
          .A_EXT (A_EXT)
      )
      a_decoder_i
      (
        .instr_rdata_i  ( instr_rdata        ),
        .decoder_ctrl_o ( decoder_a_ctrl_int )
      );

      assign dec_a_rf_illegal_addr = (decoder_a_ctrl_int.rf_re[0] && rf_illegal_raddr_o[0]) ||
                                     (decoder_a_ctrl_int.rf_re[1] && rf_illegal_raddr_o[1]) ||
                                     (decoder_a_ctrl_int.rf_we    && rf_illegal_waddr);

      // Take illegal compressed instruction and illegal RV32E GPR address into account
      assign decoder_a_ctrl = (dec_a_rf_illegal_addr || if_id_pipe_i.illegal_c_insn) ?
                              DECODER_CTRL_ILLEGAL_INSN :
                              decoder_a_ctrl_int;

    end else begin: no_a_decoder
      assign dec_a_rf_illegal_addr = 1'b0;
      assign decoder_a_ctrl = DECODER_CTRL_ILLEGAL_INSN;
    end

    if (B_EXT != B_NONE) begin: b_decoder
      // RV32B extension decoder
      cv32e40x_b_decoder
      #(
        .B_EXT  (B_EXT )
      )
      b_decoder_i
      (
        .instr_rdata_i      ( instr_rdata                        ),
        .decoder_ctrl_o     ( decoder_b_ctrl_int                 )
      );

      assign dec_b_rf_illegal_addr = (decoder_b_ctrl_int.rf_re[0] && rf_illegal_raddr_o[0]) ||
                                     (decoder_b_ctrl_int.rf_re[1] && rf_illegal_raddr_o[1]) ||
                                     (decoder_b_ctrl_int.rf_we    && rf_illegal_waddr);

      // Take illegal compressed instruction and illegal RV32E GPR address into account
      assign decoder_b_ctrl = (dec_b_rf_illegal_addr || if_id_pipe_i.illegal_c_insn) ?
                              DECODER_CTRL_ILLEGAL_INSN :
                              decoder_b_ctrl_int;

    end else begin: no_b_decoder
      assign dec_b_rf_illegal_addr = 1'b0;
      assign decoder_b_ctrl = DECODER_CTRL_ILLEGAL_INSN;
    end

    if (M_EXT != M_NONE) begin: m_decoder
      // RV32M extension decoder
      cv32e40x_m_decoder
        #(
          .M_EXT (M_EXT)
          )
      m_decoder_i
      (
       .instr_rdata_i  ( instr_rdata        ),
       .decoder_ctrl_o ( decoder_m_ctrl_int )
      );

      assign dec_m_rf_illegal_addr = (decoder_m_ctrl_int.rf_re[0] && rf_illegal_raddr_o[0]) ||
                                     (decoder_m_ctrl_int.rf_re[1] && rf_illegal_raddr_o[1]) ||
                                     (decoder_m_ctrl_int.rf_we    && rf_illegal_waddr);

      // Take illegal compressed instruction and illegal RV32E GPR address into account
      assign decoder_m_ctrl = (dec_m_rf_illegal_addr || if_id_pipe_i.illegal_c_insn) ?
                              DECODER_CTRL_ILLEGAL_INSN :
                              decoder_m_ctrl_int;

    end else begin: no_m_decoder
      assign dec_m_rf_illegal_addr = 1'b0;
      assign decoder_m_ctrl = DECODER_CTRL_ILLEGAL_INSN;
    end

  endgenerate

  // Mux control outputs from decoders
  always_comb
  begin
    unique case (1'b1)
      !decoder_m_ctrl.illegal_insn : decoder_ctrl_mux = decoder_m_ctrl; // M decoder got a match
      !decoder_a_ctrl.illegal_insn : decoder_ctrl_mux = decoder_a_ctrl; // A decoder got a match
      !decoder_i_ctrl.illegal_insn : decoder_ctrl_mux = decoder_i_ctrl; // I decoder got a match
      !decoder_b_ctrl.illegal_insn : decoder_ctrl_mux = decoder_b_ctrl; // B decoder got a match
      default                      : decoder_ctrl_mux = DECODER_CTRL_ILLEGAL_INSN; // No match from decoders, illegal instruction
    endcase
  end

  assign alu_en             = decoder_ctrl_mux.alu_en;
  assign alu_bch_o          = decoder_i_ctrl.alu_bch;                           // Only I decoder handles branches/jumps
  assign alu_jmp_o          = decoder_i_ctrl.alu_jmp;                           // Only I decoder handles branches/jumps
  assign alu_jmpr_o         = decoder_i_ctrl.alu_jmpr;                          // Only I decoder handles branches/jumps
  assign alu_operator_o     = decoder_ctrl_mux.alu_operator;
  assign alu_op_a_mux_sel_o = decoder_ctrl_mux.alu_op_a_mux_sel;
  assign alu_op_b_mux_sel_o = decoder_ctrl_mux.alu_op_b_mux_sel;
  assign op_c_mux_sel_o     = decoder_ctrl_mux.op_c_mux_sel;
  assign imm_a_mux_sel_o    = decoder_ctrl_mux.imm_a_mux_sel;
  assign imm_b_mux_sel_o    = decoder_ctrl_mux.imm_b_mux_sel;
  assign bch_jmp_mux_sel_o  = decoder_i_ctrl.bch_jmp_mux_sel;                   // Only I decoder handles branches/jumps
  assign mul_en             = decoder_m_ctrl.mul_en;                            // Only M decoder handles mul/div
  assign mul_operator_o     = decoder_m_ctrl.mul_operator;                      // Only M decoder handles mul/div
  assign mul_signed_mode_o  = decoder_m_ctrl.mul_signed_mode;                   // Only M decoder handles mul/div
  assign div_en             = decoder_m_ctrl.div_en;                            // Only M decoder handles mul/div
  assign div_operator_o     = decoder_m_ctrl.div_operator;                      // Only M decoder handles mul/div
  assign rf_re_o            = decoder_ctrl_mux.rf_re;
  assign rf_we              = decoder_ctrl_mux.rf_we;
  assign csr_en             = decoder_i_ctrl.csr_en;                            // Only I decoder handles CSR
  assign csr_op_o           = decoder_i_ctrl.csr_op;                            // Only I decoder handles CSR
  assign lsu_en             = decoder_ctrl_mux.lsu_en;
  assign lsu_we_o           = decoder_ctrl_mux.lsu_we;
  assign lsu_size_o         = decoder_ctrl_mux.lsu_size;
  assign lsu_sext_o         = decoder_ctrl_mux.lsu_sext;
  assign lsu_atop_o         = decoder_a_ctrl.lsu_atop;                          // Only A decoder handles atomics
  assign sys_en             = decoder_i_ctrl.sys_en;                            // Only I decoder handles SYS
  assign sys_mret_insn_o    = decoder_i_ctrl.sys_mret_insn;                     // Only I decoder handles MRET
  assign sys_dret_insn_o    = decoder_i_ctrl.sys_dret_insn;                     // Only I decoder handles DRET
  assign sys_ebrk_insn_o    = decoder_i_ctrl.sys_ebrk_insn;                     // Only I decoder handles EBREAK
  assign sys_ecall_insn_o   = decoder_i_ctrl.sys_ecall_insn;                    // Only I decoder handles ECALL
  assign sys_wfi_insn_o     = decoder_i_ctrl.sys_wfi_insn;                      // Only I decoder handles WFI
  assign sys_wfe_insn_o     = decoder_i_ctrl.sys_wfe_insn;                      // Only I decoder handles WFE
  assign sys_fence_insn_o   = decoder_i_ctrl.sys_fence_insn;                    // Only I decoder handles FENCE
  assign sys_fencei_insn_o  = decoder_i_ctrl.sys_fencei_insn;                   // Only I decoder handles FENCE.I

  // Suppress control signals
  assign alu_en_o = deassert_we_i ? 1'b0 : alu_en;
  assign sys_en_o = deassert_we_i ? 1'b0 : sys_en;
  assign mul_en_o = deassert_we_i ? 1'b0 : mul_en;
  assign div_en_o = deassert_we_i ? 1'b0 : div_en;
  assign lsu_en_o = deassert_we_i ? 1'b0 : lsu_en;

  assign csr_en_o = deassert_we_i ? 1'b0 : csr_en;

  // rf_we is deasserted with deassert_we as all other enables
  // but also for the first part of a table jump (only the last part write to the link register)
  assign rf_we_o  = (deassert_we_i || tbljmp_first_i) ? 1'b0 : rf_we;

  // Suppress special instruction/illegal instruction bits
  assign illegal_insn_o = deassert_we_i ? 1'b0 : decoder_ctrl_mux.illegal_insn;

  assign csr_en_raw_o = csr_en;

endmodule
