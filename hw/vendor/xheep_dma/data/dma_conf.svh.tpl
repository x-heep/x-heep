/*
 * Copyright 2025 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <tommaso.terzano@epfl.ch> 
 *                         <tommaso.terzano@gmail.com>
 *  
 * Info: Header file for the DMA subsystem.
 */

<% 
    dma = xheep.get_base_peripheral_domain().get_dma()
    dma_addr_mode = dma.get_addr_mode()
    dma_zero_padding = dma.get_zero_padding()
    dma_subaddr_mode = dma.get_subaddr_mode()
    dma_hw_fifo_mode = dma.get_hw_fifo_mode()
%>

% if dma_addr_mode:
`define ADDR_MODE_EN
% endif
% if dma_zero_padding:
`define ZERO_PADDING_EN
% endif
% if dma_subaddr_mode:
`define SUBADDR_MODE_EN
% endif
% if dma_hw_fifo_mode:
`define HW_FIFO_MODE_EN
% endif
