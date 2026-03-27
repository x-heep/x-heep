// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

module quadrilatero_mac_int #(
    //parameter DATA_WIDTH = 32
    parameter ENABLE_SIMD = 1
) (
    input logic [32-1:0] data_i,
    input logic [32-1:0] weight_i,
    input logic [32-1:0] acc_i,

    // Only has effect if ENABLE_SIMD == 1
    input quadrilatero_pkg::datatype_t op_datatype_i,  // whether 32,16,8 bit op

    output logic mac_finished_o,
    output logic [32-1:0] acc_o

);

  logic [32-1:0] data_x_weight;
  assign mac_finished_o = 1;  // always take 1 cycle in our case
  assign acc_o = acc_i + data_x_weight;

  generate

    if (ENABLE_SIMD) begin

      always_comb begin
        data_x_weight = '0;

        case (op_datatype_i)

          quadrilatero_pkg::SIZE_32: begin
            data_x_weight = data_i * weight_i;
          end

          quadrilatero_pkg::SIZE_16: begin
            for (integer i = 0; i < 2; i++) begin
              data_x_weight += {{16{data_i  [i*16+15]}},data_i  [i*16+:16]} * 
                               {{16{weight_i[i*16+15]}},weight_i[i*16+:16]};
            end
          end

          quadrilatero_pkg::SIZE_8: begin
            for (integer i = 0; i < 4; i++) begin
              data_x_weight += {{24{data_i  [i*8+7]}},data_i  [i*8+:8]} * 
                               {{24{weight_i[i*8+7]}},weight_i[i*8+:8]};
            end
          end

          default: data_x_weight = 32'hcacacaca;
        endcase
      end


    end else begin
      assign data_x_weight = data_i * weight_i;
    end

  endgenerate

endmodule
