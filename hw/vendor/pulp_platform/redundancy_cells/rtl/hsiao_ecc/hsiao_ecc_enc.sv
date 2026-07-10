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
// Hsiao ECC encoder
// Based in part on work by lowRISC

module hsiao_ecc_enc import hsiao_ecc_pkg::*; #(
  parameter int unsigned DataWidth = 32,
  parameter int unsigned ProtWidth = min_ecc(DataWidth),
  parameter int unsigned TotalWidth = DataWidth + ProtWidth,
  parameter bit          PrintHsiao = 1'b0
) (
  input  logic [ DataWidth-1:0] in,
  output logic [TotalWidth-1:0] out
);

  if (ProtWidth < min_ecc(DataWidth)) $error("ProtWidth must be greater than $clog2(DataWidth)+2");

  localparam bit [MaxParityWidth-1:0][MaxTotalWidth-1:0] HsiaoCodes =
                                                         hsiao_matrix(DataWidth, ProtWidth);

  always_comb begin : proc_encode
    out[DataWidth-1:0] = in;
    for (int unsigned i = 0; i < ProtWidth; i++) begin
      out[DataWidth + i] = ^(in & HsiaoCodes[i][DataWidth-1:0]);
    end
  end

`ifndef TARGET_SYNTHESIS
  if (PrintHsiao) begin : gen_print_matrix
    initial begin : p_hsiao_matrix
      automatic string s = "##";
      for (int i = 0; i < TotalWidth; i++) begin
        s = {s, "#"};
      end
      $display("%s", s);
      $display("hsiao_ecc_enc for %d_%d", TotalWidth, DataWidth);
      for (int i = ProtWidth-1; i >= 0; i--) begin
        $display("%b",HsiaoCodes[i][TotalWidth-1:0]);
      end
      $display("%s", s);
    end
  end
`endif

endmodule
