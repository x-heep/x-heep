// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%
    base_peripheral_domain = xheep.get_base_peripheral_domain()
    if base_peripheral_domain.contains_peripheral('w25q128jw_controller'):
        w25 = xheep.get_base_peripheral_domain().get_W25Q128JW_controller()
        cache = w25.get_cache()
    else:
        cache = 0
%>

module spi_subsystem
  import power_manager_pkg::*;
#(
    // SPI host memory address
    parameter logic [31:0] SPI_FLASH_START_ADDRESS = 'h0,
    parameter logic [31:0] W25Q128JW_CONTROLLER_START_ADDRESS = 'h0,
    // External DMA number of channels
    parameter int unsigned DMA_CH_NUM = 'd1,
    // Cache enable
    parameter bit CACHE_EN = 1'b0,
    // OBI and Register Interface data types
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic,
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // Memory mapped SPI
    input  obi_req_t  spimemio_req_i,
    output obi_rsp_t  spimemio_resp_o,

    // OpenTitan SPI configuration
    input  reg_req_t  ot_reg_req_i,
    output reg_rsp_t  ot_reg_rsp_o,
    
    // w25q128jw flash controller configuration
    input  reg_req_t  flash_ctr_reg_req_i,
    output reg_rsp_t  flash_ctr_reg_rsp_o,

% if cache:
    input power_manager_out_t w25q128jw_cache_pwr_ctrl_i,
    output power_manager_in_t w25q128jw_cache_pwr_ctrl_o,
% endif

    //dma hw controller
    output dma_reg_pkg::dma_hw2reg_t external_dma_hw2reg_o,
    // flash controller interrupt
    output logic w25q128jw_controller_intr_o,

    input logic [DMA_CH_NUM-1:0] dma_ready_i,
    input logic [DMA_CH_NUM-1:0] dma_done_i,

    // SPI Interface
    output logic                               spi_flash_sck_o,
    output logic                               spi_flash_sck_en_o,
    output logic [spi_host_reg_pkg::NumCS-1:0] spi_flash_csb_o,
    output logic [spi_host_reg_pkg::NumCS-1:0] spi_flash_csb_en_o,
    output logic [                        3:0] spi_flash_sd_o,
    output logic [                        3:0] spi_flash_sd_en_o,
    input  logic [                        3:0] spi_flash_sd_i,

    // SPI HOST interrupts
    output logic spi_flash_intr_error_o,
    output logic spi_flash_intr_event_o,

    // SPI - DMA interface
    output logic spi_flash_rx_valid_o,
    output logic spi_flash_tx_ready_o
);
  // OpenTitan SPI Interface
  logic                               ot_spi_sck;
  logic                               ot_spi_sck_en;
  logic [spi_host_reg_pkg::NumCS-1:0] ot_spi_csb;
  logic [spi_host_reg_pkg::NumCS-1:0] ot_spi_csb_en;
  logic [                        3:0] ot_spi_sd_out;
  logic [                        3:0] ot_spi_sd_en;
  logic [                        3:0] ot_spi_sd_in;
  logic                               ot_spi_intr_error;
  logic                               ot_spi_intr_event;
  logic                               ot_spi_rx_valid;
  logic                               ot_spi_tx_ready;

  import spi_host_reg_pkg::*;
  spi_host_reg_pkg::spi_host_hw2reg_status_reg_t external_spi_host_hw2reg_status;

  assign spi_flash_sck_o = ot_spi_sck;
  assign spi_flash_sck_en_o = ot_spi_sck_en;
  assign spi_flash_csb_o = ot_spi_csb;
  assign spi_flash_csb_en_o = ot_spi_csb_en;
  assign spi_flash_sd_o = ot_spi_sd_out;
  assign spi_flash_sd_en_o = ot_spi_sd_en;
  assign ot_spi_sd_in = spi_flash_sd_i;
  assign spi_flash_intr_error_o = ot_spi_intr_error;
  assign spi_flash_intr_event_o = ot_spi_intr_event;
  assign spi_flash_rx_valid_o = ot_spi_rx_valid;
  assign spi_flash_tx_ready_o = ot_spi_tx_ready;


% if base_peripheral_domain.contains_peripheral('w25q128jw_controller'):

  // Master ports to the SPI HOST from Flash Controller
  reg_req_t spi_host_reg_req;
  reg_rsp_t spi_host_reg_rsp;
  reg_req_t spi_host_reg_req_mux;
  reg_rsp_t spi_host_reg_rsp_mux;
  reg_req_t [1:0] spi_host_reg_packet_req;
  reg_rsp_t [1:0] spi_host_reg_packet_rsp;

  assign spi_host_reg_packet_req[0] = ot_reg_req_i;
  assign spi_host_reg_packet_req[1] = spi_host_reg_req;
  assign ot_reg_rsp_o               = spi_host_reg_packet_rsp[0];
  assign spi_host_reg_rsp           = spi_host_reg_packet_rsp[1];

  reg_mux #(
      .NoPorts(2),
      .req_t  (reg_req_t),
      .rsp_t  (reg_rsp_t),
      .AW     (32),
      .DW     (32)
  ) reg_mux_i (
      .clk_i,
      .rst_ni,
      .in_req_i (spi_host_reg_packet_req),
      .in_rsp_o (spi_host_reg_packet_rsp),
      .out_req_o(spi_host_reg_req_mux),
      .out_rsp_i(spi_host_reg_rsp_mux)
  );

% if not cache:
  power_manager_out_t w25q128jw_cache_pwr_ctrl_i = '0;
  power_manager_in_t w25q128jw_cache_pwr_ctrl_o;
% endif

  w25q128jw_controller #(
      .SPI_FLASH_START_ADDRESS(SPI_FLASH_START_ADDRESS),
      .W25Q128JW_CONTROLLER_START_ADDRESS(W25Q128JW_CONTROLLER_START_ADDRESS),
      .DMA_CH_NUM(DMA_CH_NUM),
      .CACHE_EN(CACHE_EN),
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t),
      .obi_req_t(obi_req_t),
      .obi_rsp_t(obi_rsp_t)
  ) w25q128jw_controller_i (
      .clk_i,
      .rst_ni,

      // Register interface
      .reg_req_i(flash_ctr_reg_req_i),
      .reg_rsp_o(flash_ctr_reg_rsp_o),

      // Memory mapped SPI
      .spimemio_req_i(spimemio_req_i),
      .spimemio_resp_o(spimemio_resp_o),

      // Interrupt signal
      .w25q128jw_controller_intr_o,

      //dma hw controller
      .external_dma_hw2reg_o,
      //spi status if
      .external_spi_host_hw2reg_status_i(external_spi_host_hw2reg_status),

      // Master ports on the system bus
      .spi_host_reg_req_o(spi_host_reg_req),
      .spi_host_reg_rsp_i(spi_host_reg_rsp),

      .llc_cache_pwr_ctrl_i(w25q128jw_cache_pwr_ctrl_i),
      .llc_cache_pwr_ctrl_o(w25q128jw_cache_pwr_ctrl_o),

      .dma_ready_i,
      .dma_done_i
  );

% else:
  assign w25q128jw_controller_intr_o = '0;
  assign flash_ctr_reg_rsp_o = '0;
  assign external_dma_hw2reg_o = '0;
  assign spimemio_resp_o = '0;
  logic [DMA_CH_NUM-1:0] dma_ready_unused = dma_ready_i;
  spi_host_reg_pkg::spi_host_hw2reg_status_reg_t external_spi_host_hw2reg_status_unused = external_spi_host_hw2reg_status;
% endif



  // OpenTitan SPI Snitch Version used for booting
  spi_host #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) ot_spi_i (
      .clk_i,
      .rst_ni,
% if base_peripheral_domain.contains_peripheral('w25q128jw_controller'):
      .reg_req_i(spi_host_reg_req_mux),
      .reg_rsp_o(spi_host_reg_rsp_mux),
% else:
      .reg_req_i(ot_reg_req_i),
      .reg_rsp_o(ot_reg_rsp_o),
% endif
      .alert_rx_i(),
      .alert_tx_o(),
      .passthrough_i(spi_device_pkg::PASSTHROUGH_REQ_DEFAULT),
      .passthrough_o(),
      .cio_sck_o(ot_spi_sck),
      .cio_sck_en_o(ot_spi_sck_en),
      .cio_csb_o(ot_spi_csb),
      .cio_csb_en_o(ot_spi_csb_en),
      .cio_sd_o(ot_spi_sd_out),
      .cio_sd_en_o(ot_spi_sd_en),
      .cio_sd_i(ot_spi_sd_in),
      .rx_valid_o(ot_spi_rx_valid),
      .tx_ready_o(ot_spi_tx_ready),
      .hw2reg_status_o(external_spi_host_hw2reg_status),
      .intr_error_o(ot_spi_intr_error),
      .intr_spi_event_o(ot_spi_intr_event)
  );

endmodule  // spi_subsystem
