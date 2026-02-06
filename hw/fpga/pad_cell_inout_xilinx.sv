// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module pad_cell_inout #(
    parameter PADATTR = 16
) (
    input logic pad_in_i,
    input logic pad_oe_i,
    output logic pad_out_o,
    inout logic pad_io,
    input logic [PADATTR-1:0] pad_attributes_i
);

  IOBUF xilinx_iobuf_i (
      .T (~pad_oe_i),
      .I (pad_in_i),
      .O (pad_out_o),
      .IO(pad_io)
  );

endmodule
