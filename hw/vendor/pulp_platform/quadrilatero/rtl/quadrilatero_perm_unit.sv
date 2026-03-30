// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

module quadrilatero_perm_unit #(
    parameter int unsigned DEPTH  =   1,
    parameter int unsigned RLEN   = 128,
    parameter int unsigned N_REGS =   8,
    parameter int unsigned N_ROWS =   4
) (
    input  logic                           clk_i               ,
    input  logic                           rst_ni              ,

    // Register Write Port 
    output logic [     $clog2(N_REGS)-1:0] waddr_o             ,
    output logic [     $clog2(N_ROWS)-1:0] wrowaddr_o          ,
    output logic [               RLEN-1:0] wdata_o             ,
    output logic                           we_o                ,
    output logic                           wlast_o             ,
    input  logic                           wready_i            ,  // to stall the request in case the port is busy

    // Configuration Signals
    input  logic [     $clog2(N_REGS)-1:0] operand_reg_i       ,  // destination register
    input  logic                           start_i             ,  // start loading: MUST BE A PULSE
    input  logic [xif_pkg::X_ID_WIDTH-1:0] instr_id_i          ,  //instruction id

    output logic                           busy_o  ,
    output logic [xif_pkg::X_ID_WIDTH-1:0] id_o                ,
    
    output logic                           finished_o          , 
    input  logic                           finished_ack_i      ,
    output logic [xif_pkg::X_ID_WIDTH-1:0] finished_instr_id_o    //instruction id out

);

  //----------------------------------------------------------------------------------------------------------

  logic [     $clog2(N_REGS)-1:0] operand_reg_new    ;
  logic [xif_pkg::X_ID_WIDTH-1:0] id_new             ;
  logic [     $clog2(N_REGS)-1:0] operand_reg_d      ;
  logic [     $clog2(N_REGS)-1:0] operand_reg_q      ;
  logic [xif_pkg::X_ID_WIDTH-1:0] id_d               ;
  logic [xif_pkg::X_ID_WIDTH-1:0] id_q               ;
  logic                           finished_d         ;
  logic                           finished_q         ;
  logic [xif_pkg::X_ID_WIDTH-1:0] finished_instr_id_d;
  logic [xif_pkg::X_ID_WIDTH-1:0] finished_instr_id_q;
  logic                           write_started_d    ;
  logic                           write_started_q    ;
  logic [     $clog2(N_ROWS)-1:0] counter_d          ;
  logic [     $clog2(N_ROWS)-1:0] counter_q          ;
  logic                           finished           ;
  logic [xif_pkg::X_ID_WIDTH-1:0] finished_id        ;     
  logic                           start              ; 
  logic                           busy               ;
  logic                           mask_req           ;
  logic                           fifo_full          ;
  logic                           fifo_empty         ;

  localparam int unsigned USAGE = DEPTH > 1 ? $clog2(DEPTH)-1 : 0;
  logic [USAGE:0] fifo_usage;
  logic           fifo_almost_full;
  //----------------------------------------------------------------------------------------------------------

  fifo_v3 #(
      .FALL_THROUGH  (1'b1                                          ),
      .DEPTH         (DEPTH                                         ),
      .dtype         (logic [$clog2(N_REGS)+xif_pkg::X_ID_WIDTH-1:0])
  ) i_fifo (
      .clk_i         (clk_i                      ),
      .rst_ni        (rst_ni                     ),
      .flush_i       (1'b0                       ),
      .testmode_i    (1'b0                       ),
      .full_o        (fifo_full                  ),
      .empty_o       (fifo_empty                 ),
      .usage_o       (fifo_usage                 ),
      .data_i        ({operand_reg_i, instr_id_i}),
      .push_i        (start_i & ~fifo_full       ),
      .data_o        ({operand_reg_new, id_new}  ),
      .pop_i         (start                      )
  );

  assign fifo_almost_full = (fifo_usage == DEPTH-1);

  always_comb begin : ctrl_block 
    mask_req    = (counter_q == $clog2(N_ROWS)'(N_ROWS - 1)) & finished_q & ~finished_ack_i;
    finished    = (counter_q == $clog2(N_ROWS)'(N_ROWS - 1)) & write_started_q & wready_i  ;
    busy        = write_started_q &~ finished                                              ;
    start       = ~busy & ~fifo_empty                                                      ;
    finished_id = id_q                                                                     ;
  end

  always_comb begin : next_value
    operand_reg_d       = operand_reg_q      ;
    id_d                = id_q               ;
    counter_d           = counter_q          ;
    write_started_d     = write_started_q    ;
    finished_d          = finished_q         ;
    finished_instr_id_d = finished_instr_id_q;

    if (start) begin
      operand_reg_d = operand_reg_new;
      id_d          = id_new         ;
    end

    if ((write_started_q && wready_i)) begin
      counter_d = counter_q + 1;
    end else if (finished) begin
      counter_d = '0;
    end  

    if (start) begin
      write_started_d = 1'b1;
    end else if (finished) begin
      write_started_d = 1'b0;
    end

    if (finished) begin
      finished_d          = '1;
      finished_instr_id_d = finished_id;
    end else if (finished_ack_i) begin
      finished_d          = '0;
      finished_instr_id_d = '0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : seq_block
    if (!rst_ni) begin
      finished_q          <= '0;
      finished_instr_id_q <= '0;
      operand_reg_q       <= '0;
      id_q                <= '0;
      write_started_q     <= '0;
      counter_q           <= '0;
    end else begin
      finished_q          <= finished_d         ;
      finished_instr_id_q <= finished_instr_id_d;
      operand_reg_q       <= operand_reg_d      ;       
      id_q                <= id_d               ;
      write_started_q     <= write_started_d    ;
      counter_q           <= counter_d          ;
    end
  end


  assign waddr_o             = operand_reg_q              ;
  assign wrowaddr_o          = counter_q                  ;
  assign wdata_o             = '0                         ;
  assign we_o                = write_started_q &~ mask_req;
  assign wlast_o             = finished                   ;
  assign busy_o              = fifo_full | fifo_almost_full;
  assign id_o                = id_q                       ;
  assign finished_o          = finished_q                 ;
  assign finished_instr_id_o = finished_instr_id_q        ;

  // Assertions
  if (N_ROWS < 2) begin
    $error(
        "[quadrilatero_perm_unit] N_ROWS must be at least 2.\n"
    );
  end
endmodule
