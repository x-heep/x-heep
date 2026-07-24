/*
 * Copyright 2026 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Info: Direct Memory Access (DMA) channel module.
 */

<%
  ch_num = dma.get_num_channels()
  master_ports = dma.get_num_master_ports()
  ch_length = dma.get_ch_length()
  fifo_depth = dma.get_fifo_depth()
  channels_per_master = dma.get_num_channels_per_master_port()
%>

package dma_pkg;

  import addr_map_rule_pkg::*;

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

  localparam int DMA_CH_NUM = ${ch_num};
  localparam DMA_CH_SIZE = 32'h${hex(ch_length)[2:]};
  localparam int DMA_NUM_MASTER_PORTS = ${master_ports};

% if master_ports > 1:
  localparam int DMA_XBAR_MASTERS [DMA_NUM_MASTER_PORTS] = '{${dma.get_xbar_array()[::-1]}};
% else:
  localparam int DMA_XBAR_MASTERS [DMA_NUM_MASTER_PORTS] = '{${dma.get_xbar_array()}};
% endif

  localparam int DMA_FIFO_DEPTH = ${fifo_depth};

  localparam int unsigned DMA_CH_PORT_SEL_WIDTH = DMA_CH_NUM > 1 ? $clog2(DMA_CH_NUM) : 32'd1;

endpackage
