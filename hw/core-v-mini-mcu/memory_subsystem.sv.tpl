// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%
    memory_ss = xheep.memory_ss()
%>

/* verilator lint_off UNUSED */
/* verilator lint_off MULTIDRIVEN */

module memory_subsystem #(
    parameter NUM_BANKS = 2,
    parameter type obi_req_t = xheep_obi_pkg::xheep_obi_req_t,
    parameter type obi_rsp_t = xheep_obi_pkg::xheep_obi_rsp_t
) (
    input logic clk_i,
    input logic rst_ni,

    // Clock-gating signal
    input logic [NUM_BANKS-1:0] clk_gate_en_ni,

    input  obi_req_t  [NUM_BANKS-1:0] ram_req_i,
    output obi_rsp_t  [NUM_BANKS-1:0] ram_resp_o,

    // power manager signals that goes to the ASIC macros
    input logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] pwrgate_ni,
    output logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] pwrgate_ack_no,
    input logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] set_retentive_ni
);

  logic [NUM_BANKS-1:0] ram_valid_q;
  // Clock-gating
  logic [NUM_BANKS-1:0] clk_cg;

% for i, bank in enumerate(memory_ss.iter_ram_banks()):
  logic [${bank.size().bit_length()-1 -2}-1:0] ram_req_addr_${i};
% endfor

% for i, bank in enumerate(memory_ss.iter_ram_banks()):
<%
  p1 = bank.size().bit_length()-1 + bank.il_level()
  p2 = 2 + bank.il_level()
%>
  assign ram_req_addr_${i} = ram_req_i[${i}].addr[${p1}-1:${p2}];
% endfor

  for (genvar i = 0; i < NUM_BANKS; i++) begin : gen_sram

    tc_clk_gating clk_gating_cell_i (
        .clk_i,
        .en_i(clk_gate_en_ni[i]),
        .test_en_i(1'b0),
        .clk_o(clk_cg[i])
    );

    always_ff @(posedge clk_cg[i] or negedge rst_ni) begin
      if (!rst_ni) begin
        ram_valid_q[i] <= '0;
      end else begin
        ram_valid_q[i] <= ram_resp_o[i].gnt & ram_req_i[i].req;;
      end
    end

    assign ram_resp_o[i].gnt = 1'b1;
    assign ram_resp_o[i].rvalid = ram_valid_q[i];
  end

%for i, bank in enumerate(memory_ss.iter_ram_banks()):
  sram_wrapper #(
      .NumWords (${bank.size() // 4}),
      .DataWidth(32'd32)
  ) ram${bank.name()}_i (
      .clk_i(clk_cg[${i}]),
      .rst_ni(rst_ni),
      .req_i(ram_req_i[${i}].req),
      .we_i(ram_req_i[${i}].we),
      .addr_i(ram_req_addr_${i}),
      .wdata_i(ram_req_i[${i}].wdata),
      .be_i(ram_req_i[${i}].be),
      .pwrgate_ni(pwrgate_ni[${i}]),
      .pwrgate_ack_no(pwrgate_ack_no[${i}]),
      .set_retentive_ni(set_retentive_ni[${i}]),
      .rdata_o(ram_resp_o[${i}].rdata)
  );

%endfor

endmodule
