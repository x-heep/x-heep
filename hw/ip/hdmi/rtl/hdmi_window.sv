// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Write-only pass-through for the PIXEL window: mirrors camera_window.sv,
// but for pushes instead of pops. Accepts one 32-bit word per bus write,
// stalling (ready low) while push_ready_i is low, so a DMA writing here
// blocks until whatever is downstream (the pixel FIFO) has room. Reads are
// acknowledged immediately with all-zero data; there is nothing to read
// back from this window.

module hdmi_window #(
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input  reg_req_t win_i,
    output reg_rsp_t win_o,

    input  logic        push_ready_i,
    output logic        push_valid_o,
    output logic [31:0] push_data_o
);

  assign push_valid_o = win_i.valid & win_i.write;
  assign push_data_o  = win_i.wdata;

  assign win_o.rdata  = 32'h0;
  assign win_o.error  = 1'b0;
  assign win_o.ready  = win_i.write ? push_ready_i : 1'b1;

endmodule  // hdmi_window
