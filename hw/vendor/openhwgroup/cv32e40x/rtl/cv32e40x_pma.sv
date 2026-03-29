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

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Authors:        Oivind Ekelund - oivind.ekelund@silabs.com                 //
//                                                                            //
// Description:    PMA (Physical Memory Attribution)                          //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_pma import cv32e40x_pkg::*;
#(
  parameter a_ext_e      A_EXT = A_NONE,
  parameter int          PMA_NUM_REGIONS = 0,
  parameter pma_cfg_t    PMA_CFG[PMA_NUM_REGIONS-1:0] = '{default:PMA_R_DEFAULT}
)
(
  input  logic [31:0] trans_addr_i,
  input  logic        trans_debug_region_i, // Transaction address is inside the debug region
  input  logic        trans_pushpop_i,      // Transaction is part of a PUSH or POP sequence
  input  logic        instr_fetch_access_i, // Indicate that ongoing access is an instruction fetch
  input  logic        atomic_access_i,      // Indicate that ongoing access is atomic
  input  logic        misaligned_access_i,  // Indicate that ongoing access is part of a misaligned access
  input  logic        load_access_i,        // Indicate that ongoing access is a load
  output logic        pma_err_o,
  output logic        pma_bufferable_o,
  output logic        pma_cacheable_o
);

  // Attributes for accessing the DM (DM_REGION_START:DM_REGION_END) in debug mode
  localparam pma_cfg_t PMA_DBG = '{word_addr_low   : '0, // not used
                                   word_addr_high  : '0, // not used
                                   main            : 1'b1,
                                   bufferable      : 1'b0,
                                   cacheable       : 1'b0,
                                   atomic          : 1'b0};


  pma_cfg_t pma_cfg;
  logic [31:0] word_addr;
  logic pma_cfg_atomic;

  // PMA addresses are word addresses
  assign word_addr = {2'b00, trans_addr_i[31:2]};

  generate
    if(PMA_NUM_REGIONS == 0) begin: no_pma

      always_comb begin
        // PMA is deconfigured, use NO_PMA_R_DEFAULT as default.
        pma_cfg = NO_PMA_R_DEFAULT;

        // Debug mode transactions within the Debug Module region use PMA_DBG as attributes for the DM range
        if (trans_debug_region_i) begin
          pma_cfg = PMA_DBG;
        end
      end

    end
    else begin: pma

      // Identify PMA region
      always_comb begin

        // If no match, use default PMA config as default.
        pma_cfg = PMA_R_DEFAULT;

        for(int i = PMA_NUM_REGIONS-1; i >= 0; i--)  begin
          if((word_addr >= PMA_CFG[i].word_addr_low) &&
             (word_addr <  PMA_CFG[i].word_addr_high)) begin
            pma_cfg = PMA_CFG[i];
          end
        end

        // Debug mode transactions within the Debug Module region use PMA_DBG as attributes for the DM range
        if (trans_debug_region_i) begin
          pma_cfg = PMA_DBG;
        end
      end
    end

  endgenerate

  // Tie of atomic attribute if A_EXT=0
  generate
    if (A_EXT != A_NONE) begin: pma_atomic
      assign pma_cfg_atomic = pma_cfg.atomic;
    end
    else begin: pma_no_atomic
      assign pma_cfg_atomic = 1'b0;
    end
  endgenerate

  // Check transaction based on PMA region config
  always_comb begin

    pma_err_o = 1'b0;

    // Check for atomic access
    if (atomic_access_i && !pma_cfg_atomic) begin
      pma_err_o = 1'b1;
    end

    // Instruction fetches only allowed in main memory
    if (instr_fetch_access_i && !pma_cfg.main) begin
      pma_err_o   = 1'b1;
    end

    // Misaligned access to I/O memory
    if (misaligned_access_i && !pma_cfg.main) begin
      pma_err_o   = 1'b1;
    end

    // PUSH/POP outside of main is not allowed
    if (trans_pushpop_i && !pma_cfg.main) begin
      pma_err_o   = 1'b1;
    end
  end

  // Set cacheable and bufferable based on PMA region attributes
  // Instruction fetches, atomic operations and loads are never classified as bufferable
  assign pma_bufferable_o = pma_cfg.bufferable && !instr_fetch_access_i && !atomic_access_i && !load_access_i;
  assign pma_cacheable_o  = pma_cfg.cacheable;

endmodule
