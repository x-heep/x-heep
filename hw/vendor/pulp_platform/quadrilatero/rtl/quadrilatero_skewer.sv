// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

/*
Takes as input a row of values and outputs them in a skewed manner:
input: 1234
       5678
       9abc
       defg

output: 1000
        5200
        9630
        da74
        0eb8
        00fc
        000g
*/
module quadrilatero_skewer #(
    parameter MESH_WIDTH = 4,
    parameter DATA_WIDTH = 32
) (
    input logic clk_i,
    input logic rst_ni,

    input logic pump_i,

    input  logic [MESH_WIDTH-1:0][DATA_WIDTH-1:0] data_i,
    output logic [MESH_WIDTH-1:0][DATA_WIDTH-1:0] data_o
);

  assign data_o[0] = data_i[0];  // first value always unchanged

  generate
    genvar i;

    for (i = 1; i < MESH_WIDTH; i++) begin  // first element handled already
      logic [i-1:0][DATA_WIDTH-1:0] backup;
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          backup <= '0;
          //data_o[i] <= '0;
        end else begin
          if (pump_i) begin
            backup[0] <= data_i[i];
            for (integer j = 1; j < i; j++) begin
              backup[j] <= backup[j-1];
            end
          end
        end
      end
      assign data_o[i] = backup[i-1];
    end


  endgenerate



endmodule
