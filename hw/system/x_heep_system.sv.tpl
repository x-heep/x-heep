// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%!
    from x_heep_gen.pads.pin import Input, Output, Inout, PinDigital, Asignal
%>

<%
    attribute_bits = xheep.get_padring().attributes.get("bits")
    any_muxed_pads = xheep.get_padring().num_muxed_pads() > 0
%>

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

  % if attribute_bits != None:
    logic [core_v_mini_mcu_pkg::NUM_PAD-1:0][${attribute_bits}] pad_attributes;
  % endif
  % if any_muxed_pads:
    logic [core_v_mini_mcu_pkg::NUM_PAD-1:0][${xheep.get_padring().get_muxed_pad_select_width()-1}:0] pad_muxes;
  % endif

  logic rst_ngen;

  // core_v_mini_mcu input/output pins
  % for pad in xheep.get_padring().pad_list:
    % for pin in pad.pins:
      % if isinstance(pin, PinDigital):
        logic ${pin.rtl_name()}in_x, ${pin.rtl_name()}out_x, ${pin.rtl_name()}oe_x;
      % endif
    % endfor
    % if len(pad.pins) > 1 and any( isinstance(pin, PinDigital) for pin in pad.pins ):
      logic ${pad.pins[0].rtl_name()}in_x_muxed, ${pad.pins[0].rtl_name()}out_x_muxed, ${pad.pins[0].rtl_name()}oe_x_muxed;
    % endif
  % endfor


  core_v_mini_mcu #(
    .EXT_XBAR_NMASTER(EXT_XBAR_NMASTER),
    .AO_SPC_NUM(AO_SPC_NUM),
    .EXT_HARTS(EXT_HARTS)
  ) core_v_mini_mcu_i (
    // MCU pads
    .rst_ni(rst_ngen),
    % for pin in xheep.get_padring().get_connected_pins():
      % if pin.module == "core_v_mini_mcu":
        % if isinstance(pin, (Input, Inout)):
          .${pin.rtl_name()}i(${pin.rtl_name()}in_x),
        % endif
        % if isinstance(pin, (Output, Inout)):
          .${pin.rtl_name()}o(${pin.rtl_name()}out_x),
        % endif
        % if isinstance(pin, Inout):
          .${pin.rtl_name()}oe_o(${pin.rtl_name()}oe_x),
        % endif
      % endif
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

<%
analog_signal_pads = [ pad for pad in xheep.get_padring().pad_list if any(isinstance(pin, Asignal) for pin in pad.pins) ] 
%>
  pad_ring pad_ring_i (
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
        .${pin0_name}i(${pin0_name}out_x${muxed_string}),
        .${pin0_name}oe_i(${pin0_name}oe_x${muxed_string}),
        .${pin0_name}o(${pin0_name}in_x${muxed_string}),
        .${pin0_name}io(${pin0_name}io),
      % elif has_input_pin:
        .${pin0_name}o(${pin0_name}in_x${muxed_string}),
        .${pin0_name}io(${pin0_name}i),
      % elif has_output_pin:
        .${pin0_name}i(${pin0_name}out_x${muxed_string}),
        .${pin0_name}io(${pin0_name}o${muxed_string}),
      % endif
    % endfor

    % if len(analog_signal_pads) > 0:
      `ifdef SYNTHESIS
        % for pad in analog_signal_pads:
          .${pad.name.lower()}_io,
        % endfor
      `endif
    %endif

    % if attribute_bits != None:
      .pad_attributes_i(pad_attributes)
    % else:
      .pad_attributes_i('0)
    % endif
  );

% for pin in xheep.get_padring().pin_list:
  % if isinstance(pin, Input):
    assign ${pin.rtl_name()}out_x = 1'b0;
    assign ${pin.rtl_name()}oe_x = 1'b0;
  % endif
  % if isinstance(pin, Output):
    assign ${pin.rtl_name()}oe_x = 1'b1;
  % endif
% endfor

// PAD MULTIPLEXERS
% for pad in [pad for pad in xheep.get_padring().pad_list if pad.is_muxed() and any(isinstance(pin, PinDigital) for pin in pad.pins)]:
  <% pin0_name = pad.pins[0].rtl_name() %>\
  always_comb
  begin
    % for pin in pad.pins:
      ${pin.rtl_name()}in_x = 1'b0;
    % endfor
    unique case(pad_muxes[core_v_mini_mcu_pkg::PAD_${pad.name.upper()}])
      % for idx, pin in enumerate(pad.pins):
        ${idx}: begin
          <% pinidx_name = pin.rtl_name() %>
          ${pin0_name}out_x_muxed = ${pinidx_name}out_x;
          ${pin0_name}oe_x_muxed  = ${pinidx_name}oe_x;
          ${pinidx_name}in_x        = ${pin0_name}in_x_muxed;
        end
      % endfor
      default: begin
        ${pin0_name}out_x_muxed = ${pin0_name}out_x;
        ${pin0_name}oe_x_muxed  = ${pin0_name}oe_x;
        ${pin0_name}in_x        = ${pin0_name}in_x_muxed;
      end
    endcase
  end
% endfor

  pad_control #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t),
      .NUM_PAD  (core_v_mini_mcu_pkg::NUM_PAD)
  ) pad_control_i (
      .clk_i(clk_in_x),
      .rst_ni(rst_ngen),
      .reg_req_i(pad_req),
      .reg_rsp_o(pad_resp)${"," if any_muxed_pads or attribute_bits != None else ""}
      % if attribute_bits != None:
        .pad_attributes_o(pad_attributes)${"," if any_muxed_pads else ""}
      % endif
      % if any_muxed_pads:
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
