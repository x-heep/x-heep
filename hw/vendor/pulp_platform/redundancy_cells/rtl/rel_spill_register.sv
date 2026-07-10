// Copyright 2025 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module rel_spill_register #(
  parameter type T           = logic, // Assumed ECC protected
  parameter bit  Bypass      = 1'b0,   // make this spill register transparent
  parameter bit  TmrHandshake = 1'b1,    // use TMR handshake
  parameter bit  DataCorrector = 1'b0, // use 0-cycle data corrector signals
  parameter int unsigned HsWidth = TmrHandshake ? 3 : 1 // width of the handshake signals
) (
  input  logic clk_i   ,
  input  logic rst_ni  ,
  input  logic [HsWidth-1:0] valid_i ,
  output logic [HsWidth-1:0] ready_o ,
  input  T      data_i  ,
  output logic [HsWidth-1:0] valid_o ,
  input  logic [HsWidth-1:0] ready_i ,
  output T      data_o,
  output logic fault_o,
  output T      data_corrector_o,
  input  T      data_corrected_i
);

  typedef logic [$bits(T)-1:0] T_vec_t;

  if (Bypass) begin : gen_bypass
    assign valid_o = valid_i;
    assign ready_o = ready_i;
    assign data_o = data_i;
    assign fault_o = 1'b0;
    assign data_corrector_o = '0;
  end else begin : gen_spill_reg
    logic [7+$bits(T):0] faults;
    assign fault_o = |faults;

    logic [2:0] valid_in, ready_out, valid_out, ready_in;
    if (TmrHandshake) begin : gen_tmr_handshake
      assign valid_in  = valid_i;
      assign ready_o = ready_out;
      assign valid_o = valid_out;
      assign ready_in  = ready_i;
      assign faults[1:0] = '0;
    end else begin : gen_non_tmr_handshake
      assign valid_in  = {3{valid_i}};
      assign ready_in  = {3{ready_i}};
      TMR_voter_fail #(
        .VoterType ( 0 ) // Classical_MV
      ) i_ready_tmr (
        .a_i              ( ready_out[0] ),
        .b_i              ( ready_out[1] ),
        .c_i              ( ready_out[2] ),
        .majority_o       ( ready_o      ),
        .fault_detected_o ( faults[0]    )
      );
      TMR_voter_fail #(
        .VoterType ( 0 ) // Classical_MV
      ) i_valid_tmr (
        .a_i              ( valid_out[0] ),
        .b_i              ( valid_out[1] ),
        .c_i              ( valid_out[2] ),
        .majority_o       ( valid_o      ),
        .fault_detected_o ( faults[1]    )
      );
    end

    // The A register.
    T_vec_t a_data_d, a_data_q;

    // The B register.
    T_vec_t b_data_d, b_data_q;

    T_vec_t [2:0] a_fill_tmr, b_fill_tmr, b_full_q_tmr;

    logic [2:0] a_full_q_sync, b_full_q_sync;
    logic [2:0][1:0] alt_a_full_q_sync, alt_b_full_q_sync;

    for (genvar i = 0; i < 3; i++) begin : gen_tmr_part
      for (genvar j = 0; j < 2; j++) begin : gen_sync
        assign alt_a_full_q_sync[i][j] = a_full_q_sync[(i+j+1) % 3];
        assign alt_b_full_q_sync[i][j] = b_full_q_sync[(i+j+1) % 3];
      end
      rel_spill_reg_tmr_part #(
        .T           ( T ),
        .Bypass      ( Bypass )
      ) i_tmr_part (
        .clk_i                ( clk_i              ),
        .rst_ni               ( rst_ni             ),
        .alt_a_full_q_sync_i  ( alt_a_full_q_sync[i] ),
        .a_full_q_sync_o      ( a_full_q_sync[i] ),
        .alt_b_full_q_sync_i  ( alt_b_full_q_sync[i] ),
        .b_full_q_sync_o      ( b_full_q_sync[i] ),
        .a_fill_tmr_o         ( a_fill_tmr[i]      ),
        .b_fill_tmr_o         ( b_fill_tmr[i]      ),
        .b_full_q_tmr_o       ( b_full_q_tmr[i]    ),
        .valid_i              ( valid_in[i]        ),
        .valid_o              ( valid_out[i]       ),
        .ready_i              ( ready_in[i]        ),
        .ready_o              ( ready_out[i]       ),
        .faults_o             ( faults[3+2*i:2+2*i] )
      );
    end

    for (genvar i = 0; i < $bits(T); i++) begin : gen_muxes
      logic a_fill, b_fill, b_full_q;
      logic [2:0] faults_here;
      assign faults[8+i] = |faults_here;
      TMR_voter_fail #(
        .VoterType ( 1 ) // KP_MV
      ) i_a_data_tmr (
        .a_i              ( a_fill_tmr[0][i] ),
        .b_i              ( a_fill_tmr[1][i] ),
        .c_i              ( a_fill_tmr[2][i] ),
        .majority_o       ( a_fill         ),
        .fault_detected_o ( faults_here[0]       )
      );
      assign a_data_d[i] = a_fill ? data_i[i] : a_data_q[i];

      TMR_voter_fail #(
        .VoterType ( 1 ) // KP_MV
      ) i_b_data_tmr (
        .a_i              ( b_fill_tmr[0][i] ),
        .b_i              ( b_fill_tmr[1][i] ),
        .c_i              ( b_fill_tmr[2][i] ),
        .majority_o       ( b_fill         ),
        .fault_detected_o ( faults_here[1]       )
      );
      if (DataCorrector) begin : gen_data_corrector_connect
        assign data_corrector_o[i] = b_data_q[i];
        assign b_data_d[i] = b_fill ? a_data_q[i] : data_corrected_i[i];
      end else begin : gen_no_data_corrector
        assign data_corrector_o[i] = '0;
        assign b_data_d[i] = b_fill ? a_data_q[i] : b_data_q[i];
      end

      TMR_voter_fail #(
        .VoterType ( 1 ) // KP_MV
      ) i_b_full_q_tmr (
        .a_i              ( b_full_q_tmr[0][i] ),
        .b_i              ( b_full_q_tmr[1][i] ),
        .c_i              ( b_full_q_tmr[2][i] ),
        .majority_o       ( b_full_q         ),
        .fault_detected_o ( faults_here[2]       )
      );
      assign data_o[i] = b_full_q ? b_data_q[i] : a_data_q[i];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : ps_a_data
      if (!rst_ni)
        a_data_q <= '0;
      else
        a_data_q <= a_data_d;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : ps_b_data
      if (!rst_ni)
        b_data_q <= '0;
      else
        b_data_q <= b_data_d;
    end
  end

endmodule

(* no_ungroup *)
(* no_boundary_optimization *)
module rel_spill_reg_tmr_part #(
  parameter type T           = logic, // Assumed ECC protected
  parameter bit  Bypass      = 1'b0
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic [1:0] alt_a_full_q_sync_i,
  output logic a_full_q_sync_o,
  input  logic [1:0] alt_b_full_q_sync_i,
  output logic b_full_q_sync_o,
  output logic [$bits(T)-1:0] a_fill_tmr_o,
  output logic [$bits(T)-1:0] b_fill_tmr_o,
  output logic [$bits(T)-1:0] b_full_q_tmr_o,
  input  logic valid_i,
  output logic valid_o,
  input  logic ready_i,
  output logic ready_o,
  output logic [1:0] faults_o
);

  logic a_full_q;
  logic a_fill, a_drain;
  logic b_full_q;
  logic b_fill, b_drain;

  for (genvar i = 0; i < $bits(T); i++) begin : gen_tmr_fill
    assign a_fill_tmr_o[i] = a_fill;
    assign b_fill_tmr_o[i] = b_fill;
    assign b_full_q_tmr_o[i] = b_full_q_sync_o;
  end



  always_ff @(posedge clk_i or negedge rst_ni) begin : ps_a_data
    if (!rst_ni)
      a_full_q_sync_o <= '0;
    else if (a_fill || a_drain)
      a_full_q_sync_o <= a_fill;
  end

  TMR_voter_fail #(
    .VoterType ( 1 ) // KP_MV
  ) i_a_full_tmr (
    .a_i              ( a_full_q_sync_o ),
    .b_i              ( alt_a_full_q_sync_i[0] ),
    .c_i              ( alt_a_full_q_sync_i[1] ),
    .majority_o       ( a_full_q ),
    .fault_detected_o ( faults_o[0] )
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin : ps_b_data
    if (!rst_ni)
      b_full_q_sync_o <= '0;
    else if (b_fill || b_drain)
      b_full_q_sync_o <= b_fill;
  end

  TMR_voter_fail #(
    .VoterType ( 0 ) // Classical_MV
  ) i_b_full_tmr (
    .a_i              ( b_full_q_sync_o ),
    .b_i              ( alt_b_full_q_sync_i[0] ),
    .c_i              ( alt_b_full_q_sync_i[1] ),
    .majority_o       ( b_full_q ),
    .fault_detected_o ( faults_o[1] )
  );

  // Fill the A register when the A or B register is empty. Drain the A register
  // whenever it is full and being filled, or if a flush is requested.
  assign a_fill = valid_i && ready_o;
  assign a_drain = (a_full_q && !b_full_q);

  // Fill the B register whenever the A register is drained, but the downstream
  // circuit is not ready. Drain the B register whenever it is full and the
  // downstream circuit is ready, or if a flush is requested.
  assign b_fill = a_drain && (!ready_i);
  assign b_drain = (b_full_q && ready_i);

  // We can accept input as long as register B is not full.
  // Note: flush_i and valid_i must not be high at the same time,
  // otherwise an invalid handshake may occur
  assign ready_o = !a_full_q || !b_full_q;

  // The unit provides output as long as one of the registers is filled.
  assign valid_o = a_full_q | b_full_q;

endmodule
