// Copyright 2022 Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License");
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Authors:        Oivind Ekelund - oivind.ekelund@silabs.com                 //
//                                                                            //
// Description:    RTL assertions for register file                           //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_register_file_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
#(
  parameter rv32_e RV32   = RV32I
)
(
  input logic     clk,
  input logic     rst_n,
  input rf_addr_t waddr_i [REGFILE_NUM_WRITE_PORTS],
  input logic     we_i    [REGFILE_NUM_WRITE_PORTS]
);

  generate
    if(RV32 == RV32E) begin: a_rv32e

      a_rf_we_illegal :
        assert property (@(posedge clk) disable iff (!rst_n)
                         we_i[0] |-> waddr_i[0] <= 15)
          else `uvm_error("regiter_file", "Write to GPR > 15 with RV32E")

    end
  endgenerate

endmodule : cv32e40x_register_file_sva
