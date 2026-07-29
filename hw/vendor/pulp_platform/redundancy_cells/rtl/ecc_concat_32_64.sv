// Copyright 2021 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Concatenates two ecc words

module ecc_concat_32_64 #(
  localparam int unsigned DataInWidthA = 39, // 32+secded
  localparam int unsigned DataInWidthB = 39, // 32+secded
  localparam int unsigned DataOutWidth  = 72  // 64+secded
) (
  input  logic [DataInWidthA-1:0] data_a_i, // data_o[31:0]
  input  logic [DataInWidthB-1:0] data_b_i, // data_o[63:32]
  output logic [DataOutWidth -1:0] data_o
);

  // Naiive implementation - decode and encode
  logic [31:0] data_a;
  logic [31:0] data_b;

  prim_secded_39_32_dec dec_a (
    .in         ( data_a_i ),
    .d_o        ( data_a   ),
    .syndrome_o (),
    .err_o      ()
  );

  prim_secded_39_32_dec dec_b (
    .in         ( data_b_i ),
    .d_o        ( data_b   ),
    .syndrome_o (),
    .err_o      ()
  );

  prim_secded_72_64_enc enc_out (
    .in  ( {data_b, data_a} ),
    .out ( data_o           )
  );

endmodule
