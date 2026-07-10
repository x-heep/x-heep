// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Francesco Conti - f.conti@unibo.it                         //
//                                                                            //
// Additional contributions by:                                               //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    RISC-V register file                                       //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Register file with 31x 32 bit wide registers. Register 0   //
//                 is fixed to 0. This register file is based on flip-flops.  //
//                 Also supports the fp-register file now if FPU=1            //
//                 If PULP_ZFINX is 1, floating point operations take values  //
//                 from the X register file                                   //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module recovery_rf #(
  parameter  int unsigned ECCEnabled        = 0,
  parameter  int unsigned ADDR_WIDTH        = 5,
  parameter  int unsigned NonProtectedWidth = 32,
  parameter  int unsigned ProtectedWidth    = 39,
  parameter  int unsigned FPU               = 0,
  parameter  int unsigned PULP_ZFINX        = 0,
  parameter  type         regfile_write_t   = logic,
  parameter  type         regfile_raddr_t   = logic,
  parameter  type         regfile_rdata_t   = logic,
  localparam int unsigned DataWidth         = ( ECCEnabled ) ? ProtectedWidth
                                                             : NonProtectedWidth
)(
  // Clock and Reset
  input logic clk_i,
  input logic rst_ni,

  //Read port R1
  input  logic [ADDR_WIDTH-1:0]        raddr_a_i,
  output logic [NonProtectedWidth-1:0] rdata_a_o,

  //Read port R2
  input  logic [ADDR_WIDTH-1:0]        raddr_b_i,
  output logic [NonProtectedWidth-1:0] rdata_b_o,

  //Read port R3
  input  logic [ADDR_WIDTH-1:0]      raddr_c_i,
  output logic [NonProtectedWidth:0] rdata_c_o,

  // Write port W1
  input logic [ADDR_WIDTH-1:0]        waddr_a_i,
  input logic [NonProtectedWidth-1:0] wdata_a_i,
  input logic                         we_a_i,

  // Write port W2
  input logic [ADDR_WIDTH-1:0]        waddr_b_i,
  input logic [NonProtectedWidth-1:0] wdata_b_i,
  input logic                         we_b_i
);

  // number of integer registers
  localparam int unsigned NumWords = 2 ** (ADDR_WIDTH - 1);
  // number of floating point registers
  localparam int unsigned NumFpWords = 2 ** (ADDR_WIDTH - 1);
  localparam int unsigned NumTotWords =
    FPU ? (PULP_ZFINX ? NumWords : NumWords + NumFpWords) : NumWords;

  // integer register file
  logic [NumWords-1:0][NonProtectedWidth-1:0] mem;
  logic [NumWords-1:0][        DataWidth-1:0] ecc_mem;
  // fp register file
  logic [NumFpWords-1:0][NonProtectedWidth-1:0] mem_fp;
  logic [NumFpWords-1:0][        DataWidth-1:0] ecc_mem_fp;

  logic [DataWidth-1:0] wdata_a,
                        wdata_b;

  // masked write addresses
  logic [ADDR_WIDTH-1:0] waddr_a;
  logic [ADDR_WIDTH-1:0] waddr_b;

  // write enable signals for all registers
  logic [NumTotWords-1:0] we_a_dec;
  logic [NumTotWords-1:0] we_b_dec;

  generate
    if (ECCEnabled) begin : gen_ecc_region

      prim_secded_39_32_enc a_port_ecc_encoder (
        .in  ( wdata_a_i ),
        .out ( wdata_a   )
      );

      prim_secded_39_32_enc b_port_ecc_encoder (
        .in  ( wdata_b_i ),
        .out ( wdata_b   )
      );

      for (genvar index = 0; index < NumWords; index++) begin : gen_internal_decoder
        prim_secded_39_32_dec internal_memory_decoder (
          .in         ( ecc_mem [index] ),
          .d_o        ( mem [index]     ),
          .syndrome_o (                 ),
          .err_o      (                 )
        );
      end

      if (FPU == 1 && PULP_ZFINX == 0) begin : gen_fp_decoders
        for (genvar index = 0; index < NumFpWords; index++) begin : gen_internal_fp_decoder
          prim_secded_39_32_dec internal_fp_memory_decoder (
            .in         ( ecc_mem_fp [index]  ),
            .d_o        ( mem_fp [index]      ),
            .syndrome_o (                     ),
            .err_o      (                     )
          );
        end
      end
    end else begin : gen_no_ecc_region
      assign wdata_a     = wdata_a_i;
      assign wdata_b     = wdata_b_i;

      for (genvar index = 0; index < NumWords; index++)
        assign mem [index] = ecc_mem [index];

      for (genvar index = 0; index < NumFpWords; index++)
        assign mem_fp [index] = ecc_mem_fp [index];
    end
  endgenerate

  //-----------------------------------------------------------------------------
  //-- READ : Read address decoder RAD
  //-----------------------------------------------------------------------------
  generate
    if (FPU == 1 && PULP_ZFINX == 0) begin : gen_mem_fp_read
      assign rdata_a_o = raddr_a_i[5] ? mem_fp[raddr_a_i[4:0]] : mem[raddr_a_i[4:0]];
      assign rdata_b_o = raddr_b_i[5] ? mem_fp[raddr_b_i[4:0]] : mem[raddr_b_i[4:0]];
      assign rdata_c_o = raddr_c_i[5] ? mem_fp[raddr_c_i[4:0]] : mem[raddr_c_i[4:0]];
    end else begin : gen_mem_read
      assign rdata_a_o = mem[raddr_a_i[4:0]];
      assign rdata_b_o = mem[raddr_b_i[4:0]];
      assign rdata_c_o = mem[raddr_c_i[4:0]];
    end
  endgenerate

  //-----------------------------------------------------------------------------
  //-- WRITE : Write Address Decoder (WAD), combinatorial process
  //-----------------------------------------------------------------------------

  // Mask top bit of write address to disable fp regfile
  assign waddr_a = waddr_a_i;
  assign waddr_b = waddr_b_i;

  genvar gidx;
  generate
    for (gidx = 0; gidx < NumTotWords; gidx++) begin : gen_we_decoder
      assign we_a_dec[gidx] = (waddr_a == gidx) ? we_a_i : 1'b0;
      assign we_b_dec[gidx] = (waddr_b == gidx) ? we_b_i : 1'b0;
    end
  endgenerate

  genvar i, l;
  generate

    //-----------------------------------------------------------------------------
    //-- WRITE : Write operation
    //-----------------------------------------------------------------------------
    // R0 is nil
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (~rst_ni) begin
        // R0 is nil
        ecc_mem[0] <= 32'b0;
      end else begin
        // R0 is nil
        ecc_mem[0] <= 32'b0;
      end
    end

    // loop from 1 to NumWords-1 as R0 is nil
    for (i = 1; i < NumWords; i++) begin : gen_rf
      always_ff @(posedge clk_i, negedge rst_ni) begin : register_write_behavioral
        if (rst_ni == 1'b0) begin
          ecc_mem[i] <= 32'b0;
        end else begin
          if (we_b_dec[i] == 1'b1) ecc_mem[i] <= wdata_b;
          else if (we_a_dec[i] == 1'b1) ecc_mem[i] <= wdata_a;
        end
      end
    end

    if (FPU == 1 && PULP_ZFINX == 0) begin : gen_mem_fp_write
      // Floating point registers
      for (l = 0; l < NumFpWords; l++) begin : gen_fp_regs
        always_ff @(posedge clk_i, negedge rst_ni) begin : fp_regs
          if (rst_ni == 1'b0) begin
            ecc_mem_fp[l] <= '0;
          end else begin
            if (we_b_dec[l+NumWords] == 1'b1) ecc_mem_fp[l] <= wdata_b;
            else if (we_a_dec[l+NumWords] == 1'b1) ecc_mem_fp[l] <= wdata_a;
          end
        end
      end
    end else begin : gen_no_mem_fp_write
      assign ecc_mem_fp = 'b0;
    end

  endgenerate

endmodule
