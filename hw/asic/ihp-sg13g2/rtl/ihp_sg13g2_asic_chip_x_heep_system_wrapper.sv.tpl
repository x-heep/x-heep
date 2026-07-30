// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// MODIFICATION NOTICE:
// This file has been modified by Nathan Chandanson on 30/07/2026.
// Brief description of changes: Tie off all the extensions to x-heep to only keep the pins.
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

module ihp_sg13g2_asic_x_heep_system_wrapper #(
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
    `ifdef USE_POWER_PINS
    inout wire IOVDD,
    inout wire IOVSS,
    inout wire VDD,
    inout wire VSS,
    `endif


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
        inout wire ${pin0_name}io${"" if loop.last else ","}
      % elif has_input_pin:
        inout wire ${pin0_name}i${"" if loop.last else ","}
      % elif has_output_pin:
        inout wire ${pin0_name}o${"" if loop.last else ","}
      % endif
    % endfor
);

  import core_v_mini_mcu_pkg::*;

  // Tie off unused signals
  logic [31:0] unused_xheep_instance_id = 32'h0;
  logic [31:0] unused_hart_id = 32'h0;
  logic [NEXT_INT_RND-1:0] unused_intr_vector_ext = '0;
  logic unused_intr_ext_peripheral = 1'b0;
  obi_req_t [EXT_XBAR_NMASTER_RND-1:0] unused_ext_xbar_master_req = '{default: '0};
  obi_rsp_t unused_ext_core_instr_resp = '{default: '0};
  obi_rsp_t unused_ext_core_data_resp = '{default: '0};
  obi_rsp_t unused_ext_debug_master_resp = '{default: '0};
  obi_rsp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] unused_ext_dma_read_resp = '{default: '0};
  obi_rsp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] unused_ext_dma_write_resp = '{default: '0};
  obi_rsp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] unused_ext_dma_addr_resp = '{default: '0};
  fifo_rsp_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] unused_hw_fifo_resp = '{default: '0};
  reg_req_t [AO_SPC_NUM_RND:0] unused_ext_ao_peripheral_req = '{default: '0};
  reg_rsp_t unused_ext_peripheral_slave_resp = '{default: '0};
  logic unused_cpu_subsystem_powergate_switch_ack_n = 1'b1;
  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] unused_ext_dma_slot_tx = '0;
  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] unused_ext_dma_slot_rx = '0;
  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] unused_ext_dma_stop    = '0;
  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] unused_hw_fifo_done    = '0;
  logic unused_peripheral_subsystem_powergate_switch_ack_n = 1'b1;
  logic [EXT_DOMAINS_RND-1:0] unused_external_subsystem_powergate_switch_ack_n = '1; // Set all bits high

  // eXtension interface
  if_xif xif_compressed_if();
  if_xif xif_issue_if();
  if_xif xif_commit_if();
  if_xif xif_mem_if();
  if_xif xif_mem_result_if();
  if_xif xif_result_if();



  // Rest is simply x_heep_system
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

    .hart_id_i(unused_hart_id),
    .xheep_instance_id_i(unused_xheep_instance_id),
    .intr_vector_ext_i(unused_intr_vector_ext),
    .intr_ext_peripheral_i(unused_intr_ext_peripheral),
    .xif_compressed_if,
    .xif_issue_if,
    .xif_commit_if,
    .xif_mem_if,
    .xif_mem_result_if,
    .xif_result_if,
    .pad_req_o(pad_req),
    .pad_resp_i(pad_resp),
    .ext_xbar_master_req_i(unused_ext_xbar_master_req),
    .ext_xbar_master_resp_o(),
    .ext_ao_peripheral_slave_req_i(unused_ext_ao_peripheral_req),
    .ext_ao_peripheral_slave_resp_o(),
    .ext_core_instr_req_o(),
    .ext_core_instr_resp_i(unused_ext_core_instr_resp),
    .ext_core_data_req_o(),
    .ext_core_data_resp_i(unused_ext_core_data_resp),
    .ext_debug_master_req_o(),
    .ext_debug_master_resp_i(unused_ext_debug_master_resp),
    .ext_dma_read_req_o(),
    .ext_dma_read_resp_i(unused_ext_dma_read_resp),
    .ext_dma_write_req_o(),
    .ext_dma_write_resp_i(unused_ext_dma_write_resp),
    .ext_dma_addr_req_o(),
    .ext_dma_addr_resp_i(unused_ext_dma_addr_resp),
    .hw_fifo_done_i(unused_hw_fifo_done),
    .ext_dma_stop_i(unused_ext_dma_stop),
    .hw_fifo_req_o(),
    .hw_fifo_resp_i(unused_hw_fifo_resp),
    .ext_peripheral_slave_req_o(),
    .ext_peripheral_slave_resp_i(unused_ext_peripheral_slave_resp),
    .ext_debug_req_o(ext_debug_req),
    .ext_debug_reset_no(ext_debug_reset_n),
    .cpu_subsystem_powergate_switch_no(),
    .cpu_subsystem_powergate_switch_ack_ni(unused_cpu_subsystem_powergate_switch_ack_n),
    .peripheral_subsystem_powergate_switch_no(),
    .peripheral_subsystem_powergate_switch_ack_ni(unused_peripheral_subsystem_powergate_switch_ack_n),
    .external_subsystem_powergate_switch_no(),
    .external_subsystem_powergate_switch_ack_ni(unused_external_subsystem_powergate_switch_ack_n),
    .external_subsystem_powergate_iso_no(),
    .external_subsystem_rst_no(),
    .ext_cpu_subsystem_rst_no(ext_cpu_subsystem_rst_n),
    .external_ram_banks_set_retentive_no(),
    .external_subsystem_clkgate_en_no(),
    .exit_value_o(),
    .ext_dma_slot_tx_i(unused_ext_dma_slot_tx),
    .ext_dma_slot_rx_i(unused_ext_dma_slot_rx),
    .dma_done_o()
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

    // Not parametrized: for a chip you NEED the power pads
    `ifdef USE_POWER_PINS
    .vdd_io(VDD),
    .vss_io(VSS),
    .iovdd_io(IOVDD),
    .iovss_io(IOVSS),
    `endif

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
