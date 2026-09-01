// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Module to manage TX FIFO window for Serial Peripheral Interface (SPI) host IP.
//

`include "common_cells/assertions.svh"

module camera_window #(
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input  reg_req_t        win_i,
    output reg_rsp_t        win_o,
    input            [31:0] data_i,
    output logic            ready_o
);

  localparam int AW = camera_reg_pkg::BlockAw;


  logic [AW-1:0] addr;
  // Only support reads/writes to the data fifo window
  logic win_error;
  assign win_error = (win_i.write == 1'b1) && (addr != camera_reg_pkg::CAMERA_DATA_OFFSET);

  // Check that our regbus data is 32 bit wide
  `ASSERT_INIT(RegbusRXIs32Bit, $bits(win_i.wdata) == 32)


  assign ready_o     = win_i.valid & ~win_i.write;  // read-enable
  assign win_o.rdata = data_i;
  // Response: always ready, else over/underflow error reported in regfile
  assign win_o.error = win_error;
  assign win_o.ready = 1'b1;
  assign addr        = win_i.addr[AW-1:0];

endmodule : camera_window
