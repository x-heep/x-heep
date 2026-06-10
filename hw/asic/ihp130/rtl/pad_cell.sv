// Copyright 2026 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1


module pad_cell_input #(
  parameter int unsigned PADATTR = 16
) (
  input  logic               pad_in_i,
  input  logic               pad_oe_i,
  output logic               pad_out_o,
  inout  logic               pad_io,
  input  logic [PADATTR-1:0] pad_attributes_i
);
  sg13g2_IOPadIn pad_cell_in (
  	.pad ( pad_io    ),
    .p2c ( pad_out_o )
  );
endmodule


module pad_cell_inout #(
  parameter int unsigned PADATTR = 16
) (
  input  logic               pad_in_i,
  input  logic               pad_oe_i,
  output logic               pad_out_o,
  inout  logic               pad_io,
  input  logic [PADATTR-1:0] pad_attributes_i
);
  sg13g2_IOPadInOut4mA u_pad (
    .pad    ( pad_io    ),
    .c2p    ( pad_in_i  ),
    .c2p_en ( pad_oe_i  ),
    .p2c    ( pad_out_o )
  );
endmodule


module pad_cell_output #(
  parameter int unsigned PADATTR = 16
) (
  input  logic               pad_in_i,
  input  logic               pad_oe_i,
  output logic               pad_out_o,
  inout  logic               pad_io,
  input  logic [PADATTR-1:0] pad_attributes_i
);
  sg13g2_IOPadOut4mA pad_cell_out (
    .pad ( pad_io   ),
    .c2p ( pad_in_i )
  );
  assign pad_out_o = pad_io;
endmodule