// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%
  base_peripheral_domain = xheep.get_base_peripheral_domain()
%>

module spi_subsystem
  import obi_pkg::*;
  import reg_pkg::*;
  import core_v_mini_mcu_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic use_spimemio_i,

    // Memory mapped SPI
    input  obi_req_t  spimemio_req_i,
    output obi_resp_t spimemio_resp_o,

    // Yosys SPI configuration
    input  reg_req_t  yo_reg_req_i,
    output reg_rsp_t  yo_reg_rsp_o,
    // OpenTitan SPI configuration
    input  reg_req_t  ot_reg_req_i,
    output reg_rsp_t  ot_reg_rsp_o,
    // w25q128jw flash controller configuration
    input  reg_req_t  flash_ctr_reg_req_i,
    output reg_rsp_t  flash_ctr_reg_rsp_o,

    //dma hw controller
    output dma_reg_pkg::dma_hw2reg_t external_dma_hw2reg_o,
    // flash controller interrupt
    output logic w25q128jw_controller_intr_o,

    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_ready_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_done_i,

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

  // YosysHW SPI Interface
  logic                               yo_spi_sck;
  logic                               yo_spi_sck_en;
  logic [spi_host_reg_pkg::NumCS-1:0] yo_spi_csb;
  logic [spi_host_reg_pkg::NumCS-1:0] yo_spi_csb_en;
  logic [                        3:0] yo_spi_sd_out;
  logic [                        3:0] yo_spi_sd_en;
  logic [                        3:0] yo_spi_sd_in;

  import spi_host_reg_pkg::*;
  spi_host_reg_pkg::spi_host_hw2reg_status_reg_t external_spi_host_hw2reg_status;

  // Multiplexer
  always_comb begin
    if (!use_spimemio_i) begin
      spi_flash_sck_o = ot_spi_sck;
      spi_flash_sck_en_o = ot_spi_sck_en;
      spi_flash_csb_o = ot_spi_csb;
      spi_flash_csb_en_o = ot_spi_csb_en;
      spi_flash_sd_o = ot_spi_sd_out;
      spi_flash_sd_en_o = ot_spi_sd_en;
      ot_spi_sd_in = spi_flash_sd_i;
      yo_spi_sd_in = '0;
      spi_flash_intr_error_o = ot_spi_intr_error;
      spi_flash_intr_event_o = ot_spi_intr_event;
      spi_flash_rx_valid_o = ot_spi_rx_valid;
      spi_flash_tx_ready_o = ot_spi_tx_ready;
    end else begin
      spi_flash_sck_o = yo_spi_sck;
      spi_flash_sck_en_o = yo_spi_sck_en;
      spi_flash_csb_o = yo_spi_csb;
      spi_flash_csb_en_o = yo_spi_csb_en;
      spi_flash_sd_o = yo_spi_sd_out;
      spi_flash_sd_en_o = yo_spi_sd_en;
      ot_spi_sd_in = '0;
      yo_spi_sd_in = spi_flash_sd_i;
      spi_flash_intr_error_o = 1'b0;
      spi_flash_intr_event_o = 1'b0;
      spi_flash_rx_valid_o = 1'b0;
      spi_flash_tx_ready_o = 1'b0;
    end
  end

  // YosysHQ SPI
  assign yo_spi_sck_en = 1'b1;
  assign yo_spi_csb_en = 2'b01;
  assign yo_spi_csb[1] = 1'b1;

  obi_spimemio obi_spimemio_i (
      .clk_i,
      .rst_ni,
      .flash_csb_o(yo_spi_csb[0]),
      .flash_clk_o(yo_spi_sck),
      .flash_io0_oe_o(yo_spi_sd_en[0]),
      .flash_io1_oe_o(yo_spi_sd_en[1]),
      .flash_io2_oe_o(yo_spi_sd_en[2]),
      .flash_io3_oe_o(yo_spi_sd_en[3]),
      .flash_io0_do_o(yo_spi_sd_out[0]),
      .flash_io1_do_o(yo_spi_sd_out[1]),
      .flash_io2_do_o(yo_spi_sd_out[2]),
      .flash_io3_do_o(yo_spi_sd_out[3]),
      .flash_io0_di_i(yo_spi_sd_in[0]),
      .flash_io1_di_i(yo_spi_sd_in[1]),
      .flash_io2_di_i(yo_spi_sd_in[2]),
      .flash_io3_di_i(yo_spi_sd_in[3]),
      .reg_req_i(yo_reg_req_i),
      .reg_rsp_o(yo_reg_rsp_o),
      .spimemio_req_i(spimemio_req_i),
      .spimemio_resp_o(spimemio_resp_o)
  );


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
      .req_t  (reg_pkg::reg_req_t),
      .rsp_t  (reg_pkg::reg_rsp_t),
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

  w25q128jw_controller #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
  ) w25q128jw_controller_i (
      .clk_i,
      .rst_ni,

      // Register interface
      .reg_req_i(flash_ctr_reg_req_i),
      .reg_rsp_o(flash_ctr_reg_rsp_o),

      // Interrupt signal
      .w25q128jw_controller_intr_o,

      //dma hw controller
      .external_dma_hw2reg_o,
      //spi status if
      .external_spi_host_hw2reg_status_i(external_spi_host_hw2reg_status),

      // Master ports on the system bus
      .spi_host_reg_req_o(spi_host_reg_req),
      .spi_host_reg_rsp_i(spi_host_reg_rsp),

      .dma_ready_i,
      .dma_done_i
  );

% else:
  assign w25q128jw_controller_intr_o = '0;
  assign flash_ctr_reg_rsp_o = '0;
  assign external_dma_hw2reg_o = '0;
  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_ready_unused = dma_ready_i;
  spi_host_reg_pkg::spi_host_hw2reg_status_reg_t external_spi_host_hw2reg_status_unused = external_spi_host_hw2reg_status;
% endif



  // OpenTitan SPI Snitch Version used for booting
  spi_host #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
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

`ifndef SYNTHESIS

  always_ff @(posedge clk_i) begin : yosys_spi_write
    if (spimemio_req_i.req && spimemio_req_i.we) begin
      $error("%t: Writing to Yosys OBI SPI port", $time);
      $finish;
    end
  end

`endif

endmodule  // spi_subsystem
