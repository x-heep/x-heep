// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

module quadrilatero_mesh #(
    parameter MESH_WIDTH  = 4,
    parameter DATA_WIDTH  = 32,
    parameter ENABLE_SIMD = 1,
    parameter FPU = 1
) (
    input  logic                                                  clk_i,
    input  logic                                                  rst_ni,

    input  logic                                                  pump_i   ,
    input  quadrilatero_pkg::sa_ctrl_t[MESH_WIDTH-1:0]              sa_ctrl_i,

    input  logic                 [MESH_WIDTH-1:0][DATA_WIDTH-1:0] data_i   , // From left
    input  logic                 [MESH_WIDTH-1:0][DATA_WIDTH-1:0] acc_i    , // From Top
    input  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0][DATA_WIDTH-1:0] weight_i ,
    output logic                 [MESH_WIDTH-1:0][DATA_WIDTH-1:0] acc_o
);


  logic [MESH_WIDTH-1:0][MESH_WIDTH  :0][DATA_WIDTH-1:0]     data_internal   ;
  logic [MESH_WIDTH  :0][MESH_WIDTH-1:0][DATA_WIDTH-1:0]     acc_internal    ;   
  quadrilatero_pkg::sa_ctrl_t[MESH_WIDTH-1:0][MESH_WIDTH  :0]  sa_ctrl_internal;

  genvar i, j;
  generate
    for (i = 0; i < MESH_WIDTH; i++) begin : rows
      for (j = 0; j < MESH_WIDTH; j++) begin : cols 

        quadrilatero_pe #(
            .DATA_WIDTH (DATA_WIDTH ),
            .ENABLE_SIMD(ENABLE_SIMD),
            .FPU        (FPU        )
        ) pe_inst (
            .clk_i                                   ,
            .rst_ni                                  ,
            .pump_i                                  ,
            .sa_ctrl_i      (sa_ctrl_internal[i][j]    ),

            .acc_i          (acc_internal[i][j]     ),
            .data_i         (data_internal[i][j]    ),
            .weight_i       (weight_i[i][j]         ),   

            .sa_ctrl_o      (sa_ctrl_internal[i][j+1]    ),
            .acc_o          (acc_internal[i+1][j]   ),
            .data_o         (data_internal[i][j+1]  )
        );


      end
    end


    for (j = 0; j < MESH_WIDTH; j++) begin
      assign acc_internal[0][j] = acc_i[j];
    end

    for (j = 0; j < MESH_WIDTH; j++) begin
      assign acc_o[j] = acc_internal[MESH_WIDTH][j];
    end

    for (i = 0; i < MESH_WIDTH; i++) begin
      assign data_internal[i][0] = data_i[i];
      assign sa_ctrl_internal[i][0] = sa_ctrl_i[i];
    end

  endgenerate

endmodule
