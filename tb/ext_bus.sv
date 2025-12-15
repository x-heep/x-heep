// Copyright 2022 EPFL and Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: ext_bus.sv
// Author: Michele Caon
// Date: 19/05/2023
// Description: external peripheral bus for X-HEEP testbench

module ext_bus #(
    parameter int unsigned EXT_XBAR_NMASTER = 1,
    parameter int unsigned EXT_XBAR_NSLAVE = 1,
    // Dependent parameters: do not override
    localparam int unsigned EXT_XBAR_NMASTER_RND = EXT_XBAR_NMASTER == 0 ? 1 : EXT_XBAR_NMASTER,
    localparam int unsigned EXT_XBAR_NSLAVE_RND = EXT_XBAR_NSLAVE == 0 ? 1 : EXT_XBAR_NSLAVE,
    localparam int unsigned IDX_WIDTH = cf_math_pkg::idx_width(EXT_XBAR_NSLAVE)
) (
    input logic clk_i,
    input logic rst_ni,

    // Address map
    input addr_map_rule_pkg::addr_map_rule_t [EXT_XBAR_NSLAVE-1:0] addr_map_i,

    // Default external slave index
    input logic [IDX_WIDTH-1:0] default_idx_i,

    // X-HEEP master ports
    input  obi_pkg::obi_req_t  heep_core_instr_req_i,
    output obi_pkg::obi_resp_t heep_core_instr_resp_o,

    input  obi_pkg::obi_req_t  heep_core_data_req_i,
    output obi_pkg::obi_resp_t heep_core_data_resp_o,

    input  obi_pkg::obi_req_t  heep_debug_master_req_i,
    output obi_pkg::obi_resp_t heep_debug_master_resp_o,

    input obi_pkg::obi_req_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_read_req_i,
    output obi_pkg::obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_read_resp_o,

    input obi_pkg::obi_req_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_write_req_i,
    output obi_pkg::obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_write_resp_o,

    input obi_pkg::obi_req_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_addr_req_i,
    output obi_pkg::obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_addr_resp_o,

    // External master ports
    input  obi_pkg::obi_req_t  [EXT_XBAR_NMASTER_RND-1:0] ext_master_req_i,
    output obi_pkg::obi_resp_t [EXT_XBAR_NMASTER_RND-1:0] ext_master_resp_o,

    // X-HEEP slave ports (one per external master)
    output obi_pkg::obi_req_t  [EXT_XBAR_NMASTER_RND-1:0] heep_slave_req_o,
    input  obi_pkg::obi_resp_t [EXT_XBAR_NMASTER_RND-1:0] heep_slave_resp_i,

    // External slave ports
    output obi_pkg::obi_req_t  [EXT_XBAR_NSLAVE_RND-1:0] ext_slave_req_o,
    input  obi_pkg::obi_resp_t [EXT_XBAR_NSLAVE_RND-1:0] ext_slave_resp_i
);
  import obi_pkg::*;
  import addr_map_rule_pkg::*;
  import core_v_mini_mcu_pkg::*;

  // X-HEEP + external master ports
  obi_req_t [core_v_mini_mcu_pkg::SYSTEM_XBAR_NMASTER+EXT_XBAR_NMASTER-1:0] master_req;
  obi_resp_t [core_v_mini_mcu_pkg::SYSTEM_XBAR_NMASTER+EXT_XBAR_NMASTER-1:0] master_resp;

  // Forward crossbars ports
  obi_req_t [EXT_XBAR_NMASTER-1:0][1:0] demux_xbar_req;
  obi_resp_t [EXT_XBAR_NMASTER-1:0][1:0] demux_xbar_resp;

  // Dummy external master port (to prevent unused warning)
  obi_req_t [EXT_XBAR_NMASTER_RND-1:0] ext_master_req_unused;
  obi_resp_t [EXT_XBAR_NMASTER_RND-1:0] heep_slave_resp_unused;
  obi_resp_t [EXT_XBAR_NSLAVE_RND-1:0] ext_slave_resp_unused;

  assign ext_master_req_unused = ext_master_req_i;
  assign heep_slave_resp_unused = heep_slave_resp_i;
  assign ext_slave_resp_unused = ext_slave_resp_i;

  // X-HEEP + external master requests
  assign master_req[CORE_INSTR_IDX] = heep_core_instr_req_i;
  assign master_req[CORE_DATA_IDX] = heep_core_data_req_i;
  assign master_req[DEBUG_MASTER_IDX] = heep_debug_master_req_i;

  generate
    for (
        genvar i = 0; i < core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS; i++
    ) begin : gen_dma_master_req_map
      assign master_req[core_v_mini_mcu_pkg::DMA_READ_P0_IDX+i*3]  = heep_dma_read_req_i[i];
      assign master_req[core_v_mini_mcu_pkg::DMA_WRITE_P0_IDX+i*3] = heep_dma_write_req_i[i];
      assign master_req[core_v_mini_mcu_pkg::DMA_ADDR_P0_IDX+i*3]  = heep_dma_addr_req_i[i];
    end
  endgenerate

  generate
    for (genvar i = 0; i < EXT_XBAR_NMASTER; i++) begin : gen_ext_master_req_map
      assign master_req[SYSTEM_XBAR_NMASTER+i] = demux_xbar_req[i][DEMUX_XBAR_EXT_SLAVE_IDX];
    end
  endgenerate

  // X-HEEP master responses
  assign heep_core_instr_resp_o = master_resp[CORE_INSTR_IDX];
  assign heep_core_data_resp_o = master_resp[CORE_DATA_IDX];
  assign heep_debug_master_resp_o = master_resp[DEBUG_MASTER_IDX];

  generate
    for (
        genvar i = 0; i < core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS; i++
    ) begin : gen_dma_master_resp_map
      assign heep_dma_read_resp_o[i]  = master_resp[core_v_mini_mcu_pkg::DMA_READ_P0_IDX+i];
      assign heep_dma_write_resp_o[i] = master_resp[core_v_mini_mcu_pkg::DMA_WRITE_P0_IDX+i];
      assign heep_dma_addr_resp_o[i]  = master_resp[core_v_mini_mcu_pkg::DMA_ADDR_P0_IDX+i];
    end
  endgenerate

  // X-HEEP slave requests
  generate
    for (genvar i = 0; i < EXT_XBAR_NMASTER; i++) begin : gen_ext_xbar_req
      assign heep_slave_req_o[i] = demux_xbar_req[i][DEMUX_XBAR_INT_SLAVE_IDX];
    end
  endgenerate

  // X-HEEP slave responses
  generate
    for (genvar i = 0; unsigned'(i) < EXT_XBAR_NMASTER; i++) begin : gen_ext_xbar_rsp
      assign demux_xbar_resp[i][DEMUX_XBAR_INT_SLAVE_IDX] = heep_slave_resp_i[i];
    end
  endgenerate

  // External slave responses
  generate
    for (genvar i = 0; unsigned'(i) < EXT_XBAR_NMASTER; i++) begin : gen_demux_master_resp_map
      assign demux_xbar_resp[i][DEMUX_XBAR_EXT_SLAVE_IDX] = master_resp[SYSTEM_XBAR_NMASTER+i];
    end
  endgenerate

`ifndef SYNTHESIS
  // show writes if requested
  always_ff @(posedge clk_i, negedge rst_ni) begin : verbose_writes
    if ($test$plusargs("verbose") != 0 && heep_core_data_req_i.req && heep_core_data_req_i.we)
      if ($test$plusargs("verbose") != 0 && heep_core_data_req_i.req && heep_core_data_req_i.we)
        $display(
            "write addr=0x%08x: data=0x%08x", heep_core_data_req_i.addr, heep_core_data_req_i.wdata
        );
  end
`endif

  // 1-to-2 forward crossbars
  // ------------------------
  // These crossbars forward each external master to a port on the external
  // crossbar or to the corresponding slave port of X-HEEP.
  generate
    for (genvar i = 0; unsigned'(i) < EXT_XBAR_NMASTER; i++) begin : gen_demux_xbar
      xbar_varlat_one_to_n #(
          .XBAR_NSLAVE(32'd2),  // internal crossbar + external crossbar
          .NUM_RULES  (32'd1)   // only the external address space is defined
      ) demux_xbar_i (
          .clk_i        (clk_i),
          .rst_ni       (rst_ni),
          .addr_map_i   (DEMUX_XBAR_ADDR_RULES),
          .default_idx_i(DEMUX_XBAR_INT_SLAVE_IDX[0:0]),
          .master_req_i (ext_master_req_i[i]),
          .master_resp_o(ext_master_resp_o[i]),
          .slave_req_o  (demux_xbar_req[i]),
          .slave_resp_i (demux_xbar_resp[i])
      );
    end
  endgenerate

  // External system crossbar
  // ------------------------
  ext_xbar #(
      .XBAR_NMASTER(SYSTEM_XBAR_NMASTER + EXT_XBAR_NMASTER),
      .XBAR_NSLAVE (EXT_XBAR_NSLAVE)
  ) ext_xbar_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .addr_map_i(addr_map_i),
      .default_idx_i(default_idx_i),
      .master_req_i(master_req),
      .master_resp_o(master_resp),
      .slave_req_o(ext_slave_req_o),
      .slave_resp_i(ext_slave_resp_i)
  );

endmodule
