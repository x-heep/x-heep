// Copyright 2026 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%
  user_peripheral_domain = xheep.get_user_peripheral_domain()
%>
<%!
    from x_heep_gen.pads.pin import Input, Output, Inout, PinDigital, Asignal
%>

<%
    attribute_bits = xheep.get_padring().attributes.get("bits")
    any_muxed_pads = xheep.get_padring().num_muxed_pads() > 0
%>

module asic_x_heep_system_wrapper
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

    % if user_peripheral_domain.contains_peripheral('serial_link'):
      //Serial Link
      input  logic [serial_link_single_channel_reg_pkg::NumChannels-1:0]    ddr_rcv_clk_i,  
      output logic [serial_link_single_channel_reg_pkg::NumChannels-1:0]    ddr_rcv_clk_o,
      input  logic [serial_link_single_channel_reg_pkg::NumChannels-1:0][serial_link_minimum_axi_pkg::NumLanes-1:0] ddr_i,
      output logic [serial_link_single_channel_reg_pkg::NumChannels-1:0][serial_link_minimum_axi_pkg::NumLanes-1:0] ddr_o,
    %endif

    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_tx_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_rx_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_stop_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_done_i,

    // External SPC interface
    output logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_done_o,

    % for pad in xheep.get_padring().pad_list:
      <%
      has_input_pin = any(isinstance(pin, Input) for pin in pad.pins)
      has_output_pin = any(isinstance(pin, Output) for pin in pad.pins)
      has_inout_pin = any(isinstance(pin, Inout) for pin in pad.pins)

      if not (has_input_pin or has_output_pin or has_inout_pin):
        continue
      pin0_name = pad.pins[0].rtl_name()
      muxed_string = "_muxed" if pad.is_muxed() else ""
      %>\
      % if has_inout_pin or (has_input_pin and has_output_pin):
        inout wire ${pin0_name}io${"" if loop.last else ","}
      % elif has_input_pin:
        inout wire ${pin0_name}i${"" if loop.last else ","}
      % elif has_output_pin:
        inout wire ${pin0_name}o${"" if loop.last else ","}
      % endif
    % endfor
);

    // eXtension interface
    if_xif xif_compressed_if();
    if_xif xif_issue_if();
    if_xif xif_commit_if();
    if_xif xif_mem_if();
    if_xif xif_mem_result_if();
    if_xif xif_result_if();

  x_heep_system #(
    .XHEEP_INSTANCE_ID  (XHEEP_INSTANCE_ID),
    .EXT_XBAR_NMASTER   (EXT_XBAR_NMASTER),
    .AO_SPC_NUM         (AO_SPC_NUM)
  ) u_x_heep_system (
    // IDs
    .hart_id_i                              (hart_id_i),
    .xheep_instance_id_i                    (xheep_instance_id_i),

    .intr_vector_ext_i                      (intr_vector_ext_i),
    .intr_ext_peripheral_i                  (intr_ext_peripheral_i),

    .ext_xbar_master_req_i                  (ext_xbar_master_req_i),
    .ext_xbar_master_resp_o                 (ext_xbar_master_resp_o),

    // External slave ports
    .ext_core_instr_req_o                   (ext_core_instr_req_o),
    .ext_core_instr_resp_i                  (ext_core_instr_resp_i),
    .ext_core_data_req_o                    (ext_core_data_req_o),
    .ext_core_data_resp_i                   (ext_core_data_resp_i),
    .ext_debug_master_req_o                 (ext_debug_master_req_o),
    .ext_debug_master_resp_i                (ext_debug_master_resp_i),
    .ext_dma_read_req_o                     (ext_dma_read_req_o),
    .ext_dma_read_resp_i                    (ext_dma_read_resp_i),
    .ext_dma_write_req_o                    (ext_dma_write_req_o),
    .ext_dma_write_resp_i                   (ext_dma_write_resp_i),
    .ext_dma_addr_req_o                     (ext_dma_addr_req_o),
    .ext_dma_addr_resp_i                    (ext_dma_addr_resp_i),

    .hw_fifo_req_o                          (hw_fifo_req_o),
    .hw_fifo_resp_i                         (hw_fifo_resp_i),

    .ext_ao_peripheral_req_i                (ext_ao_peripheral_req_i),
    .ext_ao_peripheral_resp_o               (ext_ao_peripheral_resp_o),

    .ext_peripheral_slave_req_o             (ext_peripheral_slave_req_o),
    .ext_peripheral_slave_resp_i            (ext_peripheral_slave_resp_i),

    // Power management
    .cpu_subsystem_powergate_switch_no              (cpu_subsystem_powergate_switch_no),
    .cpu_subsystem_powergate_switch_ack_ni          (cpu_subsystem_powergate_switch_ack_ni),
    .peripheral_subsystem_powergate_switch_no       (peripheral_subsystem_powergate_switch_no),
    .peripheral_subsystem_powergate_switch_ack_ni   (peripheral_subsystem_powergate_switch_ack_ni),

    .external_subsystem_powergate_switch_no         (external_subsystem_powergate_switch_no),
    .external_subsystem_powergate_switch_ack_ni     (external_subsystem_powergate_switch_ack_ni),
    .external_subsystem_powergate_iso_no            (external_subsystem_powergate_iso_no),
    .external_subsystem_rst_no                      (external_subsystem_rst_no),
    .external_ram_banks_set_retentive_no            (external_ram_banks_set_retentive_no),
    .external_subsystem_clkgate_en_no               (external_subsystem_clkgate_en_no),

    .exit_value_o                           (exit_value_o),

    % if user_peripheral_domain.contains_peripheral('serial_link'):
    // Serial Link
    .ddr_rcv_clk_i                          (ddr_rcv_clk_i),
    .ddr_rcv_clk_o                          (ddr_rcv_clk_o),
    .ddr_i                                  (ddr_i),
    .ddr_o                                  (ddr_o),
    %endif

    .ext_dma_slot_tx_i                      (ext_dma_slot_tx_i),
    .ext_dma_slot_rx_i                      (ext_dma_slot_rx_i),
    .ext_dma_stop_i                         (ext_dma_stop_i),
    .hw_fifo_done_i                         (hw_fifo_done_i),

    // eXtension Interface
    .xif_compressed_if                      (xif_compressed_if),
    .xif_issue_if                           (xif_issue_if),
    .xif_commit_if                          (xif_commit_if),
    .xif_mem_if                             (xif_mem_if),
    .xif_mem_result_if                      (xif_mem_result_if),
    .xif_result_if                          (xif_result_if),

    // External SPC interface
    .dma_done_o                             (dma_done_o),

    % for pad in xheep.get_padring().pad_list:
      <%
      has_input_pin = any(isinstance(pin, Input) for pin in pad.pins)
      has_output_pin = any(isinstance(pin, Output) for pin in pad.pins)
      has_inout_pin = any(isinstance(pin, Inout) for pin in pad.pins)
      if not (has_input_pin or has_output_pin or has_inout_pin):
        continue
      pin0_name = pad.pins[0].rtl_name()
      %>\
      % if has_inout_pin or (has_input_pin and has_output_pin):
        .${pin0_name}io  (${pin0_name}io)${"" if loop.last else ","}
      % elif has_input_pin:
        .${pin0_name}i   (${pin0_name}i)${"" if loop.last else ","}
      % elif has_output_pin:
        .${pin0_name}o   (${pin0_name}o)${"" if loop.last else ","}
      % endif
    % endfor
  );

endmodule
