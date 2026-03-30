// Copyright 2020 Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License").
//
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
//
// You may obtain a copy of the License at:
//
//     https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof distributed under the License
// is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
//
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Øystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Design Name:    Register file wrapper                                      //
// Project Name:   CV32E40X                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Wrapper for the register file                              //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_register_file_wrapper import cv32e40x_pkg::*;
#(
      parameter int unsigned REGFILE_NUM_READ_PORTS = 2,
      parameter rv32_e       RV32                   = RV32I
)
(
        // Clock and Reset
        input  logic         clk,
        input  logic         rst_n,
    
        // Read ports
        input  rf_addr_t     raddr_i [REGFILE_NUM_READ_PORTS],
        output rf_data_t     rdata_o [REGFILE_NUM_READ_PORTS],
    
        // Write ports
        input rf_addr_t     waddr_i [REGFILE_NUM_WRITE_PORTS],
        input rf_data_t     wdata_i [REGFILE_NUM_WRITE_PORTS],
        input logic         we_i [REGFILE_NUM_WRITE_PORTS]
);
    
    cv32e40x_register_file
    #(
      .REGFILE_NUM_READ_PORTS       ( REGFILE_NUM_READ_PORTS ),
      .RV32                         ( RV32                   )
    )
    register_file_i
    (
      .clk                ( clk                ),
      .rst_n              ( rst_n              ),
    
      // Read ports
      .raddr_i            ( raddr_i            ),
      .rdata_o            ( rdata_o            ),
    
      // Write ports
      .waddr_i            ( waddr_i            ),
      .wdata_i            ( wdata_i            ),
      .we_i               ( we_i               )
                 
    ); 
    
    endmodule
    
