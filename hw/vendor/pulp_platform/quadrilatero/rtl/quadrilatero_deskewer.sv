// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

/*
Takes as input a row of skewed values and outputs them in an unskewed manner:

input: 1000
        5200
        9630
        da74
        0eb8
        00fc
        000g

output: 1234
       5678
       9abc
       defg
*/

module quadrilatero_deskewer #(
    parameter MESH_WIDTH = 4,
    parameter DATA_WIDTH = 32
) (
    input logic clk_i,
    input logic rst_ni,

    input logic pump_i,

    input  logic [MESH_WIDTH-1:0][DATA_WIDTH-1:0] data_i,
    output logic [MESH_WIDTH-1:0][DATA_WIDTH-1:0] data_o
);

  assign data_o[MESH_WIDTH-1] = data_i[MESH_WIDTH-1];  // last value always unchanged

  generate
    genvar i;

    for (i = 0; i < MESH_WIDTH - 1; i++) begin  // first element handled already
      logic [MESH_WIDTH-i-2:0][DATA_WIDTH-1:0] backup;
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          backup <= '0;
        end else begin
          if (pump_i) begin
            backup[0] <= data_i[i];
            for (integer j = 1; j < MESH_WIDTH - i - 1; j++) begin
              backup[j] <= backup[j-1];
            end
          end
        end
      end
      assign data_o[i] = backup[MESH_WIDTH-i-2];
    end

  endgenerate


endmodule
