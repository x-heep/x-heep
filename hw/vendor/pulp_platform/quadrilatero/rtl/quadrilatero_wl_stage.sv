// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

module quadrilatero_wl_stage #(
    parameter MESH_WIDTH = 4,
    parameter DATA_WIDTH = 32
) (
    input  logic                                                  clk_i               ,
    input  logic                                                  rst_ni              ,

    input  logic [$clog2(MESH_WIDTH)-1 : 0]                       ff_counter          ,
    input  logic                                                  clear_i             ,
    input  logic                                                  pump_i              ,
    input  logic                                                  weight_rdata_valid_i,
    
    // Weight Data 
    input  logic                 [MESH_WIDTH*DATA_WIDTH-1:0]      weight_rdata_i      ,
    output logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0][DATA_WIDTH-1:0] weight_rdata_o      
);


  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0] sel_reg_clr_value  ;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0] sel_reg_new_value  ;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0] sel_reg_d          ;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0] sel_reg_q          ;
  
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0] sel_weight         ;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0] weight_load        ;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0] weight_load_buff1  ;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0] weight_load_buff2  ;

  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0][DATA_WIDTH-1:0]      weight_data_input  ;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0][DATA_WIDTH-1:0]      weight_data_buff1_d;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0][DATA_WIDTH-1:0]      weight_data_buff1_q;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0][DATA_WIDTH-1:0]      weight_data_buff2_d;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0][DATA_WIDTH-1:0]      weight_data_buff2_q;
  logic [MESH_WIDTH-1:0][MESH_WIDTH-1:0][DATA_WIDTH-1:0]      weight_data_output ;


  always_comb begin: sel_reg_block

    // clear_i Value
    sel_reg_clr_value       = '0  ;
    sel_reg_clr_value[0][0] = 1'b1;
    for(int ii=1; ii<MESH_WIDTH ; ii++) begin: clr_rows
      sel_reg_clr_value[ii][MESH_WIDTH-1] = ~sel_reg_clr_value[ii-1][0];

      for(int jj=MESH_WIDTH-2; jj>=0 ; jj--) begin: clr_cols
        sel_reg_clr_value[ii][jj] = sel_reg_clr_value[ii-1][jj+1];
      end
    end

    // New Value
    for(int ii=0; ii<MESH_WIDTH ; ii++) begin: new_value
      sel_reg_new_value[ii] = { sel_reg_q[ii][MESH_WIDTH-2:0], ~sel_reg_q[ii][MESH_WIDTH-1] };
    end
  end

  always_comb begin: ctrl_block
    for(int ii=0; ii<MESH_WIDTH ; ii++) begin: weight_load_rows
      for(int jj=0; jj<MESH_WIDTH ; jj++) begin: weight_load_cols
        sel_weight       [ii][jj] = ($clog2(MESH_WIDTH)'(jj)==ff_counter && ii== 0) ? 1'b1 : 1'b0;
        weight_load      [ii][jj] = ($clog2(MESH_WIDTH)'(jj)==ff_counter) ? weight_rdata_valid_i : 1'b0;  
        weight_load_buff1[ii][jj] = weight_load[ii][jj] &  sel_reg_q[0][0];   
        weight_load_buff2[ii][jj] = weight_load[ii][jj] & ~sel_reg_q[0][0];                               
      end
    end
  end

  always_comb begin: data_block    
    for(int ii=0; ii<MESH_WIDTH ; ii++) begin: weight_data_rows
      for(int jj=0; jj<MESH_WIDTH ; jj++) begin: weight_data_cols
        
        // Input Data
        weight_data_input[ii][jj]  = weight_rdata_i[DATA_WIDTH*ii +: DATA_WIDTH];    

        // Output Data
        weight_data_output[ii][jj] =  (sel_weight[ii][jj]) ? weight_data_input  [ii][jj] :
                                      (sel_reg_q [ii][jj]) ? weight_data_buff1_q[ii][jj] : weight_data_buff2_q[ii][jj];                   
      end
    end
  end

  always_comb begin: next_value
    // Sel Reg signal
    sel_reg_d = clear_i ? sel_reg_clr_value :
                pump_i  ? sel_reg_new_value : sel_reg_q;

    for(int ii=0; ii<MESH_WIDTH ; ii++) begin: weight_data_rows
      for(int jj=0; jj<MESH_WIDTH ; jj++) begin: weight_data_cols

        // Buffer 1
        weight_data_buff1_d[ii][jj] = (clear_i                  ) ? '0                        :
                                      (weight_load_buff1[ii][jj]) ? weight_data_input[ii][jj] : weight_data_buff1_q[ii][jj]; 

        // Buffer 2
        weight_data_buff2_d[ii][jj] = (clear_i                  ) ?  '0                       :
                                      (weight_load_buff2[ii][jj]) ? weight_data_input[ii][jj] : weight_data_buff2_q[ii][jj]; 
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin: seq_block
    if (!rst_ni) begin
      sel_reg_q           <= '0;
      weight_data_buff1_q <= '0;
      weight_data_buff2_q <= '0;
    end else begin
      sel_reg_q           <= sel_reg_d          ;
      weight_data_buff1_q <= weight_data_buff1_d;
      weight_data_buff2_q <= weight_data_buff2_d;
    end
  end

  assign weight_rdata_o = weight_data_output;

  // Assertions
  if (MESH_WIDTH < 2) begin
    $error(
        "[wl_stage] MESH_WIDTH must be at least 2.\n"
    );
  end
endmodule
