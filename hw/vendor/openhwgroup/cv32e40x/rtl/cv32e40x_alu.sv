// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////
// Engineer:       Matthias Baer - baermatt@student.ethz.ch                   //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                 Arjan Bink - arjan.bink@silabs.com                         //
//                 Kristine D�svik  - kristine.dosvik@silabs.com              //
//                                                                            //
// Design Name:    ALU                                                        //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Arithmetic logic unit of the pipelined processor           //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////
// Shifter based on https://github.com/riscv/riscv-bitmanip/blob/main-history///
// verilog/rvb_shifter/rvb_shifter.v                                          //
//                                                                            //
// Copyright (C) 2019  Claire Wolf <claire@symbioticeda.com>                  //
//                                                                            //
// Permission to use, copy, modify, and/or distribute this software for any   //
// purpose with or without fee is hereby granted, provided that the above     //
// copyright notice and this permission notice appear in all copies.          //
//                                                                            //
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES   //
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF           //
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR    //
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES     //
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN      //
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF    //
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.             //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_alu import cv32e40x_pkg::*;
#(
  parameter b_ext_e B_EXT  = B_NONE
)
(
  input  alu_opcode_e       operator_i,
  input  logic [31:0]       operand_a_i,
  input  logic [31:0]       operand_b_i,
  input  logic [31:0]       muldiv_operand_b_i,

  output logic [31:0]       result_o,
  output logic              cmp_result_o,

  // Divider interface towards CLZ
  input logic               div_clz_en_i,
  input logic [31:0]        div_clz_data_rev_i,
  output logic [5:0]        div_clz_result_o,

  // Divider interface towards shifter
  input logic               div_shift_en_i,
  input logic [5:0]         div_shift_amt_i,
  output logic [31:0]       div_op_b_shifted_o
);

  logic [31:0] operand_a_rev;
  logic [31:0] operand_b_rev;

  // Reverse operands
  assign operand_a_rev = {<<{operand_a_i}};
  assign operand_b_rev = {<<{operand_b_i}};

  ////////////////////////////////////
  //     _       _     _            //
  //    / \   __| | __| | ___ _ __  //
  //   / _ \ / _` |/ _` |/ _ \ '__| //
  //  / ___ \ (_| | (_| |  __/ |    //
  // /_/   \_\__,_|\__,_|\___|_|    //
  //                                //
  ////////////////////////////////////

  // Adder is used for:
  //
  // - ALU_ADD, ALU_SUB
  //
  // Currently not used for ALU_B_SH1ADD, ALU_B_SH2ADD, ALU_B_SH3ADD

  logic [32:0] adder_in_a, adder_in_b;
  logic [31:0] adder_result;
  logic [33:0] adder_result_expanded;
  logic        adder_subtract;

  assign adder_subtract = operator_i[3];

  // Prepare carry
  assign adder_in_a = {operand_a_i,                                 1'b1          };
  assign adder_in_b = {adder_subtract ? ~operand_b_i : operand_b_i, adder_subtract};

  // Actual adder
  assign adder_result_expanded = $unsigned(adder_in_a) + $unsigned(adder_in_b);
  assign adder_result = adder_result_expanded[32:1];

  ////////////////////////////////////////
  //  ____  _   _ ___ _____ _____       //
  // / ___|| | | |_ _|  ___|_   _|      //
  // \___ \| |_| || || |_    | |        //
  //  ___) |  _  || ||  _|   | |        //
  // |____/|_| |_|___|_|     |_|        //
  //                                    //
  ////////////////////////////////////////

  // Shifter is used for:
  //
  // - ALU_SLL, ALU_SRA, ALU_SRL
  // - ALU_B_ROL, ALU_B_ROR
  // - ALU_B_BEXT, ALU_B_BSET, ALU_B_BCLR, ALU_B_BINV
  //
  // - DIV_DIVU, DIV_DIVU, DIV_REM, DIV_REMU

  logic [5:0]  shifter_shamt;           // Shift amount
  logic        shifter_rshift;          // Shift right
  logic [31:0] shifter_aa, shifter_bb;
  logic [63:0] shifter_tmp;
  logic [31:0] shifter_result;

  assign shifter_rshift = operator_i[2];

  always_comb begin
    if (div_shift_en_i) begin
      shifter_shamt =  {1'b0, div_shift_amt_i[4:0]};    // DIV(U), REM(U) always use shift left
    end else if (shifter_rshift) begin
      shifter_shamt = -{1'b0, operand_b_i[4:0]};
    end else begin
      shifter_shamt =  {1'b0, operand_b_i[4:0]};
    end
  end

  always_comb begin
    // Defaults (ALU_SLL, ALU_SRL, ALU_B_BEXT, DIV_DIVU, DIV_DIVU, DIV_REM, DIV_REMU)
    shifter_aa = div_shift_en_i ? muldiv_operand_b_i : operand_a_i;
    shifter_bb = 32'h0;

    unique case (operator_i)
      ALU_SRA : begin
        shifter_bb = {32{operand_a_i[31]}};
      end
      ALU_B_ROL,
      ALU_B_ROR : begin
        shifter_bb = operand_a_i;
      end
      ALU_B_BSET,
      ALU_B_BCLR,
      ALU_B_BINV : begin
        shifter_aa = 32'h1;
      end
      default: ;
    endcase
  end

  always_comb begin
    shifter_tmp = {shifter_bb, shifter_aa};
    shifter_tmp = shifter_shamt[5] ? {shifter_tmp[31:0], shifter_tmp[63:32]} : shifter_tmp;
    shifter_tmp = shifter_shamt[4] ? {shifter_tmp[47:0], shifter_tmp[63:48]} : shifter_tmp;
    shifter_tmp = shifter_shamt[3] ? {shifter_tmp[55:0], shifter_tmp[63:56]} : shifter_tmp;
    shifter_tmp = shifter_shamt[2] ? {shifter_tmp[59:0], shifter_tmp[63:60]} : shifter_tmp;
    shifter_tmp = shifter_shamt[1] ? {shifter_tmp[61:0], shifter_tmp[63:62]} : shifter_tmp;
    shifter_tmp = shifter_shamt[0] ? {shifter_tmp[62:0], shifter_tmp[63:63]} : shifter_tmp;
  end

  always_comb begin
    shifter_result = shifter_tmp[31:0];

    unique case (operator_i)
      ALU_B_BEXT : shifter_result =       32'h1 &  shifter_tmp[31:0];
      ALU_B_BSET : shifter_result = operand_a_i |  shifter_tmp[31:0];
      ALU_B_BCLR : shifter_result = operand_a_i & ~shifter_tmp[31:0];
      ALU_B_BINV : shifter_result = operand_a_i ^  shifter_tmp[31:0];
      default: ;
    endcase
  end

  assign div_op_b_shifted_o = shifter_tmp[31:0];

  //////////////////////////////////////////////////////////////////
  // Shift and add

  logic [31:0] result_shnadd;

  assign result_shnadd = (operand_a_i << ((operator_i == ALU_B_SH1ADD) ? 1 : (operator_i == ALU_B_SH2ADD) ? 2 : 3)) + operand_b_i;

  //////////////////////////////////////////////////////////////////
  //   ____ ___  __  __ ____   _    ____  ___ ____   ___  _   _   //
  //  / ___/ _ \|  \/  |  _ \ / \  |  _ \|_ _/ ___| / _ \| \ | |  //
  // | |  | | | | |\/| | |_) / _ \ | |_) || |\___ \| | | |  \| |  //
  // | |__| |_| | |  | |  __/ ___ \|  _ < | | ___) | |_| | |\  |  //
  //  \____\___/|_|  |_|_| /_/   \_\_| \_\___|____/ \___/|_| \_|  //
  //                                                              //
  //////////////////////////////////////////////////////////////////

  // Comparator used for:
  //
  // - ALU_EQ, ALU_NE, ALU_GE, ALU_GEU, ALU_LT, ALU_LTU
  // - ALU_SLT, ALU_SLTU
  // - ALU_B_MIN, ALU_B_MINU, ALU_B_MAX, ALU_B_MAXU

  logic is_equal;
  logic is_greater;     // Handles both signed and unsigned forms
  logic is_signed;

  assign is_signed = operator_i[3];
  assign is_equal = (operand_a_i == operand_b_i);
  assign is_greater = $signed({operand_a_i[31] & is_signed, operand_a_i}) > $signed({operand_b_i[31] & is_signed, operand_b_i});

  // Generate comparison result
  always_comb
  begin
    cmp_result_o = is_equal;
    unique case (operator_i)
      ALU_EQ          : cmp_result_o = is_equal;
      ALU_NE          : cmp_result_o = !is_equal;
      ALU_GE, ALU_GEU : cmp_result_o = is_greater || is_equal;
      ALU_LT, ALU_LTU : cmp_result_o = !(is_greater || is_equal);

      default: ;
    endcase
  end

  //////////////////////////////////////////////////////////////////
  // Min/max

  logic [31:0] min_minu_result;
  logic [31:0] max_maxu_result;

  assign min_minu_result = (!is_greater) ? operand_a_i : operand_b_i;
  assign max_maxu_result = ( is_greater) ? operand_a_i : operand_b_i;

  /////////////////////////////////////////////////////////////////////
  //   ____  _ _      ____                  _      ___               //
  //  | __ )(_) |_   / ___|___  _   _ _ __ | |_   / _ \ _ __  ___    //
  //  |  _ \| | __| | |   / _ \| | | | '_ \| __| | | | | '_ \/ __|   //
  //  | |_) | | |_  | |__| (_) | |_| | | | | |_  | |_| | |_) \__ \_  //
  //  |____/|_|\__|  \____\___/ \__,_|_| |_|\__|  \___/| .__/|___(_) //
  //                                                   |_|           //
  /////////////////////////////////////////////////////////////////////

  logic [31:0] clz_data_in;
  logic [4:0]  ff1_result; // holds the index of the first '1'
  logic        ff_no_one;  // if no ones are found
  logic [ 5:0] cpop_result_o;

  assign clz_data_in = div_clz_en_i ? div_clz_data_rev_i :
                       (operator_i == ALU_B_CTZ) ? operand_a_i : operand_a_rev;

  cv32e40x_ff_one ff_one_i
  (
    .in_i        ( clz_data_in ),
    .first_one_o ( ff1_result ),
    .no_ones_o   ( ff_no_one  )
  );

  // Divider assumes CLZ returning 32 when there are no zeros (as per CLZ spec)
  assign div_clz_result_o = ff_no_one ? 6'd32 : ff1_result;

  // CPOP
  cv32e40x_alu_b_cpop alu_b_cpop_i
    (.operand_i (operand_a_i),
     .result_o  (cpop_result_o));


  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
  //   ____                      _                 __  __       _ _   _       _ _           _   _              //
  //  / ___|__ _ _ __ _ __ _   _| | ___  ___ ___  |  \/  |_   _| | |_(_)_ __ | (_) ___ __ _| |_(_) ___  _ __   //
  // | |   / _` | '__| '__| | | | |/ _ \/ __/ __| | |\/| | | | | | __| | '_ \| | |/ __/ _` | __| |/ _ \| '_ \  //
  // | |__| (_| | |  | |  | |_| | |  __/\__ \__ \ | |  | | |_| | | |_| | |_) | | | (_| (_| | |_| | (_) | | | | //
  //  \____\__,_|_|  |_|   \__, |_|\___||___/___/ |_|  |_|\__,_|_|\__|_| .__/|_|_|\___\__,_|\__|_|\___/|_| |_| //
  //                       |___/                                       |_|                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

  logic [31:0] clmul_result;
  logic [31:0] clmulr_result;
  logic [31:0] clmulh_result;

  generate
    if (B_EXT == ZBA_ZBB_ZBC_ZBS) begin: clmul

      logic [31:0] clmul_op_a;
      logic [31:0] clmul_op_b;

      assign clmul_op_a = (operator_i != ALU_B_CLMUL) ? operand_a_rev : operand_a_i;
      assign clmul_op_b = (operator_i != ALU_B_CLMUL) ? operand_b_rev : operand_b_i;

      always_comb begin
        clmul_result ='0;
        for (integer i = 0; i < 32; i++) begin
          for (integer j = 0; j < i+1; j++) begin
            clmul_result[i] = clmul_result[i] ^ (clmul_op_a[i-j] & clmul_op_b[j]);
          end
        end
      end

      assign clmulr_result = {<<{clmul_result}}; // Reverse for clmulr
      assign clmulh_result = {1'b0, clmulr_result[31:1]};

    end else begin: no_clmul

      assign clmul_result  = 32'h0;
      assign clmulr_result = 32'h0;
      assign clmulh_result = 32'h0;

    end
  endgenerate

  ////////////////////////////////////////////////////////
  //   ____                 _ _     __  __              //
  //  |  _ \ ___  ___ _   _| | |_  |  \/  |_   ___  __  //
  //  | |_) / _ \/ __| | | | | __| | |\/| | | | \ \/ /  //
  //  |  _ <  __/\__ \ |_| | | |_  | |  | | |_| |>  <   //
  //  |_| \_\___||___/\__,_|_|\__| |_|  |_|\__,_/_/\_\  //
  //                                                    //
  ////////////////////////////////////////////////////////

  always_comb
  begin
    result_o = 32'h0;

    // RV32I
    unique case (operator_i)
      // Bitwise operators
      ALU_AND    : result_o = operand_a_i &  operand_b_i;
      ALU_OR     : result_o = operand_a_i |  operand_b_i;
      ALU_XOR    : result_o = operand_a_i ^  operand_b_i;
      ALU_B_ANDN : result_o = operand_a_i & ~operand_b_i;
      ALU_B_ORN  : result_o = operand_a_i | ~operand_b_i;
      ALU_B_XNOR : result_o = operand_a_i ^ ~operand_b_i;

      // Adder Operations
      ALU_ADD,
      ALU_SUB : result_o = adder_result;

      // Shift Operations
      ALU_SLL,
      ALU_SRL,
      ALU_SRA,
      ALU_B_ROL,
      ALU_B_ROR,
      ALU_B_BSET,
      ALU_B_BCLR,
      ALU_B_BINV,
      ALU_B_BEXT   : result_o = shifter_result;

      // Comparisons
      ALU_SLT, ALU_SLTU: result_o = {31'b0, !(is_greater || is_equal)};

      // Shift and add
      ALU_B_SH1ADD,
      ALU_B_SH2ADD,
      ALU_B_SH3ADD : result_o = result_shnadd;

      ALU_B_CLZ,
      ALU_B_CTZ    : result_o = {26'h0, div_clz_result_o};
      ALU_B_CPOP   : result_o = {26'h0, cpop_result_o};


      ALU_B_MIN,
      ALU_B_MINU   : result_o = min_minu_result;
      ALU_B_MAX,
      ALU_B_MAXU   : result_o = max_maxu_result;

      ALU_B_ORC_B  : result_o = {{(8){|operand_a_i[31:24]}}, {(8){|operand_a_i[23:16]}}, {(8){|operand_a_i[15:8]}}, {(8){|operand_a_i[7:0]}}};

      ALU_B_REV8   : result_o = {operand_a_i[7:0], operand_a_i[15:8], operand_a_i[23:16], operand_a_i[31:24]};

      ALU_B_SEXT_B : result_o = {{(24){operand_a_i[ 7]}}, operand_a_i[ 7:0]};
      ALU_B_SEXT_H : result_o = {{(16){operand_a_i[15]}}, operand_a_i[15:0]};

      ALU_B_ZEXT_H : result_o = {16'h0000, operand_a_i[15:0]};

      ALU_B_CLMUL  : result_o = clmul_result;
      ALU_B_CLMULH : result_o = clmulh_result;
      ALU_B_CLMULR : result_o = clmulr_result;

      default: ;
    endcase

  end

endmodule
