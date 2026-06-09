// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%
  base_peripheral_domain = xheep.get_base_peripheral_domain()
%>

module spi_subsystem
#(
    parameter int DataWidth = 64,
    parameter int AddrWidth = 64,
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,
% if base_peripheral_domain.contains_peripheral('axi_spi'):
    parameter type axi_req_t = logic,
    parameter type axi_resp_t = logic,
    parameter int ClockFrequencyMAX_MHz = 1e3,
% else:
% endif
% if base_peripheral_domain.contains_peripheral('obi_spi'):
    parameter type obi_req_t = logic,
    parameter type obi_resp_t = logic,
% else:
% endif
    parameter logic ByteOrder = 1  // 1 = little endian , 0 = big endian

)(

    input logic clk_i,
    input logic rst_ni,

% if base_peripheral_domain.contains_peripheral('obi_spi'):
    // Select signal between spimemio and spi_host (YOSYS and OpenTitan)
    input logic use_spimemio_i,

    // spimemio data interface (obi)
    input  obi_req_t  spimemio_obi_req_i,
    output obi_resp_t spimemio_obi_resp_o,

    // spimemio configuration interface (reg)
    input  reg_req_t  spimemio_reg_req_i,
    output reg_rsp_t  spimemio_reg_rsp_o,
% else:
% endif

% if base_peripheral_domain.contains_peripheral('axi_spi'):
    // AXI interface
    input  axi_req_t  axi_req_i,
    output axi_resp_t axi_rsp_o,
% else:
% endif

    // spi_subsystem configuration interface (reg)
    input  reg_req_t  top_reg_req_i, 
    output reg_rsp_t  top_reg_rsp_o,

    // spi_host data and configuration interface
    input  reg_req_t  spihost_reg_req_i,
    output reg_rsp_t  spihost_reg_rsp_o,

% if base_peripheral_domain.contains_peripheral('w25q128jw_controller'):
    // w25q128jw flash controller configuration interface
    input  reg_req_t  w25_ctr_reg_req_i,
    output reg_rsp_t  w25_ctr_reg_rsp_o,

    // DMA hw controller register direct access
    output dma_reg_pkg::dma_hw2reg_t external_dma_hw2reg_o,

    // flash controller interrupt
    output logic w25q128jw_controller_intr_o,

    // DMA handshake
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_ready_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_done_i,
% else:
% endif

    // SPI Interface
    output logic                               spi_flash_sck_o,
    output logic                               spi_flash_sck_en_o,
    output logic [spi_host_reg_pkg::NumCS-1:0] spi_flash_csb_o,
    output logic [spi_host_reg_pkg::NumCS-1:0] spi_flash_csb_en_o,
    output logic [                        3:0] spi_flash_sd_o,
    output logic [                        3:0] spi_flash_sd_en_o,
    input  logic [                        3:0] spi_flash_sd_i,

    // spi_host interrupts
    output logic spi_flash_intr_error_o,
    output logic spi_flash_intr_event_o,

    // spi_host data fifos handshake to DMA
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

  spi_host_reg_pkg::spi_host_hw2reg_status_reg_t external_spi_host_hw2reg_status;

% if base_peripheral_domain.contains_peripheral('obi_spi'):

  // YosysHW SPI Interface
  logic                               yo_spi_sck;
  logic                               yo_spi_sck_en;
  logic [spi_host_reg_pkg::NumCS-1:0] yo_spi_csb;
  logic [spi_host_reg_pkg::NumCS-1:0] yo_spi_csb_en;
  logic [                        3:0] yo_spi_sd_out;
  logic [                        3:0] yo_spi_sd_en;
  logic [                        3:0] yo_spi_sd_in;

  // // Multiplexer - select the active spi controller
    // among:
    // spimemio
    // spi_host
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


  // spi controller : spimemio
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
      .reg_req_i(spimemio_reg_req_i),
      .reg_rsp_o(spimemio_reg_rsp_o),
      .spimemio_req_i(spimemio_obi_req_i),
      .spimemio_resp_o(spimemio_obi_resp_o)
  );

% else:

always_comb begin
  spi_flash_sck_o = ot_spi_sck;
  spi_flash_sck_en_o = ot_spi_sck_en;
  spi_flash_csb_o = ot_spi_csb;
  spi_flash_csb_en_o = ot_spi_csb_en;
  spi_flash_sd_o = ot_spi_sd_out;
  spi_flash_sd_en_o = ot_spi_sd_en;
  ot_spi_sd_in = spi_flash_sd_i;
  spi_flash_intr_error_o = ot_spi_intr_error;
  spi_flash_intr_event_o = ot_spi_intr_event;
  spi_flash_rx_valid_o = ot_spi_rx_valid;
  spi_flash_tx_ready_o = ot_spi_tx_ready;
end

%endif

% if base_peripheral_domain.contains_peripheral('axi_spi'):

  // AXI to flash controller
  reg_req_t reg_req_from_a2f_ctr;
  reg_rsp_t reg_rsp_to_a2f_ctr;

  axi_to_flash_controller #(
      .ByteOrder,
      .AddrWidth,   // behavior differs depending from dataWidth, generated HW is always the same.
      .ClockFrequencyMAX_MHz,
      .FlashAddrW(24),
      .DataWidth,
      .axi_req_t(axi_req_t),
      .axi_resp_t(axi_resp_t),
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) axi_to_flash_controller_i (
      .clk_i,
      .rst_ni,

      // Enable by xspi register
      .en_i(reg2hw.control.use_axi.q),

      // Enable power-on subrutine
      .poweron_en_i(reg2hw.control.a2f_ctr_poweron_en.q),

      // Enable quad spi
      .quadspi_en_i(reg2hw.control.a2f_ctr_quadspi_en.q),

      // register interface to SPI controller
      .spi_host_reg_req_o(reg_req_from_a2f_ctr),
      .spi_host_reg_rsp_i(reg_rsp_to_a2f_ctr),

      // SPI controller status direct connection from hw2reg
      .external_spi_host_hw2reg_status_i(external_spi_host_hw2reg_status),

      // AXI interface
      .axi_req_i(axi_req_i),
      .axi_rsp_o(axi_rsp_o)
  );

% else:  
% endif

  reg_req_t muxed_controllers_reg_req;
  reg_rsp_t muxed_controllers_reg_rsp;

% if base_peripheral_domain.contains_peripheral('w25q128jw_controller'):

  // w25q128jw_controller
  import dma_reg_pkg::*;
  reg_req_t reg_req_from_w25_ctr;
  reg_rsp_t reg_rsp_to_w25_ctr;

  w25q128jw_controller #(
      .reg_req_t(reg_req_t), // useful addr is always 31:0
      .reg_rsp_t(reg_rsp_t)
  ) w25q128jw_controller_i (
      .clk_i,
      .rst_ni,

      // Register interface with master
      .reg_req_i(w25_ctr_reg_req_i),
      .reg_rsp_o(w25_ctr_reg_rsp_o),

      // Interrupt signal
      .w25q128jw_controller_intr_o,

      // DMA hw controller
      .external_dma_hw2reg_o,

      // spi_host reg2hw.status direct access
      .external_spi_host_hw2reg_status_i(external_spi_host_hw2reg_status),

      // Register interface with spi_host (slave)
      .spi_host_reg_req_o(reg_req_from_w25_ctr),
      .spi_host_reg_rsp_i(reg_rsp_to_w25_ctr),

      // Handshake from DMA hw
      .dma_ready_i,
      .dma_done_i
  );

% else:
% endif

% if base_peripheral_domain.contains_peripheral('w25q128jw_controller'):

% if base_peripheral_domain.contains_peripheral('axi_spi'):

  // // Multiplexer - select the active flash controller
    // among:
    // w25q128jw_controller - driven by external register interface
    // axi_to_flash_controller - driven by external AXI interface

  always_comb begin
    if(reg2hw.control.use_axi.q) begin

      muxed_controllers_reg_req = reg_req_from_a2f_ctr;
      reg_rsp_to_a2f_ctr = muxed_controllers_reg_rsp;
      reg_rsp_to_w25_ctr = reg_rsp_unused;

    end else begin

      muxed_controllers_reg_req = reg_req_from_w25_ctr;
      reg_rsp_to_a2f_ctr = reg_rsp_unused;
      reg_rsp_to_w25_ctr = muxed_controllers_reg_rsp;

    end
  end

% else: ## w25_ctr , no axi

  assign muxed_controllers_reg_req = reg_req_from_w25_ctr;
  assign reg_rsp_to_w25_ctr = muxed_controllers_reg_rsp;

% endif

% else: 

% if base_peripheral_domain.contains_peripheral('axi_spi'): ## no w25_ctr , axi
 
  assign muxed_controllers_reg_req = reg_req_from_a2f_ctr;
  assign reg_rsp_to_a2f_ctr = muxed_controllers_reg_rsp;

% else: ## no w25_ctr , no axi
  
  assign muxed_controllers_reg_req = '0;

% endif

% endif

  // // Multiplexer - select the spi controller's master
    // among:
    // active flash controller
    // external
  reg_req_t [1:0] spi_host_reg_packet_req;
  reg_rsp_t [1:0] spi_host_reg_packet_rsp;

  assign spi_host_reg_packet_req[0] = spihost_reg_req_i;
  assign spi_host_reg_packet_req[1] = muxed_controllers_reg_req;
  assign muxed_controllers_reg_rsp  = spi_host_reg_packet_rsp[1];
  assign spihost_reg_rsp_o          = spi_host_reg_packet_rsp[0];
 

  reg_req_t spi_host_reg_req_mux;
  reg_rsp_t spi_host_reg_rsp_mux;

  reg_mux #(
      .NoPorts(2),
      .req_t  (reg_req_t),
      .rsp_t  (reg_rsp_t),
      .AW     (AddrWidth),
      .DW     (32)
  ) reg_mux_i (
      .clk_i,
      .rst_ni,
      .in_req_i (spi_host_reg_packet_req),
      .in_rsp_o (spi_host_reg_packet_rsp),
      .out_req_o(spi_host_reg_req_mux),
      .out_rsp_i(spi_host_reg_rsp_mux)
  );


  // OpenTitan SPI Snitch Version used for booting
  spi_host #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) ot_spi_i (
      .clk_i,
      .rst_ni,

      // Register interface with master
      .reg_req_i(spi_host_reg_req_mux),
      .reg_rsp_o(spi_host_reg_rsp_mux),
      
      .alert_rx_i(),
      .alert_tx_o(),
      .passthrough_i(spi_device_pkg::PASSTHROUGH_REQ_DEFAULT),
      .passthrough_o(),

      // SPI interface
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

  // Registers
  spi_subsystem_reg_pkg::spi_subsystem_reg2hw_t reg2hw;
  spi_subsystem_reg_pkg::spi_subsystem_hw2reg_t hw2reg;

  spi_subsystem_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) spi_subsystem_reg_top_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .reg_req_i(top_reg_req_i),
      .reg_rsp_o(top_reg_rsp_o),
      .reg2hw,
      .hw2reg,
      .devmode_i(1'b1)
  );

% if base_peripheral_domain.contains_peripheral('w25q128jw_controller'):
`ifndef SYNTHESIS

  always_ff @(posedge clk_i) begin : yosys_spi_write
    if (spimemio_obi_req_i.req && spimemio_obi_req_i.we) begin
      $error("%t: Writing to Yosys OBI SPI port", $time);
      $finish;
    end
  end

`endif
% else:
% endif

endmodule  // spi_subsystem
