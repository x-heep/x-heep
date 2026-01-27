// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%
  dma = xheep.get_base_peripheral_domain().get_dma()
  memory_ss = xheep.memory_ss()
%>

module core_v_mini_mcu
  import obi_pkg::*;
  import reg_pkg::*;
  import fifo_pkg::*;
#(
    parameter EXT_XBAR_NMASTER = 0,
    parameter AO_SPC_NUM = 0,
    parameter EXT_HARTS = 0,
    //do not touch these parameters
    parameter AO_SPC_NUM_RND = AO_SPC_NUM == 0 ? 0 : AO_SPC_NUM - 1,
    parameter EXT_XBAR_NMASTER_RND = EXT_XBAR_NMASTER == 0 ? 1 : EXT_XBAR_NMASTER,
    parameter EXT_DOMAINS_RND = core_v_mini_mcu_pkg::EXTERNAL_DOMAINS == 0 ? 1 : core_v_mini_mcu_pkg::EXTERNAL_DOMAINS,
    parameter NEXT_INT_RND = core_v_mini_mcu_pkg::NEXT_INT == 0 ? 1 : core_v_mini_mcu_pkg::NEXT_INT,
    parameter EXT_HARTS_RND = EXT_HARTS == 0 ? 1 : EXT_HARTS
) (

    input logic rst_ni,

% for pad in xheep.get_padring().pad_list:
${pad.core_v_mini_mcu_interface}
% endfor

    // IDs
    input logic [31:0] hart_id_i,
    input logic [31:0] xheep_instance_id_i,

    // eXtension interface
    if_xif.cpu_compressed xif_compressed_if,
    if_xif.cpu_issue      xif_issue_if,
    if_xif.cpu_commit     xif_commit_if,
    if_xif.cpu_mem        xif_mem_if,
    if_xif.cpu_mem_result xif_mem_result_if,
    if_xif.cpu_result     xif_result_if,

    output reg_req_t pad_req_o,
    input  reg_rsp_t pad_resp_i,

    input  obi_req_t  [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_master_req_i,
    output obi_resp_t [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_master_resp_o,

    input reg_req_t  [AO_SPC_NUM_RND:0] ext_ao_peripheral_slave_req_i,
    output reg_rsp_t [AO_SPC_NUM_RND:0] ext_ao_peripheral_slave_resp_o,

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

    // External SPC interface
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_tx_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_rx_i,
    output logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_done_o
);

  import core_v_mini_mcu_pkg::*;
  import cv32e40p_apu_core_pkg::*;
  import power_manager_pkg::*;

  localparam NUM_BYTES = core_v_mini_mcu_pkg::MEM_SIZE;
  localparam DM_HALTADDRESS = core_v_mini_mcu_pkg::DEBUG_START_ADDRESS + 32'h00000800; //debug rom code (section .text in linker) starts at 0x800

  localparam JTAG_IDCODE = 32'h10001c05;
  localparam NRHARTS = EXT_HARTS + 1; //external harts + single hart core-v-mini-mcu
  localparam BOOT_ADDR = core_v_mini_mcu_pkg::BOOTROM_START_ADDRESS;

  // Log top level parameter values
`ifndef SYNTHESIS
  initial begin
    $display("[X-HEEP]: NUM_BYTES = %dKB", NUM_BYTES / 1024);
  end
`endif

<%
  obi_msb = dma.get_num_master_ports() - 1
%>

  // masters signals
  obi_req_t core_instr_req;
  obi_resp_t core_instr_resp;
  obi_req_t core_data_req;
  obi_resp_t core_data_resp;
  obi_req_t debug_master_req;
  obi_resp_t debug_master_resp;
  obi_req_t [${obi_msb}:0]dma_read_req;
  obi_resp_t [${obi_msb}:0]dma_read_resp;
  obi_req_t [${obi_msb}:0]dma_write_req;
  obi_resp_t [${obi_msb}:0]dma_write_resp;
  obi_req_t [${obi_msb}:0]dma_addr_req;
  obi_resp_t [${obi_msb}:0]dma_addr_resp;

  // ram signals
  obi_req_t [core_v_mini_mcu_pkg::NUM_BANKS-1:0] ram_slave_req;
  obi_resp_t [core_v_mini_mcu_pkg::NUM_BANKS-1:0] ram_slave_resp;

  // debug signals
  obi_req_t debug_slave_req;
  obi_resp_t debug_slave_resp;

  // peripherals signals
  obi_req_t ao_peripheral_slave_req;
  obi_resp_t ao_peripheral_slave_resp;
  obi_req_t peripheral_slave_req;
  obi_resp_t peripheral_slave_resp;

  // signals to debug unit
  logic debug_core_req;
  logic debug_reset_n;
  logic [NRHARTS-1:0] debug_req;
  // core
  logic core_sleep;

  // irq signals
  logic irq_ack;
  logic [4:0] irq_id_out;
  logic irq_software;
  logic irq_external;
  logic [15:0] irq_fast;

  // Memory Map SPI Region
  obi_req_t flash_mem_slave_req;
  obi_resp_t flash_mem_slave_resp;

  // rv_timer
  logic [3:0] rv_timer_intr;

  // interrupt array
  logic [31:0] intr;
  logic [15:0] fast_intr;

  //Power manager signals
  power_manager_out_t cpu_subsystem_pwr_ctrl_out;
  power_manager_out_t peripheral_subsystem_pwr_ctrl_out;
  power_manager_out_t memory_subsystem_pwr_ctrl_out[core_v_mini_mcu_pkg::NUM_BANKS-1:0];
  power_manager_out_t external_subsystem_pwr_ctrl_out[EXT_DOMAINS_RND-1:0];

  power_manager_in_t  cpu_subsystem_pwr_ctrl_in;
  power_manager_in_t  peripheral_subsystem_pwr_ctrl_in;
  power_manager_in_t  memory_subsystem_pwr_ctrl_in[core_v_mini_mcu_pkg::NUM_BANKS-1:0];
  power_manager_in_t  external_subsystem_pwr_ctrl_in[EXT_DOMAINS_RND-1:0];

  logic cpu_subsystem_rst_n;
  logic cpu_subsystem_powergate_iso_n;

  logic peripheral_subsystem_rst_n;
  logic peripheral_subsystem_powergate_iso_n;
  logic peripheral_subsystem_clkgate_en_n;

  logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] memory_subsystem_banks_powergate_switch_n;
  logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] memory_subsystem_banks_powergate_switch_ack_n;
  logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] memory_subsystem_banks_set_retentive_n;
  logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] memory_subsystem_banks_powergate_iso_n;
  logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] memory_subsystem_clkgate_en_n;

  //pwrgate exposed outside for UPF sim flow and switch cells
  assign cpu_subsystem_powergate_switch_no    = cpu_subsystem_pwr_ctrl_out.pwrgate_en_n;
  assign cpu_subsystem_pwr_ctrl_in.pwrgate_ack_n = cpu_subsystem_powergate_switch_ack_ni;
  //isogate exposed outside for UPF sim flow and switch cells
  assign cpu_subsystem_powergate_iso_n                 = cpu_subsystem_pwr_ctrl_out.isogate_en_n;
  assign cpu_subsystem_rst_n                  = cpu_subsystem_pwr_ctrl_out.rst_n;

  //pwrgate exposed both outside for UPF sim flow
  assign peripheral_subsystem_powergate_switch_no = peripheral_subsystem_pwr_ctrl_out.pwrgate_en_n;
  assign peripheral_subsystem_pwr_ctrl_in.pwrgate_ack_n  = peripheral_subsystem_powergate_switch_ack_ni;
  //isogate exposed outside for UPF sim flow and switch cells
  assign peripheral_subsystem_powergate_iso_n = peripheral_subsystem_pwr_ctrl_out.isogate_en_n;
  assign peripheral_subsystem_rst_n           = peripheral_subsystem_pwr_ctrl_out.rst_n;
  assign peripheral_subsystem_clkgate_en_n    = peripheral_subsystem_pwr_ctrl_out.clkgate_en_n;

% for bank in memory_ss.iter_ram_banks():
  assign memory_subsystem_banks_powergate_switch_n[${bank.name()}] = memory_subsystem_pwr_ctrl_out[${bank.name()}].pwrgate_en_n;
  assign memory_subsystem_pwr_ctrl_in[${bank.name()}].pwrgate_ack_n = memory_subsystem_banks_powergate_switch_ack_n[${bank.name()}];
  //isogate exposed outside for UPF sim flow and switch cells
  assign memory_subsystem_banks_powergate_iso_n[${bank.name()}] = memory_subsystem_pwr_ctrl_out[${bank.name()}].isogate_en_n;
  assign memory_subsystem_banks_set_retentive_n[${bank.name()}] = memory_subsystem_pwr_ctrl_out[${bank.name()}].retentive_en_n;
  assign memory_subsystem_clkgate_en_n[${bank.name()}] = memory_subsystem_pwr_ctrl_out[${bank.name()}].clkgate_en_n;
% endfor

  for (genvar i = 0; i < EXT_DOMAINS_RND; i = i + 1) begin : gen_external_subsystem_pwr_gating
    assign external_subsystem_powergate_switch_no[i]        = external_subsystem_pwr_ctrl_out[i].pwrgate_en_n;
    assign external_subsystem_powergate_iso_no[i] = external_subsystem_pwr_ctrl_out[i].isogate_en_n;
    assign external_subsystem_rst_no[i] = external_subsystem_pwr_ctrl_out[i].rst_n;
    assign external_ram_banks_set_retentive_no[i]           = external_subsystem_pwr_ctrl_out[i].retentive_en_n;
    assign external_subsystem_clkgate_en_no[i] = external_subsystem_pwr_ctrl_out[i].clkgate_en_n;
    assign external_subsystem_pwr_ctrl_in[i].pwrgate_ack_n = external_subsystem_powergate_switch_ack_ni[i];
  end

  // DMA
  logic dma_done_intr;
  logic dma_window_intr;

  // SPI
  logic spi_flash_intr, spi_intr, spi_rx_valid, spi_tx_ready;

  // GPIO
  logic [31:8] gpio_in;
  logic [31:8] gpio_out;
  logic [31:8] gpio_oe;

  // GPIO_AO
  logic [7:0] gpio_ao_in;
  logic [7:0] gpio_ao_out;
  logic [7:0] gpio_ao_oe;
  logic [7:0] gpio_ao_intr;

  // I2s
  logic i2s_rx_valid;

  assign intr = {
    irq_fast, 4'b0, irq_external, 3'b0, rv_timer_intr[0], 3'b0, irq_software, 3'b0
  };

  assign fast_intr = {
    intr_ext_peripheral_i,
    dma_window_intr,
    gpio_ao_intr,
    spi_flash_intr,
    spi_intr,
    dma_done_intr,
    rv_timer_intr[3],
    rv_timer_intr[2],
    rv_timer_intr[1]
  };

  cpu_subsystem #(
      .BOOT_ADDR(BOOT_ADDR),
      .DM_HALTADDRESS(DM_HALTADDRESS)
  ) cpu_subsystem_i (
      // Clock and Reset
      .clk_i,
      .rst_ni(cpu_subsystem_rst_n && debug_reset_n),
      .hart_id_i,
      .core_instr_req_o(core_instr_req),
      .core_instr_resp_i(core_instr_resp),
      .core_data_req_o(core_data_req),
      .core_data_resp_i(core_data_resp),
      .xif_compressed_if,
      .xif_issue_if,
      .xif_commit_if,
      .xif_mem_if,
      .xif_mem_result_if,
      .xif_result_if,
      .irq_i(intr),
      .irq_ack_o(irq_ack),
      .irq_id_o(irq_id_out),
      .debug_req_i(debug_core_req),
      .core_sleep_o(core_sleep)
  );

  debug_subsystem #(
      .NRHARTS    (NRHARTS),
      .JTAG_IDCODE(JTAG_IDCODE),
      .SPI_SLAVE(${has_spi_slave})
  ) debug_subsystem_i (
      .clk_i,
      .rst_ni,
      .jtag_tck_i,
      .jtag_tms_i,
      .jtag_trst_ni,
      .jtag_tdi_i,
      .jtag_tdo_o,
      .spi_slave_sck_i(spi_slave_sck_i),
      .spi_slave_cs_i(spi_slave_cs_i),
      .spi_slave_miso_o(spi_slave_miso_o),
      .spi_slave_miso_oe_o(spi_slave_miso_oe_o),
      .spi_slave_mosi_i(spi_slave_mosi_i),
      .debug_core_req_o(debug_req),
      .debug_ndmreset_no(debug_reset_n),
      .debug_slave_req_i(debug_slave_req),
      .debug_slave_resp_o(debug_slave_resp),
      .debug_master_req_o(debug_master_req),
      .debug_master_resp_i(debug_master_resp)
  );

  system_bus #(
      .NUM_BANKS(core_v_mini_mcu_pkg::NUM_BANKS),
      .EXT_XBAR_NMASTER(EXT_XBAR_NMASTER)
  ) system_bus_i (
      .clk_i,
      .rst_ni(rst_ni && debug_reset_n),
      .core_instr_req_i(core_instr_req),
      .core_instr_resp_o(core_instr_resp),
      .core_data_req_i(core_data_req),
      .core_data_resp_o(core_data_resp),
      .debug_master_req_i(debug_master_req),
      .debug_master_resp_o(debug_master_resp),
      .dma_read_req_i(dma_read_req),
      .dma_read_resp_o(dma_read_resp),
      .dma_write_req_i(dma_write_req),
      .dma_write_resp_o(dma_write_resp),
      .dma_addr_req_i(dma_addr_req),
      .dma_addr_resp_o(dma_addr_resp),
      .ext_xbar_master_req_i(ext_xbar_master_req_i),
      .ext_xbar_master_resp_o(ext_xbar_master_resp_o),
      .ram_req_o(ram_slave_req),
      .ram_resp_i(ram_slave_resp),
      .debug_slave_req_o(debug_slave_req),
      .debug_slave_resp_i(debug_slave_resp),
      .ao_peripheral_slave_req_o(ao_peripheral_slave_req),
      .ao_peripheral_slave_resp_i(ao_peripheral_slave_resp),
      .peripheral_slave_req_o(peripheral_slave_req),
      .peripheral_slave_resp_i(peripheral_slave_resp),
      .flash_mem_slave_req_o(flash_mem_slave_req),
      .flash_mem_slave_resp_i(flash_mem_slave_resp),
      .ext_core_instr_req_o(ext_core_instr_req_o),
      .ext_core_instr_resp_i(ext_core_instr_resp_i),
      .ext_core_data_req_o(ext_core_data_req_o),
      .ext_core_data_resp_i(ext_core_data_resp_i),
      .ext_debug_master_req_o(ext_debug_master_req_o),
      .ext_debug_master_resp_i(ext_debug_master_resp_i),
      .ext_dma_read_req_o(ext_dma_read_req_o),
      .ext_dma_read_resp_i(ext_dma_read_resp_i),
      .ext_dma_write_req_o(ext_dma_write_req_o),
      .ext_dma_write_resp_i(ext_dma_write_resp_i),
      .ext_dma_addr_req_o(ext_dma_addr_req_o),
      .ext_dma_addr_resp_i(ext_dma_addr_resp_i)
  );

  memory_subsystem #(
      .NUM_BANKS(core_v_mini_mcu_pkg::NUM_BANKS)
  ) memory_subsystem_i (
      .clk_i,
      .rst_ni(rst_ni && debug_reset_n),
      .clk_gate_en_ni(memory_subsystem_clkgate_en_n),
      .ram_req_i(ram_slave_req),
      .ram_resp_o(ram_slave_resp),
      .pwrgate_ni(memory_subsystem_banks_powergate_switch_n),
      .pwrgate_ack_no(memory_subsystem_banks_powergate_switch_ack_n),
      .set_retentive_ni(memory_subsystem_banks_set_retentive_n)
  );

  ao_peripheral_subsystem #(
      .AO_SPC_NUM(AO_SPC_NUM)
  ) ao_peripheral_subsystem_i (
      .clk_i,
      .rst_ni(rst_ni && debug_reset_n),
      .slave_req_i(ao_peripheral_slave_req),
      .slave_resp_o(ao_peripheral_slave_resp),
      .spc2ao_req_i(ext_ao_peripheral_slave_req_i),
      .ao2spc_resp_o(ext_ao_peripheral_slave_resp_o),
      .xheep_instance_id_i,
      .boot_select_i,
      .execute_from_flash_i,
      .exit_valid_o,
      .exit_value_o,
      .spimemio_req_i(flash_mem_slave_req),
      .spimemio_resp_o(flash_mem_slave_resp),
      .spi_flash_sck_o,
      .spi_flash_sck_en_o(spi_flash_sck_oe_o),
      .spi_flash_csb_o({spi_flash_cs_1_o,spi_flash_cs_0_o}),
      .spi_flash_csb_en_o({spi_flash_cs_1_oe_o, spi_flash_cs_0_oe_o}),
      .spi_flash_sd_o({spi_flash_sd_3_o,spi_flash_sd_2_o, spi_flash_sd_1_o, spi_flash_sd_0_o}),
      .spi_flash_sd_en_o({spi_flash_sd_3_oe_o,spi_flash_sd_2_oe_o, spi_flash_sd_1_oe_o, spi_flash_sd_0_oe_o}),
      .spi_flash_sd_i({spi_flash_sd_3_i,spi_flash_sd_2_i, spi_flash_sd_1_i, spi_flash_sd_0_i}),
      .intr_i(intr),
      .intr_vector_ext_i,
      .core_sleep_i(core_sleep),
      .cpu_subsystem_pwr_ctrl_o(cpu_subsystem_pwr_ctrl_out),
      .peripheral_subsystem_pwr_ctrl_o(peripheral_subsystem_pwr_ctrl_out),
      .memory_subsystem_pwr_ctrl_o(memory_subsystem_pwr_ctrl_out),
      .external_subsystem_pwr_ctrl_o(external_subsystem_pwr_ctrl_out),
      .cpu_subsystem_pwr_ctrl_i(cpu_subsystem_pwr_ctrl_in),
      .peripheral_subsystem_pwr_ctrl_i(peripheral_subsystem_pwr_ctrl_in),
      .memory_subsystem_pwr_ctrl_i(memory_subsystem_pwr_ctrl_in),
      .external_subsystem_pwr_ctrl_i(external_subsystem_pwr_ctrl_in),
      .rv_timer_0_intr_o(rv_timer_intr[0]),
      .rv_timer_1_intr_o(rv_timer_intr[1]),
      .dma_read_req_o(dma_read_req),
      .dma_read_resp_i(dma_read_resp),
      .dma_write_req_o(dma_write_req),
      .dma_write_resp_i(dma_write_resp),
      .dma_addr_req_o(dma_addr_req),
      .dma_addr_resp_i(dma_addr_resp),
      .dma_done_intr_o(dma_done_intr),
      .dma_window_intr_o(dma_window_intr),
      .hw_fifo_req_o,
      .hw_fifo_resp_i,
      .spi_flash_intr_event_o(spi_flash_intr),
      .pad_req_o,
      .pad_resp_i,
      .fast_intr_i(fast_intr),
      .fast_intr_o(irq_fast),
      .cio_gpio_i(gpio_ao_in),
      .cio_gpio_o(gpio_ao_out),
      .cio_gpio_en_o(gpio_ao_oe),
      .intr_gpio_o(gpio_ao_intr),
      .spi_rx_valid_i(spi_rx_valid),
      .spi_tx_ready_i(spi_tx_ready),
      .i2s_rx_valid_i(i2s_rx_valid),
      .ext_peripheral_slave_req_o,
      .ext_peripheral_slave_resp_i,
      .ext_dma_slot_tx_i,
      .ext_dma_slot_rx_i,
      .ext_dma_stop_i,
      .hw_fifo_done_i,
      .dma_done_o
  );

  peripheral_subsystem peripheral_subsystem_i (
      .clk_i,
      .rst_ni(peripheral_subsystem_rst_n && debug_reset_n),
      .clk_gate_en_ni(peripheral_subsystem_clkgate_en_n),
      .slave_req_i(peripheral_slave_req),
      .slave_resp_o(peripheral_slave_resp),
      .intr_vector_ext_i,
      .irq_plic_o(irq_external),
      .msip_o(irq_software),
      .cio_gpio_i(gpio_in),
      .cio_gpio_o(gpio_out),
      .cio_gpio_en_o(gpio_oe),
      .cio_scl_i(i2c_scl_i),
      .cio_scl_o(i2c_scl_o),
      .cio_scl_en_o(i2c_scl_oe_o),
      .cio_sda_i(i2c_sda_i),
      .cio_sda_o(i2c_sda_o),
      .cio_sda_en_o(i2c_sda_oe_o),
      .spi_sck_o,
      .spi_sck_en_o(spi_sck_oe_o),
      .spi_csb_o({spi_cs_1_o,spi_cs_0_o}),
      .spi_csb_en_o({spi_cs_1_oe_o, spi_cs_0_oe_o}),
      .spi_sd_o({spi_sd_3_o,spi_sd_2_o, spi_sd_1_o, spi_sd_0_o}),
      .spi_sd_en_o({spi_sd_3_oe_o,spi_sd_2_oe_o, spi_sd_1_oe_o, spi_sd_0_oe_o}),
      .spi_sd_i({spi_sd_3_i,spi_sd_2_i, spi_sd_1_i, spi_sd_0_i}),
      .spi_intr_event_o(spi_intr),
      .spi_rx_valid_o(spi_rx_valid),
      .spi_tx_ready_o(spi_tx_ready),
      .spi2_sck_o,
      .spi2_sck_en_o(spi2_sck_oe_o),
      .spi2_csb_o({spi2_cs_1_o, spi2_cs_0_o}),
      .spi2_csb_en_o({spi2_cs_1_oe_o, spi2_cs_0_oe_o}),
      .spi2_sd_o({spi2_sd_3_o, spi2_sd_2_o, spi2_sd_1_o, spi2_sd_0_o}),
      .spi2_sd_en_o({spi2_sd_3_oe_o, spi2_sd_2_oe_o, spi2_sd_1_oe_o, spi2_sd_0_oe_o}),
      .spi2_sd_i({spi2_sd_3_i, spi2_sd_2_i, spi2_sd_1_i, spi2_sd_0_i}),
      .rv_timer_2_intr_o(rv_timer_intr[2]),
      .rv_timer_3_intr_o(rv_timer_intr[3]),
      .pdm2pcm_clk_o(pdm2pcm_clk_o),
      .pdm2pcm_clk_en_o(pdm2pcm_clk_oe_o),
      .pdm2pcm_pdm_i(pdm2pcm_pdm_i),
      .i2s_sck_o(i2s_sck_o),
      .i2s_sck_oe_o(i2s_sck_oe_o),
      .i2s_sck_i(i2s_sck_i),
      .i2s_ws_o(i2s_ws_o),
      .i2s_ws_oe_o(i2s_ws_oe_o),
      .i2s_ws_i(i2s_ws_i),
      .i2s_sd_o(i2s_sd_o),
      .i2s_sd_oe_o(i2s_sd_oe_o),
      .i2s_sd_i(i2s_sd_i),
      .i2s_rx_valid_o(i2s_rx_valid),
      .uart_rx_i,
      .uart_tx_o
  );

  // Debug_req assign
  if (NRHARTS == 1) begin : gen_single_hart_debug
    assign debug_core_req = debug_req;
    assign ext_debug_req_o  = 1'b0;
  end else begin : gen_multi_hart_debug
    always @(*) begin
      for (int i = 0; i < NRHARTS; i++) begin
        if (i == 0) debug_core_req = debug_req[i];
        else ext_debug_req_o[i-1] = debug_req[i];
      end
    end
  end

  assign ext_cpu_subsystem_rst_no = cpu_subsystem_rst_n;
  assign ext_debug_reset_no = debug_reset_n;

  assign pdm2pcm_pdm_o = 0;
  assign pdm2pcm_pdm_oe_o = 0;

  assign gpio_ao_in[0] = gpio_0_i;
  assign gpio_0_o      = gpio_ao_out[0];
  assign gpio_0_oe_o   = gpio_ao_oe[0];
  assign gpio_ao_in[1] = gpio_1_i;
  assign gpio_1_o      = gpio_ao_out[1];
  assign gpio_1_oe_o   = gpio_ao_oe[1];
  assign gpio_ao_in[2] = gpio_2_i;
  assign gpio_2_o      = gpio_ao_out[2];
  assign gpio_2_oe_o   = gpio_ao_oe[2];
  assign gpio_ao_in[3] = gpio_3_i;
  assign gpio_3_o      = gpio_ao_out[3];
  assign gpio_3_oe_o   = gpio_ao_oe[3];
  assign gpio_ao_in[4] = gpio_4_i;
  assign gpio_4_o      = gpio_ao_out[4];
  assign gpio_4_oe_o   = gpio_ao_oe[4];
  assign gpio_ao_in[5] = gpio_5_i;
  assign gpio_5_o      = gpio_ao_out[5];
  assign gpio_5_oe_o   = gpio_ao_oe[5];
  assign gpio_ao_in[6] = gpio_6_i;
  assign gpio_6_o      = gpio_ao_out[6];
  assign gpio_6_oe_o   = gpio_ao_oe[6];
  assign gpio_ao_in[7] = gpio_7_i;
  assign gpio_7_o      = gpio_ao_out[7];
  assign gpio_7_oe_o   = gpio_ao_oe[7];
  assign gpio_in[8]    = gpio_8_i;
  assign gpio_8_o      = gpio_out[8];
  assign gpio_8_oe_o   = gpio_oe[8];
  assign gpio_in[9]    = gpio_9_i;
  assign gpio_9_o      = gpio_out[9];
  assign gpio_9_oe_o   = gpio_oe[9];
  assign gpio_in[10]   = gpio_10_i;
  assign gpio_10_o     = gpio_out[10];
  assign gpio_10_oe_o  = gpio_oe[10];
  assign gpio_in[11]   = gpio_11_i;
  assign gpio_11_o     = gpio_out[11];
  assign gpio_11_oe_o  = gpio_oe[11];
  assign gpio_in[12]   = gpio_12_i;
  assign gpio_12_o     = gpio_out[12];
  assign gpio_12_oe_o  = gpio_oe[12];
  assign gpio_in[13]   = gpio_13_i;
  assign gpio_13_o     = gpio_out[13];
  assign gpio_13_oe_o  = gpio_oe[13];
  assign gpio_in[14]   = gpio_14_i;
  assign gpio_14_o     = gpio_out[14];
  assign gpio_14_oe_o  = gpio_oe[14];
  assign gpio_in[15]   = gpio_15_i;
  assign gpio_15_o     = gpio_out[15];
  assign gpio_15_oe_o  = gpio_oe[15];
  assign gpio_in[16]   = gpio_16_i;
  assign gpio_16_o     = gpio_out[16];
  assign gpio_16_oe_o  = gpio_oe[16];
  assign gpio_in[17]   = gpio_17_i;
  assign gpio_17_o     = gpio_out[17];
  assign gpio_17_oe_o  = gpio_oe[17];
  assign gpio_in[18]   = gpio_18_i;
  assign gpio_18_o     = gpio_out[18];
  assign gpio_18_oe_o  = gpio_oe[18];
  assign gpio_in[19]   = gpio_19_i;
  assign gpio_19_o     = gpio_out[19];
  assign gpio_19_oe_o  = gpio_oe[19];
  assign gpio_in[20]   = gpio_20_i;
  assign gpio_20_o     = gpio_out[20];
  assign gpio_20_oe_o  = gpio_oe[20];
  assign gpio_in[21]   = gpio_21_i;
  assign gpio_21_o     = gpio_out[21];
  assign gpio_21_oe_o  = gpio_oe[21];
  assign gpio_in[22]   = gpio_22_i;
  assign gpio_22_o     = gpio_out[22];
  assign gpio_22_oe_o  = gpio_oe[22];
  assign gpio_in[23]   = gpio_23_i;
  assign gpio_23_o     = gpio_out[23];
  assign gpio_23_oe_o  = gpio_oe[23];
  assign gpio_in[24]   = gpio_24_i;
  assign gpio_24_o     = gpio_out[24];
  assign gpio_24_oe_o  = gpio_oe[24];
  assign gpio_in[25]   = gpio_25_i;
  assign gpio_25_o     = gpio_out[25];
  assign gpio_25_oe_o  = gpio_oe[25];
  assign gpio_in[26]   = gpio_26_i;
  assign gpio_26_o     = gpio_out[26];
  assign gpio_26_oe_o  = gpio_oe[26];
  assign gpio_in[27]   = gpio_27_i;
  assign gpio_27_o     = gpio_out[27];
  assign gpio_27_oe_o  = gpio_oe[27];
  assign gpio_in[28]   = gpio_28_i;
  assign gpio_28_o     = gpio_out[28];
  assign gpio_28_oe_o  = gpio_oe[28];
  assign gpio_in[29]   = gpio_29_i;
  assign gpio_29_o     = gpio_out[29];
  assign gpio_29_oe_o  = gpio_oe[29];
  assign gpio_in[30]   = gpio_30_i;
  assign gpio_30_o     = gpio_out[30];
  assign gpio_30_oe_o  = gpio_oe[30];
  assign gpio_in[31]   = gpio_31_i;
  assign gpio_31_o     = gpio_out[31];
  assign gpio_31_oe_o  = gpio_oe[31];

endmodule  // core_v_mini_mcu
