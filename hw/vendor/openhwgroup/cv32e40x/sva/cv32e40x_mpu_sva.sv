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
// Description:    MPU (Memory Protection Unit) assertions                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_mpu_sva import cv32e40x_pkg::*; import uvm_pkg::*;
  #(  parameter int          PMA_NUM_REGIONS              = 0,
      parameter pma_cfg_t    PMA_CFG[PMA_NUM_REGIONS-1:0] = '{default:PMA_R_DEFAULT},
      parameter bit          IS_INSTR_SIDE = 0,
      parameter type         CORE_RESP_TYPE = inst_resp_t,
      parameter type         CORE_REQ_TYPE  = obi_inst_req_t,
      parameter a_ext_e      A_EXT = A_NONE,
      parameter bit          DEBUG = 1,
      parameter logic [31:0] DM_REGION_START = 32'hF0000000,
      parameter logic [31:0] DM_REGION_END   = 32'hF0003FFF)
  (
   input logic        clk,
   input logic        rst_n,

   input logic        instr_fetch_access,
   input logic        atomic_access_i,
   input logic        misaligned_access_i,
   input logic        bus_trans_bufferable,
   input logic        bus_trans_cacheable,

   // PMA signals
   input logic        pma_err,
   input logic [31:0] pma_addr,
   input pma_cfg_t    pma_cfg,
   input logic        pma_dbg,

   // Core OBI signals
   input logic [ 1:0] obi_memtype,
   input logic [31:0] obi_addr,
   input logic        obi_req,
   input logic        obi_gnt,
   input logic        obi_dbg,

   input obi_if_state_e obi_if_state,

   // Interface towards bus interface
   input logic        bus_trans_ready_i,
   input logic        bus_trans_valid_o,

   input logic        bus_resp_valid_i,

   // Write buffer signals
   input write_buffer_state_e write_buffer_state,
   input logic        write_buffer_valid_o,
   input logic        write_buffer_txn_bufferable,
   input logic        write_buffer_txn_cacheable,

   // Interface towards core
   input logic         core_trans_valid_i,
   input logic         core_trans_ready_o,
   input CORE_REQ_TYPE core_trans_i,
   input logic         core_trans_pushpop_i,

   input logic        core_resp_valid_o,

   input              mpu_status_e mpu_status,
   input logic        mpu_err_trans_valid,
   input logic        mpu_block_core,
   input logic        mpu_block_bus,
   input              mpu_state_e state_q,
   input logic        mpu_err,
   input logic        load_access
   );

  // PMA assertions helper signals

  logic is_addr_match;

  // Not checking bits [1:0]; bit 0 is always 0; bit 1 is not checked because it is only
  // suppressed after the PMA. These address bits are also ignored by the PMA itself.
  assign is_addr_match = obi_addr[31:2] == pma_addr[31:2];

  // Check if a transaction matches DM_REGION while in debug mode
  logic is_pma_dbg_matched;

  assign is_pma_dbg_matched = (core_trans_i.addr >= DM_REGION_START && core_trans_i.addr <= DM_REGION_END) && core_trans_i.dbg;

  logic was_obi_waiting;
  logic was_obi_reqnognt;
  logic [1:0] was_obi_memtype;
  assign was_obi_waiting = was_obi_reqnognt && !bus_trans_ready_i;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      was_obi_reqnognt <= 0;
      was_obi_memtype <= 0;
    end
    else begin
      was_obi_reqnognt <= obi_req && !obi_gnt;
      was_obi_memtype <= obi_memtype;
    end
  end

  function logic bufferable_in_config;
    bufferable_in_config = 0;
    foreach (PMA_CFG[i]) begin
      if (PMA_CFG[i].bufferable) begin
        bufferable_in_config = 1;
      end
    end
  endfunction

  function logic cacheable_in_config;
    cacheable_in_config = 0;
    foreach (PMA_CFG[i]) begin
      if (PMA_CFG[i].cacheable) begin
        cacheable_in_config = 1;
      end
    end
  endfunction

  logic is_lobound_ok;
  logic is_hibound_ok;
  assign is_lobound_ok = {pma_cfg.word_addr_low, 2'b00} <= pma_addr;
  assign is_hibound_ok = pma_addr < {pma_cfg.word_addr_high, 2'b00};

  logic is_pma_matched;
  int pma_match_num;
  logic [$clog2(PMA_NUM_REGIONS)-1:0] pma_lowest_match;
  //int pma_lowest_match;
  always_comb begin
    is_pma_matched = 0;
    pma_match_num = 999;
    pma_lowest_match = 0;

    // Find pma module's attributes among cfgs
    for (int i = 0; i < PMA_NUM_REGIONS; i++) begin
      if ((pma_cfg == PMA_CFG[i]) && (pma_cfg != PMA_R_DEFAULT)) begin
        is_pma_matched = 1;
        pma_match_num = i;
        break;
      end
    end

    // Find lowest region matching addr
    for (int i = 0; i < PMA_NUM_REGIONS; i++) begin
      if (({PMA_CFG[i].word_addr_low, 2'b00} <= pma_addr) && (pma_addr < {PMA_CFG[i].word_addr_high, 2'b00})) begin
        pma_lowest_match = i;
        break;
      end
    end
  end
  `ifndef FORMAL
    cov_pma_matchnone : cover property (@(posedge clk) disable iff (!rst_n) (!is_pma_matched));
    cov_pma_matchfirst : cover property (@(posedge clk) disable iff (!rst_n) (is_pma_matched && (pma_match_num == 0)));
    cov_pma_matchother : cover property (@(posedge clk) disable iff (!rst_n) (is_pma_matched && (pma_match_num > 0)));
  `endif


  // Checks for illegal PMA region configuration

  always_comb begin
    if (PMA_NUM_REGIONS != 0) begin
      a_pma_valid_config : assert (PMA_NUM_REGIONS == $size(PMA_CFG))
        else `uvm_error("mpu", "PMA_CFG must contain PMA_NUM_REGION entries");
    end
  end

  generate for (genvar i = 0; i < PMA_NUM_REGIONS; i++)
    begin : a_pma_no_illegal_configs
    always_comb begin
        if (PMA_CFG[i].main == 1'b1) begin
          a_main_atomic : assert (PMA_CFG[i].atomic == 1'b1)
            else `uvm_error("mpu", "PMA regions configured as main must also support atomic operations");
        end
        if (PMA_CFG[i].main == 1'b0) begin
          a_io_noncacheable : assert (PMA_CFG[i].cacheable == 1'b0)
            else `uvm_error("mpu", "PMA regions configured as I/O cannot be defined as cacheable");
        end
      end
    end
  endgenerate

  a_pma_valid_num_regions :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (0 <= PMA_NUM_REGIONS) && (PMA_NUM_REGIONS <= 16))
      else `uvm_error("mpu", "PMA number of regions is badly configured")

  // Region matching
  generate
    if (PMA_NUM_REGIONS) begin
      a_pma_match_bounds :
        assert property (@(posedge clk) disable iff (!rst_n)
                         is_pma_matched |-> (is_lobound_ok && is_hibound_ok))
          else `uvm_error("mpu", "PMA region match doesn't fit bounds")
      a_pma_match_lowest :
        assert property (@(posedge clk) disable iff (!rst_n)
                         is_pma_matched |-> (pma_match_num == pma_lowest_match))
          else `uvm_error("mpu", "PMA region match wasn't lowest")
      a_pma_match_index :
        assert property (@(posedge clk) disable iff (!rst_n)
                         is_pma_matched |-> ((0 <= pma_match_num) && (pma_match_num < 16)))
          else `uvm_error("mpu", "illegal cfg index")
    end else begin
      a_pma_match_unreachable :
        assert property (@(posedge clk) disable iff (!rst_n)
          is_pma_matched == 0)
        else `uvm_error("mpu", "No PMA regions defined, PMA should not match any address")
    end
  endgenerate

  // RTL vs SVA expectations
  pma_cfg_t    pma_expected_cfg;
  logic        pma_expected_err;
  logic        pma_expected_misaligned_err;
  always_comb begin
    pma_expected_cfg = NO_PMA_R_DEFAULT;
    if (PMA_NUM_REGIONS) begin
      pma_expected_cfg = is_pma_dbg_matched ? '{main    : 1'b1, default : '0} :
                         is_pma_matched     ? PMA_CFG[pma_lowest_match]       : PMA_R_DEFAULT;

    end
  end
  assign pma_expected_err = (instr_fetch_access && !pma_expected_cfg.main)  ||
                            (misaligned_access_i && !pma_expected_cfg.main) ||
                            (atomic_access_i && !pma_expected_cfg.atomic)   ||
                            (core_trans_pushpop_i && !pma_expected_cfg.main);

  assign pma_expected_misaligned_err = (misaligned_access_i && atomic_access_i);

  a_pma_expect_cfg :
    assert property (@(posedge clk) disable iff (!rst_n) pma_cfg == pma_expected_cfg)
      else `uvm_error("mpu", "RTL cfg don't match SVA expectations")

  generate
    if (bufferable_in_config() && !IS_INSTR_SIDE) begin
    a_pma_expect_bufferable :
      assert property (@(posedge clk) disable iff (!rst_n) bus_trans_bufferable |-> !load_access && !atomic_access_i && pma_expected_cfg.bufferable)
        else `uvm_error("mpu", "expected different bufferable flag")
    end else begin
    a_pma_no_expect_bufferable :
      assert property (@(posedge clk) disable iff (!rst_n) bus_trans_bufferable == '0)
        else `uvm_error("mpu", "expected different bufferable flag")
    end
  endgenerate

  a_pma_expect_cacheable :
    assert property (@(posedge clk) disable iff (!rst_n) bus_trans_cacheable == pma_expected_cfg.cacheable)
      else `uvm_error("mpu", "expected different cacheable flag")

  a_pma_expect_err :
    assert property (@(posedge clk) disable iff (!rst_n) pma_err == pma_expected_err)
      else `uvm_error("mpu", "expected different err flag")

  // Bufferable
  generate
    if (bufferable_in_config() && !IS_INSTR_SIDE) begin
      a_pma_obi_bufon :
        assert property (@(posedge clk) disable iff (!rst_n)
                        obi_memtype[0] |-> (bus_trans_bufferable) ||
                                           (write_buffer_txn_bufferable && write_buffer_valid_o))
          else `uvm_error("mpu", "obi should have had bufferable flag")
    end else begin
      a_pma_obi_bufon_unreachable :
        assert property (@(posedge clk) disable iff (!rst_n)
                         !obi_memtype[0])
          else `uvm_error("mpu", "obi should never have bufferable flag with no bufferable pma regions or on instruction side")
   end
  endgenerate

  a_pma_obi_bufoff :
    assert property (@(posedge clk) disable iff (!rst_n)
                    !obi_memtype[0] |-> !bus_trans_bufferable)
      else `uvm_error("mpu", "obi should not have had bufferable flag")

  // Cacheable
  logic obicache_expected;
  logic obicache_excuse;
  assign obicache_expected = bus_trans_cacheable || (IS_INSTR_SIDE && was_obi_reqnognt && was_obi_memtype[1]);
  assign obicache_excuse = IS_INSTR_SIDE && bus_trans_cacheable && (was_obi_reqnognt && !was_obi_memtype[1]);

  generate
    if (cacheable_in_config()) begin
      a_pma_obi_cacheon :
        assert property (@(posedge clk) disable iff (!rst_n)
                         obi_memtype[1] |-> (obicache_expected && !obicache_excuse) ||
                                            (write_buffer_txn_cacheable && write_buffer_valid_o))
          else `uvm_error("mpu", "obi should have had cacheable flag")
    end else begin
      a_pma_obi_cacheon_unreachable :
        assert property (@(posedge clk) disable iff (!rst_n)
                         !obi_memtype[1])
          else `uvm_error("mpu", "obi should not have had cacheable flag")
    end
  endgenerate

  a_pma_obi_cacheoff :
    assert property (@(posedge clk) disable iff (!rst_n)
                     !obi_memtype[1] |-> !(obicache_expected && !obicache_excuse) ||
                                         (!write_buffer_txn_cacheable && write_buffer_valid_o))
      else `uvm_error("mpu", "obi should not have had cacheable flag")


  // OBI req vs PMA err
  a_pma_obi_reqallowed :
    assert property (@(posedge clk) disable iff (!rst_n)
                     obi_req
                     |->
                     // If we have an address match, there must be no PMA error
                     (!pma_err && is_addr_match) ||
                     // or a transaction from the write buffer is causing obi_req
                     // (a different transaction could cause pma_err in the same cycle)
                     (!IS_INSTR_SIDE && (write_buffer_state && write_buffer_valid_o)) ||
                     // or we are already outputting a obi_req but a new address comes in which may cause a pma_err
                     (IS_INSTR_SIDE && (!is_addr_match && (obi_if_state == REGISTERED))) ||
                     // or we get an address match, but was already outputting the same address (no pma_err)
                     // but a change in debug mode causes the new transaction the same address to fail
                     (IS_INSTR_SIDE && (is_addr_match && (obi_if_state == REGISTERED) && (!pma_dbg && obi_dbg))))
      else `uvm_error("mpu", "obi made request to pma-forbidden region")

  generate
    if (PMA_NUM_REGIONS) begin
      a_pma_obi_reqdenied :
        assert property (@(posedge clk) disable iff (!rst_n)
                         pma_err
                         |-> !obi_req ||
                             (was_obi_waiting && $past(obi_req)) ||
                             (write_buffer_state && write_buffer_valid_o))
          else `uvm_error("mpu", "pma error should forbid obi req")
    end else begin
      a_pma_obi_reqdenied :
        assert property (@(posedge clk) disable iff (!rst_n)
                        !pma_err)
        else `uvm_error("mpu", "pma deconfigured, should not trigger error")
    end
  endgenerate

  // Cover PMA signals

  covergroup cg_pma @(posedge clk);
    cp_err: coverpoint pma_err;
    cp_instr: coverpoint instr_fetch_access;
    cp_bufferable: coverpoint bus_trans_bufferable;
    cp_cacheable: coverpoint bus_trans_cacheable;
    cp_atomic: coverpoint atomic_access_i;
    cp_addr: coverpoint pma_addr[31:2] {
      bins min = {0};
      bins max = {30'h 3FFF_FFFF};
      bins range[3] = {[1 : 30'h 3FFF_FFFe]};
      illegal_bins il = default;
      }

    x_err_instr: cross cp_err, cp_instr;
    x_err_bufferable: cross cp_err, cp_bufferable;
    x_err_cacheable: cross cp_err, cp_cacheable;
    x_err_atomic: cross cp_err, cp_atomic;
  endgroup
  `ifndef FORMAL
    cg_pma cgpma = new;
  `endif

  `ifndef FORMAL
    cov_pma_nondefault :
      cover property (@(posedge clk) disable iff (!rst_n)
        (pma_cfg != PMA_R_DEFAULT) && bus_trans_valid_o);
  `endif

  // MPU FSM and bus interface should never assert trans valid at the same time
  a_mpu_bus_mpu_err_valid :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (! (bus_resp_valid_i && mpu_err_trans_valid) ))
      else `uvm_error("mpu", "MPU FSM and bus interface response collision")

  generate
    if (PMA_NUM_REGIONS) begin
      // Should only give MPU error response during mpu_err_trans_valid
      a_mpu_status_no_obi_rvalid :
        assert property (@(posedge clk) disable iff (!rst_n)
                         (mpu_status != MPU_OK) |-> (mpu_err_trans_valid) )
          else `uvm_error("mpu", "MPU error status wile not mpu_err_trans_valid")

      // Should only block core side upon when waiting for MPU error response
      a_mpu_block_core_iff_wait :
        assert property (@(posedge clk) disable iff (!rst_n)
                         (mpu_block_core) |-> (state_q != MPU_IDLE) )
          else `uvm_error("mpu", "MPU blocking core side when not needed")

      // Should only block OBI side upon MPU error
      a_mpu_block_bus_iff_err :
        assert property (@(posedge clk) disable iff (!rst_n)
                         (mpu_block_bus) |-> (mpu_err || (state_q != MPU_IDLE)) )
          else `uvm_error("mpu", "MPU blocking OBI side when not needed")
        end
  endgenerate


  // Check that PMA sets correct attribution for non-atomic accesses DM during debug
  // main, non-cacheable, non-bufferable, non-atomics
  logic [5:0] atop;
  generate
    if (IS_INSTR_SIDE) begin
      assign atop = '0;
    end else begin
      assign atop = core_trans_i.atop;
    end
  endgenerate


if (A_EXT != A_NONE) begin
  if (DEBUG) begin
    // Check that PMA sets correct attribution for non-atomic accesses DM during debug
    // main, non-cacheable, non-bufferable, non-atomics
    a_dm_region_atomic_dbg:
    assert property (@(posedge clk) disable iff (!rst_n)
                      is_pma_dbg_matched &&
                      (|atop)
                      |->
                      pma_err &&               // No atomics allowed to DM region
                      !bus_trans_cacheable &&
                      !bus_trans_bufferable)
          else `uvm_error("mpu", "Wrong attributes for non-atomic access to DM during debug mode")
  end // DEBUG

end

if (DEBUG) begin
  a_dm_region_nonatomic_dbg:
  assert property (@(posedge clk) disable iff (!rst_n)
                  is_pma_dbg_matched &&
                  !(|atop)
                  |->
                  !pma_err &&               // Always 'main' while accessing DM in debug mode
                  !bus_trans_cacheable &&
                  !bus_trans_bufferable)
        else `uvm_error("mpu", "Wrong attributes for non-atomic access to DM during debug mode")
end
endmodule : cv32e40x_mpu_sva

