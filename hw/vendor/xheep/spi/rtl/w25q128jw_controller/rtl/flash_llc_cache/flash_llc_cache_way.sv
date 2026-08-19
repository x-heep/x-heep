// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// This module contains the metadata for each of the cache ways.
// It is used to check a hit/miss, if the line is dirty and which line to replace
// if needed.
//
// The cache data lives in `cache.sv`.
//
// Author: Patrick Pataky     <patrick.pataky@epfl.ch>
//                            <patdb10@gmail.com>

module flash_llc_cache_way
  import flash_llc_cache_reg_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input cache_op_e active_op_i,

    // Lookup index: address currently *presented* by the controller. The metadata is
    // combinational on it so hit/dirty/victim are answered in the same cycle the request
    // is issued, before the address is registered.
    input logic [N_SETS_WIDTH-1:0] lookup_set_i,
    input logic [TAG_WIDTH-1:0] lookup_tag_i,

    // Update index: address of the operation currently in flight (registered), used to
    // update the metadata when the operation completes.
    input logic [N_SETS_WIDTH-1:0] current_set_i,
    input logic [TAG_WIDTH-1:0] current_tag_i,
    input logic request_dirty_i, // Only valid for WRITE, indicates whether the sector being written is dirty or clean
    input logic last_sector_word_i,

    output logic                            hit_o,
    output logic                            dirty_o,
    output logic [SECTOR_ADDRESS_WIDTH-1:0] victim_sector_o  // Only defined in case of miss
);

  logic [N_SETS-1:0] valid;
  logic [N_SETS-1:0] dirty;
  logic [TAG_WIDTH-1:0] tags[N_SETS-1:0];

  logic lookup_hit;
  logic update_hit;

  assign lookup_hit = valid[lookup_set_i] & (tags[lookup_set_i] == lookup_tag_i);
  assign update_hit = valid[current_set_i] & (tags[current_set_i] == current_tag_i);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid <= 'h0;
      dirty <= 'h0;

      for (int i = 0; i < N_SETS; i++) tags[i] <= 'h0;
    end else begin
      unique case (active_op_i)
        CACHE_WRITE: begin
          // Sector is now fully in cache (valid), and may be dirty if it's a write
          if (last_sector_word_i) begin
            valid[current_set_i] <= 1'b1;
            dirty[current_set_i] <= request_dirty_i;
            tags[current_set_i]  <= current_tag_i;
          end
        end

        CACHE_EVICT: begin
          // Sector is evicted (not valid)
          if (update_hit) begin
            valid[current_set_i] <= 1'b0;
          end
        end

        default: ;
      endcase
    end
  end

  assign hit_o = lookup_hit;
  assign dirty_o = dirty[lookup_set_i];
  assign victim_sector_o = {tags[lookup_set_i], lookup_set_i};

endmodule
