// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/////////////////////////////////////////////////////////////////////////////////
// Engineer:       Francesco Conti - f.conti@unibo.it                          //
//                                                                             //
// Additional contributions by:                                                //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                  //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                  //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com              //
//                                                                             //
// Design Name:    RISC-V register file                                        //
// Project Name:   RI5CY                                                       //
// Language:       SystemVerilog                                               //
//                                                                             //
// Description:    Register file with 31x registers. Register 0 is fixed to 0. //
//                 This register file is based on flip-flops. The register     //
//                 width is configurable to allow adding a parity bit or ECC.  //
//                                                                             //
/////////////////////////////////////////////////////////////////////////////////

module cv32e40x_register_file import cv32e40x_pkg::*;
  #(
      parameter int unsigned REGFILE_NUM_READ_PORTS = 2,
      parameter rv32_e       RV32                   = RV32I
  )
  (
    // Clock and Reset
    input logic                           clk,
    input logic                           rst_n,

    // Read ports
    input  rf_addr_t                      raddr_i [REGFILE_NUM_READ_PORTS],
    output logic [REGFILE_WORD_WIDTH-1:0] rdata_o [REGFILE_NUM_READ_PORTS],

    // Write ports
    input rf_addr_t                       waddr_i [REGFILE_NUM_WRITE_PORTS],
    input logic [REGFILE_WORD_WIDTH-1:0]  wdata_i [REGFILE_NUM_WRITE_PORTS],
    input logic                           we_i    [REGFILE_NUM_WRITE_PORTS]
   );

  // Number of regfile integer registers
  localparam REGFILE_NUM_WORDS = (RV32 == RV32I) ? 32 : 16;
  localparam REGFILE_IMPL_ADDR_WIDTH = $clog2(REGFILE_NUM_WORDS);

  // integer register file
  logic [REGFILE_WORD_WIDTH-1:0]          mem [REGFILE_NUM_WORDS];

  // write enable signals for all registers
  logic [REGFILE_NUM_WORDS-1:0]           we_dec[REGFILE_NUM_WRITE_PORTS];

  //-----------------------------------------------------------------------------
  //-- READ : Read address decoder RAD
  //-----------------------------------------------------------------------------
  genvar ridx;
  generate
    for (ridx=0; ridx<REGFILE_NUM_READ_PORTS; ridx++) begin : gen_regfile_rdata
      assign rdata_o[ridx] = mem[raddr_i[ridx][REGFILE_IMPL_ADDR_WIDTH-1:0]];
    end
  endgenerate

  //-----------------------------------------------------------------------------
  //-- WRITE : Write Address Decoder (WAD), combinatorial process
  //-----------------------------------------------------------------------------


  genvar reg_index, port_index;
  generate
    for (reg_index=0; reg_index<REGFILE_NUM_WORDS; reg_index++) begin : gen_we_decoder
      for (port_index=0; port_index<REGFILE_NUM_WRITE_PORTS; port_index++) begin : gen_we_ports
        assign we_dec[port_index][reg_index] = (waddr_i[port_index] == reg_index) ? we_i[port_index] : 1'b0;
      end // gen_we_ports
    end // gen_we_decoder
  endgenerate

  genvar i;
  generate

    //-----------------------------------------------------------------------------
    //-- WRITE : Write operation
    //-----------------------------------------------------------------------------
    // R0 is nil
    always_ff @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
        // R0 is nil
        mem[0] <= '0;
      end else begin
        // R0 is nil
        mem[0] <= '0;
      end
    end

    // loop from 1 to NUM_WORDS-1 as R0 is nil
    for (i = 1; i < REGFILE_NUM_WORDS; i++)
    begin : gen_rf

      always_ff @(posedge clk, negedge rst_n)
      begin : register_write_behavioral
        if (rst_n==1'b0) begin
          mem[i] <= '0;
        end else begin
          // Highest indexed write port will have priority
          for(int j=0; j<REGFILE_NUM_WRITE_PORTS; j++) begin : rf_write_ports
            if(we_dec[j][i] == 1'b1) begin
              mem[i] <= wdata_i[j];
            end
          end
        end
      end

    end

  endgenerate

endmodule
