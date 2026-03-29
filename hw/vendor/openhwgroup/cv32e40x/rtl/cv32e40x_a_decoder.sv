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
// Design Name:    A Decoder                                                  //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decoder for the RV32A extension                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_a_decoder import cv32e40x_pkg::*;
  #(
      parameter a_ext_e A_EXT = A
  )
  (
   // from IF/ID pipeline
   input logic [31:0] instr_rdata_i,

   output             decoder_ctrl_t decoder_ctrl_o
   );

  localparam A_LRSC = (A_EXT == A) || (A_EXT == ZALRSC);
  localparam A_AMO  = (A_EXT == A);

  always_comb
  begin

    // Default assignments
    decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
    decoder_ctrl_o.illegal_insn = 1'b0;

    unique case (instr_rdata_i[6:0])

      OPCODE_AMO: begin
        if (instr_rdata_i[14:12] == 3'b010) begin // RV32A Extension (word)
          decoder_ctrl_o.lsu_en           = 1'b1;
          decoder_ctrl_o.rf_re[0]         = 1'b1;
          decoder_ctrl_o.rf_we            = 1'b1;
          decoder_ctrl_o.alu_op_a_mux_sel = OP_A_REGA_OR_FWD;
          decoder_ctrl_o.alu_op_b_mux_sel = OP_B_NONE;
          decoder_ctrl_o.lsu_size         = 2'b10; // All atomics are 32-bit word accesses
          decoder_ctrl_o.lsu_sext         = 1'b1;
          decoder_ctrl_o.lsu_atop         = {1'b1, instr_rdata_i[31:27]};

          unique case (instr_rdata_i[31:27])
            AMO_LR: begin
              if (A_LRSC) begin
                decoder_ctrl_o.rf_re[1]     = 1'b0;
                decoder_ctrl_o.op_c_mux_sel = OP_C_NONE;
                decoder_ctrl_o.lsu_we       = 1'b0;
                if (instr_rdata_i[24:20] != 5'b00000) begin
                  decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
                end
              end else begin
                decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
              end
            end
            AMO_SC: begin
              if (A_LRSC) begin
                decoder_ctrl_o.rf_re[1]     = 1'b1;             // Used for operand C
                decoder_ctrl_o.op_c_mux_sel = OP_C_REGB_OR_FWD; // Used for write data
                decoder_ctrl_o.lsu_we       = 1'b1;
              end else begin
                decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
              end
            end
            AMO_SWAP,
            AMO_ADD,
            AMO_XOR,
            AMO_AND,
            AMO_OR,
            AMO_MIN,
            AMO_MAX,
            AMO_MINU,
            AMO_MAXU: begin
              if (A_AMO) begin
                decoder_ctrl_o.rf_re[1]     = 1'b1;             // Used for operand C
                decoder_ctrl_o.op_c_mux_sel = OP_C_REGB_OR_FWD; // Used for write data
                decoder_ctrl_o.lsu_we       = 1'b1;
              end else begin
                decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
              end
            end
            default : begin
              decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
            end
          endcase
        end
        else begin
          // No match
          decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
        end
      end

      default: begin
        // No match
        decoder_ctrl_o = DECODER_CTRL_ILLEGAL_INSN;
      end
    endcase

  end

endmodule

