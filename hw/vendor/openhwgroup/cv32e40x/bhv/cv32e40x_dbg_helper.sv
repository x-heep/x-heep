// Copyright 2021 Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License");
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
// See the License for the specific language governing permissions and
// limitations under the License.

///////////////////////////////////////////////////////////////////////////////////////
//                                                                                   //
// Authors:        Oivind Ekelund - oivind.ekelund@silabs.com                        //
//                                                                                   //
// Description:    This module contains helper signals intended to aid in debugging  //
//                                                                                   //
///////////////////////////////////////////////////////////////////////////////////////

module cv32e40x_dbg_helper
  import cv32e40x_pkg::*;
  #(
    parameter int unsigned REGFILE_NUM_READ_PORTS = 2
  )
  ( input logic [31:0]                       instr,
    input logic                              is_compressed,
    input logic [REGFILE_NUM_READ_PORTS-1:0] rf_re,
    input                                    rf_addr_t rf_raddr[REGFILE_NUM_READ_PORTS],
    input logic                              rf_we,
    input                                    rf_addr_t rf_waddr,
    input logic                              illegal_insn);


  typedef struct {
    logic [31:0] instr;
    logic        is_compressed;
    opcode_e     opcode;
    logic     [REGFILE_NUM_READ_PORTS-1:0] rf_re;
    rf_addr_t [REGFILE_NUM_READ_PORTS-1:0] rf_raddr;
    logic        rf_we;
    rf_addr_t    rf_waddr;
    logic        illegal_insn;
  } dbg_help_t;

  dbg_help_t dbg_help;

  assign dbg_help.instr         = instr;
  assign dbg_help.is_compressed = is_compressed;
  assign dbg_help.opcode        = opcode_e'(instr[6:0]);
  assign dbg_help.rf_re         = rf_re;
  assign dbg_help.rf_we         = rf_we;
  assign dbg_help.rf_waddr      = rf_waddr;
  assign dbg_help.illegal_insn  = illegal_insn;

  // Convert from unpacked to packed array (for verilator support)
  genvar i;
  generate for (i=0; i<REGFILE_NUM_READ_PORTS; i++)
    begin: gen_dbg_rf_raddr
      assign dbg_help.rf_raddr[i] = rf_raddr[i];
    end
  endgenerate



endmodule
