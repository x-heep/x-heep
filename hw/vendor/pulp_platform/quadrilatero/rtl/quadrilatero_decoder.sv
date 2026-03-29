// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

module quadrilatero_decoder
  import quadrilatero_pkg::*;
#(
) (
    input logic [31:0] instr_i,

    // Signals to the controller
    output logic [$clog2(quadrilatero_pkg::MAX_NUM_READ_OPERANDS)-1:0]                         n_matrix_operands_read_o,  // how many RF operands are read from RF
    output logic [        quadrilatero_pkg::MAX_NUM_READ_OPERANDS-1:0][$clog2(N_REGS)-1:0]     rf_read_regs_o          ,  // which registers to read from 
    output logic                                                    [$clog2(N_REGS)-1:0]     rf_writeback_reg_o      ,  // which register to writeback to 
    output logic                                                                             rf_writeback_o          ,
    output logic                                                                             instr_valid_o           ,
    output logic                                                                             is_store_o              ,
    output logic                                                                             is_float_o              ,
    output quadrilatero_pkg::execution_units_t                                                 exec_unit_o             ,
    output quadrilatero_pkg::datatype_t                                                        datatype_o
);

  always_comb begin: decoder_block
    exec_unit_o              = quadrilatero_pkg::FU_SYSTOLIC_ARRAY;
    instr_valid_o            = '0;
    rf_read_regs_o           = '0;
    rf_writeback_reg_o       = '0;
    datatype_o               = quadrilatero_pkg::SIZE_32;
    is_store_o               = '0;
    n_matrix_operands_read_o = '0;
    rf_writeback_o           = '0;
    is_float_o               = 1'b0;

    unique casez (instr_i)
      quadrilatero_instr_pkg::FMMACC_B: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_SYSTOLIC_ARRAY;
        rf_read_regs_o[0]        = instr_i[20:18];  // weight 
        rf_read_regs_o[1]        = instr_i[23:21];  // data
        rf_read_regs_o[2]        = instr_i[17:15];  // accumulator
        rf_writeback_reg_o       = instr_i[17:15];  // accumulator
        n_matrix_operands_read_o = 3;
        rf_writeback_o           = '1;
        datatype_o               = quadrilatero_pkg::SIZE_8;
        is_float_o               = 1'b1;
      end
      quadrilatero_instr_pkg::FMMACC_H: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_SYSTOLIC_ARRAY;
        rf_read_regs_o[0]        = instr_i[20:18];  // weight 
        rf_read_regs_o[1]        = instr_i[23:21];  // data
        rf_read_regs_o[2]        = instr_i[17:15];  // accumulator
        rf_writeback_reg_o       = instr_i[17:15];  // accumulator
        n_matrix_operands_read_o = 3;
        rf_writeback_o           = '1;
        datatype_o               = quadrilatero_pkg::SIZE_16;
        is_float_o               = 1'b1;
      end
      quadrilatero_instr_pkg::FMMACC_S: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_SYSTOLIC_ARRAY;
        rf_read_regs_o[0]        = instr_i[20:18];  // weight 
        rf_read_regs_o[1]        = instr_i[23:21];  // data
        rf_read_regs_o[2]        = instr_i[17:15];  // accumulator
        rf_writeback_reg_o       = instr_i[17:15];  // accumulator
        n_matrix_operands_read_o = 3;
        rf_writeback_o           = '1;
        datatype_o               = quadrilatero_pkg::SIZE_32;
        is_float_o               = 1'b1;
      end
      quadrilatero_instr_pkg::MMAQA_B: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_SYSTOLIC_ARRAY;
        rf_read_regs_o[0]        = instr_i[20:18];  // weight 
        rf_read_regs_o[1]        = instr_i[23:21];  // data
        rf_read_regs_o[2]        = instr_i[17:15];  // accumulator
        rf_writeback_reg_o       = instr_i[17:15];  // accumulator
        n_matrix_operands_read_o = 3;
        rf_writeback_o           = '1;
        datatype_o               = quadrilatero_pkg::SIZE_8;
      end
      quadrilatero_instr_pkg::MMADA_H: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_SYSTOLIC_ARRAY;
        rf_read_regs_o[0]        = instr_i[20:18];  // weight 
        rf_read_regs_o[1]        = instr_i[23:21];  // data
        rf_read_regs_o[2]        = instr_i[17:15];  // accumulator
        rf_writeback_reg_o       = instr_i[17:15];  // accumulator
        n_matrix_operands_read_o = 3;
        rf_writeback_o           = '1;
        datatype_o               = quadrilatero_pkg::SIZE_16;
      end
      quadrilatero_instr_pkg::MMASA_W: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_SYSTOLIC_ARRAY;
        rf_read_regs_o[0]        = instr_i[20:18];  // weight 
        rf_read_regs_o[1]        = instr_i[23:21];  // data
        rf_read_regs_o[2]        = instr_i[17:15];  // accumulator
        rf_writeback_reg_o       = instr_i[17:15];  // accumulator
        n_matrix_operands_read_o = 3;
        rf_writeback_o           = '1;
        datatype_o               = quadrilatero_pkg::SIZE_32;
      end
      /*
       quadrilatero_instr_pkg::MCFG       : begin
       end
       quadrilatero_instr_pkg::MCFGK      : begin
       end
       quadrilatero_instr_pkg::MCFGKI     : begin
       end
       quadrilatero_instr_pkg::MCFGM      : begin
       end
       quadrilatero_instr_pkg::MCFGMI     : begin
       end
       quadrilatero_instr_pkg::MCFGN      : begin
       end
       quadrilatero_instr_pkg::MCFGNI     : begin
       end
       */
      // quadrilatero_instr_pkg::MLD_B: begin
      //   instr_valid_o            = '1;
      //   exec_unit_o              = quadrilatero_pkg::FU_LSU;
      //   rf_writeback_reg_o       = instr_i[9:7];
      //   datatype_o               = quadrilatero_pkg::SIZE_8;
      //   rf_writeback_o           = '1;
      // end
      /*
        quadrilatero_instr_pkg::MLD_D: begin
        instr_valid_o            = '1;
        exec_unit_o   = quadrilatero_pkg::FU_LSU;
        rf_writeback_reg_o       = instr_i[9:7];
        end
      */
      // quadrilatero_instr_pkg::MLD_H: begin
      //   instr_valid_o            = '1;
      //   exec_unit_o              = quadrilatero_pkg::FU_LSU;
      //   rf_writeback_reg_o       = instr_i[9:7];
      //   datatype_o               = quadrilatero_pkg::SIZE_16;
      //   rf_writeback_o           = '1;
      // end
      quadrilatero_instr_pkg::MLD_W: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_LSU;
        rf_writeback_reg_o       = instr_i[9:7];
        datatype_o               = quadrilatero_pkg::SIZE_32;
        rf_writeback_o           = '1;
      end
      /*
         quadrilatero_instr_pkg::MMOV_MM    : begin
         end
       */
      quadrilatero_instr_pkg::MST_B: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_LSU;
        datatype_o               = quadrilatero_pkg::SIZE_8;
        n_matrix_operands_read_o = 1;
        rf_read_regs_o[0]        = instr_i[9:7];
        is_store_o = '1;
      end
      /*
        quadrilatero_instr_pkg::MST_D: begin
        instr_valid_o            = '1;
        exec_unit_o   = quadrilatero_pkg::FU_LSU;
        rf_writeback_reg_o       = instr_i[9:7];
        end
      */
      quadrilatero_instr_pkg::MST_H: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_LSU;
        datatype_o               = quadrilatero_pkg::SIZE_16;
        n_matrix_operands_read_o = 1;
        rf_read_regs_o[0]        = instr_i[9:7];
        is_store_o = '1;
      end
      quadrilatero_instr_pkg::MST_W: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_LSU;
        datatype_o               = quadrilatero_pkg::SIZE_32;
        n_matrix_operands_read_o = 1;
        rf_read_regs_o[0]        = instr_i[9:7];
        is_store_o = '1;
      end
      quadrilatero_instr_pkg::MZERO: begin
        instr_valid_o            = '1;
        exec_unit_o              = quadrilatero_pkg::FU_RF;
        rf_writeback_reg_o       = instr_i[17:15];
        datatype_o               = quadrilatero_pkg::SIZE_32;
        rf_writeback_o           = '1;
      end
      default: begin
      end

    endcase
  end

endmodule
