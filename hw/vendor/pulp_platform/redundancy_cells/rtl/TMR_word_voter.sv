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
//
// based on https://doi.org/10.1109/VTEST.2000.843880

module TMR_word_voter #(
  parameter int unsigned DataWidth = 32
) (
  input  logic [DataWidth-1:0] a_i,
  input  logic [DataWidth-1:0] b_i,
  input  logic [DataWidth-1:0] c_i,
  output logic [DataWidth-1:0] majority_o,
  output logic                 error_o, // Indicates a complete mismatch (i.e. all inputs disagree)
  output logic [          2:0] error_cba_o // Indicates which input is mismatched to majority
);

  logic match_ab, match_bc, match_ac;
  logic mismatch;

  assign match_ab = &(a_i ~^ b_i);
  assign match_bc = &(b_i ~^ c_i);
  assign match_ac = &(a_i ~^ c_i);
  assign error_o  = ~(match_ab | match_bc | match_ac);
  assign mismatch = ~(match_ab & match_bc & match_ac);

  for (genvar i = 0; i < DataWidth; i++) begin : gen_majority_bits
    assign majority_o[i] = (match_ac & a_i[i]) | (~match_ac & b_i[i]);
  end

  assign error_cba_o[0] = mismatch & match_bc;
  assign error_cba_o[1] = mismatch & match_ac;
  assign error_cba_o[2] = mismatch & match_ab;

endmodule

