// (copied from spi_host_data_fifos by OpenTitan)
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Module for SPI_HOST RX and TX queues
//

module axi_to_flash_beat_queues #(
  parameter int                DataWidth = 64,
  parameter int                DataBytes = DataWidth/8,
  parameter int                WrDepth   = 72,
  parameter int                RdDepth   = 64,
  parameter logic              SwapBytes = 0
) (
  input logic                  clk_i,
  input logic                  rst_ni,

  input  logic [DataWidth-1:0] axi2fls_wr_data_i,
  input  logic [DataBytes-1:0] axi2fls_wr_be_i,
  input  logic                 axi2fls_wr_valid_i,
  output logic                 axi2fls_wr_ready_o,


  output logic [DataWidth-1:0] spihost_wr_data_o,
  output logic [DataBytes-1:0] spihost_wr_be_o,
  output logic                 spihost_wr_valid_o,
  input  logic                 spihost_wr_ready_i,

  input  logic [DataWidth-1:0] spihost_rd_data_i,
  input  logic                 spihost_rd_valid_i,
  output logic                 spihost_rd_ready_o,

  output logic [DataWidth-1:0] axi2fls_rd_data_o,
  output logic                 axi2fls_rd_valid_o,
  input  logic                 axi2fls_rd_ready_i,


  input  logic                 clear_i,
  
  input  logic [7:0]           wr_watermark_i,
  input  logic [7:0]           rd_watermark_i,
  
  output logic                 wr_empty_o,
  output logic                 wr_full_o,
  output logic [7:0]           wr_qd_o,
  output logic                 wr_wm_o,
  output logic                 rd_empty_o,
  output logic                 rd_full_o,
  output logic [7:0]           rd_qd_o,
  output logic                 rd_wm_o
);

  // Numer of bits coding RdDepth and WrDepth
  localparam int RdDepthWidth = prim_util_pkg::vbits(RdDepth+1);
  localparam int WrDepthWidth = prim_util_pkg::vbits(WrDepth+1);

  // Byte Swapping
  logic [DataWidth-1:0] axi2fls_wr_data_ordered;
  logic [DataBytes-1:0] axi2fls_wr_be_ordered;
  logic [DataWidth-1:0] axi2fls_rd_data_unordered;
  if (SwapBytes) begin : gen_swap
    assign axi2fls_wr_data_ordered = { << 8 { axi2fls_wr_data_i } };
    assign axi2fls_wr_be_ordered   = { << { axi2fls_wr_be_i } };
    assign axi2fls_rd_data_o       = { << 8 { axi2fls_rd_data_unordered } };
  end else begin : gen_do_not_swap
    assign axi2fls_wr_data_ordered = axi2fls_wr_data_i;
    assign axi2fls_wr_be_ordered   = axi2fls_wr_be_i;
    assign axi2fls_rd_data_o       = axi2fls_rd_data_unordered;
  end : gen_do_not_swap

  // Concatenation of byte enable and data
  logic [DataWidth+DataBytes-1:0] axi2fls_wr_data_be;
  logic [DataWidth+DataBytes-1:0] spihost_wr_data_be;
  assign axi2fls_wr_data_be = { axi2fls_wr_data_ordered, axi2fls_wr_be_ordered };
  assign { spihost_wr_data_o, spihost_wr_be_o } = spihost_wr_data_be;

  // Write queue
  logic [WrDepthWidth-1:0] wr_depth;
  assign wr_qd_o = 8'(wr_depth);

  prim_fifo_sync #(
    .Width(DataWidth+DataBytes),
    .Pass(1),
    .Depth(WrDepth)
  ) u_wr_queue (
    .clk_i,
    .rst_ni,
    .clr_i    (clear_i),
    .wvalid_i (axi2fls_wr_valid_i),
    .wready_o (axi2fls_wr_ready_o),
    .wdata_i  (axi2fls_wr_data_be),
    .rvalid_o (spihost_wr_valid_o),
    .rready_i (spihost_wr_ready_i),
    .rdata_o  (spihost_wr_data_be),
    .full_o   (),
    .depth_o  (wr_depth)
  );

  // Read Queue
  logic [RdDepthWidth-1:0] rd_depth;
  assign rd_qd_o = 8'(rd_depth);

  prim_fifo_sync #(
    .Width(DataWidth),
    .Pass(1),
    .Depth(RdDepth)
  ) u_rd_queue (
    .clk_i,
    .rst_ni,
    .clr_i    (clear_i),
    .wvalid_i (spihost_rd_valid_i),
    .wready_o (spihost_rd_ready_o),
    .wdata_i  (spihost_rd_data_i),
    .rvalid_o (axi2fls_rd_valid_o),
    .rready_i (axi2fls_rd_ready_i),
    .rdata_o  (axi2fls_rd_data_unordered),
    .full_o   (),
    .depth_o  (rd_depth)
  );

  // Status flag assignments
  assign wr_empty_o = (wr_qd_o == 0);
  assign rd_empty_o = (rd_qd_o == 0);
  assign wr_full_o  = (wr_qd_o >= 8'(WrDepth));
  assign rd_full_o  = (rd_qd_o >= 8'(RdDepth));
  assign wr_wm_o    = (wr_qd_o <  wr_watermark_i);
  assign rd_wm_o    = (rd_qd_o >= rd_watermark_i);

endmodule