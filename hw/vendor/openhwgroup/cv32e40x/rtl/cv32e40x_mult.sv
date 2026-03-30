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
// Engineer:       Matthias Baer - baermatt@student.ethz.ch                   //
//                                                                            //
// Additional contributions by:                                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                                                                            //
// Design Name:    Multiplier                                                 //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Multiplier unit.                                           //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_mult import cv32e40x_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  input  logic        valid_i,
  input  mul_opcode_e operator_i,

  // integer and short multiplier
  input  logic [ 1:0] signed_mode_i,

  input  logic [31:0] op_a_i,
  input  logic [31:0] op_b_i,

  output logic [31:0] result_o,

  output logic        ready_o,
  output logic        valid_o,
  input  logic        ready_i
);

  ///////////////////////////////////////////////////////////////
  //  ___ _  _ _____ ___ ___ ___ ___   __  __ _   _ _  _____   //
  // |_ _| \| |_   _| __/ __| __| _ \ |  \/  | | | | ||_   _|  //
  //  | || .  | | | | _| (_ | _||   / | |\/| | |_| | |__| |    //
  // |___|_|\_| |_| |___\___|___|_|_\ |_|  |_|\___/|____|_|    //
  //                                                           //
  ///////////////////////////////////////////////////////////////

  // Multiplier Operands
  logic [31:0] op_a;
  logic [31:0] op_b;
  logic [33:0] int_result;

  // MULH control signals
  logic        mulh_shift;

  // MULH State variables
  mul_state_e  mulh_state;
  mul_state_e  mulh_state_next;

  // MULH Part select operands
  logic [16:0] mulh_al;
  logic [16:0] mulh_bl;
  logic [16:0] mulh_ah;
  logic [16:0] mulh_bh;

  // MULH Operands
  logic [16:0] mulh_a;
  logic [16:0] mulh_b;

  // MULH Intermediate Results
  logic [32:0] mulh_acc;
  logic [32:0] mulh_acc_next;
  logic [32:0] mulh_acc_res;

  // Result
  logic [33:0] result;
  logic [33:0] result_shifted;

  assign mulh_al[15:0] = op_a_i[15:0];
  assign mulh_bl[15:0] = op_b_i[15:0];
  assign mulh_ah[15:0] = op_a_i[31:16];
  assign mulh_bh[15:0] = op_b_i[31:16];

  // Lower halfwords are always multiplied as unsigned
  assign mulh_al[16] = 1'b0;
  assign mulh_bl[16] = 1'b0;

  // Sign extention for the upper halfword is decided by the instuction used.
  // MULH   :   signed x signed    : signed_mode_i == 'b00
  // MULHSU :   signed x unsigned  : signed_mode_i == 'b01
  // MULHU  : unsigned x unsigned  : signed_mode_i == 'b11
  assign mulh_ah[16] = signed_mode_i[0] && op_a_i[31];
  assign mulh_bh[16] = signed_mode_i[1] && op_b_i[31];

  ////////////////
  //  MULH FSM  //
  ////////////////

  always_comb
  begin
    mulh_shift       = 1'b0;
    mulh_a           = mulh_al;
    mulh_b           = mulh_bl;
    mulh_state_next  = mulh_state;
    ready_o          = 1'b0;
    valid_o          = 1'b0;
    mulh_acc_next    = mulh_acc;

    // Case statement assumes valid_i = 1; the valid_i = 0 scenario
    // is handled after the case statement.    
    case (mulh_state)
      MUL_ALBL: begin
        if (operator_i == MUL_H) begin
          // Multicycle multiplication
          mulh_shift      = 1'b1;
          mulh_state_next = MUL_ALBH;
          mulh_acc_next   = mulh_acc_res;
        end
        else begin
          // Single cycle multiplication
          valid_o         = 1'b1;

          if (ready_i) begin
            ready_o        = 1'b1;
          end
        end
      end

      MUL_ALBH: begin
        mulh_state_next  = MUL_AHBL;
        mulh_acc_next    = mulh_acc_res;
        mulh_a           = mulh_al;
        mulh_b           = mulh_bh;
      end

      MUL_AHBL: begin
        mulh_state_next  = MUL_AHBH;
        mulh_acc_next    = mulh_acc_res;
        mulh_shift       = 1'b1;
        mulh_a           = mulh_ah;
        mulh_b           = mulh_bl;
      end

      MUL_AHBH: begin
        valid_o           = 1'b1;
        mulh_a            = mulh_ah;
        mulh_b            = mulh_bh;

        if (ready_i) begin
          ready_o         = 1'b1;
          mulh_state_next = MUL_ALBL;
          mulh_acc_next   = '0;
        end
      end
      default: ;
    endcase

    // Allow kill at any time
    if (!valid_i) begin
      mulh_state_next = MUL_ALBL;
      ready_o = 1'b1;
      valid_o = 1'b0;
      mulh_acc_next = '0;
    end
  end // always_comb

  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      mulh_acc   <=  '0;
      mulh_state <= MUL_ALBL;
    end else begin
      mulh_acc   <= mulh_acc_next;
      mulh_state <= mulh_state_next;
    end
  end

  // MULH Shift Mux
  assign result_shifted = $signed(result) >>> 16;
  assign mulh_acc_res   = mulh_shift ? result_shifted[32:0] : result[32:0];

  ///////////////////////////
  //   32-bit multiplier   //
  ///////////////////////////

  assign op_a = (operator_i == MUL_M32) ? op_a_i : {{16{mulh_a[16]}}, mulh_a[15:0]};
  assign op_b = (operator_i == MUL_M32) ? op_b_i : {{16{mulh_b[16]}}, mulh_b[15:0]};

  assign int_result = $signed(op_a) * $signed(op_b);

  ////////////////////////////////////
  //   ____                 _ _     //
  //  |  _ \ ___  ___ _   _| | |_   //
  //  | |_) / _ \/ __| | | | | __|  //
  //  |  _ <  __/\__ \ |_| | | |_   //
  //  |_| \_\___||___/\__,_|_|\__|  //
  //                                //
  ////////////////////////////////////

  // 34bit Adder - mulh_acc is always 0 for the MUL instruction
  assign result   = $signed(int_result) + $signed(mulh_acc);

  assign result_o = result[31:0];

endmodule
