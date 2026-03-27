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
//                 Oivind Ekelund - oivind.ekelund@silabs.com                 //
//                                                                            //
// Design Name:    M Decoder                                                  //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decoder for the RV32M extension                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_m_decoder import cv32e40x_pkg::*;
  #(
    parameter m_ext_e M_EXT = M
    )
  (
   // from IF/ID pipeline
   input logic [31:0] instr_rdata_i,
   output             decoder_ctrl_t decoder_ctrl_o
   );
  
  always_comb
  begin

    // Default assignments
    decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
    decoder_ctrl_o.illegal_insn = 1'b0;

    unique case (instr_rdata_i[6:0])
     
      OPCODE_OP: begin

        // Common signals for all MUL/DIV 
        decoder_ctrl_o.rf_we    = 1'b1;
        decoder_ctrl_o.rf_re[0] = 1'b1;
        decoder_ctrl_o.rf_re[1] = 1'b1;

        // Multiplier and divider has its own operand registers.
        // Settings will be overruled for div(u) and rem(u) which rely on ALU.
        decoder_ctrl_o.alu_op_a_mux_sel = OP_A_NONE;
        decoder_ctrl_o.alu_op_b_mux_sel = OP_B_NONE;
        decoder_ctrl_o.op_c_mux_sel     = OP_C_NONE;

        unique case ({instr_rdata_i[31:25], instr_rdata_i[14:12]})
          // supported RV32M instructions
          {7'b000_0001, 3'b000}: begin // mul
            decoder_ctrl_o.mul_en        = 1'b1;
            decoder_ctrl_o.mul_operator  = MUL_M32;
          end
          {7'b000_0001, 3'b001}: begin // mulh
            decoder_ctrl_o.mul_en           = 1'b1;
            decoder_ctrl_o.mul_signed_mode  = 2'b11;
            decoder_ctrl_o.mul_operator     = MUL_H;
          end
          {7'b000_0001, 3'b010}: begin // mulhsu
            decoder_ctrl_o.mul_en           = 1'b1;
            decoder_ctrl_o.mul_signed_mode  = 2'b01;
            decoder_ctrl_o.mul_operator     = MUL_H;
          end
          {7'b000_0001, 3'b011}: begin // mulhu
            decoder_ctrl_o.mul_en           = 1'b1;
            decoder_ctrl_o.mul_signed_mode  = 2'b00;
            decoder_ctrl_o.mul_operator     = MUL_H;
          end
          {7'b000_0001, 3'b100}: begin // div
            if (M_EXT == M) begin
              decoder_ctrl_o.div_en       = 1'b1;
              decoder_ctrl_o.div_operator = DIV_DIV;
              decoder_ctrl_o.alu_operator = ALU_SLL;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b000_0001, 3'b101}: begin // divu
            if (M_EXT == M) begin
              decoder_ctrl_o.div_en       = 1'b1;
              decoder_ctrl_o.div_operator = DIV_DIVU;
              decoder_ctrl_o.alu_operator = ALU_SLL;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b000_0001, 3'b110}: begin // rem
            if (M_EXT == M) begin
              decoder_ctrl_o.div_en       = 1'b1;
              decoder_ctrl_o.div_operator = DIV_REM;
              decoder_ctrl_o.alu_operator = ALU_SLL;
            end else begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          end
          {7'b000_0001, 3'b111}: begin // remu
            if (M_EXT == M) begin
              decoder_ctrl_o.div_en       = 1'b1;
              decoder_ctrl_o.div_operator = DIV_REMU;
              decoder_ctrl_o.alu_operator = ALU_SLL;
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
      
      default: begin
        // No match
        decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
      end
      
    endcase // unique case (instr_rdata_i[6:0])
    
  end // always_comb

endmodule
