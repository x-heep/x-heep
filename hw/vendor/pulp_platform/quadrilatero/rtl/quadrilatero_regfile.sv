// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

module quadrilatero_regfile #(
    parameter READ_PORTS = 3,  // number of read ports of the register file
    parameter WRITE_PORTS = 2,  // number of write ports 
    parameter N_REGS = 8,  // how many registers
    parameter RLEN = 128,  // length in bits for each register row
    localparam N_ROWS = RLEN / 32  // this is done in the thead spec
) (
    // clock and reset
    input logic clk_i,
    input logic rst_ni,

    // read port
    input  logic [READ_PORTS-1:0][$clog2(N_REGS)-1:0] raddr_i,  // register and port address
    input  logic [READ_PORTS-1:0][$clog2(N_ROWS)-1:0] rrowaddr_i,  // we can ask for a single row of a register
    output logic [READ_PORTS-1:0][RLEN-1:0] rdata_o,  // row out

    // write port
    input logic [WRITE_PORTS-1:0][$clog2(N_REGS)-1:0] waddr_i,
    input logic [WRITE_PORTS-1:0][$clog2(N_ROWS)-1:0] wrowaddr_i,
    input logic [WRITE_PORTS-1:0][          RLEN-1:0] wdata_i,
    input logic [WRITE_PORTS-1:0]                     we_i

);

`ifdef SIMULATION
  // Multiple of 2 and less than 2**16
  if (!(RLEN < (1 << 16) && $countones(RLEN) == 1)) begin
    $fatal("invalid register configuration");
  end
`endif

  logic [N_REGS-1:0][N_ROWS-1:0][RLEN-1:0] mem_q;
  logic [N_REGS-1:0][N_ROWS-1:0][RLEN-1:0] mem_d;
  
  always_comb begin : write_mem
    mem_d = mem_q;
    for (int j = 0; j < WRITE_PORTS; j++) begin
      if (we_i[j]) begin
        mem_d[waddr_i[j]][wrowaddr_i[j]] = wdata_i[j];
      end
    end
  end

  always_comb begin : read_mem
    for (int j = 0; j < READ_PORTS; j++) begin
      rdata_o[j] = mem_q[raddr_i[j]][rrowaddr_i[j]];    
    end
  end

  // Sequential block: memory
  always_ff @(posedge clk_i, negedge rst_ni) begin: seq_block
    if (~rst_ni) begin
      mem_q <= '0;
    end else begin
      mem_q <= mem_d;
    end
  end


endmodule
