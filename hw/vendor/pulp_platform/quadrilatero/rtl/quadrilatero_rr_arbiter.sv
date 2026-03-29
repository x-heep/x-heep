// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

module quadrilatero_rr_arbiter #(
    parameter NumActOut = 3,
    parameter N_ROWS = 4   ,
    parameter WIDTH = 8
) (
    input  logic             clk_i  ,
    input  logic             rst_ni ,
    input  logic [WIDTH-1:0] req_i  ,
    output logic [WIDTH-1:0] grant_o
);

  logic [WIDTH-1:0]          base_q;
  logic [WIDTH-1:0]          new_base;
  logic [WIDTH-1:0]          base_d;
  logic [2*WIDTH-1:0]        double_req; 
  logic [WIDTH-1:0]          grant;
  logic [2*WIDTH-1:0]        double_grant;
  logic [$clog2(N_ROWS)-1:0] cnt_d;
  logic [$clog2(N_ROWS)-1:0] cnt_q;
  int act;
  
  always_comb begin
    double_req   = {req_i,req_i};
    double_grant = '0;
    grant_o      = '0;
    new_base     = '0;

    act = 0;
    for(int ii= $clog2(base_q); ii< $clog2(base_q)+WIDTH; ii++) begin
      if(double_req[ii]) begin
        act += 1;
        double_grant[ii] = 1'b1;
        if(act == NumActOut) begin
          new_base[ii%WIDTH] = 1'b1;
          break; 
        end
      end
    end

    grant_o = double_grant[WIDTH-1:0] | double_grant[2*WIDTH-1:WIDTH];
    cnt_d   = (|grant_o) ? cnt_q + 1 : cnt_q;
    base_d  = ((cnt_q == N_ROWS-1) && |new_base) ? new_base : base_q;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin 
      base_q <=  1;
      cnt_q  <= '0;
    end else begin
      base_q <= base_d;
      cnt_q  <= cnt_d ;
    end
  end
endmodule
