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
    parameter int unsigned DATA_WIDTH = 32,
    parameter obi_pkg::obi_cfg_t ObiCfg    = obi_pkg::ObiDefaultConfig,
    % if (xheep.reliability.bus_redundant and xheep.reliability.memory_ecc):
    parameter type               a_optional_t = logic,
    parameter type               r_optional_t = logic,
    parameter bit                EnableScrubber = 1'b0,
    parameter bit                ScrubberCorrectRead = 1'b1,
    % endif
    parameter type obi_req_t = xheep_obi_pkg::xheep_obi_req_t,
    parameter type obi_rsp_t = xheep_obi_pkg::xheep_obi_rsp_t
) (
    input logic clk_i,
    input logic rst_ni,

    // Clock-gating signal
    input logic [NUM_BANKS-1:0] clk_gate_en_ni,

    input  obi_req_t  [NUM_BANKS-1:0] ram_req_i,
    output obi_rsp_t  [NUM_BANKS-1:0] ram_resp_o,

    % if xheep.reliability.memory_ecc:
    // Scrubber signals
    input  logic scrub_trigger_i,
    output logic [NUM_BANKS-1:0] scrub_bit_corrected_o,
    output logic [NUM_BANKS-1:0] scrub_uncorrectable_o,
    output logic [NUM_BANKS-1:0][1:0] fault_o,
    % endif

    // power manager signals that goes to the ASIC macros
    input logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] pwrgate_ni,
    output logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] pwrgate_ack_no,
    input logic [core_v_mini_mcu_pkg::NUM_BANKS-1:0] set_retentive_ni
);

  //logic [NUM_BANKS-1:0] ram_valid_q;
  logic [NUM_BANKS-1:0] ram_req;
  logic [NUM_BANKS-1:0] ram_gnt;
  logic [NUM_BANKS-1:0] ram_we;
  logic [NUM_BANKS-1:0][DATA_WIDTH-1:0] ram_wdata;
  logic [NUM_BANKS-1:0][DATA_WIDTH-1:0] ram_rdata;
  localparam int unsigned PhysicalByteWidth = (DATA_WIDTH % 8 == 0) ? 8 : DATA_WIDTH;
  localparam int unsigned BeWidth = (DATA_WIDTH + PhysicalByteWidth - 1) / PhysicalByteWidth;
  logic [NUM_BANKS-1:0][BeWidth-1:0] ram_be;
  logic [NUM_BANKS-1:0][ObiCfg.AddrWidth-1:0] ram_addr;

% if xheep.reliability.bus_redundant and xheep.reliability.memory_ecc:
  // Used to correctly size the address range inside the relobi_sram_shim
  localparam int unsigned BankNumWords [NUM_BANKS] = '{
      ${", ".join(str(bank.size() // 4) for bank in memory_ss.iter_ram_banks())}
  };
  localparam int unsigned BankInterleaveLevel [NUM_BANKS] = '{
      ${", ".join(str(bank.il_level()) for bank in memory_ss.iter_ram_banks())}
  };
% endif
 
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
% if xheep.reliability.bus_redundant and xheep.reliability.memory_ecc:
  assign ram_req_addr_${i} = ram_addr[${i}][${bank.size().bit_length()-1 -2}-1:0];
% else:
  assign ram_req_addr_${i} = ram_addr[${i}][${p1}-1:${p2}];
% endif
% endfor

  for (genvar i = 0; i < NUM_BANKS; i++) begin : gen_sram

    tc_clk_gating clk_gating_cell_i (
        .clk_i,
        .en_i(clk_gate_en_ni[i]),
        .test_en_i(1'b0),
        .clk_o(clk_cg[i])
    );
    // OBI SRAM shim
    // -------------
    // Shifts of 1cc ahead rvalid and convert obi to sram if
    % if (xheep.reliability.bus_redundant and xheep.reliability.memory_ecc):
      relobi_sram_shim #(
        .ObiCfg(ObiCfg),
        .relobi_req_t(obi_req_t),
        .relobi_rsp_t(obi_rsp_t),
        .a_optional_t(a_optional_t),
        .r_optional_t(r_optional_t),
        .EnableScrubber(EnableScrubber),
        .ScrubberMemWords(BankNumWords[i]),
        .ScrubberCorrectRead(ScrubberCorrectRead),
        .AddrOffset(BankInterleaveLevel[i])
      ) obi_sram_shim_i (
        .clk_i(clk_cg[i]),
        .rst_ni(rst_ni),
        .obi_req_i(ram_req_i[i]),
        .obi_rsp_o(ram_resp_o[i]),
        .req_o(ram_req[i]),
        .we_o(ram_we[i]),
        .addr_o(ram_addr[i]),
        .wdata_o(ram_wdata[i]),
        .gnt_i(ram_gnt[i]),
        .rdata_i(ram_rdata[i]),
        .scrub_trigger_i(scrub_trigger_i),
        .scrub_bit_corrected_o(scrub_bit_corrected_o[i]),
        .scrub_uncorrectable_o(scrub_uncorrectable_o[i]),
        .fault_o(fault_o[i])
      );
      assign ram_be[i] = '1; // always write the whole word (check)
    % else :
      obi_sram_shim #(
        .ObiCfg(ObiCfg),
        .obi_req_t(obi_req_t),
        .obi_rsp_t(obi_rsp_t)
      ) obi_sram_shim_i (
          .clk_i(clk_cg[i]),
          .rst_ni(rst_ni),
          .obi_req_i(ram_req_i[i]),
          .obi_rsp_o(ram_resp_o[i]),
          .req_o(ram_req[i]),
          .we_o(ram_we[i]),
          .addr_o(ram_addr[i]),
          .wdata_o(ram_wdata[i]),
          .be_o(ram_be[i]),
          .gnt_i(ram_gnt[i]),
          .rdata_i(ram_rdata[i])
      );
    
    % endif
    % if not(not xheep.reliability.bus_redundant and xheep.reliability.memory_ecc): 
      assign ram_gnt[i] = 1'b1;
    % endif
  end

%for i, bank in enumerate(memory_ss.iter_ram_banks()):
  % if (not xheep.reliability.bus_redundant and xheep.reliability.memory_ecc):
  // Create a wrapper that should be a tpl, with inside the sram_wrapper instead of the tc_srams
  
  ecc_sram_xheep_wrapper #(
    .NumWords (${bank.size() // 4}), //?TODO: check
    .UnprotectedWidth(ObiCfg.DataWidth),
    .ProtectedWidth(ObiCfg.DataWidth + hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)),
    .InputECC(0),
    .NumRMWCuts(0)
  ) ecc_sram_${bank.name()}_i(
    .clk_i(clk_cg[${i}]),
    .rst_ni(rst_ni),
    .scrub_trigger_i(scrub_trigger_i),
    .scrubber_fix_o(scrub_bit_corrected_o[${i}]),
    .scrub_uncorrectable_o(scrub_uncorrectable_o[${i}]),
    .wdata_i(ram_wdata[${i}]),
    .addr_i(ram_req_addr_${i}),
    .req_i(ram_req[${i}]),
    .we_i(ram_we[${i}]),
    .be_i(ram_be[${i}]),
    .rdata_o(ram_rdata[${i}]),
    .gnt_o(ram_gnt[${i}]), // ECC calculation Read-modify-write, require 1cc
    .pwrgate_ni(pwrgate_ni[${i}]),
    .pwrgate_ack_no(pwrgate_ack_no[${i}]),
    .set_retentive_ni(set_retentive_ni[${i}]),
    .single_error_o(fault_o[${i}][0]),
    .multi_error_o(fault_o[${i}][1])
  );

  % else:
  sram_wrapper #(
      .NumWords (${bank.size() // 4}), //?TODO: check
      .DataWidth(DATA_WIDTH)
  ) ram${bank.name()}_i (
      .clk_i(clk_cg[${i}]),
      .rst_ni(rst_ni),
      .req_i(ram_req[${i}]),
      .we_i(ram_we[${i}]),
      .addr_i(ram_req_addr_${i}),
      .wdata_i(ram_wdata[${i}]),
      .be_i(ram_be[${i}]),
      .pwrgate_ni(pwrgate_ni[${i}]),
      .pwrgate_ack_no(pwrgate_ack_no[${i}]),
      .set_retentive_ni(set_retentive_ni[${i}]),
      .rdata_o(ram_rdata[${i}])
  );
  % endif
%endfor

endmodule
