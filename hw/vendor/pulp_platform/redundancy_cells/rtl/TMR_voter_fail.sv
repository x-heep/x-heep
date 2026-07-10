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
// Triple Modular Redundancy Majority Voter (MV) for a single bit with a failure output
//
// Classical_MV: standard and & or gates
// KP_MV:        Kshirsagar and Patrikar MV [https://doi.org/10.1016/j.microrel.2009.08.001]
// BN_MV:        Ban and Naviner MV         [https://doi.org/10.1109/NEWCAS.2010.5603933]
//
// Fault detection logic added on our own Ideas

module TMR_voter_fail #(
  parameter int unsigned VoterType = 1 // 0: Classical_MV, 1: KP_MV, 2: BN_MV
) (
  input  logic a_i,
  input  logic b_i,
  input  logic c_i,
  output logic majority_o,
  output logic fault_detected_o
);

  if (VoterType == 0) begin : gen_classical_mv
    assign majority_o = (a_i & b_i) | (a_i & c_i) | (b_i & c_i);
    assign fault_detected_o = (a_i ^ b_i) | (a_i ^ c_i); // 3 extra gates
  end else if (VoterType == 1) begin : gen_kp_mv
    logic n_1, n_2, p;
    assign n_1 = a_i ^ b_i;
    assign n_2 = b_i ^ c_i;
    assign p = n_1 & ~n_2;
    assign majority_o = p ? c_i : a_i;
    assign fault_detected_o = n_1 | n_2; // 1 extra gate
  end else if (VoterType == 2) begin : gen_bn_mv
    logic n;
    assign n = a_i ^ b_i;
    assign majority_o = n ? c_i : b_i;
    assign fault_detected_o = n | b_i ^ c_i; // 2 extra gates
  end else begin : gen_unsupported
`ifndef TARGET_SYNTHESIS
    $fatal(1, "Please select a valid VoterType.\n");
`endif
  end

endmodule
