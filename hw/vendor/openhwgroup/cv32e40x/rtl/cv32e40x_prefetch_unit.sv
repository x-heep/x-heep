// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Design Name:    Prefetcher Buffer for 32 bit memory interface              //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Prefetch unit that prefetches instructions and store them  //
//                 in a buffer that extracts compressed and uncompressed      //
//                 instructions.                                              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// input port: send address one cycle before the data
// clear_i clears the FIFO for the following cycle. in_addr_i can be sent in
// this cycle already

module cv32e40x_prefetch_unit import cv32e40x_pkg::*;
#(
    parameter bit CLIC                     = 1'b0,
    parameter int unsigned ALBUF_DEPTH     = 3,
    parameter int unsigned ALBUF_CNT_WIDTH = $clog2(ALBUF_DEPTH)
)
(
  input  logic        clk,
  input  logic        rst_n,

  input  ctrl_fsm_t   ctrl_fsm_i,

  input  logic [31:0] branch_addr_i,

  input  logic        prefetch_ready_i,
  output logic        prefetch_valid_o,
  output inst_resp_t  prefetch_instr_o,
  output logic [31:0] prefetch_addr_o,
  output privlvl_t    prefetch_priv_lvl_o,
  output logic        prefetch_is_clic_ptr_o,
  output logic        prefetch_is_mret_ptr_o,
  output logic        prefetch_is_tbljmp_ptr_o,

  // Transaction interface to obi interface
  output logic        trans_valid_o,
  input  logic        trans_ready_i,
  output logic [31:0] trans_addr_o,
  output logic        trans_ptr_o,

  input  logic        resp_valid_i,
  input  inst_resp_t  resp_i,

  output logic                       one_txn_pend_n,
  output logic [ALBUF_CNT_WIDTH-1:0] outstnd_cnt_q_o,

  // Prefetch Buffer Status
  output logic        prefetch_busy_o
);

  logic fetch_valid;
  logic fetch_ready;

  logic        fetch_branch;
  logic [31:0] fetch_branch_addr;
  logic        fetch_ptr_access;
  logic        fetch_ptr_resp;
  privlvl_t    fetch_priv_lvl_access;
  privlvl_t    fetch_priv_lvl_resp;



  //////////////////////////////////////////////////////////////////////////////
  // Prefetcher
  //////////////////////////////////////////////////////////////////////////////

  cv32e40x_prefetcher
  #(
      .CLIC  (CLIC)
  )
  prefetcher_i
  (
    .clk                      ( clk                  ),
    .rst_n                    ( rst_n                ),

    .fetch_branch_i           ( fetch_branch         ),
    .fetch_branch_addr_i      ( fetch_branch_addr    ),
    .fetch_valid_i            ( fetch_valid          ),
    .fetch_ready_o            ( fetch_ready          ),
    .fetch_ptr_access_i       ( fetch_ptr_access     ),
    .fetch_ptr_access_o       ( fetch_ptr_resp       ),
    .fetch_priv_lvl_access_i  ( fetch_priv_lvl_access),
    .fetch_priv_lvl_access_o  ( fetch_priv_lvl_resp  ),
    .trans_valid_o            ( trans_valid_o        ),
    .trans_ready_i            ( trans_ready_i        ),
    .trans_addr_o             ( trans_addr_o         ),
    .trans_ptr_o              ( trans_ptr_o          )
  );


  cv32e40x_alignment_buffer
  #(
    .ALBUF_DEPTH(ALBUF_DEPTH),
    .ALBUF_CNT_WIDTH(ALBUF_CNT_WIDTH)
  )
  alignment_buffer_i
  (
    .clk                   ( clk                     ),
    .rst_n                 ( rst_n                   ),

    .ctrl_fsm_i            ( ctrl_fsm_i              ),

    .branch_addr_i         ( branch_addr_i           ),
    .prefetch_busy_o       ( prefetch_busy_o         ),

    // prefetch unit
    .fetch_valid_o         ( fetch_valid             ),
    .fetch_ready_i         ( fetch_ready             ),
    .fetch_branch_o        ( fetch_branch            ),
    .fetch_branch_addr_o   ( fetch_branch_addr       ),
    .fetch_ptr_access_o    ( fetch_ptr_access        ),
    .fetch_ptr_access_i    ( fetch_ptr_resp          ),
    .fetch_priv_lvl_o      ( fetch_priv_lvl_access   ),
    .fetch_priv_lvl_i      ( fetch_priv_lvl_resp     ),

    .resp_valid_i          ( resp_valid_i            ),
    .resp_i                ( resp_i                  ),
    .one_txn_pend_n        ( one_txn_pend_n          ),
    .outstnd_cnt_q_o       ( outstnd_cnt_q_o         ),

    // Instruction interface
    .instr_valid_o         ( prefetch_valid_o        ),
    .instr_ready_i         ( prefetch_ready_i        ),
    .instr_instr_o         ( prefetch_instr_o        ),
    .instr_addr_o          ( prefetch_addr_o         ),
    .instr_priv_lvl_o      ( prefetch_priv_lvl_o     ),
    .instr_is_clic_ptr_o   ( prefetch_is_clic_ptr_o  ),
    .instr_is_mret_ptr_o   ( prefetch_is_mret_ptr_o  ),
    .instr_is_tbljmp_ptr_o ( prefetch_is_tbljmp_ptr_o)

  );

endmodule
