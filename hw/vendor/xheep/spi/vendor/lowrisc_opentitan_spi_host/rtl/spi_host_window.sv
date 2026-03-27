// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Module to manage TX FIFO window for Serial Peripheral Interface (SPI) host IP.
//

`include "common_cells/assertions.svh"

module spi_host_window
#(
  parameter type reg_req_t = logic,
  parameter type reg_rsp_t = logic
)(
  input  clk_i,
  input  rst_ni,
  input  reg_req_t rx_win_i,
  output reg_rsp_t rx_win_o,
  input  reg_req_t tx_win_i,
  output reg_rsp_t tx_win_o,
  output logic [31:0]       tx_data_o,
  output logic [3:0]        tx_be_o,
  output logic              tx_valid_o,
  input        [31:0]       rx_data_i,
  output logic              rx_ready_o
);

  localparam int AW = spi_host_reg_pkg::BlockAw;

  logic [AW-1:0] tx_addr;
  // Only support reads/writes to the data fifo window
  logic tx_win_error;
  assign tx_win_error = (tx_win_i.write == 1'b0) &&
                     (tx_addr != spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET);

  logic [AW-1:0] rx_addr;
  // Only support reads/writes to the data fifo window
  logic rx_win_error;
  assign rx_win_error = (rx_win_i.write == 1'b1) &&
                     (rx_addr != spi_host_reg_pkg::SPI_HOST_RXDATA_OFFSET);

    // Check that our regbus data is 32 bit wide
  `ASSERT_INIT(RegbusTXIs32Bit, $bits(tx_win_i.wdata) == 32)
  `ASSERT_INIT(RegbusRXIs32Bit, $bits(rx_win_i.wdata) == 32)
  
    // We are already a regbus, so no stateful adapter should be needed here
    // TODO @(paulsc, zarubaf): check this assumption!
    // Request
    assign rx_ready_o   = rx_win_i.valid & ~rx_win_i.write;   // read-enable
    assign rx_win_o.rdata  = rx_data_i;
    // Response: always ready, else over/underflow error reported in regfile
    assign rx_win_o.error  = rx_win_error;
    assign rx_win_o.ready  = 1'b1;
    assign rx_addr         = rx_win_i.addr;

    assign tx_valid_o   = tx_win_i.valid & tx_win_i.write;    // write-enable
    assign tx_data_o    = tx_win_i.wdata;
    assign tx_be_o      = tx_win_i.wstrb;
    // Response: always ready, else over/underflow error reported in regfile
    assign tx_win_o.error  = tx_win_error;
    assign tx_win_o.rdata  = 32'h0;
    assign tx_win_o.ready  = 1'b1;
    assign tx_addr         = tx_win_i.addr;

endmodule : spi_host_window
