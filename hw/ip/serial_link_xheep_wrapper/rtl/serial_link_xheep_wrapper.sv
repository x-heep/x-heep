/*
 * Copyright 2025 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *  
 * Info: XHEEP wrapper for pulp-platform/serial_link.
  On the sending side, it translates OBI transactions to AXI requests. 
  On the receiving side, write requests are not propagated as 
  AXI master operations but stored in a memory-mapped FIFO, 
  which can be accessed via DMA in tests. 
  Master functionality on the receiving side is not implemented.
 */

module serial_link_xheep_wrapper
  import obi_pkg::*;
  import serial_link_minimum_axi_pkg::*;
  import axi_pkg::*;
#(
    parameter int MaxClkDiv = 32,
    parameter int AddrWidth = 32,
    parameter int DataWidth = 32
) (
    input logic clk_i,
    input logic rst_ni,
    input logic clk_reg_i,
    input logic rst_reg_ni,
    input logic testmode_i,

    input  obi_pkg::obi_req_t  writer_req_i,
    output obi_pkg::obi_resp_t writer_rsp_i,

    input  obi_pkg::obi_req_t  reader_req_i,
    output obi_pkg::obi_resp_t reader_resp_o,

    input  reg_pkg::reg_req_t cfg_req_i,
    output reg_pkg::reg_rsp_t cfg_rsp_o,


    input logic [serial_link_minimum_axi_pkg::NumChannels-1:0] ddr_rcv_clk_i,
    output logic [serial_link_minimum_axi_pkg::NumChannels-1:0] ddr_rcv_clk_o,
    input  logic [serial_link_minimum_axi_pkg::NumChannels-1:0][serial_link_minimum_axi_pkg::NumLanes-1:0] ddr_i,
    output logic [serial_link_minimum_axi_pkg::NumChannels-1:0][serial_link_minimum_axi_pkg::NumLanes-1:0] ddr_o

);

  import serial_link_reg_pkg::*;
  logic rst_serial_link_n;
  logic reset_n;

  serial_link_minimum_axi_pkg::axi_req_t fast_sl_req_O, axi_in_req, axi_lite_req;
  serial_link_minimum_axi_pkg::axi_resp_t fast_sl_rsp_O, axi_in_rsp, axi_lite_rsp;

  axi_lite_from_mem #(
      .MemAddrWidth(AddrWidth),
      .AxiAddrWidth(AddrWidth),
      .DataWidth   (DataWidth),
      .MaxRequests (DataWidth),  // fifo size
      .axi_req_t   (serial_link_minimum_axi_pkg::axi_req_t),
      .axi_rsp_t   (serial_link_minimum_axi_pkg::axi_resp_t)
  ) i_obi2axi (
      .clk_i,
      .rst_ni,
      .mem_req_i      (writer_req_i.req),
      .mem_addr_i     (writer_req_i.addr),
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
      .slv_aw_cache_i(),
      .slv_ar_cache_i(),
      .mst_req_o(axi_in_req),
      .mst_resp_i(axi_in_rsp)
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
      .writer_axi_req_i(fast_sl_req_O),
      .writer_axi_rsp_o(fast_sl_rsp_O)
  );

  tc_clk_mux2 i_tc_reset_mux (
      .clk0_i(reset_n),
      .clk1_i(rst_ni),
      .clk_sel_i(testmode_i),
      .clk_o(rst_serial_link_n)
  );

  if (NumChannels > 1) begin : gen_multi_channel_serial_link
    serial_link #(
        .axi_req_t  (serial_link_minimum_axi_pkg::axi_req_t),
        .axi_rsp_t  (serial_link_minimum_axi_pkg::axi_resp_t),
        .aw_chan_t  (serial_link_minimum_axi_pkg::axi_aw_t),
        .w_chan_t   (serial_link_minimum_axi_pkg::axi_w_t),
        .b_chan_t   (serial_link_minimum_axi_pkg::axi_b_t),
        .ar_chan_t  (serial_link_minimum_axi_pkg::axi_ar_t),
        .r_chan_t   (serial_link_minimum_axi_pkg::axi_r_t),
        .cfg_req_t  (reg_pkg::reg_req_t),
        .cfg_rsp_t  (reg_pkg::reg_rsp_t),
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
        .ddr_rcv_clk_o(ddr_rcv_clk_o),
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
        .cfg_req_t  (reg_pkg::reg_req_t),
        .cfg_rsp_t  (reg_pkg::reg_rsp_t),
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
        .ddr_rcv_clk_o(ddr_rcv_clk_o),
        .ddr_i        (ddr_i),
        .ddr_o        (ddr_o),
        .isolated_i   (2'b0),
        .isolate_o    (),
        .clk_ena_o    (),
        .reset_no     (reset_n)
    );
  end

endmodule


