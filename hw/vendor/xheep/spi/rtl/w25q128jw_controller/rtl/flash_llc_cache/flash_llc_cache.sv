// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// SRAM bank instantiation heavily inspired by:
//   "hw/vendor/pulp_platform/tech_cells_generic/src/fpga/tc_sram_xilinx.sv"
//   "hw/ip_examples/slow_memory/rtl/slow_memory.sv"
//
// Author: Patrick Pataky     <patrick.pataky@epfl.ch>
//                            <patdb10@gmail.com>

module flash_llc_cache
  import flash_llc_cache_reg_pkg::*;
  import power_manager_pkg::*;
#(
    // OBI Interface data types
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // Power control
    input  power_manager_out_t pwr_ctrl_i,
    output power_manager_in_t  pwr_ctrl_o,

    // DMA (SLAVE) communication
    input  obi_req_t dma_req_i,
    output obi_rsp_t dma_resp_o,

    // Controller (MASTER) communication
    input  cache_req_t controller_req_i,
    output cache_res_t controller_resp_o,

    // Address the hit/miss lookup (`controller_resp_o`) is answered for. It is answered
    // combinationally, so the controller can decide hit vs miss in the very cycle it
    // issues its request. It MUST be driven from registered state / module inputs only,
    // never from `controller_resp_o`, otherwise a combinational loop is created.
    input addr_t lookup_addr_i,

    input  logic  mem_man_req_i,
    input  be_t   memio_be_i,
    input  data_t memio_wdata_i,
    output logic  valid_bridge_o,
    output data_t mem_rdata_o
);

  // Currently implements single way cache (direct-mapped) only
  // === N_WAYS = 1 ===

  localparam int unsigned SramAddrWidth = $clog2(N_WORDS);

  cache_op_e active_op_q, active_op_d;
  logic [SECTOR_SIZE_WORDS_WIDTH-1:0] word_counter_q, word_counter_d;

  // Sector address registered at start of READ/WRITE
  logic [N_SETS_WIDTH-1:0] target_set_q, target_set_d;
  logic [TAG_WIDTH-1:0] target_tag_q, target_tag_d;
  logic [SECTOR_SIZE_WORDS_WIDTH:0]
      target_word_len_q, target_word_len_d;  // Number of words to transfer
  logic
      target_dirty_q,
      target_dirty_d; // Only valid for WRITE, indicates whether the sector being written is dirty or clean

  // Cache way(s) signals
  logic                             hit;
  logic                             dirty;
  logic  [SECTOR_ADDRESS_WIDTH-1:0] victim_sector;
  logic                             last_sector_word;

  // Cache Port signals
  logic                             mem_req;
  logic                             mem_we;
  logic  [       SramAddrWidth-1:0] mem_addr;
  data_t                            mem_wdata;
  be_t                              mem_be;

  logic                             gnt;
  logic                             rvalid;

  // FSM state, word counter, and target sector address
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      active_op_q       <= CACHE_IDLE;
      word_counter_q    <= '0;
      target_set_q      <= '0;
      target_tag_q      <= '0;
      target_word_len_q <= '0;
      target_dirty_q    <= '0;
    end else begin
      active_op_q       <= active_op_d;
      word_counter_q    <= word_counter_d;
      target_set_q      <= target_set_d;
      target_tag_q      <= target_tag_d;
      target_word_len_q <= target_word_len_d;
      target_dirty_q    <= target_dirty_d;
    end
  end

  always_comb begin
    active_op_d       = active_op_q;
    word_counter_d    = word_counter_q;
    target_set_d      = target_set_q;
    target_tag_d      = target_tag_q;
    target_word_len_d = target_word_len_q;
    target_dirty_d    = target_dirty_q;

    // Last word of the sector is being transferred in current cycle
    last_sector_word  = (target_word_len_q == 'h1) & dma_req_i.req;

    if (controller_req_i.req) begin
      active_op_d       = controller_req_i.op;
      target_set_d      = controller_req_i.addr.internal.set;
      target_tag_d      = controller_req_i.addr.internal.tag;
      target_word_len_d = controller_req_i.word_count;
      target_dirty_d    = controller_req_i.dirty;

      // Start at requested word offset within sector
      word_counter_d    = controller_req_i.addr.internal.byte_offset[SECTOR_SIZE_BYTES_WIDTH-1:2];
    end else begin
      unique case (active_op_q)
        CACHE_CHECK: begin
          // Return to IDLE after checking for hit/miss
          active_op_d = CACHE_IDLE;
        end

        CACHE_READ, CACHE_WRITE: begin
          if (dma_req_i.req) begin
            target_word_len_d = target_word_len_q - 1'b1;
            word_counter_d    = word_counter_q    + 1'b1;

            if (last_sector_word) begin
              active_op_d = CACHE_IDLE;
            end
          end
        end

        CACHE_EVICT: begin
          // Eviction completes immediately as we mark the sector as invalid in the cache way metadata
          active_op_d = CACHE_IDLE;
        end

        default: ;
      endcase
    end
  end

  // Cache Accesses
  always_comb begin
    mem_req   = 1'b0;
    mem_we    = 1'b0;
    mem_addr  = '0;
    mem_wdata = '0;
    mem_be    = '0;

    if (dma_req_i.req) begin
      unique case (active_op_q)
        CACHE_WRITE: begin
          mem_req   = 1'b1;
          mem_we    = 1'b1;
          mem_addr  = SramAddrWidth'({target_set_q, word_counter_q});
          mem_wdata = dma_req_i.wdata;
          mem_be    = dma_req_i.be;
        end

        CACHE_READ: begin
          mem_req  = 1'b1;
          mem_we   = 1'b0;
          mem_addr = SramAddrWidth'({target_set_q, word_counter_q});
          mem_be   = dma_req_i.be;
        end

        default: ;
      endcase
    end else if (mem_man_req_i) begin
      unique case (active_op_d)
        CACHE_WRITE: begin
          mem_req   = 1'b1;
          mem_we    = 1'b1;
          mem_addr  = SramAddrWidth'({target_set_d, word_counter_d});
          mem_wdata = memio_wdata_i;
          mem_be    = memio_be_i;
        end

        CACHE_READ: begin
          mem_req  = 1'b1;
          mem_we   = 1'b0;
          mem_addr = SramAddrWidth'({target_set_d, word_counter_d});
          mem_be   = 4'hf;
        end

        default: ;
      endcase
    end
  end

  // Cache valid signal
  // - grand only when the new operation is registered
  assign gnt = (active_op_q == CACHE_READ) | (active_op_q == CACHE_WRITE);

  logic clk_cg;
  always_ff @(posedge clk_cg or negedge rst_ni) begin
    if (!rst_ni) begin
      rvalid <= '0;
      valid_bridge_o <= '0;
    end else begin
      rvalid <= gnt & dma_req_i.req;
      valid_bridge_o <= mem_man_req_i;
    end
  end

  // Cache way metadata
  flash_llc_cache_way way (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .active_op_i(active_op_q),
      .lookup_set_i(lookup_addr_i.internal.set),
      .lookup_tag_i(lookup_addr_i.internal.tag),
      .current_set_i(target_set_q),
      .current_tag_i(target_tag_q),
      .request_dirty_i(target_dirty_q),
      .last_sector_word_i(last_sector_word),

      .hit_o(hit),
      .dirty_o(dirty),
      .victim_sector_o(victim_sector)
  );

  tc_clk_gating clk_gating_cell_i (
      .clk_i,
      .en_i(pwr_ctrl_i.clkgate_en_n),
      .test_en_i(1'b0),
      .clk_o(clk_cg)
  );

  // Cache data (SRAM bank)
  sram_wrapper #(
      .NumWords (N_WORDS),        // Number of Words in data array
      .DataWidth(WORD_SIZE_BITS)  // Data signal width (in bits)
  ) cache_data (
      .clk_i  (clk_cg),
      .rst_ni (rst_ni),
      .req_i  (mem_req),
      .we_i   (mem_we),
      .addr_i (mem_addr),
      .wdata_i(mem_wdata),
      .be_i   (mem_be),
      // Power signal
      .pwrgate_ni(pwr_ctrl_i.pwrgate_en_n),
      .pwrgate_ack_no(pwr_ctrl_o.pwrgate_ack_n),
      .set_retentive_ni(pwr_ctrl_i.retentive_en_n),
      // output ports
      .rdata_o(mem_rdata_o)
  );

  // Output assignments

  // DMA response
  assign dma_resp_o.gnt = gnt;
  assign dma_resp_o.rvalid = rvalid;
  assign dma_resp_o.rdata = mem_rdata_o;

  // Controller response
  assign controller_resp_o.hit = hit;

  assign controller_resp_o.miss_info.dirty = dirty;
  assign controller_resp_o.miss_info.victim_sector_address = victim_sector;

endmodule
