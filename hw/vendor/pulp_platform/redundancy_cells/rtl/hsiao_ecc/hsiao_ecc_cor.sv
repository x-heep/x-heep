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
// Hsiao ECC decoder
// Based in part on work by lowRISC

module hsiao_ecc_cor import hsiao_ecc_pkg::*; #(
  parameter int unsigned DataWidth = 32,
  parameter int unsigned ProtWidth = min_ecc(DataWidth),
  parameter int unsigned TotalWidth = DataWidth + ProtWidth,
  parameter bit          PrintHsiao = 1'b0
) (
  input  logic [TotalWidth-1:0] in,
  output logic [TotalWidth-1:0] out,
  output logic [ ProtWidth-1:0] syndrome_o,
  output logic [           1:0] err_o
);

  if (ProtWidth < min_ecc(DataWidth)) $error("ProtWidth must be greater than $clog2(DataWidth)+2");

  localparam bit [MaxParityWidth-1:0][ MaxTotalWidth-1:0] HsiaoCodes =
                                                          hsiao_matrix(DataWidth, ProtWidth);
  localparam bit [ MaxTotalWidth-1:0][MaxParityWidth-1:0] CorrCodes  =
                                          transpose(HsiaoCodes, ProtWidth, TotalWidth);

  logic single_error;

  for (genvar i = 0; i < ProtWidth; i++) begin : gen_syndrome
    assign syndrome_o[i] = ^(in & HsiaoCodes[i][TotalWidth-1:0]);
  end

  for (genvar i = 0; i < TotalWidth; i++) begin : gen_out
    assign out[i] = in[i] ^ (syndrome_o == CorrCodes[i][ProtWidth-1:0]);
  end

  assign single_error = ^syndrome_o;
  assign err_o[0] = single_error;
  assign err_o[1] = ~single_error & (|syndrome_o);

`ifndef TARGET_SYNTHESIS
  if (PrintHsiao) begin : gen_print_matrix
    initial begin : p_hsiao_matrix
      automatic string s = "##";
      for (int i = 0; i < TotalWidth; i++) begin
        s = {s, "#"};
      end
      $display("%s", s);
      $display("hsiao_ecc_cor for %d_%d", TotalWidth, DataWidth);
      for (int i = ProtWidth-1; i >= 0; i--) begin
        $display("%b",HsiaoCodes[i][TotalWidth-1:0]);
      end
      $display("%s", s);
      for (int i = TotalWidth-1; i >= 0; i--) begin
        $display("%b",CorrCodes[i][ProtWidth-1:0]);
      end
      $display("%s", s);
    end
  end
`endif

endmodule
