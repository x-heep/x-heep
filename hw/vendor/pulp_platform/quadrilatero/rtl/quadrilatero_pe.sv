// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio


// Update the module to output a signal to let the controller know if a pump has occurred! In case the MAC unit stalls the pump, 
// the controller might think it has indeed finished thus defeating the purpose of handling multi-cycle MAC operations.
module quadrilatero_pe #(
    parameter DATA_WIDTH  = 32,
    parameter ENABLE_SIMD = 1,
    parameter FPU = 1
) (
    input  logic clk_i ,
    input  logic rst_ni,

    input quadrilatero_pkg::sa_ctrl_t sa_ctrl_i,  // whether 32,16,8 bit op (only has effect if ENABLE_SIMD == 1)
    input  logic                     pump_i       ,  // pump data out of the cell

    input  logic [DATA_WIDTH-1:0]    acc_i        ,  // Accumulator from Top
    input  logic [DATA_WIDTH-1:0]    data_i       ,  // Data from Left
    input  logic [DATA_WIDTH-1:0]    weight_i     ,  // Weight
    output quadrilatero_pkg::sa_ctrl_t sa_ctrl_o,
    output logic [DATA_WIDTH-1:0]    data_o       ,  // Data to Right
    output logic [DATA_WIDTH-1:0]    acc_o           // Accumulator to Bottom

);

  quadrilatero_pkg::sa_ctrl_t sa_ctrl_d; 
  quadrilatero_pkg::sa_ctrl_t sa_ctrl_q;  
  logic [DATA_WIDTH-1:0]     acc_d        ;
  logic [DATA_WIDTH-1:0]     acc_q        ;
  logic [DATA_WIDTH-1:0]     data_d       ;
  logic [DATA_WIDTH-1:0]     data_q       ;
  logic [DATA_WIDTH-1:0]     weight_d     ;
  logic [DATA_WIDTH-1:0]     weight_q     ;
   
  logic [DATA_WIDTH-1:0]     int_acc      ;
  logic [DATA_WIDTH-1:0]     int_data     ;
  logic [DATA_WIDTH-1:0]     int_weight   ;
  logic [DATA_WIDTH-1:0]     int_acc_out  ;
  logic                      int_pump     ; 
  logic [DATA_WIDTH-1:0]     fp_acc       ;
  logic [DATA_WIDTH-1:0]     fp_data      ;
  logic [DATA_WIDTH-1:0]     fp_weight    ;
  logic [DATA_WIDTH-1:0]     fp_acc_out   ;
  logic                      fp_pump      ; 
  logic is_float;
  quadrilatero_pkg::datatype_t fp_datatype;

  assign is_float = sa_ctrl_i.is_float;

  generate
    if(FPU) begin: gen_mac_float
    quadrilatero_mac_float mac_float_inst (
        .clk_i                          ,
        .rst_ni                         ,
        .weight_i           (fp_weight) ,
        .data_i             (fp_data)   ,
        .acc_i              (fp_acc)    ,
        .datatype_i         (fp_datatype),
        .valid_i            (fp_pump)   ,
        .acc_o              (fp_acc_out),
        .mac_finished_o     ()
    );
    end else begin
      assign fp_acc_out = '0;
    end

  endgenerate

  quadrilatero_mac_int #(
      .ENABLE_SIMD(ENABLE_SIMD)
  ) mac_int_inst (
      .weight_i           (int_weight),
      .data_i             (int_data),
      .acc_i              (int_acc),
      .op_datatype_i      (sa_ctrl_q.datatype),
      .acc_o              (int_acc_out),
      .mac_finished_o     ()
  );

  always_comb begin: signals_block
    int_acc     = sa_ctrl_q.is_float ? '0       : acc_q   ;
    int_data    = sa_ctrl_q.is_float ? '0       : data_q  ;
    int_weight  = sa_ctrl_q.is_float ? '0       : weight_q;
    int_pump    = sa_ctrl_q.is_float ? '0       : pump_i  ;

    fp_acc      = is_float ? acc_i    : '0      ;
    fp_data     = is_float ? data_i   : '0      ;
    fp_weight   = is_float ? weight_i : '0      ;
    fp_pump     = is_float ? pump_i   : '0      ;
    fp_datatype = is_float ? sa_ctrl_i.datatype : quadrilatero_pkg::SIZE_32 ;
  end

  always_comb begin: next_value
    data_d        = pump_i ? data_i        : data_q       ;
    acc_d         = pump_i ? acc_i         : acc_q        ;
    weight_d      = pump_i ? weight_i      : weight_q     ;
    sa_ctrl_d     = pump_i ? sa_ctrl_i     : sa_ctrl_q    ;
  end

  // Sequential Block
  always_ff @(posedge clk_i or negedge rst_ni) begin : seq_block
    if (!rst_ni) begin
      data_q        <= '0;
      acc_q         <= '0;
      weight_q      <= '0;
      sa_ctrl_q     <= '0;
    end else begin
      data_q        <= data_d       ;
      acc_q         <= acc_d        ;
      weight_q      <= weight_d     ;
      sa_ctrl_q     <= sa_ctrl_d;
    end
  end

  // Output Assignments
  assign acc_o     = sa_ctrl_q.is_float ? fp_acc_out : int_acc_out;
  assign data_o    = data_q                                       ;
  assign sa_ctrl_o = sa_ctrl_q                                    ;

endmodule
