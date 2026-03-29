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
// Engineers       Oivind Ekelund    -     oivind.ekelund@silabs.com          //
//                 Halfdan Bechmann  -   halfdan.bechmann@silabs.com          //
//                                                                            //
// Design Name:    B Decoder                                                  //
// Project Name:   CV32E40X                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decoder for the RV32B extension                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_b_decoder import cv32e40x_pkg::*;
#(
  parameter b_ext_e B_EXT  = B_NONE
)
(
  // from IF/ID pipeline
  input logic [31:0] instr_rdata_i,
  output             decoder_ctrl_t decoder_ctrl_o
);

  localparam RV32B_ZBA = (B_EXT == ZBA_ZBB) || (B_EXT == ZBA_ZBB_ZBS) || (B_EXT == ZBA_ZBB_ZBC_ZBS);
  localparam RV32B_ZBB = (B_EXT == ZBA_ZBB) || (B_EXT == ZBA_ZBB_ZBS) || (B_EXT == ZBA_ZBB_ZBC_ZBS);
  localparam RV32B_ZBS = (B_EXT == ZBA_ZBB_ZBS) || (B_EXT == ZBA_ZBB_ZBC_ZBS);
  localparam RV32B_ZBC = (B_EXT == ZBA_ZBB_ZBC_ZBS);

  always_comb
  begin

    // Default assignments
    decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
    decoder_ctrl_o.illegal_insn = 1'b0;

    unique case (instr_rdata_i[6:0])

      OPCODE_OP: begin
        decoder_ctrl_o.alu_en           = 1'b1;
        decoder_ctrl_o.alu_op_a_mux_sel = OP_A_REGA_OR_FWD;
        decoder_ctrl_o.alu_op_b_mux_sel = OP_B_REGB_OR_FWD;
        decoder_ctrl_o.rf_re[0]         = 1'b1;
        decoder_ctrl_o.rf_re[1]         = 1'b1;
        decoder_ctrl_o.rf_we            = 1'b1;

        unique case ({instr_rdata_i[31:25], instr_rdata_i[14:12]})

          // Supported RV32B Zca instructions
          {7'b001_0000, 3'b010}: begin // Shift left by 1 and add (sh1add)
            if (RV32B_ZBA) begin
              decoder_ctrl_o.alu_operator = ALU_B_SH1ADD;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b001_0000, 3'b100}: begin // Shift left by 2 and add (sh2add)
            if (RV32B_ZBA) begin
              decoder_ctrl_o.alu_operator = ALU_B_SH2ADD;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b001_0000, 3'b110}: begin // Shift left by 3 and add (sh3add)
            if (RV32B_ZBA) begin
              decoder_ctrl_o.alu_operator = ALU_B_SH3ADD;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end

          // RVB Zbb
          {7'b0000101, 3'b100}: begin // Return minimum number, signed (min)
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator = ALU_B_MIN;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0000101, 3'b101}: begin // Return minimum number, unsigned (minu)
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator = ALU_B_MINU;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0000101, 3'b110}: begin // Return maximum number, signed (max)
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator = ALU_B_MAX;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0000101, 3'b111}: begin // Return maximum number, signed (maxu)
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator = ALU_B_MAXU;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end

          {7'b0100000, 3'b111}: begin // Return minimum number, signed (andn)
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator = ALU_B_ANDN;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0100000, 3'b110}: begin // Return minimum number, signed (orn)
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator = ALU_B_ORN;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0100000, 3'b100}: begin // Return minimum number, signed (xnor)
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator = ALU_B_XNOR;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0110000, 3'b001}: begin // Rotate Left (rol)
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator = ALU_B_ROL;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0110000, 3'b101}: begin // Rotate Right (ror)
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator = ALU_B_ROR;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0000100, 3'b100}: begin // Zero extend halfword (zext.h)
            // zext.h is a subset of the proposed pack instruction in Zbkb
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator     = ALU_B_ZEXT_H;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_NONE;
              decoder_ctrl_o.rf_re[1]         = 1'b0; // rs2 is not read, but field is hardcoded to x0

              if (instr_rdata_i[24:20] != 5'b00000) begin
                decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
              end
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end

          // RVB Zbc
          {7'b0000101, 3'b001}: begin // Carry-less Multiply (clmul)
            if (RV32B_ZBC) begin
              decoder_ctrl_o.alu_operator = ALU_B_CLMUL;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0000101, 3'b011}: begin // Carry-less Multiply upper bits (clmulh)
            if (RV32B_ZBC) begin
              decoder_ctrl_o.alu_operator = ALU_B_CLMULH;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0000101, 3'b010}: begin // Carry-less Multiply reversed (clmulr)
            if (RV32B_ZBC) begin
              decoder_ctrl_o.alu_operator = ALU_B_CLMULR;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end

          // RVB Zbs
          {7'b0010100, 3'b001}: begin // Set bit in rs1 at index specified by rs2 (bset)
            if (RV32B_ZBS) begin
              decoder_ctrl_o.alu_operator = ALU_B_BSET;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0100100, 3'b001}: begin // Clear bit in rs1 at index specified by rs2 (bclr)
            if (RV32B_ZBS) begin
              decoder_ctrl_o.alu_operator = ALU_B_BCLR;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0110100, 3'b001}: begin // Invert bit in rs1 at index specified by rs2 (binv)
            if (RV32B_ZBS) begin
              decoder_ctrl_o.alu_operator = ALU_B_BINV;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0100100, 3'b101}: begin // Extract bit from rs1 at index specified by rs2 (bext)
            if (RV32B_ZBS) begin
              decoder_ctrl_o.alu_operator = ALU_B_BEXT;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end

          default: begin
            // No match
            decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
          end
        endcase

      end // case: OPCODE_OP

      OPCODE_OPIMM: begin
        decoder_ctrl_o.alu_en           = 1'b1;
        decoder_ctrl_o.alu_op_a_mux_sel = OP_A_REGA_OR_FWD;
        decoder_ctrl_o.rf_re[0]         = 1'b1;
        decoder_ctrl_o.rf_re[1]         = 1'b0;
        decoder_ctrl_o.rf_we            = 1'b1;

        unique casez ({instr_rdata_i[31:25], instr_rdata_i[24:20], instr_rdata_i[14:12]})
          // RVB Zbb
          {7'b011_0000, 5'b0_0000, 3'b001} : begin
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator     = ALU_B_CLZ;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_NONE;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b011_0000, 5'b0_0001, 3'b001} : begin
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator     = ALU_B_CTZ;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_NONE;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b011_0000, 5'b0_0010, 3'b001} : begin
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator     = ALU_B_CPOP;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_NONE;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end

          {7'b001_0100, 5'b0_0111, 3'b101}: begin
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator     = ALU_B_ORC_B;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_NONE;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b011_0100, 5'b1_1000, 3'b101}: begin
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator     = ALU_B_REV8;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_NONE;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end

          {7'b011_0000, 5'b0_0100, 3'b001}: begin
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator     = ALU_B_SEXT_B;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_NONE;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b011_0000, 5'b0_0101, 3'b001}: begin
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator     = ALU_B_SEXT_H;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_NONE;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0110000, 5'b?_????, 3'b101}: begin // Rotate Right immediate (rori)
            if (RV32B_ZBB) begin
              decoder_ctrl_o.alu_operator     = ALU_B_ROR;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_IMM;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end

          // RVB Zbs immediate
          {7'b0010100, 5'b?_????, 3'b001}: begin // Set bit in rs1 at index specified by immediate (bseti)
            if (RV32B_ZBS) begin
              decoder_ctrl_o.alu_operator     = ALU_B_BSET;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_IMM;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0100100, 5'b?_????, 3'b001}: begin // Clear bit in rs1 at index specified by immediate (bclri)
            if (RV32B_ZBS) begin
              decoder_ctrl_o.alu_operator     = ALU_B_BCLR;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_IMM;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0110100, 5'b?_????, 3'b001}: begin // Invert bit in rs1 at index specified by immediate (binvi)
            if (RV32B_ZBS) begin
              decoder_ctrl_o.alu_operator     = ALU_B_BINV;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_IMM;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b0100100, 5'b?_????, 3'b101}: begin // Extract bit from rs1 at index specified by immediate (bexti)
            if (RV32B_ZBS) begin
              decoder_ctrl_o.alu_operator     = ALU_B_BEXT;
              decoder_ctrl_o.alu_op_b_mux_sel = OP_B_IMM;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end

          default: begin
            // No match
            decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
          end
        endcase
      end // case: OPCODE_OPIMM

      default: begin
        // No match
        decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
      end

    endcase // unique case (instr_rdata_i[6:0])

  end // always_comb

endmodule
