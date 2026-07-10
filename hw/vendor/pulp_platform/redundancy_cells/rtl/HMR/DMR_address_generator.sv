/* Copyright 2020 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * Dual Modular Address Generator
 * Generates addresses for RF refill
 *
 */

module DMR_address_generator #(
  parameter  int unsigned AddrWidth = 5
)(
  input  logic                 clk_i    ,
  input  logic                 rst_ni   ,
  input  logic                 clear_i  ,
  input  logic                 enable_i ,
  output logic                 done_o   ,
  output logic                 fatal_o  ,
  output logic [AddrWidth-1:0] address_o
);

localparam int unsigned NumAddr = 2 ** (AddrWidth - 1);
localparam int unsigned NumVotingSignals = 3;
localparam int unsigned NumTMRResults = 1;
localparam int unsigned ArrayWidth = NumVotingSignals + NumTMRResults;

logic addr_count_err;
logic [NumVotingSignals-1:0] addr_count_rst;
logic [ArrayWidth-1:0][AddrWidth-1:0] addr_count;

generate
  for (genvar i = 0; i < NumVotingSignals; i++) begin : gen_addr_ffs
    always_ff @(posedge clk_i, negedge  rst_ni) begin : address_generator_counter
      if (~rst_ni)
        addr_count [i] <= '1;
      else begin
        if (clear_i || addr_count_rst [i])
          addr_count [i] <= '1;
        else if (enable_i)
          addr_count [i] <= addr_count [i] + 1;
        else
          addr_count [i] <= addr_count [i];
      end
    end
  assign addr_count_rst [i] = ( addr_count [i] == NumAddr/2 - 1) ? 1'b1 : 1'b0;
  end
endgenerate

bitwise_TMR_voter #(
  .DataWidth ( AddrWidth ),
  .VoterType ( 0         )
) address_counter_voter (
  .a_i         ( addr_count [0] ),
  .b_i         ( addr_count [1] ),
  .c_i         ( addr_count [2] ),
  .majority_o  ( addr_count [3] ),
  .error_o     ( addr_count_err ),
  .error_cba_o ( /* ... */      )
);

assign address_o = addr_count [3]; // Result of TMR address voter
assign fatal_o = addr_count_err; // Error from one of the two TMR voters
assign done_o = |addr_count_rst;

endmodule : DMR_address_generator
