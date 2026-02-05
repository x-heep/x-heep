// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1



module cpu_subsystem
  import obi_pkg::*;
  import core_v_mini_mcu_pkg::*;
#(
    parameter BOOT_ADDR = 'h180,
    parameter DM_HALTADDRESS = '0
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Core ID
    input logic [31:0] hart_id_i,

    // Instruction memory interface
    output obi_req_t  core_instr_req_o,
    input  obi_resp_t core_instr_resp_i,

    // Data memory interface
    output obi_req_t  core_data_req_o,
    input  obi_resp_t core_data_resp_i,

    // eXtension interface
    if_xif.cpu_compressed xif_compressed_if,
    if_xif.cpu_issue      xif_issue_if,
    if_xif.cpu_commit     xif_commit_if,
    if_xif.cpu_mem        xif_mem_if,
    if_xif.cpu_mem_result xif_mem_result_if,
    if_xif.cpu_result     xif_result_if,

    // Interrupt inputs
    input  logic [31:0] irq_i,      // CLINT interrupts + CLINT extension interrupts
    output logic        irq_ack_o,
    output logic [ 4:0] irq_id_o,

    // Debug Interface
    input logic debug_req_i,

    // sleep
    output logic core_sleep_o
);


  // CPU Control Signals
  logic fetch_enable;

  assign fetch_enable = 1'b1;

  assign core_instr_req_o.wdata = '0;
  assign core_instr_req_o.we    = '0;
  assign core_instr_req_o.be    = 4'b1111;

  logic [16-1:0] scoreboard_d, scoreboard_q;
  logic [4-1:0]  x_instr_id_d, x_instr_id_q;
  logic [31:16]  int_tb;
  logic [3:0] fake_cnt_q, fake_cnt_d;
  logic debug_tb;
  typedef enum logic [2:0] { TB_INT_ENABLE, TB_INT_NOT_ENABLE, TB_NEXT_INT, TB_HOLD, TB_FINISHED } id_fsm_e;
  id_fsm_e id_fsm_q, id_fsm_d;


    always_comb begin
        scoreboard_d = scoreboard_q;
        x_instr_id_d = x_instr_id_q;
        if (xif_issue_if.issue_valid && xif_issue_if.issue_ready && xif_issue_if.issue_resp.accept) begin
        scoreboard_d[x_instr_id_q] = 1'b1;
        x_instr_id_d = x_instr_id_q + 1'b1;
        end
        if (xif_result_if.result_valid) begin
        scoreboard_d[xif_result_if.result.id] = 1'b0;
        end
    end
    always_ff @(posedge clk_i or negedge rst_ni) begin : x_scoreboard
        if (!rst_ni) begin
        scoreboard_q <= '0;
        x_instr_id_q <= '0;
        fake_cnt_q <='0;
        id_fsm_q <= TB_INT_ENABLE;
        end else begin
        scoreboard_q <= scoreboard_d;
        x_instr_id_q <= x_instr_id_d;
        id_fsm_q <= id_fsm_d;
        fake_cnt_q <= fake_cnt_d;
        end
    end

    assign int_tb[30:16] = '0;
    assign debug_tb = '0;

 always_comb begin
    id_fsm_d   = id_fsm_q;
    int_tb[31] = x_instr_id_q >= 1;
    fake_cnt_d = fake_cnt_q + 1;

    unique case (id_fsm_q)
        TB_INT_ENABLE: begin
            if (core_instr_req_o.addr == 32'h07C && core_instr_req_o.req && core_instr_resp_i.gnt)
                id_fsm_d = TB_INT_NOT_ENABLE;
        end
        TB_INT_NOT_ENABLE: begin
            if(core_instr_req_o.addr == 32'h0300 && core_instr_req_o.req && core_instr_resp_i.gnt) begin
                id_fsm_d  = TB_NEXT_INT;
                fake_cnt_d = '0;
            end
            int_tb[31]    = 1'b0;
        end

        TB_NEXT_INT: begin
            id_fsm_d      = fake_cnt_q > 3 ? TB_HOLD : TB_NEXT_INT;
            int_tb[31]    = fake_cnt_q > 3;
        end

        TB_HOLD: begin
            int_tb[31]    = 1'b1;
            if (core_instr_req_o.addr == 32'h07C && core_instr_req_o.req && core_instr_resp_i.gnt)
                id_fsm_d = TB_FINISHED;
        end

        TB_FINISHED: begin
            int_tb[31]    = 1'b0;
        end


        default: begin
            id_fsm_d      = TB_INT_ENABLE;
        end
    endcase
 end
    

  cve2_xif_wrapper #(
      .RV32E(1'b0),
      .RV32M(cve2_pkg::RV32MFast),
      .XInterface(1)
  ) cv32e20_i (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .test_en_i(1'b0),

      .hart_id_i,
      .boot_addr_i(BOOT_ADDR),
      .dm_exception_addr_i(32'h0),
      .dm_halt_addr_i(DM_HALTADDRESS),

      .instr_addr_o  (core_instr_req_o.addr),
      .instr_req_o   (core_instr_req_o.req),
      .instr_rdata_i (core_instr_resp_i.rdata),
      .instr_gnt_i   (core_instr_resp_i.gnt),
      .instr_rvalid_i(core_instr_resp_i.rvalid),

      .data_addr_o  (core_data_req_o.addr),
      .data_wdata_o (core_data_req_o.wdata),
      .data_we_o    (core_data_req_o.we),
      .data_req_o   (core_data_req_o.req),
      .data_be_o    (core_data_req_o.be),
      .data_rdata_i (core_data_resp_i.rdata),
      .data_gnt_i   (core_data_resp_i.gnt),
      .data_rvalid_i(core_data_resp_i.rvalid),

      .irq_software_i(irq_i[3]),
      .irq_timer_i   (irq_i[7]),
      .irq_external_i(irq_i[11]),
      .irq_fast_i    (irq_i[31:16] | int_tb),

      .debug_req_i(debug_req_i  | debug_tb),
      .debug_halted_o(),

      // CORE-V-XIF
      // Compressed interface
      .x_compressed_valid_o(xif_compressed_if.compressed_valid),
      .x_compressed_ready_i(xif_compressed_if.compressed_ready),
      .x_compressed_req_o  (xif_compressed_if.compressed_req),
      .x_compressed_resp_i (xif_compressed_if.compressed_resp),

      // Issue Interface
      .x_issue_valid_o(xif_issue_if.issue_valid),
      .x_issue_ready_i(xif_issue_if.issue_ready),
      .x_issue_req_o  (xif_issue_if.issue_req),
      .x_issue_resp_i (xif_issue_if.issue_resp),

      // Commit Interface
      .x_commit_valid_o(xif_commit_if.commit_valid),
      .x_commit_o(xif_commit_if.commit),

      // Memory Request/Response Interface
      .x_mem_valid_i(xif_mem_if.mem_valid),
      .x_mem_ready_o(xif_mem_if.mem_ready),
      .x_mem_req_i  (xif_mem_if.mem_req),
      .x_mem_resp_o (xif_mem_if.mem_resp),

      // Memory Result Interface
      .x_mem_result_valid_o(xif_mem_result_if.mem_result_valid),
      .x_mem_result_o(xif_mem_result_if.mem_result),

      // Result Interface
      .x_result_valid_i(xif_result_if.result_valid),
      .x_result_ready_o(xif_result_if.result_ready),
      .x_result_i(xif_result_if.result),

      .fetch_enable_i(fetch_enable),

      .core_sleep_o
  );

  assign irq_ack_o = '0;
  assign irq_id_o  = '0;


endmodule
