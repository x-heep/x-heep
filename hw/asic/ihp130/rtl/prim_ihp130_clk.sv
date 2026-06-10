// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

/*IHP130 Prefix*/
module ihp130_clk_gating (
   input  logic clk_i,
   input  logic en_i,
   input  logic test_en_i,
   output logic clk_o
);
  (* keep *)(* dont_touch = "true" *)
  sg13g2_slgcp_1 clk_gate_i (
    .GATE ( en_i  ),
    .SCE  ( test_en_i ),
    .CLK  ( clk_i ),
    .GCLK ( clk_o )
  );
endmodule

module ihp130_clk_inverter (
  input  logic clk_i,
  output logic clk_o
);
  sg13g2_inv_1 clk_inv_i (
    .A ( clk_i ),
    .Y ( clk_o )
  );
endmodule

module ihp130_clk_mux2 (
  input  logic clk0_i,
  input  logic clk1_i,
  input  logic clk_sel_i,
  output logic clk_o
);
  (* keep *)(* dont_touch = "true" *)
  sg13g2_mux2_1 clk_mux2_i (
    .A0 ( clk0_i    ),
    .A1 ( clk1_i    ),
    .S  ( clk_sel_i ),
    .X  ( clk_o     )
  );
endmodule

module ihp130_clk_xor2 (
  input  logic clk0_i,
  input  logic clk1_i,
  output logic clk_o
);
  (* keep *)(* dont_touch = "true" *)
  sg13g2_xor2_1 i_mux (
    .A ( clk0_i ),
    .B ( clk1_i ),
    .X ( clk_o  )
  );
endmodule



/*TC Prefix*/
module tc_clk_gating #(
  parameter bit IS_FUNCTIONAL = 1'b1
)(
   input  logic clk_i,
   input  logic en_i,
   input  logic test_en_i,
   output logic clk_o
);
  ihp130_clk_gating clk_gate_i (
    .*
  );
endmodule

module tc_clk_inverter(
  input  logic clk_i,
  output logic clk_o
);
  ihp130_clk_inverter clk_inv_i (
    .*
  );
endmodule

module tc_clk_mux2 (
  input  logic clk0_i,
  input  logic clk1_i,
  input  logic clk_sel_i,
  output logic clk_o
);
  ihp130_clk_mux2 clk_mux2_i (
    .*
  );
endmodule

module tc_clk_xor2 (
  input  logic clk0_i,
  input  logic clk1_i,
  output logic clk_o
);
  ihp130_clk_xor2 clk_xor2_i (
    .*
  );
endmodule



/*Cluster Prefix*/
module cluster_clock_inverter(
  input  logic clk_i,
  output logic clk_o
);

  ihp130_clk_inverter clk_inv_i (
    .*
  );

endmodule



/*Pulp Prefix*/
module pulp_clock_inverter(
  input  logic clk_i,
  output logic clk_o
);
  ihp130_clk_inverter clk_inv_i (
    .*
  );
endmodule

module pulp_clock_mux2 (
  input  logic clk0_i,
  input  logic clk1_i,
  input  logic clk_sel_i,
  output logic clk_o
);

  ihp130_clk_mux2 clk_mux2_i (
    .*
  );

endmodule



/*COREV*/
module cve2_clock_gate (
   input  logic clk_i,
   input  logic en_i,
   input  logic scan_cg_en_i,
   output logic clk_o
);

  ihp130_clk_gating clk_gate_i (
    .clk_i,
    .en_i,
    .test_en_i(scan_cg_en_i),
    .clk_o
  );

endmodule

module cv32e40p_clock_gate (
   input  logic clk_i,
   input  logic en_i,
   input  logic scan_cg_en_i,
   output logic clk_o
);

  ihp130_clk_gating clk_gate_i (
    .clk_i,
    .en_i,
    .test_en_i(scan_cg_en_i),
    .clk_o
  );

endmodule