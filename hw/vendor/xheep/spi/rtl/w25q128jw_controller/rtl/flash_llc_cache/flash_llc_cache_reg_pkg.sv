// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Patrick Pataky     <patrick.pataky@epfl.ch>
//                            <patdb10@gmail.com>

package flash_llc_cache_reg_pkg;

  parameter int N_WAYS = 1;  // Currently implements only 1 WAY
  parameter int N_SETS = 4;
  parameter int SECTOR_SIZE_BYTES = 4096;

  parameter int WORD_SIZE_BYTES = 4;
  parameter int BYTE_SIZE_BITS = 8;
  parameter int WORD_SIZE_BITS = WORD_SIZE_BYTES * BYTE_SIZE_BITS;  // 32
  parameter int SECTOR_SIZE_WORDS = SECTOR_SIZE_BYTES / WORD_SIZE_BYTES;  // 1024

  parameter int N_WAYS_WIDTH = (N_WAYS > 1) ? $clog2(N_WAYS) : 1;  // 1
  parameter int N_SETS_WIDTH = (N_SETS > 1) ? $clog2(N_SETS) : 1;  // 2
  parameter int SECTOR_SIZE_BYTES_WIDTH = (SECTOR_SIZE_BYTES > 1) ? $clog2(
      SECTOR_SIZE_BYTES
  ) : 1;  // 12
  parameter int SECTOR_SIZE_WORDS_WIDTH = (SECTOR_SIZE_WORDS > 1) ? $clog2(
      SECTOR_SIZE_WORDS
  ) : 1;  // 10

  parameter int ADDR_WIDTH = 24;  // FLASH memory is 16MiB, byte-addressable
  parameter int TAG_WIDTH = ADDR_WIDTH - N_SETS_WIDTH - SECTOR_SIZE_BYTES_WIDTH;  // 10
  parameter int SECTOR_ADDRESS_WIDTH = ADDR_WIDTH - SECTOR_SIZE_BYTES_WIDTH;  // 12

  parameter int N_WORDS = N_SETS * SECTOR_SIZE_WORDS;

  parameter type data_t = logic [WORD_SIZE_BITS-1:0];
  parameter type be_t = logic [(WORD_SIZE_BITS / BYTE_SIZE_BITS)-1:0];

  typedef union packed {
    logic [ADDR_WIDTH-1:0] exposed;

    // Packed fields: tag[23:14] | set[13:12] | byte_offset[11:0]
    struct packed {
      logic [TAG_WIDTH-1:0]               tag;
      logic [N_SETS_WIDTH-1:0]            set;
      logic [SECTOR_SIZE_BYTES_WIDTH-1:0] byte_offset;
    } internal;
  } addr_t;

  typedef enum logic [2:0] {
    CACHE_IDLE,
    CACHE_CHECK,  // Check for hit/miss
    CACHE_READ,   // stream word from cache -> DMA
    CACHE_WRITE,  // stream word from DMA -> cache
    CACHE_EVICT   // set sector as invalid within the cache
  } cache_op_e;

  // Cache request
  typedef struct packed {
    logic req;  // high on a new request
    cache_op_e op;  // read or write
    addr_t addr;  // address to read/write, byte-addressable
    logic [SECTOR_SIZE_WORDS_WIDTH:0]     word_count; // number of words to read/write in current request
    logic dirty;  // (Write only) 1 if sector written is dirty, 0 if clean
  } cache_req_t;

  // Cache response
  typedef struct packed {
    logic                            dirty;                  // 1 if dirty, 0 if clean
    logic [SECTOR_ADDRESS_WIDTH-1:0] victim_sector_address;  // {tag, set}
  } eviction_info_t;

  typedef struct packed {
    logic           hit;        // 1 if hit, 0 if miss
    eviction_info_t miss_info;  // Only in case of miss, to handle eviction
  } cache_res_t;

endpackage
