// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module x_heep_system
  import obi_pkg::*;
  import reg_pkg::*;
  import fifo_pkg::*;
#(
    parameter logic [31:0] XHEEP_INSTANCE_ID = 0,
    parameter EXT_XBAR_NMASTER = 0,
    parameter AO_SPC_NUM = 0,
    //do not touch these parameters
    parameter AO_SPC_NUM_RND = AO_SPC_NUM == 0 ? 0 : AO_SPC_NUM - 1,
    parameter EXT_XBAR_NMASTER_RND = EXT_XBAR_NMASTER == 0 ? 1 : EXT_XBAR_NMASTER,
    parameter EXT_DOMAINS_RND = core_v_mini_mcu_pkg::EXTERNAL_DOMAINS == 0 ? 1 : core_v_mini_mcu_pkg::EXTERNAL_DOMAINS,
    parameter NEXT_INT_RND = core_v_mini_mcu_pkg::NEXT_INT == 0 ? 1 : core_v_mini_mcu_pkg::NEXT_INT

) (
    // IDs
    input logic [31:0] hart_id_i,
    input logic [31:0] xheep_instance_id_i,

    input logic [NEXT_INT_RND-1:0] intr_vector_ext_i,
    input logic intr_ext_peripheral_i,

    input  obi_req_t  [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_master_req_i,
    output obi_resp_t [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_master_resp_o,

    // External slave ports
    output obi_req_t  ext_core_instr_req_o,
    input  obi_resp_t ext_core_instr_resp_i,
    output obi_req_t  ext_core_data_req_o,
    input  obi_resp_t ext_core_data_resp_i,
    output obi_req_t  ext_debug_master_req_o,
    input  obi_resp_t ext_debug_master_resp_i,
    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_read_req_o,
    input  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_read_resp_i,
    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_write_req_o,
    input  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_write_resp_i,
    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_addr_req_o,
    input  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_addr_resp_i,

    output fifo_req_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_req_o,
    input fifo_resp_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_resp_i,

    input reg_req_t  [AO_SPC_NUM_RND:0] ext_ao_peripheral_req_i,
    output reg_rsp_t [AO_SPC_NUM_RND:0] ext_ao_peripheral_resp_o,
    
    output reg_req_t ext_peripheral_slave_req_o,
    input  reg_rsp_t ext_peripheral_slave_resp_i,
    
    // PM signals
    output logic cpu_subsystem_powergate_switch_no,
    input  logic cpu_subsystem_powergate_switch_ack_ni,
    output logic peripheral_subsystem_powergate_switch_no,
    input  logic peripheral_subsystem_powergate_switch_ack_ni,

    output logic [EXT_DOMAINS_RND-1:0] external_subsystem_powergate_switch_no,
    input  logic [EXT_DOMAINS_RND-1:0] external_subsystem_powergate_switch_ack_ni,
    output logic [EXT_DOMAINS_RND-1:0] external_subsystem_powergate_iso_no,
    output logic [EXT_DOMAINS_RND-1:0] external_subsystem_rst_no,
    output logic [EXT_DOMAINS_RND-1:0] external_ram_banks_set_retentive_no,
    output logic [EXT_DOMAINS_RND-1:0] external_subsystem_clkgate_en_no,

    output logic [31:0] exit_value_o,

    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_tx_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_rx_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_stop_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_done_i,

    // eXtension interface
    if_xif.cpu_compressed xif_compressed_if,
    if_xif.cpu_issue      xif_issue_if,
    if_xif.cpu_commit     xif_commit_if,
    if_xif.cpu_mem        xif_mem_if,
    if_xif.cpu_mem_result xif_mem_result_if,
    if_xif.cpu_result     xif_result_if,

    // External SPC interface
    output logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_done_o,

% for pad in xheep.get_padring().total_pad_list:
${pad.x_heep_system_interface}
% endfor
);

  import core_v_mini_mcu_pkg::*;


  localparam EXT_HARTS = 0;

  //do not touch these parameter
  localparam EXT_HARTS_RND = EXT_HARTS == 0 ? 1 : EXT_HARTS;


  logic [EXT_HARTS_RND-1:0] ext_debug_req;
  logic ext_cpu_subsystem_rst_n;
  logic ext_debug_reset_n;

  // PAD controller
  reg_req_t pad_req;
  reg_rsp_t pad_resp;
% if xheep.get_padring().pads_attributes != None:
  logic [core_v_mini_mcu_pkg::NUM_PAD-1:0][${xheep.get_padring().pads_attributes['bits']}] pad_attributes;
% endif
 % if xheep.get_padring().total_pad_muxed > 0:
  logic [core_v_mini_mcu_pkg::NUM_PAD-1:0][${xheep.get_padring().max_total_pad_mux_bitlengh-1}:0] pad_muxes;
% endif

  logic rst_ngen;

  //input, output pins from core_v_mini_mcu
% for pad in xheep.get_padring().total_pad_list:
${pad.internal_signals}
% endfor

  core_v_mini_mcu #(
    .EXT_XBAR_NMASTER(EXT_XBAR_NMASTER),
    .AO_SPC_NUM(AO_SPC_NUM),
    .EXT_HARTS(EXT_HARTS)
  ) core_v_mini_mcu_i (

    .rst_ni(rst_ngen),
% for pad in xheep.get_padring().pad_list:
${pad.core_v_mini_mcu_bonding}
% endfor

    .hart_id_i,
    .xheep_instance_id_i,
    .intr_vector_ext_i,
    .intr_ext_peripheral_i,
    .xif_compressed_if,
    .xif_issue_if,
    .xif_commit_if,
    .xif_mem_if,
    .xif_mem_result_if,
    .xif_result_if,
    .pad_req_o(pad_req),
    .pad_resp_i(pad_resp),
    .ext_xbar_master_req_i,
    .ext_xbar_master_resp_o,
    .ext_ao_peripheral_slave_req_i(ext_ao_peripheral_req_i),
    .ext_ao_peripheral_slave_resp_o(ext_ao_peripheral_resp_o),
    .ext_core_instr_req_o,
    .ext_core_instr_resp_i,
    .ext_core_data_req_o,
    .ext_core_data_resp_i,
    .ext_debug_master_req_o,
    .ext_debug_master_resp_i,
    .ext_dma_read_req_o,
    .ext_dma_read_resp_i,
    .ext_dma_write_req_o,
    .ext_dma_write_resp_i,
    .ext_dma_addr_req_o,
    .ext_dma_addr_resp_i,
    .hw_fifo_done_i,
    .ext_dma_stop_i,
    .hw_fifo_req_o,
    .hw_fifo_resp_i,
    .ext_peripheral_slave_req_o,
    .ext_peripheral_slave_resp_i,
    .ext_debug_req_o(ext_debug_req),
    .ext_debug_reset_no(ext_debug_reset_n),
    .cpu_subsystem_powergate_switch_no,
    .cpu_subsystem_powergate_switch_ack_ni,
    .peripheral_subsystem_powergate_switch_no,
    .peripheral_subsystem_powergate_switch_ack_ni,
    .external_subsystem_powergate_switch_no,
    .external_subsystem_powergate_switch_ack_ni,
    .external_subsystem_powergate_iso_no,
    .external_subsystem_rst_no,
    .ext_cpu_subsystem_rst_no(ext_cpu_subsystem_rst_n),
    .external_ram_banks_set_retentive_no,
    .external_subsystem_clkgate_en_no,
    .exit_value_o,
    .ext_dma_slot_tx_i,
    .ext_dma_slot_rx_i,
    .dma_done_o
  );

  pad_ring pad_ring_i (
% for pad in xheep.get_padring().total_pad_list:
${pad.pad_ring_bonding_bonding}
% endfor
% if xheep.get_padring().pads_attributes != None:
    .pad_attributes_i(pad_attributes)
% else:
    .pad_attributes_i('0)
% endif
  );

${xheep.get_padring().pad_constant_driver_assign}

${xheep.get_padring().pad_mux_process}

  pad_control #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t),
      .NUM_PAD  (core_v_mini_mcu_pkg::NUM_PAD)
  ) pad_control_i (
      .clk_i(clk_in_x),
      .rst_ni(rst_ngen),
      .reg_req_i(pad_req),
      .reg_rsp_o(pad_resp)
% if xheep.get_padring().total_pad_muxed > 0 or xheep.get_padring().pads_attributes != None:
      ,
% endif
% if xheep.get_padring().pads_attributes != None:
      .pad_attributes_o(pad_attributes)
% if xheep.get_padring().total_pad_muxed > 0:
      ,
% endif
% endif
% if xheep.get_padring().total_pad_muxed > 0:
      .pad_muxes_o(pad_muxes)
% endif
  );

  rstgen rstgen_i (
    .clk_i(clk_in_x),
    .rst_ni(rst_nin_x),
    .test_mode_i(1'b0),
    .rst_no(rst_ngen),
    .init_no()
  );


endmodule  // x_heep_system
