/*
 * Copyright 2026 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *  
 * Info: Direct Memory Access (DMA) channel module.
 */


package dma_pkg;

  typedef enum logic [1:0] {
    DMA_DATA_TYPE_WORD,
    DMA_DATA_TYPE_HALF_WORD,
    DMA_DATA_TYPE_BYTE,
    DMA_DATA_TYPE_BYTE_
  } dma_data_type_t;

  typedef enum logic {
    OBI_DATA_REQ,
    OBI_WAIT_GNT
  } dma_obi_state_type_t;

  typedef enum logic [1:0] {
    WAIT_FOR_OUTSTANDING_IDLE,
    WAIT_FOR_OUTSTANDING_WAIT,
    WAIT_FOR_OUTSTANDING_COUNTER
  } dma_wait_for_state_type_t;

endpackage
