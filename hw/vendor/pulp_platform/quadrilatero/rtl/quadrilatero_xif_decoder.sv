// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

// This handles only the decoding handshake with the issue xif interface port
// Actual decoding of the instruction is delegated to cps_decoder


module quadrilatero_xif_decoder#() (
    input  logic[31:0]             instr_i       ,
    output xif_pkg::x_issue_resp_t x_issue_resp_o
);

  xif_pkg::x_issue_resp_t default_resp;

  xif_pkg::x_issue_resp_t instr_fmmacc_b ;  // FMMACC_B
  xif_pkg::x_issue_resp_t instr_fmmacc_h ;  // FMMACC_H
  xif_pkg::x_issue_resp_t instr_fmmacc_s ;  // FMMACC_S
  xif_pkg::x_issue_resp_t instr_mmaqa_b  ;  // MMAQA_B
  xif_pkg::x_issue_resp_t instr_mmada_h  ;  // MMADA_H
  xif_pkg::x_issue_resp_t instr_mmasa_w  ;  // MMASA_W
  // xif_pkg::x_issue_resp_t instr_mcfg     ;  // MCFG
  // xif_pkg::x_issue_resp_t instr_mcfgk    ;  // MCFGK
  // xif_pkg::x_issue_resp_t instr_mcfgki   ;  // MCFGKI
  // xif_pkg::x_issue_resp_t instr_mcfgm    ;  // MCFGM
  // xif_pkg::x_issue_resp_t instr_mcfgmi   ;  // MCFGMI
  // xif_pkg::x_issue_resp_t instr_mcfgn    ;  // MCFGN
  // xif_pkg::x_issue_resp_t instr_mcfgni   ;  // MCFGNI
  // xif_pkg::x_issue_resp_t instr_mld_b    ;  // MLD_B
  // xif_pkg::x_issue_resp_t instr_mld_d    ;  // MLD_D
  // xif_pkg::x_issue_resp_t instr_mld_h    ;  // MLD_H
  xif_pkg::x_issue_resp_t instr_mld_w    ;  // MLD_W
  // xif_pkg::x_issue_resp_t instr_mmov_mm  ;  // MMOV_MM
  xif_pkg::x_issue_resp_t instr_mst_b    ;  // MST_B
  // xif_pkg::x_issue_resp_t instr_mst_d    ;  // MST_D
  xif_pkg::x_issue_resp_t instr_mst_h    ;  // MST_H
  xif_pkg::x_issue_resp_t instr_mst_w    ;  // MST_W
  xif_pkg::x_issue_resp_t instr_mzero    ;  // MZERO

  always_comb begin: generate_response
    default_resp.accept    = 1'b1;
    default_resp.writeback = 1'b0;
    default_resp.dualwrite = 1'b0;
    default_resp.dualread  = 3'h0;
    default_resp.loadstore = 1'b0;
    default_resp.ecswrite  = 1'b0;
    default_resp.exc       = 1'b0;

    instr_mmaqa_b  = default_resp;
    instr_mmada_h  = default_resp;
    instr_mmasa_w  = default_resp;
    instr_fmmacc_b = default_resp;
    instr_fmmacc_h = default_resp;
    instr_fmmacc_s = default_resp;
    // instr_mcfg     = default_resp;
    // instr_mcfgk    = default_resp;
    // instr_mcfgki   = default_resp;
    // instr_mcfgm    = default_resp;
    // instr_mcfgmi   = default_resp;
    // instr_mcfgn    = default_resp;
    // instr_mcfgni   = default_resp;
    // instr_mld_b    = default_resp;
    // instr_mld_h    = default_resp;
    instr_mld_w    = default_resp;
    // instr_mld_d    = default_resp;
    // instr_mmov_mm  = default_resp;
    instr_mst_b    = default_resp;
    instr_mst_h    = default_resp;
    instr_mst_w    = default_resp;
    // instr_mst_d    = default_resp;
    instr_mzero    = default_resp;

    // instr_mcfg.writeback   = 1'b1;
    // instr_mcfgk.writeback  = 1'b1;
    // instr_mcfgki.writeback = 1'b1;
    // instr_mcfgm.writeback  = 1'b1;
    // instr_mcfgmi.writeback = 1'b1;
    // instr_mcfgn.writeback  = 1'b1;
    // instr_mcfgni.writeback = 1'b1;
  end

  always_comb begin: decoder_block
    unique casez (instr_i)
      quadrilatero_instr_pkg::FMMACC_B: x_issue_resp_o = instr_fmmacc_b;
      quadrilatero_instr_pkg::FMMACC_H: x_issue_resp_o = instr_fmmacc_h;
      quadrilatero_instr_pkg::FMMACC_S: x_issue_resp_o = instr_fmmacc_s;
      quadrilatero_instr_pkg::MMAQA_B : x_issue_resp_o = instr_mmaqa_b ;
      quadrilatero_instr_pkg::MMADA_H : x_issue_resp_o = instr_mmada_h ;
      quadrilatero_instr_pkg::MMASA_W : x_issue_resp_o = instr_mmasa_w ;
      // quadrilatero_instr_pkg::MLD_B   : x_issue_resp_o = instr_mld_b   ;
      // quadrilatero_instr_pkg::MLD_H   : x_issue_resp_o = instr_mld_h   ;
      quadrilatero_instr_pkg::MLD_W   : x_issue_resp_o = instr_mld_w   ;
      quadrilatero_instr_pkg::MST_B   : x_issue_resp_o = instr_mst_b   ;
      quadrilatero_instr_pkg::MST_H   : x_issue_resp_o = instr_mst_h   ;
      quadrilatero_instr_pkg::MST_W   : x_issue_resp_o = instr_mst_w   ;
      quadrilatero_instr_pkg::MZERO   : x_issue_resp_o = instr_mzero   ;
      default                       : x_issue_resp_o = '0;
    endcase
  end

endmodule
