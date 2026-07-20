// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%
  user_peripheral_domain = xheep.get_user_peripheral_domain()
%>
<%!
    from pads.pin import Input, Output, Inout, PinDigital, Asignal, PinPower
%>

<%
    attribute_bits = xheep.get_padring().attributes.get("bits")
    any_muxed_pads = xheep.get_padring().num_muxed_pads() > 0
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
    // IDs
    input logic [31:0] hart_id_i,
    input logic [31:0] xheep_instance_id_i,

    output reg_req_t pad_req_o,
    input  reg_rsp_t pad_resp_i,

    input  obi_req_t  [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_master_req_i,
    output obi_rsp_t  [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_master_resp_o,

    input reg_req_t  [AO_SPC_NUM_RND:0] ext_ao_peripheral_slave_req_i,
    output reg_rsp_t [AO_SPC_NUM_RND:0] ext_ao_peripheral_slave_resp_o,

    // External slave ports
    output obi_req_t  ext_core_instr_req_o,
    input  obi_rsp_t  ext_core_instr_resp_i,
    output obi_req_t  ext_core_data_req_o,
    input  obi_rsp_t  ext_core_data_resp_i,
    output obi_req_t  ext_debug_master_req_o,
    input  obi_rsp_t  ext_debug_master_resp_i,
    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_read_req_o,
    input  obi_rsp_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_read_resp_i,
    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_write_req_o,
    input  obi_rsp_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_write_resp_i,
    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_addr_req_o,
    input  obi_rsp_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_addr_resp_i,

    output fifo_req_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_req_o,
    input fifo_rsp_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_resp_i,

    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_stop_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_done_i,

    output reg_req_t ext_peripheral_slave_req_o,
    input  reg_rsp_t ext_peripheral_slave_resp_i,

    output logic  [EXT_HARTS_RND-1:0] ext_debug_req_o,
    output logic  ext_debug_reset_no,

    // PLIC external interrupts
    input logic [NEXT_INT_RND-1:0] intr_vector_ext_i,
    // FIC external interrupt
    input logic intr_ext_peripheral_i,

    //power manager exposed to top level
    //signals are unrolled to easy EDA tools
    output logic cpu_subsystem_powergate_switch_no,
    input  logic cpu_subsystem_powergate_switch_ack_ni,
    output logic peripheral_subsystem_powergate_switch_no,
    input  logic peripheral_subsystem_powergate_switch_ack_ni,
    output logic [EXT_DOMAINS_RND-1:0] external_subsystem_powergate_switch_no,
    input  logic [EXT_DOMAINS_RND-1:0] external_subsystem_powergate_switch_ack_ni,
    output logic [EXT_DOMAINS_RND-1:0] external_subsystem_powergate_iso_no,
    output logic [EXT_DOMAINS_RND-1:0] external_subsystem_rst_no,
    output logic ext_cpu_subsystem_rst_no,
    output logic [EXT_DOMAINS_RND-1:0] external_ram_banks_set_retentive_no,
    output logic [EXT_DOMAINS_RND-1:0] external_subsystem_clkgate_en_no,

    output logic [31:0] exit_value_o,

    // eXtension interface
    output logic               xif_compressed_valid,
    input  logic               xif_compressed_ready,
    output x_compressed_req_t  xif_compressed_req,
    input  x_compressed_resp_t xif_compressed_resp,
    output logic               xif_issue_valid,
    input  logic               xif_issue_ready,
    output x_issue_req_t       xif_issue_req,
    input  x_issue_resp_t      xif_issue_resp,
    output logic               xif_commit_valid,
    output x_commit_t          xif_commit,
    input  logic               xif_mem_valid,
    output logic               xif_mem_ready,
    input  x_mem_req_t         xif_mem_req,
    output x_mem_resp_t        xif_mem_resp,
    output logic               xif_mem_result_valid,
    output x_mem_result_t      xif_mem_result,
    input  logic               xif_result_valid,
    output logic               xif_result_ready,
    input  x_result_t          xif_result,

    // External SPC interface
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_tx_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_rx_i,
    output logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_done_o,
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

  // eXtension interface
  if_xif xif_compressed_if();
  if_xif xif_issue_if();
  if_xif xif_commit_if();
  if_xif xif_mem_if();
  if_xif xif_mem_result_if();
  if_xif xif_result_if();

##  output logic [          15:0] xif_compressed_req_instr,
##  output logic [           1:0] xif_compressed_req_mode,
##  output logic [X_ID_WIDTH-1:0] xif_compressed_req_id,
##  input  logic [          31:0] xif_compressed_resp_instr,
##  input  logic                  xif_compressed_resp_accept,
  // Compressed interface
  assign               xif_compressed_valid = xif_compressed_if.compressed_valid;
  assign xif_compressed_if.compressed_ready = xif_compressed_ready;
  assign xif_compressed_req = xif_compressed_if.compressed_req;
  assign xif_compressed_if.compressed_resp = xif_compressed_resp;
##  assign           xif_compressed_req_instr = xif_compressed_if.compressed_req.instr;
##  assign            xif_compressed_req_mode = xif_compressed_if.compressed_req.mode;
##  assign              xif_compressed_req_id = xif_compressed_if.compressed_req.id;
##  assign xif_compressed_resp_instr
##  assign xif_compressed_resp_accept

##  output x_issue_req_t       xif_issue_req_instr,
##  output x_issue_req_t       xif_issue_req_mode,
##  output x_issue_req_t       xif_issue_req_id,
##  output x_issue_req_t       xif_issue_req_rs,
##  output x_issue_req_t       xif_issue_req_rs_valid,
##  output x_issue_req_t       xif_issue_req_ecs,
##  output x_issue_req_t       xif_issue_req_ecs_valid,
##  input  x_issue_resp_t      xif_issue_resp_accept,
##  input  x_issue_resp_t      xif_issue_resp_writeback,
##  input  x_issue_resp_t      xif_issue_resp_dualwrite,
##  input  x_issue_resp_t      xif_issue_resp_dualread,
##  input  x_issue_resp_t      xif_issue_resp_loadstore,
##  input  x_issue_resp_t      xif_issue_resp_ecswrite,
##  input  x_issue_resp_t      xif_issue_resp_exc,
  // Issue interface
  assign xif_issue_valid = xif_issue_if.issue_valid;
  assign xif_issue_if.issue_ready = xif_issue_ready;
  assign xif_issue_req = xif_issue_if.issue_req;
  assign xif_issue_if.issue_resp = xif_issue_resp;

  // Commit interface
##  output x_commit_t          xif_commit_id,
##  output x_commit_t          xif_commit_kill,
  assign xif_commit_valid = xif_commit_if.commit_valid;
  assign xif_commit = xif_commit_if.commit;

  // Memory (request/response) interface
##  input  x_mem_req_t         mem_req_id,
##  input  x_mem_req_t         mem_req_addr,
##  input  x_mem_req_t         mem_req_mode,
##  input  x_mem_req_t         mem_req_we,
##  input  x_mem_req_t         mem_req_size,
##  input  x_mem_req_t         mem_req_be,
##  input  x_mem_req_t         mem_req_attr,
##  input  x_mem_req_t         mem_req_wdata,
##  input  x_mem_req_t         mem_req_last,
##  input  x_mem_req_t         mem_req_spec,
##  output x_mem_resp_t        mem_resp_exc,
##  output x_mem_resp_t        mem_resp_exccode,
##  output x_mem_resp_t        mem_resp_dbg,
  assign xif_mem_if.mem_valid = xif_mem_valid;
  assign xif_mem_ready = xif_mem_if.mem_ready;
  assign xif_mem_if.mem_req = xif_mem_req;
  assign xif_mem_resp = xif_mem_if.mem_resp;
  // Memory result interface
  assign xif_mem_result_valid = xif_mem_result_if.mem_result_valid;
  assign xif_mem_result = xif_mem_result_if.mem_result;
  // Result interface
  assign xif_result_if.result_valid = xif_result_valid;
  assign xif_result_ready = xif_result_if.result_ready;
  assign xif_result_if.result = xif_result;

  // X-Heep system
  x_heep_system #(
    .XHEEP_INSTANCE_ID(0),
    .EXT_XBAR_NMASTER(0),
    .AO_SPC_NUM(0),
    // OBI and register interface data types
    .obi_req_t(obi_req_t),
    .obi_rsp_t(obi_rsp_t),
    .reg_req_t(reg_req_t),
    .reg_rsp_t(reg_rsp_t),
    .fifo_req_t(fifo_req_t),
    .fifo_rsp_t(fifo_rsp_t)
  ) x_heep_system_inst (
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
