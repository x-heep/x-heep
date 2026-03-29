// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

/*
NOTE: careful if you add arbiters to read port. You  must have dedicated ports for ACC and DATA as we wait for both to be valid at the same time!!
*/
module quadrilatero_ff_fs_dr_stage #(
    parameter MESH_WIDTH = 4,
    parameter DATA_WIDTH = 32,
    parameter N_REGS = 8,
    localparam N_ROWS = MESH_WIDTH,
    localparam RLEN = DATA_WIDTH * MESH_WIDTH
) (
    input logic clk_i,
    input logic rst_ni,

    input  logic wl_valid_i,  // from wl stage
    output logic ff_ready_o,  // to wl stage


    input logic [$clog2(N_REGS)-1:0] data_reg_i,  // data register
    input logic [$clog2(N_REGS)-1:0] acc_reg_i,  // accumulator register
    input logic [xif_pkg::X_ID_WIDTH-1:0] id_i,  // id of the instruction

    // Data Read Register Port 
    output logic [$clog2(N_REGS)-1:0] data_raddr_o,
    output logic [$clog2(N_ROWS)-1:0] data_rrowaddr_o,
    input logic [RLEN-1:0] data_rdata_i,
    input logic data_rdata_valid_i,
    output logic data_rdata_ready_o,
    output logic data_rlast_o,

    // Accumulator Read Register Port
    output logic [$clog2(N_REGS)-1:0] acc_raddr_o,
    output logic [$clog2(N_ROWS)-1:0] acc_rrowaddr_o,
    input logic [RLEN-1:0] acc_rdata_i,
    input logic acc_rdata_valid_i,
    output logic acc_rdata_ready_o,
    output logic acc_rlast_o,

    // Accumulator Out Write Register Port
    output logic [$clog2(N_REGS)-1:0] res_waddr_o,
    output logic [$clog2(N_ROWS)-1:0] res_wrowaddr_o,
    output logic [          RLEN-1:0] res_wdata_o,
    output logic                      res_we_o,
    output logic                      res_wlast_o,
    input  logic                      res_wready_i,

    output logic [xif_pkg::X_ID_WIDTH-1:0] sa_datacc_id_o,
    output logic [MESH_WIDTH-1:0][DATA_WIDTH-1:0] data_mesh_skewed_o,
    output logic [MESH_WIDTH-1:0][DATA_WIDTH-1:0] acc_mesh_skewed_o,
    input logic [MESH_WIDTH-1:0][DATA_WIDTH-1:0] res_mesh_skewed_i,
    output logic pump_o,
    output logic switch_db_o,

    output logic finished_o,
    output logic [xif_pkg::X_ID_WIDTH-1:0] finished_instr_id_o
);

  typedef enum logic [2:0] {
    IDLE  = 3'b000,
    FF    = 3'b001,
    FS    = 3'b011,
    DRAIN = 3'b010,
    XXX   = 'x
  } sa_state_e;

  sa_state_e state, next;

  logic [   $clog2(MESH_WIDTH):0] ff_counter;
  logic [   $clog2(MESH_WIDTH):0] fs_counter;
  logic [   $clog2(MESH_WIDTH):0] dd_counter;

  logic [     $clog2(N_REGS)-1:0] n_data_raddr;
  logic [     $clog2(N_ROWS)-1:0] n_data_rrowaddr;

  logic [     $clog2(N_REGS)-1:0] n_acc_raddr;
  logic [     $clog2(N_ROWS)-1:0] n_acc_rrowaddr;

  logic [     $clog2(N_REGS)-1:0] n_res_waddr;
  logic [     $clog2(N_ROWS)-1:0] n_res_wrowaddr;
  logic [               RLEN-1:0] n_res_wdata;
  logic                           n_res_we;

  logic [     $clog2(N_REGS)-1:0] data_reg_ff;  // data register
  logic [     $clog2(N_REGS)-1:0] acc_reg_ff;  // accumulator register
  logic [xif_pkg::X_ID_WIDTH-1:0] id_ff;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      data_reg_ff <= '0;
      acc_reg_ff <= '0;
      id_ff <= '0;
    end else begin
      if (wl_valid_i && ff_ready_o) begin
        data_reg_ff <= data_reg_i;
        acc_reg_ff <= acc_reg_i;
        id_ff <= id_i;
      end
    end
  end

  assign sa_datacc_id_o = id_ff;

  assign finished_instr_id_o = id_ff;
  assign finished_o = res_wlast_o;

  logic data_acc_valid;
  assign data_acc_valid = data_rdata_valid_i & acc_rdata_valid_i;

  // We latch onto the values only when they are both available. This blocks a read port and hopefully does not deadlock but makes it easier than buffering the value
  // assign data_rdata_ready_o = data_acc_valid;
  // assign acc_rdata_ready_o = data_acc_valid;

  assign data_rdata_ready_o = (state == FF);
  assign acc_rdata_ready_o = (state == FF);

  assign ff_ready_o = state == IDLE;

  logic pump_data_acc;
  logic pump_dr;
  logic pump_fs;
  logic stall_dr;
  assign stall_dr = !(res_wready_i && res_we_o);  // if we cannot write back this cycle we stall
  assign pump_dr  = (state == DRAIN) && !stall_dr;
  assign pump_fs  = (state == FS);
  assign pump_o   = pump_data_acc | pump_dr | pump_fs;

  logic [MESH_WIDTH-1:0][DATA_WIDTH-1:0] data_input_mesh;
  logic [MESH_WIDTH-1:0][DATA_WIDTH-1:0] acc_input_mesh;
  logic [MESH_WIDTH-1:0][DATA_WIDTH-1:0] acc_output_mesh_deskewed;

  // make sure it's only HIGH 1 cycle
  assign switch_db_o = (state == IDLE) && wl_valid_i;


  quadrilatero_skewer #(
      .MESH_WIDTH(MESH_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) skewer_inst_data (
      .clk_i,
      .rst_ni,
      .pump_i(pump_data_acc | pump_fs),
      .data_i(data_input_mesh),
      .data_o(data_mesh_skewed_o)
  );

  quadrilatero_skewer #(
      .MESH_WIDTH(MESH_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) skewer_inst_acc (
      .clk_i,
      .rst_ni,
      .pump_i(pump_data_acc | pump_fs),
      .data_i(acc_input_mesh),
      .data_o(acc_mesh_skewed_o)
  );

  quadrilatero_deskewer #(
      .MESH_WIDTH(MESH_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) deskewer_inst_acc (
      .clk_i,
      .rst_ni,
      .pump_i(pump_dr | pump_fs),
      .data_i(res_mesh_skewed_i),
      .data_o(acc_output_mesh_deskewed)
  );


  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) state <= IDLE;
    else state <= next;

  // Computes next state based on current and input
  always_comb begin
    next = XXX;
    case (state)
      IDLE:
      if (wl_valid_i) next = FF;
      else next = IDLE;  //@ loopback
      FF:
      if (data_rlast_o)
        next = FS; // this will come together with acc_rlast_o but be careful if you change the way data and accumulator are fetched!
      else next = FF;  //@ loopback
      FS:
      if (fs_counter == MESH_WIDTH - 2) next = DRAIN;
      else next = FS;  //@ loopback
      DRAIN:
      if (res_wlast_o) next = IDLE;
      else next = DRAIN;  //@ loopback
      default: next = XXX;
    endcase
  end


  always_ff @(posedge clk_i or negedge rst_ni) begin : counter_increment
    if (!rst_ni) begin
      ff_counter <= '0;
      fs_counter <= '0;
      dd_counter <= '0;
    end else begin
      if (state == FF)
        ff_counter <= ff_counter + data_acc_valid; // only if we receive valid data  and acc we advance counter
      else ff_counter <= '0;

      if (state == FS) fs_counter <= fs_counter + 1;
      else fs_counter <= '0;

      if (state == DRAIN) dd_counter <= dd_counter + !stall_dr;
      else dd_counter <= '0;
    end
  end

  assign data_rlast_o = data_acc_valid && (ff_counter == MESH_WIDTH - 1);
  assign acc_rlast_o  = data_rlast_o;

  always_comb begin : generate_weight_data_read_req
    n_data_raddr = '0;
    n_data_rrowaddr = '0;
    n_acc_raddr = '0;
    n_acc_rrowaddr = '0;

    case (state)
      FF: begin
        n_data_raddr = data_reg_ff;
        n_data_rrowaddr = ff_counter;
        n_acc_raddr = acc_reg_ff;
        n_acc_rrowaddr = ff_counter;
      end
      default: ;
    endcase
  end

  assign data_raddr_o = n_data_raddr;
  assign data_rrowaddr_o = n_data_rrowaddr;
  assign acc_raddr_o = n_acc_raddr;
  assign acc_rrowaddr_o = n_acc_rrowaddr;


  always_comb begin : generate_res_write
    n_res_waddr = '0;
    n_res_wdata = '0;
    n_res_we = '0;
    n_res_wrowaddr = '0;

    case (state)
      DRAIN: begin
        n_res_waddr = acc_reg_i;
        n_res_wdata = acc_output_mesh_deskewed; //{acc_output_mesh_deskewed[3],acc_output_mesh_deskewed[2],acc_output_mesh_deskewed[1],acc_output_mesh_deskewed[0]};
        n_res_we = 1;
        n_res_wrowaddr = dd_counter;
      end
      default: ;
    endcase
  end

  assign res_wlast_o = (dd_counter == MESH_WIDTH - 1) && !stall_dr;
  // CAREFUL: combinatorial outputs
  assign res_waddr_o = n_res_waddr;
  assign res_wdata_o = n_res_wdata;
  assign res_we_o = n_res_we;
  assign res_wrowaddr_o = n_res_wrowaddr;


  always_comb begin : feed_data_acc_to_mesh
    data_input_mesh = '0;
    acc_input_mesh  = '0;
    pump_data_acc   = '0;
    case (state)
      FF: begin
        if (data_acc_valid) begin
          data_input_mesh = data_rdata_i;
          acc_input_mesh  = acc_rdata_i;
          pump_data_acc   = '1;
        end
      end
      default: ;
    endcase
  end


endmodule
