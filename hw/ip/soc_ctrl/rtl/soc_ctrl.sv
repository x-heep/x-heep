// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

`include "common_cells/assertions.svh"

module soc_ctrl #(
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // Bus Interface
    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    input logic boot_select_i,
    input logic [31:0] xheep_instance_id_i,

    output logic        exit_valid_o,
    output logic [31:0] exit_value_o
);

  import soc_ctrl_reg_pkg::*;

  soc_ctrl_reg2hw_t reg2hw;
  soc_ctrl_hw2reg_t hw2reg;
  reg_rsp_t reg_rsp_int;

`ifndef SYNTHESIS
  logic testbench_set_exit_loop[1];
  //forced by simulation for preloading, do not touch
  //only arrays can be "forced" in verilator, thus array of 1 element is done
  //At synthesis time this signal will get removed
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_
    if (~rst_ni) begin
      testbench_set_exit_loop[0] <= '0;
    end
  end
  assign hw2reg.boot_exit_loop.d  = testbench_set_exit_loop[0];
  assign hw2reg.boot_exit_loop.de = testbench_set_exit_loop[0];
`else
  assign hw2reg.boot_exit_loop.d  = 1'b0;
  assign hw2reg.boot_exit_loop.de = 1'b0;
`endif

  assign hw2reg.boot_select.de = 1'b1;
  assign hw2reg.boot_select.d  = boot_select_i;


  soc_ctrl_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) soc_ctrl_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg_req_i,
      .reg_rsp_o(reg_rsp_int),
      .reg2hw,
      .hw2reg,
      .devmode_i(1'b1)
  );

  assign exit_valid_o = reg2hw.exit_valid.q;
  assign exit_value_o = reg2hw.exit_value.q;

  always_comb begin
    reg_rsp_o = reg_rsp_int;
    if(reg_req_i.addr[soc_ctrl_reg_pkg::BlockAw-1:0] == soc_ctrl_reg_pkg::SOC_CTRL_XHEEP_ID_OFFSET && reg_req_i.valid && ~reg_req_i.write)
      reg_rsp_o.rdata = xheep_instance_id_i;
  end
endmodule : soc_ctrl
