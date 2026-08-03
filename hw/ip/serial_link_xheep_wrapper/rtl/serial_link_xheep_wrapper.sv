/*
 * Copyright 2025 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *  
 * Info: XHEEP wrapper for pulp-platform/serial_link.
 * On the sending side, it translates OBI transactions to AXI requests.
 * On the receiving side, two RX modes are selectable via the RX_MODE
 * software register:
 *   - FIFO mode (rx_mode=0, default): incoming AXI write transactions
 *     are stored in a memory-mapped FIFO, readable via DMA or polling.
 *   - Direct write mode (rx_mode=1): incoming AXI write transactions
 *     are routed through axi_to_mem directly to into the receiving 
 *     X-HEEP’s memory space. 
 */

module serial_link_xheep_wrapper
  import serial_link_minimum_axi_pkg::*;
  import axi_pkg::*;
  import serial_link_xheep_wrapper_reg_pkg::*;
#(
    parameter int MaxClkDiv = 1024,
    parameter int AddrWidth = 32,
    parameter int DataWidth = 32,
    parameter logic [31:0] AxiAddrOffset = 32'h0,
    // OBI and Register Interface data types
    parameter type obi_req_t = xheep_obi_pkg::xheep_obi_req_t,
    parameter type obi_rsp_t = xheep_obi_pkg::xheep_obi_rsp_t,
    parameter type reg_req_t = xheep_reg_pkg::xheep_reg_req_t,
    parameter type reg_rsp_t = xheep_reg_pkg::xheep_reg_rsp_t
) (
    input logic clk_i,
    input logic rst_ni,
    input logic clk_reg_i,
    input logic rst_reg_ni,
    input logic testmode_i,

    input  obi_req_t writer_req_i,
    output obi_rsp_t writer_rsp_i,

    input  obi_req_t reader_req_i,
    output obi_rsp_t reader_resp_o,

    input  reg_req_t cfg_req_i,
    output reg_rsp_t cfg_rsp_o,

    input  reg_req_t wrapper_cfg_req_i,
    output reg_rsp_t wrapper_cfg_rsp_o,

    output obi_req_t direct_write_req_o,
    input  obi_rsp_t direct_write_resp_i,

    input logic [serial_link_minimum_axi_pkg::NumChannels-1:0] ddr_rcv_clk_i,
    output logic [serial_link_minimum_axi_pkg::NumChannels-1:0] ddr_snd_clk_o,
    input  logic [serial_link_minimum_axi_pkg::NumChannels-1:0][serial_link_minimum_axi_pkg::NumLanes-1:0] ddr_i,
    output logic [serial_link_minimum_axi_pkg::NumChannels-1:0][serial_link_minimum_axi_pkg::NumLanes-1:0] ddr_o

);

  import serial_link_reg_pkg::*;
  logic rst_serial_link_n;
  logic reset_n;

  serial_link_minimum_axi_pkg::axi_req_t fast_sl_req_O, axi_in_req, axi_lite_req;
  serial_link_minimum_axi_pkg::axi_resp_t fast_sl_rsp_O, axi_in_rsp, axi_lite_rsp;

  serial_link_minimum_axi_pkg::axi_req_t fifo_axi_req, direct_axi_req;
  serial_link_minimum_axi_pkg::axi_resp_t fifo_axi_rsp, direct_axi_rsp;
  serial_link_minimum_axi_pkg::axi_req_t direct_axi_req_cut;
  serial_link_minimum_axi_pkg::axi_resp_t direct_axi_rsp_cut;

  logic rx_mode;
  serial_link_xheep_wrapper_reg_pkg::serial_link_xheep_wrapper_reg2hw_t reg2hw;

  serial_link_xheep_wrapper_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) i_serial_link_xheep_wrapper_reg_top (
      .clk_i,
      .rst_ni,
      .reg_req_i(wrapper_cfg_req_i),
      .reg_rsp_o(wrapper_cfg_rsp_o),
      .reg2hw   (reg2hw),
      .devmode_i(1'b1)
  );

  assign rx_mode = reg2hw.rx_mode.q;

  axi_lite_from_mem #(
      .MemAddrWidth(32'd32), // obi addr width
      .AxiAddrWidth(serial_link_minimum_axi_pkg::AXI_ADDR_WIDTH),
      .DataWidth   (DataWidth),
      .MaxRequests (DataWidth),  // fifo size
      .axi_req_t   (serial_link_minimum_axi_pkg::axi_req_t),
      .axi_rsp_t   (serial_link_minimum_axi_pkg::axi_resp_t)
  ) i_obi2axi (
      .clk_i,
      .rst_ni,
      .mem_req_i      (writer_req_i.req),
      .mem_addr_i     (writer_req_i.addr - AxiAddrOffset),
      .mem_we_i       (writer_req_i.we),
      .mem_wdata_i    (writer_req_i.wdata),
      .mem_be_i       (writer_req_i.be),
      .mem_gnt_o      (writer_rsp_i.gnt),
      .mem_rsp_valid_o(writer_rsp_i.rvalid),
      .mem_rsp_rdata_o(writer_rsp_i.rdata),
      .mem_rsp_error_o(),
      .axi_req_o      (axi_lite_req),
      .axi_rsp_i      (axi_lite_rsp)
  );

  axi_lite_to_axi #(
      .AxiDataWidth(32'd32),

      .req_lite_t (serial_link_minimum_axi_pkg::axi_req_t),
      .resp_lite_t(serial_link_minimum_axi_pkg::axi_resp_t),

      .axi_req_t (serial_link_minimum_axi_pkg::axi_req_t),
      .axi_resp_t(serial_link_minimum_axi_pkg::axi_resp_t)
  ) i_axi_lite_to_axi (
      // Slave AXI LITE port
      .slv_req_lite_i(axi_lite_req),
      .slv_resp_lite_o(axi_lite_rsp),
      .slv_aw_cache_i('0),
      .slv_ar_cache_i('0),
      .mst_req_o(axi_in_req),
      .mst_resp_i(axi_in_rsp)
  );

  // MUX - route fast_sl_req_O to either FIFO or direct write path
  always_comb begin
    fifo_axi_req   = '0;
    direct_axi_req = '0;
    if (rx_mode) begin
      direct_axi_req = fast_sl_req_O;
      fast_sl_rsp_O  = direct_axi_rsp;
    end else begin
      fifo_axi_req  = fast_sl_req_O;
      fast_sl_rsp_O = fifo_axi_rsp;
    end
  end

  axi_cut #(
      .aw_chan_t (serial_link_minimum_axi_pkg::axi_aw_t),
      .w_chan_t  (serial_link_minimum_axi_pkg::axi_w_t),
      .b_chan_t  (serial_link_minimum_axi_pkg::axi_b_t),
      .ar_chan_t (serial_link_minimum_axi_pkg::axi_ar_t),
      .r_chan_t  (serial_link_minimum_axi_pkg::axi_r_t),
      .axi_req_t (serial_link_minimum_axi_pkg::axi_req_t),
      .axi_resp_t(serial_link_minimum_axi_pkg::axi_resp_t)
  ) i_axi_cut (
      .clk_i,
      .rst_ni,
      .slv_req_i (direct_axi_req),
      .slv_resp_o(direct_axi_rsp),
      .mst_req_o (direct_axi_req_cut),
      .mst_resp_i(direct_axi_rsp_cut)
  );

  axi_to_mem #(
      .axi_req_t (serial_link_minimum_axi_pkg::axi_req_t),
      .axi_resp_t(serial_link_minimum_axi_pkg::axi_resp_t),
      .AddrWidth (AddrWidth),
      .DataWidth (DataWidth),
      .IdWidth   (serial_link_minimum_axi_pkg::AXI_ID_WIDTH),
      .NumBanks  (1),
      .BufDepth  (1)
  ) i_axi_to_mem (
      .clk_i,
      .rst_ni,
      .busy_o      (),
      .axi_req_i   (direct_axi_req_cut),
      .axi_resp_o  (direct_axi_rsp_cut),
      .mem_req_o   (direct_write_req_o.req),
      .mem_gnt_i   (direct_write_resp_i.gnt),
      .mem_addr_o  (direct_write_req_o.addr),
      .mem_wdata_o (direct_write_req_o.wdata),
      .mem_strb_o  (direct_write_req_o.be),
      .mem_atop_o  (),
      .mem_we_o    (direct_write_req_o.we),
      .mem_rvalid_i(direct_write_resp_i.rvalid),
      .mem_rdata_i (direct_write_resp_i.rdata)
  );

  // Slave interface for the Serial Link
  // Data is saved in the fifo of parametrizable depth
  // The new transactions can be accepted only when fifo is empty
  serial_link_xheep_wrapper_fifo #(
      .axi_req_t (axi_req_t),
      .axi_rsp_t (axi_resp_t),
      .FIFO_DEPTH(8)
  ) serial_link_xheep_wrapper_fifo_i (
      .clk_i,
      .rst_ni,
      .reader_gnt_o    (reader_resp_o.gnt),
      .reader_req_i    (reader_req_i.req),
      .reader_rvalid_o (reader_resp_o.rvalid),
      .reader_we_i     (reader_req_i.we),
      .reader_rdata_o  (reader_resp_o.rdata),
      .writer_axi_req_i(fifo_axi_req),
      .writer_axi_rsp_o(fifo_axi_rsp)
  );

  tc_clk_mux2 i_tc_reset_mux (
      .clk0_i(reset_n),
      .clk1_i(rst_ni),
      .clk_sel_i(testmode_i),
      .clk_o(rst_serial_link_n)
  );

  if (serial_link_minimum_axi_pkg::NumChannels > 1) begin : gen_multi_channel_serial_link
    serial_link #(
        .axi_req_t  (serial_link_minimum_axi_pkg::axi_req_t),
        .axi_rsp_t  (serial_link_minimum_axi_pkg::axi_resp_t),
        .aw_chan_t  (serial_link_minimum_axi_pkg::axi_aw_t),
        .w_chan_t   (serial_link_minimum_axi_pkg::axi_w_t),
        .b_chan_t   (serial_link_minimum_axi_pkg::axi_b_t),
        .ar_chan_t  (serial_link_minimum_axi_pkg::axi_ar_t),
        .r_chan_t   (serial_link_minimum_axi_pkg::axi_r_t),
        .cfg_req_t  (reg_req_t),
        .cfg_rsp_t  (reg_rsp_t),
        .hw2reg_t   (serial_link_reg_pkg::serial_link_hw2reg_t),
        .reg2hw_t   (serial_link_reg_pkg::serial_link_reg2hw_t),
        .NumChannels(serial_link_minimum_axi_pkg::NumChannels),
        .NumLanes   (serial_link_minimum_axi_pkg::NumLanes),
        .MaxClkDiv  (MaxClkDiv)
    ) i_serial_link (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .clk_sl_i     (clk_i),
        .rst_sl_ni    (rst_serial_link_n),
        .clk_reg_i    (clk_reg_i),
        .rst_reg_ni   (rst_reg_ni),
        .testmode_i   (1'b0),
        .axi_in_req_i (axi_in_req),
        .axi_in_rsp_o (axi_in_rsp),
        .axi_out_req_o(fast_sl_req_O),
        .axi_out_rsp_i(fast_sl_rsp_O),
        .cfg_req_i    (cfg_req_i),
        .cfg_rsp_o    (cfg_rsp_o),
        .ddr_rcv_clk_i(ddr_rcv_clk_i),
        .ddr_rcv_clk_o(ddr_snd_clk_o),
        .ddr_i        (ddr_i),
        .ddr_o        (ddr_o),
        .isolated_i   (2'b0),
        .isolate_o    (),
        .clk_ena_o    (),
        .reset_no     (reset_n)
    );
  end else begin : gen_single_channel_serial_link
    serial_link #(
        .axi_req_t  (serial_link_minimum_axi_pkg::axi_req_t),
        .axi_rsp_t  (serial_link_minimum_axi_pkg::axi_resp_t),
        .aw_chan_t  (serial_link_minimum_axi_pkg::axi_aw_t),
        .w_chan_t   (serial_link_minimum_axi_pkg::axi_w_t),
        .b_chan_t   (serial_link_minimum_axi_pkg::axi_b_t),
        .ar_chan_t  (serial_link_minimum_axi_pkg::axi_ar_t),
        .r_chan_t   (serial_link_minimum_axi_pkg::axi_r_t),
        .cfg_req_t  (reg_req_t),
        .cfg_rsp_t  (reg_rsp_t),
        .hw2reg_t   (serial_link_single_channel_reg_pkg::serial_link_single_channel_hw2reg_t),
        .reg2hw_t   (serial_link_single_channel_reg_pkg::serial_link_single_channel_reg2hw_t),
        .NumChannels(serial_link_minimum_axi_pkg::NumChannels),
        .NumLanes   (serial_link_minimum_axi_pkg::NumLanes),
        .MaxClkDiv  (MaxClkDiv)
    ) i_serial_link (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .clk_sl_i     (clk_i),
        .rst_sl_ni    (rst_serial_link_n),
        .clk_reg_i    (clk_reg_i),
        .rst_reg_ni   (rst_reg_ni),
        .testmode_i   (1'b0),
        .axi_in_req_i (axi_in_req),
        .axi_in_rsp_o (axi_in_rsp),
        .axi_out_req_o(fast_sl_req_O),
        .axi_out_rsp_i(fast_sl_rsp_O),
        .cfg_req_i    (cfg_req_i),
        .cfg_rsp_o    (cfg_rsp_o),
        .ddr_rcv_clk_i(ddr_rcv_clk_i),
        .ddr_rcv_clk_o(ddr_snd_clk_o),
        .ddr_i        (ddr_i),
        .ddr_o        (ddr_o),
        .isolated_i   (2'b0),
        .isolate_o    (),
        .clk_ena_o    (),
        .reset_no     (reset_n)
    );
  end

endmodule


