// Copyright 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Triple Modular Redundancy Majority Voter (MV) for a data word

module bitwise_TMR_voter #(
  parameter int unsigned DataWidth = 32,
  parameter int unsigned VoterType = 2 // 0: Classical_MV, 1: KP_MV, 2: BN_MV
) (
  input  logic [DataWidth-1:0] a_i,
  input  logic [DataWidth-1:0] b_i,
  input  logic [DataWidth-1:0] c_i,
  output logic [DataWidth-1:0] majority_o,
  output logic                 error_o, // Indicates a complete mismatch (i.e. all inputs disagree)
  output logic [          2:0] error_cba_o // Indicates which input is mismatched to majority
);

  logic [DataWidth-1:0] err_a_all, err_b_all, err_c_all;

  for (genvar i = 0; i < DataWidth; i++) begin : gen_bit_voters
    TMR_voter_detect #(
      .VoterType ( VoterType )
    ) i_voter (
      .a_i (a_i[i]),
      .b_i (b_i[i]),
      .c_i (c_i[i]),
      .majority_o ( majority_o[i] ),
      .error_cba_o( { err_c_all[i], err_b_all[i], err_a_all[i] } )
    );
  end

  assign error_cba_o[0] = |err_a_all;
  assign error_cba_o[1] = |err_b_all;
  assign error_cba_o[2] = |err_c_all;

  TMR_voter #(
    .VoterType(0)
  ) i_triple_mismatch (
    .a_i(error_cba_o[0]),
    .b_i(error_cba_o[1]),
    .c_i(error_cba_o[2]),
    .majority_o (error_o)
  );

endmodule

