// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module ihp_sg13g2_clk_gating (
   input  logic clk_i,
   input  logic en_i,
   input  logic test_en_i,
   output logic clk_o
);

    sg13g2_lgcp_1 clk_gate_inst (
        .CLK(clk_i),
        .GATE(en_i),
        .SCE(test_en_i),
        .GCLK(clk_o)
    );

endmodule

module ihp_sg13g2_clk_inverter (
  input  logic clk_i,
  output logic clk_o
);

    sg13g2_inv_1 clk_inv_inst (
        .A(clk_i),
        .Y(ckl_o)
    );

endmodule


module ihp_sg13g2_clk_mux2 (
  input  logic clk0_i,
  input  logic clk1_i,
  input  logic clk_sel_i,
  output logic clk_o
);

    sg13g2_mux2_1 clk_mux2_inst (
        .A0(clk0_i),
        .A1(clk1_i),
        .S(clk_sel_i),
        .X(clk_o)
    );

endmodule

module cluster_clock_inverter(
  input  logic clk_i,
  output logic clk_o
);

  ihp_sg13g2_clk_inverter clk_inv_i (
    .*
  );

endmodule

module pulp_clock_mux2 (
  input  logic clk0_i,
  input  logic clk1_i,
  input  logic clk_sel_i,
  output logic clk_o
);

  ihp_sg13g2_clk_mux2 clk_mux2_i (
    .*
  );

endmodule

module cv32e40p_clock_gate (
   input  logic clk_i,
   input  logic en_i,
   input  logic scan_cg_en_i,
   output logic clk_o
);

  ihp_sg13g2_clk_gating clk_gate_i (
    .clk_i,
    .en_i,
    .test_en_i(scan_cg_en_i),
    .clk_o
  );

endmodule
