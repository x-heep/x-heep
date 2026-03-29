// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

module quadrilatero_rf_sequencer #(
    parameter READ_PORTS = 4    ,
    parameter WRITE_PORTS = 2   ,
    parameter N_REGS = 8        ,
    parameter N_ROWS = 4        ,
    parameter RLEN = 128        ,
    parameter RF_READ_PORTS = 3 ,
    parameter RF_WRITE_PORTS = 1,
    parameter SYNC_REQ  = 1,

    parameter N_ENTRIES = 3       // entries in the FIFOs for each register
) (

    input logic clk_i,
    input logic rst_ni,

    // Input from FUs
    input  logic [READ_PORTS-1:0][$clog2(N_REGS)-1:0] raddr_i    ,
    input  logic [READ_PORTS-1:0][$clog2(N_ROWS)-1:0] rrowaddr_i ,
    output logic [READ_PORTS-1:0][RLEN-1:0]           rdata_o    ,
    output logic [READ_PORTS-1:0]                     rvalid_o   ,
    input  logic [READ_PORTS-1:0]                     rlast_i    ,  // request finished (must be PULSE)
    input  logic [READ_PORTS-1:0]                     rready_i   ,  // request finished (must be PULSE)
    input  logic [READ_PORTS-1:0][xif_pkg::X_ID_WIDTH-1:0]     rd_id_i    ,


    input logic  [WRITE_PORTS-1:0][$clog2(N_REGS)-1:0] waddr_i    ,
    input logic  [WRITE_PORTS-1:0][$clog2(N_ROWS)-1:0] wrowaddr_i ,
    input logic  [WRITE_PORTS-1:0][RLEN-1:0]           wdata_i    ,
    input logic  [WRITE_PORTS-1:0]                     we_i       ,
    input logic  [WRITE_PORTS-1:0]                     wlast_i    ,  // request finished (must be PULSE)
    output logic [WRITE_PORTS-1:0]                     wready_o   ,
    input  logic [WRITE_PORTS-1:0][xif_pkg::X_ID_WIDTH-1:0]     wr_id_i    ,

    // Outputs to RF
    output logic [RF_READ_PORTS-1:0][$clog2(N_REGS)-1:0]  raddr_o    ,
    output logic [RF_READ_PORTS-1:0][$clog2(N_ROWS)-1:0]  rrowaddr_o ,
    input logic  [RF_READ_PORTS-1:0][RLEN-1:0]            rdata_i    ,


    output logic [RF_WRITE_PORTS-1:0][$clog2(N_REGS)-1:0] waddr_o    ,
    output logic [RF_WRITE_PORTS-1:0][$clog2(N_ROWS)-1:0] wrowaddr_o ,
    output logic [RF_WRITE_PORTS-1:0][RLEN-1:0]           wdata_o    ,
    output logic [RF_WRITE_PORTS-1:0]                     we_o       ,


    // Inputs from Dispatcher
    // We can share the entry as we fetch 1 instruction at a time
    // NOTE: Actually maybe it's better to have more ports so that we can push all operands and not waste cycles
    input quadrilatero_pkg::rw_queue_t [N_REGS-1:0] rw_queue_entry_i ,
    input logic [N_REGS-1:0]         rw_queue_push_i  ,

    // Outputs to Dispatcher
    output logic [N_REGS-1:0] rw_queue_full_o
);

  logic  [N_REGS-1:0][N_ROWS-1:0] head_valid    ;
  logic  [N_REGS-1:0][N_ROWS-1:0] rw_queue_empty;
  logic  [N_REGS-1:0][N_ROWS-1:0] w_pop         ;
  logic  [N_REGS-1:0][N_ROWS-1:0] r_pop         ;
  logic  [N_REGS-1:0][N_ROWS-1:0] r_clr         ;
  logic  [N_REGS-1:0][N_ROWS-1:0] rw_queue_pop  ;
  logic  [N_REGS-1:0][N_ROWS-1:0] rw_queue_full ;

  logic  [WRITE_PORTS-1:0] wr_gnt        ;
  logic  [WRITE_PORTS-1:0] wr_req        ;
  logic  [READ_PORTS -1:0] rd_req        ;  
  logic  [READ_PORTS -1:0] rd_gnt        ;

  logic                      [N_REGS-1:0]               rw_queue_push ;
  quadrilatero_pkg::rw_queue_t [N_REGS-1:0]               rw_queue_entry;
  quadrilatero_pkg::rw_queue_t [N_REGS-1:0][N_ROWS-1:0]   rw_queue      ;
  quadrilatero_pkg::rw_queue_t [N_REGS-1:0][N_ROWS-1:0]   scoreboard_d  ;
  quadrilatero_pkg::rw_queue_t [N_REGS-1:0][N_ROWS-1:0]   scoreboard_q  ;

  genvar ii,hh;

  assign rw_queue_pop     = w_pop | r_pop | ~head_valid;
  assign rw_queue_entry   = rw_queue_entry_i           ;
  assign rw_queue_push    = rw_queue_push_i            ;

  logic  [N_REGS-1:0][N_ROWS-1:0] rw_queue_pop_fifo  ;
  assign rw_queue_pop_fifo = rw_queue_pop & ~rw_queue_empty;

  for (ii = 0; ii < N_REGS; ii++) begin: gen_fifo__regs
    for (hh = 0; hh < N_ROWS; hh++) begin: gen_fifo__rows
      fifo_v3 #(
          .FALL_THROUGH   (1'b1)                       ,
          .DEPTH          (N_ENTRIES)                  ,
          .dtype          (quadrilatero_pkg::rw_queue_t)
      ) issue_queue_inst (
          .clk_i,
          .rst_ni,
          .flush_i        (1'b0                                            ),
          .testmode_i     (1'b0                                            ),
          .usage_o        (                                                ),
          .full_o         (rw_queue_full [ii][hh]                          ),
          .empty_o        (rw_queue_empty[ii][hh]                          ),
          .data_i         (rw_queue_entry[ii]                              ),    // data to push into the queue
          .push_i         (rw_queue_push [ii]                              ),    // data is valid and can be pushed to the queue
          .data_o         (rw_queue      [ii][hh]                          ),    // output data
          .pop_i          (rw_queue_pop  [ii][hh] & ~rw_queue_empty[ii][hh])     // pop head from queue
      );
    end
  end

  always_comb begin: scoreboard_block
    rw_queue_full_o = '0;
    for (int i = 0; i < N_REGS; i++) begin
      for (int h = 0; h < N_ROWS; h++) begin
        rw_queue_full_o[i]  |= (rw_queue_full[i][h]);

        head_valid[i][h]    = scoreboard_q[i][h].wready | scoreboard_q[i][h].rvalid;


        scoreboard_d[i][h].id = (rw_queue_pop[i][h] && rw_queue_empty[i][h]  ) ? '0                :     
                                (rw_queue_pop[i][h]                          ) ? rw_queue[i][h].id : scoreboard_q[i][h].id;

        scoreboard_d[i][h].wready = (rw_queue_pop[i][h] && rw_queue_empty[i][h]) ? 1'b0                  :  
                                    (rw_queue_pop[i][h]                        ) ? rw_queue[i][h].wready : scoreboard_q[i][h].wready;

        scoreboard_d[i][h].rvalid = (rw_queue_pop[i][h] && rw_queue_empty[i][h]           ) ? 1'b0                  : 
                                    (rw_queue_pop[i][h]                                   ) ? rw_queue[i][h].rvalid :  
                                    (r_clr[i][h]                                          ) ? 1'b0                  : scoreboard_q[i][h].rvalid;
      end
    end
  end

  always_comb begin: ctrl_block
    wr_req   = '0;
    rd_req   = '0;
    w_pop    = '0;
    r_pop    = '0;
    r_clr    = '0;    

    for (int jj = 0; jj < WRITE_PORTS; jj++) begin: write_request
      automatic int m = 32'(waddr_i[jj]);
      automatic int n = 32'(wrowaddr_i[jj]);
      if( scoreboard_q[m][n].id  == wr_id_i[jj] &&
          scoreboard_q[m][n].wready && we_i[jj]    ) 
        begin
          wr_req [jj] = ~scoreboard_q[m][n].rvalid;
          w_pop  [m][n] = wr_gnt[jj]; 
      end
    end

    for (int jj = 0; jj < READ_PORTS; jj++) begin: read_request
      automatic int m = 32'(raddr_i[jj]);
      automatic int n = 32'(rrowaddr_i[jj]);
      if( scoreboard_q[m][n].id  == rd_id_i[jj]     &&
          scoreboard_q[m][n].rvalid && rready_i[jj]   ) 
        begin
          rd_req [jj] = 1'b1;
          r_clr  [m][n] = rd_gnt[jj];
          r_pop  [m][n] = rd_gnt[jj] &~ scoreboard_q[m][n].wready;
      end
    end

    if(SYNC_REQ) begin: sa_sync_req

      logic block      ;
      logic same_id_acc;
      logic same_id_A  ;
      logic same_id_D  ;
      logic same_id_W  ;

      // same_id_acc = wr_id_i[quadrilatero_pkg::SYSTOLIC_ARRAY  ] == scoreboard_q[waddr_i[quadrilatero_pkg::SYSTOLIC_ARRAY  ]][wrowaddr_i[quadrilatero_pkg::SYSTOLIC_ARRAY  ]].id;
      same_id_A   = rd_id_i[quadrilatero_pkg::SYSTOLIC_ARRAY_A] == scoreboard_q[raddr_i[quadrilatero_pkg::SYSTOLIC_ARRAY_A]][rrowaddr_i[quadrilatero_pkg::SYSTOLIC_ARRAY_A]].id;
      same_id_D   = rd_id_i[quadrilatero_pkg::SYSTOLIC_ARRAY_D] == scoreboard_q[raddr_i[quadrilatero_pkg::SYSTOLIC_ARRAY_D]][rrowaddr_i[quadrilatero_pkg::SYSTOLIC_ARRAY_D]].id;
      same_id_W   = rd_id_i[quadrilatero_pkg::SYSTOLIC_ARRAY_W] == scoreboard_q[raddr_i[quadrilatero_pkg::SYSTOLIC_ARRAY_W]][rrowaddr_i[quadrilatero_pkg::SYSTOLIC_ARRAY_W]].id;

      if( // (we_i    [quadrilatero_pkg::SYSTOLIC_ARRAY  ] && !same_id_acc) ||
          (rready_i[quadrilatero_pkg::SYSTOLIC_ARRAY_A] && !same_id_A  ) ||
          (rready_i[quadrilatero_pkg::SYSTOLIC_ARRAY_D] && !same_id_D  ) ||
          (rready_i[quadrilatero_pkg::SYSTOLIC_ARRAY_W] && !same_id_W  )
        ) begin
        block = 1'b1;
      end else begin
        block = 1'b0;
      end

      // if(we_i    [quadrilatero_pkg::SYSTOLIC_ARRAY  ] && same_id_acc && block) begin
      //   wr_req[quadrilatero_pkg::SYSTOLIC_ARRAY  ] = 1'b0;
      // end
      if(rready_i[quadrilatero_pkg::SYSTOLIC_ARRAY_A] && same_id_A   && block) begin
        rd_req[quadrilatero_pkg::SYSTOLIC_ARRAY_A]  = 1'b0;
      end
      if(rready_i[quadrilatero_pkg::SYSTOLIC_ARRAY_D] && same_id_D   && block) begin
        rd_req[quadrilatero_pkg::SYSTOLIC_ARRAY_D]  = 1'b0;
      end
      if(rready_i[quadrilatero_pkg::SYSTOLIC_ARRAY_W] && same_id_W   && block) begin
        rd_req[quadrilatero_pkg::SYSTOLIC_ARRAY_W]  = 1'b0;
      end
    end
  end

  if(RF_WRITE_PORTS != WRITE_PORTS) begin: write_block_wArb

    quadrilatero_rr_arbiter #(
        .NumActOut (RF_WRITE_PORTS) ,
        .N_ROWS    (N_ROWS)         ,
        .WIDTH     (WRITE_PORTS)
    ) wr_arb_i(
        .clk_i   ,
        .rst_ni  ,
        .req_i   (wr_req),
        .grant_o (wr_gnt)
    );
    always_comb begin: wdata_block
      automatic int ll=0;

      wready_o   = wr_gnt ;
      for (int mm = 0; mm < WRITE_PORTS; mm++) begin
        if(wr_gnt[mm]) begin
          waddr_o   [ll] = waddr_i   [mm];
          wrowaddr_o[ll] = wrowaddr_i[mm];
          wdata_o   [ll] = wdata_i   [mm];
          we_o      [ll] = we_i      [mm];
          ll++;
        end
      end
    end
  end else always_comb begin : write_block_noArb
    wr_gnt     = wr_req    ;
    waddr_o    = waddr_i   ;
    wrowaddr_o = wrowaddr_i;
    wdata_o    = wdata_i   ;
    we_o       = wr_gnt    ;
    wready_o   = wr_gnt    ;
  end

  if(RF_READ_PORTS != READ_PORTS) begin: read_block_wArb

    quadrilatero_rr_arbiter #(
        .NumActOut (RF_READ_PORTS) ,
        .N_ROWS    (N_ROWS)        ,
        .WIDTH     (READ_PORTS)
    ) rd_arb_i(
        .clk_i   ,
        .rst_ni  ,
        .req_i   (rd_req),
        .grant_o (rd_gnt)
    );

    always_comb begin: rdata_block
      automatic int ll=0;

      rvalid_o = rd_gnt;
      for (int mm = 0; mm < READ_PORTS; mm++) begin
        if(rd_gnt[mm]) begin
          raddr_o   [ll] = raddr_i   [mm];
          rrowaddr_o[ll] = rrowaddr_i[mm];
          rdata_o   [mm] = rdata_i   [ll];
          ll++; 
        end else begin
          rdata_o   [mm] = rdata_i   [RF_READ_PORTS-1];
        end
      end
    end
  end else always_comb begin : read_block_noArb
    rd_gnt     = rd_req    ;
    raddr_o    = raddr_i   ;
    rrowaddr_o = rrowaddr_i;
    rdata_o    = rdata_i   ;
    rvalid_o   = rd_gnt    ;
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin: seq_block
    if (!rst_ni) begin 
      scoreboard_q <= '0;
    end else begin
      scoreboard_q <= scoreboard_d;
    end
  end

  //-------------------------------------------------------------------------------------------------------

  // Assertions
  if (WRITE_PORTS < 2) begin
    $error(
        "[rf_sequencer] WRITE_PORTS must be at least 2.\n"
    );
  end
  if (READ_PORTS < 2) begin
    $error(
        "[rf_sequencer] READ_PORTS must be at least 2.\n"
    );
  end
endmodule
