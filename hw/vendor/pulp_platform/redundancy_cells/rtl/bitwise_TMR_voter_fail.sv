// Copyright 2024 ETH Zurich and University of Bologna.
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

module bitwise_TMR_voter_fail #(
  parameter int unsigned DataWidth = 32,
  parameter int unsigned VoterType = 1 // 0: Classical_MV, 1: KP_MV, 2: BN_MV
) (
  input  logic [DataWidth-1:0] a_i,
  input  logic [DataWidth-1:0] b_i,
  input  logic [DataWidth-1:0] c_i,
  output logic [DataWidth-1:0] majority_o,
  output logic                 fault_detected_o // Indicates any type of mismatch
);

  logic [DataWidth-1:0] fault_detected;

  for (genvar i = 0; i < DataWidth; i++) begin : gen_bit_voters
    TMR_voter_fail #(
      .VoterType ( VoterType )
    ) i_voter_fail (
      .a_i              ( a_i[i]            ),
      .b_i              ( b_i[i]            ),
      .c_i              ( c_i[i]            ),
      .majority_o       ( majority_o[i]     ),
      .fault_detected_o ( fault_detected[i] )
    );
  end

  assign fault_detected_o = |fault_detected;

endmodule
