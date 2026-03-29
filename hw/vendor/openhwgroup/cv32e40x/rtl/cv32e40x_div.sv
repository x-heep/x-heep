// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

///////////////////////////////////////////////////////////////////////////////
// File       : Simple Serial Divider
// Ver        : 1.0
// Date       : 15.03.2016
///////////////////////////////////////////////////////////////////////////////
//
// Description: this is a simple serial divider for signed integers (int32).
//              Dividend = Quotient * Divisor + Remainder
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Michael Schaffner (schaffner@iis.ee.ethz.ch)
//              Andreas Traber    (atraber@iis.ee.ethz.ch)
//              Oivind Ekelund    (oivind.ekelund@silabs.com)
//
///////////////////////////////////////////////////////////////////////////////

module cv32e40x_div import cv32e40x_pkg::*;
(
    // Clock and reset
    input logic                clk,
    input logic                rst_n,

    // Control signals
    input                      div_opcode_e operator_i,
    input logic                data_ind_timing_i,

    // Input operands
    input logic [31:0]         op_a_i,
    input logic [31:0]         op_b_i,


    // CLZ interface towards ALU
    output logic               alu_clz_en_o,
    output logic [31:0]        alu_clz_data_rev_o,
    input logic [5:0]          alu_clz_result_i,

    // Shifter interface towards ALU
    output logic               alu_shift_en_o,
    output logic [5:0]         alu_shift_amt_o,
    input logic [31:0]         alu_op_b_shifted_i,

    // Divider enable
    input logic                div_en_i,

    // Input handshake
    input logic                valid_i,
    output logic               ready_o,

    // Output handshake and result
    input logic                ready_i,
    output logic               valid_o,
    output logic [31:0]        result_o
  );

  ///////////////////////////////////////////////////////////////////////////////
  // Signal declarations
  ///////////////////////////////////////////////////////////////////////////////

  logic [31:0] alu_clz_data;

  logic [31:0] quotient_q, quotient_d;
  logic [31:0] remainder_q, remainder_d;
  logic [31:0] divisor_q, divisor_d;

  logic div_rem_d, div_rem_q;
  logic comp_inv_d, comp_inv_q;
  logic res_inv_d, res_inv_q;

  logic [31:0] add_a_mux;
  logic [31:0] add_out;
  logic [31:0] add_b_mux;
  logic [31:0] divisor_mux;
  logic [31:0] res_mux;
  logic [32:0] op_b_alt;

  logic [5:0] cnt_q, cnt_d, cnt_d_dummy;
  logic cnt_q_is_zero;
  logic init_dummy_cnt;

  logic remainder_en, divisor_en, quotient_en, comp_out, init_remainder_pos, init_en;

  div_state_e next_state, state;

  logic div_signed;
  logic div_rem;
  logic op_b_is_neg;
  logic op_b_is_zero;

  ///////////////////////////////////////////////////////////////////////////////
  // Operator decoding
  ///////////////////////////////////////////////////////////////////////////////

  assign div_signed = (operator_i == DIV_DIV) || (operator_i == DIV_REM);
  assign div_rem    = (operator_i == DIV_REM) || (operator_i == DIV_REMU);

  ///////////////////////////////////////////////////////////////////////////////
  // Interaction with CLZ and shift circuitry in the ALU
  ///////////////////////////////////////////////////////////////////////////////

  // In case of negative op_b, invert op_b_i to count leading ones
  // and shift one less to preserve sign bit
  assign op_b_alt = (~op_b_i << 1);

  always_comb
  begin
    alu_clz_data = op_b_i;

    case (operator_i)
      DIV_DIVU,
      DIV_REMU: alu_clz_data = op_b_i;

      DIV_DIV,
      DIV_REM: begin
        if (op_b_is_neg) begin
          alu_clz_data = {op_b_alt[31:1], 1'b1};
        end else begin
          alu_clz_data = op_b_i;
        end
      end
      default:;
    endcase
  end

  // CLZ circuit needs reversed input
  generate
    genvar l;
    for (l = 0; l < 32; l++)
    begin : gen_div_clz_data_rev
      assign alu_clz_data_rev_o[l] = alu_clz_data[31-l];
    end
  endgenerate

  assign alu_clz_en_o = div_en_i;

  // Deternmine initial shift of divisor
  assign op_b_is_neg = op_b_i[31] & div_signed;
  assign alu_shift_amt_o = alu_clz_result_i ;
  assign alu_shift_en_o  = div_en_i;

  // Check for op_b_i == 0
  assign op_b_is_zero = !(|op_b_i);

  ///////////////////////////////////////////////////////////////////////////////
  // Datapath
  ///////////////////////////////////////////////////////////////////////////////

  // Initialize remainder with negated op_a_i upon signed division with different signs on op_a and op_b
  assign init_remainder_pos = init_en && !(div_signed && (op_a_i[$high(op_a_i)] ^ op_b_is_neg));

  // Divisor mux and shifter. Shift with sign extension in case of negative op_b
  assign divisor_mux = init_en ? alu_op_b_shifted_i : {comp_inv_q, (divisor_q[$high(divisor_q):1])};

  // Main comparator
  assign comp_out = ((remainder_q == divisor_q) || ((remainder_q > divisor_q) ^ comp_inv_q)) &&
                    ((|remainder_q) || op_b_is_zero);

  // Main adder and adder input muxes
  assign add_b_mux = init_en ? 0 : remainder_q;
  assign add_a_mux = init_en ? op_a_i : divisor_q;
  assign add_out   = init_remainder_pos ? add_b_mux + add_a_mux : add_b_mux - $signed(add_a_mux);

  // Result mux, negate if necessary
  assign res_mux  = div_rem_q ? remainder_q : quotient_q;
  assign result_o = res_inv_q ? -$signed(res_mux) : res_mux;

  ///////////////////////////////////////////////////////////////////////////////
  // Counter
  ///////////////////////////////////////////////////////////////////////////////

  assign cnt_d_dummy = 6'd32 - alu_shift_amt_o;

  assign cnt_d = init_en        ? alu_shift_amt_o    :
                 init_dummy_cnt ? cnt_d_dummy - 6'd1 : /*-1 because one cycle is used to update the counter*/
                 !cnt_q_is_zero ? cnt_q       - 6'd1 :
                 cnt_q;

  assign cnt_q_is_zero = !(|cnt_q);

  ///////////////////////////////////////////////////////////////////////////////
  // FSM
  ///////////////////////////////////////////////////////////////////////////////

  always_comb
  begin : p_fsm
    // default
    next_state     = state;

    valid_o        = 1'b0;
    ready_o        = 1'b0;

    init_en        = 1'b0;
    init_dummy_cnt = 1'b0;

    remainder_en   = 1'b0;
    divisor_en     = 1'b0;
    quotient_en    = 1'b0;

    // Case statement assumes valid_i = 1; the valid_i = 0 scenario
    // is handled after the case statement.
    case (state)
      DIV_IDLE: begin
        remainder_en = 1'b1;
        divisor_en   = 1'b1;
        init_en      = 1'b1;
        next_state   = DIV_DIVIDE;
      end

      DIV_DIVIDE: begin
        remainder_en = comp_out;
        divisor_en   = 1'b1;
        quotient_en  = 1'b1;

        // calculation finished
        // one more divide cycle (32nd divide cycle)
        if (cnt_q_is_zero) begin
          if (data_ind_timing_i && |(cnt_d_dummy)) begin
            init_dummy_cnt = 1'b1;
            next_state = DIV_DUMMY;
          end else begin
            next_state = DIV_FINISH;
          end
        end
      end

      DIV_DUMMY: begin
        if (cnt_q_is_zero) begin
          next_state = DIV_FINISH;
        end
      end

      DIV_FINISH: begin
        valid_o = 1'b1;
        if (ready_i) begin
          ready_o    = 1'b1;
          next_state = DIV_IDLE;
        end
      end

      default : /* default */ ;

    endcase

    // Allow kill at any time
    if (!valid_i) begin
      next_state = DIV_IDLE;
      ready_o    = 1'b1;
      valid_o    = 1'b0;
    end

  end

  ///////////////////////////////////////////////////////////////////////////////
  // Registers
  ///////////////////////////////////////////////////////////////////////////////

  assign div_rem_d  = init_en ? div_rem : div_rem_q;
  assign comp_inv_d = init_en ? op_b_is_neg : comp_inv_q;
  assign res_inv_d  = init_en ? (!op_b_is_zero || div_rem) && div_signed && (op_a_i[$high(op_a_i)] ^ op_b_is_neg) :
                      res_inv_q;

  assign remainder_d = remainder_en ? add_out     : remainder_q;
  assign divisor_d   = divisor_en   ? divisor_mux : divisor_q;
  assign quotient_d  = init_en      ? '0                                            :
                       quotient_en  ? {quotient_q[$high(quotient_q)-1:0], comp_out} :
                       quotient_q;

  always_ff @(posedge clk, negedge rst_n) begin : p_regs
    if (rst_n == 1'b0) begin
       state       <= DIV_IDLE;
       remainder_q <= '0;
       divisor_q   <= '0;
       quotient_q  <= '0;
       cnt_q       <= '0;
       div_rem_q   <= 1'b0;
       comp_inv_q  <= 1'b0;
       res_inv_q   <= 1'b0;
    end else begin
       state       <= next_state;
       remainder_q <= remainder_d;
       divisor_q   <= divisor_d;
       quotient_q  <= quotient_d;
       cnt_q       <= cnt_d;
       div_rem_q   <= div_rem_d;
       comp_inv_q  <= comp_inv_d;
       res_inv_q   <= res_inv_d;
    end
  end

endmodule
