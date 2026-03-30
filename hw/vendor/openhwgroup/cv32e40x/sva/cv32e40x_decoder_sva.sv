// Copyright 2021 Silicon Labs, Inc.
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
// Authors:        Oivind Ekelund - oivind.ekelund@silabs.com                 //
//                                                                            //
// Description:    RTL assertions decoder module                              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_decoder_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
#(
  parameter a_ext_e A_EXT     = A_NONE,
  parameter bit     CLIC      = 0
)
(
  input logic           clk,
  input logic           rst_n,
  input decoder_ctrl_t  decoder_m_ctrl,
  input decoder_ctrl_t  decoder_a_ctrl,
  input decoder_ctrl_t  decoder_i_ctrl,
  input decoder_ctrl_t  decoder_b_ctrl,
  input decoder_ctrl_t  decoder_ctrl_mux,
  input logic [31:0]    instr_rdata,
  input if_id_pipe_t    if_id_pipe,
  input logic           alu_en_o,
  input logic           div_en_o,
  input logic           mul_en_o,
  input logic           csr_en_o,
  input logic           sys_en_o,
  input logic           lsu_en_o,
  input logic           illegal_insn_o
);

  // Check sub decoders have their outputs idle when there is no instruction match
  property p_idle_dec(decoder_ctrl_t dec_ctrl);
    @(posedge clk) disable iff (!rst_n)
      (dec_ctrl.illegal_insn |-> dec_ctrl == DECODER_CTRL_ILLEGAL_INSN);
  endproperty

  a_m_dec_idle : assert property(p_idle_dec(decoder_m_ctrl)) else `uvm_error("decoder", "Assertion a_m_dec_idle failed")
  a_a_dec_idle : assert property(p_idle_dec(decoder_a_ctrl)) else `uvm_error("decoder", "Assertion a_a_dec_idle failed")
  a_i_dec_idle : assert property(p_idle_dec(decoder_i_ctrl)) else `uvm_error("decoder", "Assertion a_i_dec_idle failed")
  a_b_dec_idle : assert property(p_idle_dec(decoder_b_ctrl)) else `uvm_error("decoder", "Assertion a_b_dec_idle failed")

  // Check that the two LSB of the incoming instructions word is always 2'b11
  // Predecoder should always emit uncompressed instructions
  // Exclude CLIC and mret pointers
  property p_uncompressed_lsb;
    @(posedge clk) disable iff(!rst_n)
      !(if_id_pipe.instr_meta.clic_ptr || if_id_pipe.instr_meta.mret_ptr) |-> (instr_rdata[1:0] == 2'b11);
  endproperty

  a_uncompressed_lsb: assert property(p_uncompressed_lsb) else `uvm_error("decoder", "2 LSBs not 2'b11")

  generate
    if (A_EXT == A_NONE) begin : gen_no_a_extension_assertions
      // Check that A extension opcodes are decoded as illegal when A extension not enabled
      a_illegal_0 :
        assert property (@(posedge clk) disable iff (!rst_n)
          (instr_rdata[6:0] == OPCODE_AMO) |-> (decoder_ctrl_mux.illegal_insn == 'b1))
        else `uvm_error("decoder", "All atomic instructions should be illegal")
    end

    if (A_EXT == ZALRSC) begin : gen_no_a_ext_amo_assertions
      // Check that A extension AMO opcodes are decoded as illegal when A extension not enabled
      a_illegal_0 :
        assert property (@(posedge clk) disable iff (!rst_n)
          (instr_rdata[6:0] == OPCODE_AMO) &&
          (instr_rdata[31:27] inside {AMO_SWAP, AMO_ADD, AMO_XOR, AMO_AND, AMO_OR, AMO_MIN, AMO_MAX, AMO_MINU, AMO_MAXU})
          |-> (decoder_ctrl_mux.illegal_insn == 'b1))
        else `uvm_error("decoder", "AMO instruction should be illegal")
    end
  endgenerate

  // Ensure that the A operand is only used for certain functional units
  a_alu_op_a_mux_sel :
    assert property (@(posedge clk) disable iff (!rst_n)
                      (decoder_ctrl_mux.alu_op_a_mux_sel != OP_A_NONE)
                      |-> (
                      (
                        decoder_ctrl_mux.alu_en || decoder_ctrl_mux.div_en ||
                        decoder_ctrl_mux.csr_en || decoder_ctrl_mux.lsu_en
                      ) && !(decoder_ctrl_mux.mul_en || decoder_ctrl_mux.sys_en))
                    )
      else `uvm_error("decoder", "Unexpected A operand usage")

  // Ensure that the B operand is only used for certain functional units
  a_alu_op_b_mux_sel :
    assert property (@(posedge clk) disable iff (!rst_n)
                      (decoder_ctrl_mux.alu_op_b_mux_sel != OP_B_NONE)
                      |-> (
                      (
                        decoder_ctrl_mux.alu_en || decoder_ctrl_mux.div_en ||
                        decoder_ctrl_mux.csr_en || decoder_ctrl_mux.lsu_en
                      ) && !(decoder_ctrl_mux.mul_en || decoder_ctrl_mux.sys_en))
                    )
      else `uvm_error("decoder", "Unexpected B operand usage")

  // Ensure that the C operand is only used for certain functional units
  a_op_c_mux_sel :
    assert property (@(posedge clk) disable iff (!rst_n)
                      (decoder_ctrl_mux.op_c_mux_sel != OP_C_NONE)
                      |-> ((decoder_ctrl_mux.alu_en || (decoder_ctrl_mux.lsu_en && decoder_ctrl_mux.lsu_we))))
      else `uvm_error("decoder", "Unexpected C operand usage")

  // Ensure that functional unit enables are one-hot (including illegal) when no pointer is in the ID stage
  a_functional_unit_enable_onehot_noptr :
    assert property (@(posedge clk) disable iff (!rst_n)
                     !(if_id_pipe.instr_meta.clic_ptr || if_id_pipe.instr_meta.mret_ptr)
                     |->
                     $onehot({decoder_ctrl_mux.alu_en, decoder_ctrl_mux.div_en, decoder_ctrl_mux.mul_en,
                              decoder_ctrl_mux.csr_en, decoder_ctrl_mux.sys_en, decoder_ctrl_mux.lsu_en,
                              decoder_ctrl_mux.illegal_insn}))
      else `uvm_error("decoder", "Multiple functional units enabled")

  if (CLIC) begin
    // Check that all functional units are disabled when a pointer is in the ID stage
    a_functional_unit_disable_ptr :
      assert property (@(posedge clk) disable iff (!rst_n)
                        (if_id_pipe.instr_meta.clic_ptr || if_id_pipe.instr_meta.mret_ptr)
                        |->
                        !(|{alu_en_o, div_en_o, mul_en_o,
                          csr_en_o, sys_en_o, lsu_en_o,
                          illegal_insn_o}))
        else `uvm_error("decoder", "Functional units enable when a pointer is in the ID stage")
  end

  // Check that branch/jump related signals can be used from I decoder directly (bypassing other decoders)
  a_branch_jump_decode :
    assert property (@(posedge clk) disable iff (!rst_n)
      1'b1 |-> (
                (decoder_i_ctrl.alu_bch == decoder_ctrl_mux.alu_bch) &&
                (decoder_i_ctrl.bch_jmp_mux_sel == decoder_ctrl_mux.bch_jmp_mux_sel) &&
                (decoder_i_ctrl.alu_jmp == decoder_ctrl_mux.alu_jmp) &&
                (decoder_i_ctrl.alu_jmpr == decoder_ctrl_mux.alu_jmpr)))
    else `uvm_error("decoder", "Branch/jump related signals driven from unexpected decoder")

  // Check that CSR related signals can be used from I decoder directly (bypassing other decoders)
  a_csr_decode :
    assert property (@(posedge clk) disable iff (!rst_n)
      1'b1 |-> (
                (decoder_i_ctrl.csr_en == decoder_ctrl_mux.csr_en) &&
                (decoder_i_ctrl.csr_op == decoder_ctrl_mux.csr_op)))
    else `uvm_error("decoder", "CSR related signals driven from unexpected decoder")

  // Check that SYS related signals can be used from I decoder directly (bypassing other decoders)
  a_sys_decode :
    assert property (@(posedge clk) disable iff (!rst_n)
      1'b1 |-> (
                (decoder_i_ctrl.sys_en == decoder_ctrl_mux.sys_en) &&
                (decoder_i_ctrl.sys_mret_insn == decoder_ctrl_mux.sys_mret_insn) &&
                (decoder_i_ctrl.sys_dret_insn == decoder_ctrl_mux.sys_dret_insn) &&
                (decoder_i_ctrl.sys_ebrk_insn == decoder_ctrl_mux.sys_ebrk_insn) &&
                (decoder_i_ctrl.sys_ecall_insn == decoder_ctrl_mux.sys_ecall_insn) &&
                (decoder_i_ctrl.sys_wfi_insn == decoder_ctrl_mux.sys_wfi_insn) &&
                (decoder_i_ctrl.sys_wfe_insn == decoder_ctrl_mux.sys_wfe_insn) &&
                (decoder_i_ctrl.sys_fencei_insn == decoder_ctrl_mux.sys_fencei_insn)))
    else `uvm_error("decoder", "SYS related signals driven from unexpected decoder")


  // Check that MUL/DIV related signals can be used from M decoder directly (bypassing other decoders)
  a_muldiv_decode :
    assert property (@(posedge clk) disable iff (!rst_n)
      1'b1 |-> (
                (decoder_m_ctrl.mul_en == decoder_ctrl_mux.mul_en) &&
                (decoder_m_ctrl.mul_operator == decoder_ctrl_mux.mul_operator) &&
                (decoder_m_ctrl.mul_signed_mode == decoder_ctrl_mux.mul_signed_mode) &&
                (decoder_m_ctrl.div_en == decoder_ctrl_mux.div_en) &&
                (decoder_m_ctrl.div_operator == decoder_ctrl_mux.div_operator)))
    else `uvm_error("decoder", "Mul/div related signals driven from unexpected decoder")

  // Check that ATOP related signals can be used from A decoder directly (bypassing other decoders)
  a_atop_decode :
    assert property (@(posedge clk) disable iff (!rst_n)
      1'b1 |-> (
                (decoder_a_ctrl.lsu_atop == decoder_ctrl_mux.lsu_atop)))
    else `uvm_error("decoder", "Atop related signals driven from unexpected decoder")

endmodule : cv32e40x_decoder_sva
