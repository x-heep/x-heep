// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// MODIFICATION NOTICE:
// This file has been modified by Nathan Chandanson on 15/07/2026.
// Brief description of changes: Remove the pad_ring and outputs the i, o and oe signals for each pad.
//

<%
  user_peripheral_domain = xheep.get_user_peripheral_domain()
%>
<%!
    from pads.pin import Input, Output, Inout, PinDigital, Asignal, PinVdd, PinVss, PinIoVdd, PinIoVss, PinPower
%>

<%
    attribute_bits = xheep.get_padring().attributes.get("bits")
    any_muxed_pads = xheep.get_padring().num_muxed_pads() > 0
    power_pads = [ pad for pad in xheep.get_padring().pad_list if any(isinstance(pin, PinPower) for pin in pad.pins) ]
%>

module ihp_sg13g2_asic_x_heep_system_wrapper
import cv32e40px_core_v_xif_pkg::*;
#(
    parameter logic [31:0] XHEEP_INSTANCE_ID = 0,
    parameter EXT_XBAR_NMASTER = 0,
    parameter AO_SPC_NUM = 0,
    //do not touch these parameters
    parameter AO_SPC_NUM_RND = AO_SPC_NUM == 0 ? 0 : AO_SPC_NUM - 1,
    parameter EXT_XBAR_NMASTER_RND = EXT_XBAR_NMASTER == 0 ? 1 : EXT_XBAR_NMASTER,
    parameter EXT_DOMAINS_RND = core_v_mini_mcu_pkg::EXTERNAL_DOMAINS == 0 ? 1 : core_v_mini_mcu_pkg::EXTERNAL_DOMAINS,
    parameter NEXT_INT_RND = core_v_mini_mcu_pkg::NEXT_INT == 0 ? 1 : core_v_mini_mcu_pkg::NEXT_INT,
    // OBI and register interface data types
    parameter type obi_req_t  = xheep_obi_pkg::xheep_obi_req_t,
    parameter type obi_rsp_t  = xheep_obi_pkg::xheep_obi_rsp_t,
    parameter type reg_req_t  = xheep_reg_pkg::xheep_reg_req_t,
    parameter type reg_rsp_t  = xheep_reg_pkg::xheep_reg_rsp_t,
    parameter type fifo_req_t = xheep_fifo_pkg::xheep_fifo_req_t,
    parameter type fifo_rsp_t = xheep_fifo_pkg::xheep_fifo_rsp_t
) (
    // IDs
    input logic [31:0] hart_id_i,
    input logic [31:0] xheep_instance_id_i,

    input logic [NEXT_INT_RND-1:0] intr_vector_ext_i,
    input logic intr_ext_peripheral_i,

    input  obi_req_t [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_master_req_i,
    output obi_rsp_t [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_master_resp_o,

    // External slave ports
    output obi_req_t ext_core_instr_req_o,
    input  obi_rsp_t ext_core_instr_resp_i,
    output obi_req_t ext_core_data_req_o,
    input  obi_rsp_t ext_core_data_resp_i,
    output obi_req_t ext_debug_master_req_o,
    input  obi_rsp_t ext_debug_master_resp_i,
    output obi_req_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_read_req_o,
    input  obi_rsp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_read_resp_i,
    output obi_req_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_write_req_o,
    input  obi_rsp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_write_resp_i,
    output obi_req_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_addr_req_o,
    input  obi_rsp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_addr_resp_i,

    output fifo_req_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_req_o,
    input fifo_rsp_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_resp_i,

    input  reg_req_t [AO_SPC_NUM_RND:0] ext_ao_peripheral_req_i,
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
    // Compressed interface
    output logic               xif_compressed_valid,
    input  logic               xif_compressed_ready,
    output x_compressed_req_t  xif_compressed_req,
    input  x_compressed_resp_t xif_compressed_resp,
    // Issue interface
    output logic               xif_issue_valid,
    input  logic               xif_issue_ready,
    output x_issue_req_t       xif_issue_req,
    input  x_issue_resp_t      xif_issue_resp,
    // Commit interface
    output logic               xif_commit_valid,
    output x_commit_t          xif_commit,
    // Memory (request/response) interface
    input  logic               xif_mem_valid,
    output logic               xif_mem_ready,
    input  x_mem_req_t         xif_mem_req,
    output x_mem_resp_t        xif_mem_resp,
    // Memory result interface
    output logic               xif_mem_result_valid,
    output x_mem_result_t      xif_mem_result,
    // Result interface
    input  logic               xif_result_valid,
    output logic               xif_result_ready,
    input  x_result_t          xif_result,

    // External SPC interface
    output logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_done_o,

    % if power_pads:
        `ifdef USE_POWER_PINS
        <%
        has_vdd = any(isinstance(pin, PinVdd) for pad in power_pads for pin in pad.pins)
        has_vss = any(isinstance(pin, PinVss) for pad in power_pads for pin in pad.pins)
        has_iovdd = any(isinstance(pin, PinIoVdd) for pad in power_pads for pin in pad.pins)
        has_iovss = any(isinstance(pin, PinIoVss) for pad in power_pads for pin in pad.pins)
        %>\
        % if has_vdd:
        inout wire vdd_io,
        % endif
        % if has_vss:
        inout wire vss_io,
        % endif
        % if has_iovdd:
        inout wire iovdd_io,
        % endif
        % if has_iovss:
        inout wire iovss_io,
        % endif
        `endif
    % endif

    <%
    power_pads = [ pad for pad in xheep.get_padring().pad_list if any(isinstance(pin, PinPower) for pin in pad.pins) ] 
    %>
    % for pad in [pad for pad in xheep.get_padring().pad_list if pad not in power_pads]:
      <%
      has_input_pin = any(isinstance(pin, Input) for pin in pad.pins)
      has_output_pin = any(isinstance(pin, Output) for pin in pad.pins)
      has_inout_pin = any(isinstance(pin, Inout) for pin in pad.pins)

      if not (has_input_pin or has_output_pin or has_inout_pin):
        continue
      pin0_name = pad.pins[0].rtl_name()
      %>\
      % if has_inout_pin or (has_input_pin and has_output_pin):
        input  logic ${pin0_name}i,
        output logic ${pin0_name}oe,
        output logic ${pin0_name}o${"" if loop.last else ","}
      % elif has_input_pin:
        input  logic ${pin0_name}i${"" if loop.last else ","}
      % elif has_output_pin:
        output logic ${pin0_name}o${"" if loop.last else ","}
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

  % for pad in xheep.get_padring().pad_list:
      <%
      pin0_name = pad.pins[0].rtl_name()
      %>\
    % if len(pad.pins) > 1 and any( isinstance(pin, PinDigital) for pin in pad.pins ):
      assign ${pin0_name}oe         = ${pin0_name}oe_x_muxed;
      assign ${pin0_name}o          = ${pin0_name}out_x_muxed;
      assign ${pin0_name}in_x_muxed = ${pin0_name}i;
    % elif isinstance(pad.pins[0], Input):
      assign ${pin0_name}in_x = ${pin0_name}i;
    % elif isinstance(pad.pins[0], Output):
      assign ${pin0_name}o    = ${pin0_name}out_x;
    % elif isinstance(pad.pins[0], Inout):
      assign ${pin0_name}oe   = ${pin0_name}oe_x;
      assign ${pin0_name}o    = ${pin0_name}out_x;
      assign ${pin0_name}in_x = ${pin0_name}i;
    % endif
  % endfor

  // eXtension interface
  if_xif xif_compressed_if();
  if_xif xif_issue_if();
  if_xif xif_commit_if();
  if_xif xif_mem_if();
  if_xif xif_mem_result_if();
  if_xif xif_result_if();

  assign xif_compressed_valid = xif_compressed_if.compressed_valid;
  assign xif_compressed_if.compressed_ready = xif_compressed_ready;
  assign xif_compressed_req = xif_compressed_if.compressed_req;
  assign xif_compressed_if.compressed_resp = xif_compressed_resp;

  assign xif_issue_valid = xif_issue_if.issue_valid;
  assign xif_issue_if.issue_ready = xif_issue_ready;
  assign xif_issue_req = xif_issue_if.issue_req;
  assign xif_issue_if.issue_resp = xif_issue_resp;

  assign xif_commit_valid = xif_commit_if.commit_valid;
  assign xif_commit = xif_commit_if.commit;

  assign xif_mem_if.mem_valid = xif_mem_valid;
  assign xif_mem_ready = xif_mem_if.mem_ready;
  assign xif_mem_if.mem_req = xif_mem_req;
  assign xif_mem_resp = xif_mem_if.mem_resp;

  assign xif_mem_result_valid = xif_mem_result_if.mem_result_valid;
  assign xif_mem_result = xif_mem_result_if.mem_result;

  assign xif_result_if.result_valid = xif_result_valid;
  assign xif_result_ready = xif_result_if.result_ready;
  assign xif_result_if.result = xif_result;


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
      ${pin.rtl_name()}in_x = ${"1'b1" if pin.attributes.get("active") == "low" else "1'b0"};
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
      .reg_req_t(xheep_reg_pkg::xheep_reg_req_t),
      .reg_rsp_t(xheep_reg_pkg::xheep_reg_rsp_t),
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
