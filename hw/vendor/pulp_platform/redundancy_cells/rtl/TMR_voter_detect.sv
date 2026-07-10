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
// Triple Modular Redundancy Majority Voter (MV) for a single bit, with indication of erroneous bit

module TMR_voter_detect #(
  parameter int unsigned VoterType = 0 // 0: Classical_MV, 1: KP_MV, 2: BN_MV
) (
  input  logic a_i,
  input  logic b_i,
  input  logic c_i,
  output logic majority_o,
  output logic [2:0] error_cba_o // Indicates whether input is mismatched to majority
);

  TMR_voter #(
    .VoterType ( VoterType )
  ) i_voter (
    .a_i,
    .b_i,
    .c_i,
    .majority_o
  );

  assign error_cba_o[0] = (a_i ^ majority_o);
  assign error_cba_o[1] = (b_i ^ majority_o);
  assign error_cba_o[2] = (c_i ^ majority_o);

endmodule
