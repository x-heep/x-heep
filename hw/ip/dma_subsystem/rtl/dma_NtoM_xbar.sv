/*
 * Copyright 2024 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <tommaso.terzano@epfl.ch> 
 *                         <tommaso.terzano@gmail.com>
 *  
 * Info: Generated N-to-M crossbar.
 *       This module has been developed to be used in the DMA subsystem, in which it is not possible to use an NtoM crossbar.
 *       The problem is that each slave port of the DMA xbar is actually a master port of the system bus. The DMA xbar slave ports 
 *       cannot be indexed by the master's request address because they all perform the same function, they all can read/write 
 *       to/from the same memory spaces.
 *       This module is a workaround to this problem, as it is composed by a number of N-to-1 crossbars, each for a different slave
 *       (which would be a system bus master port).
 *       The amount of masters per crossbar is defined by the parameter NUM_MASTERS_PER_XBAR.
 *       It is thus possible, from an application point of view, to use channels that are guaranteed to have a dedicated master port,
 *       reducing the need for additional arbitration logic.
 */

module dma_NtoM_xbar #(
    parameter int unsigned XBAR_NMASTER = 4,
    parameter int unsigned XBAR_MSLAVE = 2,
    // OBI data types
    parameter type obi_req_t = xheep_obi_pkg::xheep_obi_req_t,
    parameter type obi_rsp_t = xheep_obi_pkg::xheep_obi_rsp_t
) (
    input logic clk_i,
    input logic rst_ni,

    // Master ports
    input  obi_req_t [XBAR_NMASTER-1:0] master_req_i,
    output obi_rsp_t [XBAR_NMASTER-1:0] master_resp_o,

    // slave ports
    output obi_req_t [XBAR_MSLAVE-1:0] slave_req_o,
    input  obi_rsp_t [XBAR_MSLAVE-1:0] slave_resp_i
);
  import core_v_mini_mcu_pkg::*;

  /* Generation of the crossbars */
  generate
    xbar_varlat_n_to_one #(
        .XBAR_NMASTER(core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[0]),
        .obi_req_t(obi_req_t),
        .obi_rsp_t(obi_rsp_t)
    ) xbar_i (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .master_req_i(master_req_i[core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[0]-1:0]),
        .master_resp_o(master_resp_o[core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[0]-1:0]),
        .slave_req_o(slave_req_o[0]),
        .slave_resp_i(slave_resp_i[0])
    );

    for (genvar i = 1; i < XBAR_MSLAVE; i++) begin : gen_xbar
      if (core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[i] == 1) begin : gen_xbar_single_channel
        assign slave_req_o[i] = master_req_i[i+core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[0]-1];
        assign master_resp_o[i+core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[0]-1] = slave_resp_i[i];
      end else begin : gen_xbar_multi_channel
        xbar_varlat_n_to_one #(
            .XBAR_NMASTER(core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[i]),
            .obi_req_t(obi_req_t),
            .obi_rsp_t(obi_rsp_t)
        ) xbar_i (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .master_req_i(master_req_i[core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[i] + core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[i-1]-1:core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[i-1]]),
            .master_resp_o(master_resp_o[core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[i] + core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[i-1]-1:core_v_mini_mcu_pkg::DMA_XBAR_MASTERS[i-1]]),
            .slave_req_o(slave_req_o[i]),
            .slave_resp_i(slave_resp_i[i])
        );
      end
    end
  endgenerate

endmodule
