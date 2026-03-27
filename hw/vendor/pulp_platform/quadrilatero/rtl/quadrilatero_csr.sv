// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

// NOT FUNCTIONING / TESTED
module quadrilatero_csr 
#(

  parameter RLEN = 4096, // length in bits for each register row
  localparam N_ROWS = RLEN / 32 // this is done in the thead spec

)(
    input logic clk_i,
    input logic rst_ni,


);


  typedef struct packed {
      logic [32 - $clog2(N_ROWS)-1:0] reserved; 
      logic [$clog2(N_ROWS)-1:0] row_index; 
  } xmrstart; // 32-bits

  typedef struct packed {
  } xmcsr; // 32-bits

  typedef struct packed {
  } xmsize; // 32-bits

  typedef struct packed {
      logic [32 - $clog2((RLEN / 8) * (N_ROWS))-1:0] reserved; 
      logic [$clog2((RLEN / 8) * (N_ROWS))-1:0] mlen; 
  } xmlenb; // 32-bits read only

  typedef struct packed {
      logic [32 - $clog2(RLEN/8)-1:0] reserved; 
      logic [$clog2(RLEN / 8)-1:0] rlen; 
  } xrlenb; // 32-bits read only

  typedef struct packed {
    logic [21:0] reserved;
    logic MULT_F32F64;
    logic MULT_F16F32;
    logic PW_I32;
    logic PW_I64;
    logic MULT_F64F64;
    logic MULT_F32F32;
    logic MULT_F16F16;
    logic MULT_I16I64;
    logic MULT_I8I32; // this should be 1 compulsatory
    logic MULT_I4I32;
  } xmisa; // 32-bits read only


  logic xrlenb xrlenb_reg;
  logic xmlenb xmlenb_reg;
  logic xmrstart xmrstart_reg;
  logic xmcsr xmcsr_reg;
  logic xmsize xmsize_reg;
  logic xmisa xmisa_reg;


  always_comb begin : read_only_regs
    xrlenb_reg.reserved = '0;
    xmlenb_reg.rlen = RLEN / 8;

    xmlenb_reg.reserved = '0;
    xrlenb_reg.mlen = N_ROWS * (RLEN / 8);

    xmcsr_reg.reserved = '0;

    xmrstart_reg.reserved = '0;
    
    xmisa_reg = {27'b0, 1'b1, 4'b0}; // MULTF32F32 supported only

    xmrstart_reg.reserved = '0;
    
  end


endmodule // fpu_ss_csr
