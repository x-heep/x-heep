// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

/* verilator lint_off UNUSED */
module pad_cell_input #(
    parameter PADATTR = 16,
    //do not touch these parameters
    parameter PADATTR_RND = PADATTR == 0 ? 1 : PADATTR
) (
    input logic pad_in_i,
    input logic pad_oe_i,
    output logic pad_out_o,
    inout wire pad_io,
    input logic [PADATTR_RND-1:0] pad_attributes_i
);

  logic pad;

  assign pad_out_o = pad_io;
  assign pad_io = pad;
  assign pad = 1'bz;

`ifndef SYNTHESIS
  // Check that you never want to drive an input PAD
  always_comb begin
    if (pad_oe_i != 1'b0) begin
      $error("%t: input PAD OE equal to 1", $time);
      $stop;
    end
  end
`endif


endmodule
