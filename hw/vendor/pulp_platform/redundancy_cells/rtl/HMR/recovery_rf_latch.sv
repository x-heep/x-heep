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
// Engineer:       Antonio Pullini - pullinia@iis.ee.ethz.ch                  //
//                                                                            //
// Additional contributions by:                                               //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    RISC-V register file                                       //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Register file with 31x 32 bit wide registers. Register 0   //
//                 is fixed to 0. This register file is based on latches and  //
//                 is thus smaller than the flip-flop based register file.    //
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
) (
  // Clock and Reset
  input logic clk_i,
  input logic rst_ni,

  input logic test_en_i,

  //Read port R1
  input  logic [ADDR_WIDTH-1:0]        raddr_a_i,
  output logic [NonProtectedWidth-1:0] rdata_a_o,

  //Read port R2
  input  logic [ADDR_WIDTH-1:0]        raddr_b_i,
  output logic [NonProtectedWidth-1:0] rdata_b_o,

  //Read port R3
  input  logic [ADDR_WIDTH-1:0]        raddr_c_i,
  output logic [NonProtectedWidth-1:0] rdata_c_o,

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
  logic [NonProtectedWidth-1:0] mem     [NumWords];
  logic [        DataWidth-1:0] ecc_mem [NumWords];
  logic [NumTotWords-1:1] waddr_onehot_a;
  logic [NumTotWords-1:1] waddr_onehot_b  ,
                            waddr_onehot_b_q;
  logic [NumTotWords-1:1] mem_clocks;
  logic [DataWidth-1:0] wdata_a    ,
                        wdata_a_q  ,
                        wdata_a_ecc;
  logic [DataWidth-1:0] wdata_b    ,
                        wdata_b_q  ,
                        wdata_b_ecc;

  // masked write addresses
  logic [ADDR_WIDTH-1:0] waddr_a;
  logic [ADDR_WIDTH-1:0] waddr_b;

  logic clk_int;

  // fp register file
  logic [NonProtectedWidth-1:0] mem_fp     [NumFpWords];
  logic [        DataWidth-1:0] ecc_mem_fp [NumFpWords];

  int unsigned i;
  int unsigned j;
  int unsigned k;
  int unsigned l;

  genvar x;
  genvar y;

  generate
    if (ECCEnabled) begin : gen_ecc_region

      prim_secded_39_32_enc a_port_ecc_encoder (
        .in  ( wdata_a_i  ),
        .out ( wdata_a_ecc)
      );
      assign wdata_a = wdata_a_ecc;

      prim_secded_39_32_enc b_port_ecc_encoder (
        .in  ( wdata_b_i  ),
        .out ( wdata_b_ecc)
      );
      assign wdata_b = wdata_b_ecc;

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
      assign wdata_a_ecc = '0;
      assign wdata_b     = wdata_b_i;
      assign wdata_b_ecc = '0;

      for (genvar index = 0; index < NumWords; index++)
        assign mem [index] = ecc_mem [index];

      for (genvar index = 0; index < NumFpWords; index++)
        assign mem_fp [index] = ecc_mem_fp [index];
    end
  endgenerate

  //-----------------------------------------------------------------------------
  //-- READ : Read address decoder RAD
  //-----------------------------------------------------------------------------
  if (FPU == 1 && PULP_ZFINX == 0) begin : gen_mem_fp_read
    assign rdata_a_o = raddr_a_i[5] ? mem_fp[raddr_a_i[4:0]] : mem[raddr_a_i[4:0]];
    assign rdata_b_o = raddr_b_i[5] ? mem_fp[raddr_b_i[4:0]] : mem[raddr_b_i[4:0]];
    assign rdata_c_o = raddr_c_i[5] ? mem_fp[raddr_c_i[4:0]] : mem[raddr_c_i[4:0]];
  end else begin : gen_standard_read
    assign rdata_a_o = mem[raddr_a_i[4:0]];
    assign rdata_b_o = mem[raddr_b_i[4:0]];
    assign rdata_c_o = mem[raddr_c_i[4:0]];
  end

  //-----------------------------------------------------------------------------
  // WRITE : SAMPLE INPUT DATA
  //---------------------------------------------------------------------------

  tc_clk_gating CG_WE_GLOBAL (
      .clk_i     ( clk_i           ),
      .en_i      ( we_a_i | we_b_i ),
      .test_en_i ( test_en_i       ),
      .clk_o     ( clk_int         )
  );

  // use clk_int here, since otherwise we don't want to write anything anyway
  always_ff @(posedge clk_int, negedge rst_ni) begin : sample_waddr
    if (~rst_ni) begin
      wdata_a_q        <= '0;
      wdata_b_q        <= '0;
      waddr_onehot_b_q <= '0;
    end else begin
      if (we_a_i) wdata_a_q <= wdata_a;

      if (we_b_i) wdata_b_q <= wdata_b;

      waddr_onehot_b_q <= waddr_onehot_b;
    end
  end

  //-----------------------------------------------------------------------------
  //-- WRITE : Write Address Decoder (WAD), combinatorial process
  //-----------------------------------------------------------------------------

  assign waddr_a = waddr_a_i;
  assign waddr_b = waddr_b_i;

  genvar gidx;
  generate
    for (gidx = 1; gidx < NumTotWords; gidx++) begin : gen_we_decoder
      assign waddr_onehot_a[gidx] = (we_a_i == 1'b1) && (waddr_a == gidx);
      assign waddr_onehot_b[gidx] = (we_b_i == 1'b1) && (waddr_b == gidx);
    end
  endgenerate

  //-----------------------------------------------------------------------------
  //-- WRITE : Clock gating (if integrated clock-gating cells are available)
  //-----------------------------------------------------------------------------
  generate
    for (x = 1; x < NumTotWords; x++) begin : gen_clock_gate
      tc_clk_gating clock_gate_i (
          .clk_i     ( clk_int                               ),
          .en_i      ( waddr_onehot_a[x] | waddr_onehot_b[x] ),
          .test_en_i ( test_en_i                             ),
          .clk_o     ( mem_clocks[x]                         )
      );
    end
  endgenerate

  //-----------------------------------------------------------------------------
  //-- WRITE : Write operation
  //-----------------------------------------------------------------------------
  //-- Generate M = WORDS sequential processes, each of which describes one
  //-- word of the memory. The processes are synchronized with the clocks
  //-- ClocksxC(i), i = 0, 1, ..., M-1
  //-- Use active low, i.e. transparent on low latches as storage elements
  //-- Data is sampled on rising clock edge

  // Integer registers
  always_latch begin : latch_wdata
    // Note: The assignment has to be done inside this process or Modelsim complains about it
    ecc_mem[0] = '0;

    for (k = 1; k < NumWords; k++) begin : w_WordIter
      if (~rst_ni) ecc_mem[k] = '0;
      else if (mem_clocks[k] == 1'b1) ecc_mem[k] = waddr_onehot_b_q[k] ? wdata_b_q : wdata_a_q;
    end
  end

  if (FPU == 1 && PULP_ZFINX == 0) begin : gen_mem_fp_latch
    // Floating point registers
    always_latch begin : latch_wdata_fp
      if (FPU == 1) begin
        for (l = 0; l < NumFpWords; l++) begin : w_WordIter
          if (~rst_ni) ecc_mem_fp[l] = '0;
          else if (mem_clocks[l+NumWords] == 1'b1)
            ecc_mem_fp[l] = waddr_onehot_b_q[l+NumWords] ? wdata_b_q : wdata_a_q;
        end
      end
    end
  end
endmodule
