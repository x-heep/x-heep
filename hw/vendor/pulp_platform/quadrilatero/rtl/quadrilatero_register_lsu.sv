// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

/*
NOTE: for now we assume we fetch the entire row in 1 cycle. TODO: Change the number of columns and adapt this to arbitrary BUS_WIDTH parameters
NOTE: we are not handling difference in endianness when loading reduced datawidths
*/

module quadrilatero_register_lsu #(
    parameter int unsigned  BUS_WIDTH = 128,
    parameter int unsigned  N_REGS = 8,
    parameter int unsigned  N_ROWS = 4,
    localparam int unsigned RLEN = BUS_WIDTH
) (
    input  logic                          clk_i               ,
    input  logic                          rst_ni              ,

    // Bus interface
    output logic                          data_req_o          ,
    output logic [                  31:0] data_addr_o         ,
    output logic                          data_we_o           ,
    output logic [     BUS_WIDTH/8 - 1:0] data_be_o           ,
    output logic [         BUS_WIDTH-1:0] data_wdata_o        ,
    input  logic                          data_gnt_i          ,
    input  logic                          data_rvalid_i       ,
    input  logic [         BUS_WIDTH-1:0] data_rdata_i        ,

    output logic[xif_pkg::X_ID_WIDTH-1:0] lsu_id_o            ,

    // Register Write Port for load unit
    output logic [    $clog2(N_REGS)-1:0] waddr_o             ,
    output logic [    $clog2(N_ROWS)-1:0] wrowaddr_o          ,
    output logic [              RLEN-1:0] wdata_o             ,
    output logic                          we_o                ,
    output logic                          wlast_o             ,
    input  logic                          wready_i            ,  // to stall the request in case the port is busy

    // Register Read Port for store unit
    output logic [    $clog2(N_REGS)-1:0] raddr_o             ,
    output logic [    $clog2(N_ROWS)-1:0] rrowaddr_o          ,
    input  logic [              RLEN-1:0] rdata_i             ,
    input  logic                          rdata_valid_i       ,
    output logic                          rdata_ready_o       ,
    output logic                          rlast_o             ,

    // Configuration Signals
    input  logic                           start_i            ,  // start loading: MUST BE A PULSE
    input  logic                           write_i            ,
    output logic                           busy_o             ,
    input  logic [                   31:0] stride_i           ,  // stride value
    input  logic [                   31:0] address_i          ,  // address value
    input  logic [     $clog2(N_REGS)-1:0] operand_reg_i      ,  // destination register
    input  logic [xif_pkg::X_ID_WIDTH-1:0] instr_id_i         ,  // instruction id
    input  logic [                   31:0] n_bytes_cols_i     ,  // we always fetch the entire row and then only take the elements we need 
    input  logic [                   31:0] n_rows_i           ,


    output logic                           finished_o         ,
    input  logic                           finished_ack_i     ,
    output logic [xif_pkg::X_ID_WIDTH-1:0] finished_instr_id_o  //instruction id out

);

  localparam MAX_EL_PER_ROW = RLEN / BUS_WIDTH;

  logic finished;
  logic [xif_pkg::X_ID_WIDTH-1:0] back_id_q;
  logic [xif_pkg::X_ID_WIDTH-1:0] back_id_d;

  logic [$clog2(N_ROWS)-1:0] counter_q;
  logic [$clog2(N_ROWS)-1:0] counter_d;
  logic [$clog2(N_REGS)-1:0] waddr_q;
  logic [$clog2(N_REGS)-1:0] waddr_d;

  logic [RLEN-1:0] load_fifo_data;

  logic load_fifo_data_available;
  logic load_fifo_pop;

  logic store_fifo_space_available;
  logic store_fifo_push;
  logic store_fifo_empty;
  logic [RLEN-1:0] store_fifo_data;

  logic [RLEN-1:0] data_mask;
  logic load_fifo_valid;
  logic busy;
  logic start;
  logic start_q;
  logic start_d;


  logic valid_d;
  logic valid_q;

  logic write_q;
  logic write_d;
  logic terminate;
  logic busy_q;
  logic busy_d;

  logic lsu_busy_q;
  logic lsu_ready;
  logic mask_req;




  logic [              31:0] src_ptr_d ;
  logic [              31:0] stride_d  ;
  logic [              31:0] src_ptr_q ;
  logic [              31:0] stride_q  ;
  logic [              31:0] src_ptr   ;
  logic [              31:0] stride    ;

  assign mask_req     = (counter_q == $clog2(N_ROWS)'(N_ROWS - 1)) & finished_o & ~finished_ack_i;
  always_comb begin
    lsu_id_o   = (write_i &~ load_fifo_data_available) ? instr_id_i : back_id_q;
    finished   = (write_q & terminate) | (~write_q & wlast_o & wready_i);
  end
  

  always_comb begin: write_to_RF
    data_mask     = '1 << (8 * n_bytes_cols_i);  // SPEC says to load zeros outside of rows and cols

    we_o          = load_fifo_data_available &~ mask_req;
    waddr_o       = waddr_q;
    wrowaddr_o    = counter_q       ;
    wdata_o       = load_fifo_data & ~data_mask;
    wlast_o       = (counter_q == $clog2(N_ROWS)'(N_ROWS - 1)) && we_o && wready_i;  
    // wlast_o       = (counter_q == $clog2(N_ROWS)'(N_ROWS - 1)) & wready_i;
  end

  always_comb begin: read_from_RF
    rdata_ready_o = write_i & store_fifo_space_available &~ load_fifo_data_available &~ mask_req;
    rrowaddr_o    = counter_q       ;
    raddr_o       = operand_reg_i ;
    rlast_o       = (counter_q == $clog2(N_ROWS)'(N_ROWS - 1)) && rdata_valid_i && rdata_ready_o;   
  end

  always_comb begin: lsu_ctrl_block
    load_fifo_pop   = wready_i;
    store_fifo_data = rdata_i;
    store_fifo_push = rdata_ready_o && rdata_valid_i;
    lsu_ready = store_fifo_empty | (write_i &~ load_fifo_data_available &~ lsu_busy_q);
    start  = (start_i | start_q) & lsu_ready;
    //busy_o = (write_i ? busy_d : busy) | start_q;
    busy_o = (write_i ? busy_d : busy | (load_fifo_data_available & counter_d == '0)) | start_q;
    
    stride  = (start) ? stride_i  : stride_q;
    src_ptr = (start) ? address_i : src_ptr_q;
  end

  always_comb begin: next_value
    if (rlast_o || wlast_o) begin
      counter_d = '0;
    end else if ((we_o && wready_i) || (rdata_valid_i && rdata_ready_o && !rlast_o)) begin
      counter_d = counter_q + 1;
    end else begin
      counter_d = counter_q;
    end

    write_d = (write_i && rlast_o && rdata_valid_i) ? 1'b1 :
              (!write_i && !busy)                   ? 1'b0 : write_q;

    valid_d = (load_fifo_valid && counter_d==0 && ~valid_q) ? 1'b1 : 
              (load_fifo_valid && counter_d==3 &&  valid_q) ? 1'b0 : valid_q;

    start_d =  start              ? 1'b0 : 
              (start_q | start_i) ? 1'b1 : start_q;

    stride_d   = (start) ? stride_i  : stride_q ;
    src_ptr_d  = (start) ? address_i : src_ptr_q;

    back_id_d = (load_fifo_valid && counter_d==0  && ~valid_q) ? instr_id_i    : 
                  rlast_o                                       ? lsu_id_o      : back_id_q;

    waddr_d   = (load_fifo_valid && counter_d==0) ? operand_reg_i : waddr_q  ;

    busy_d = (write_i && rlast_o && rdata_valid_i) ? 1'b0 :
             (write_i && start_i)                  ? 1'b1 : busy_q;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin: seq_block
    if (!rst_ni) begin
      counter_q <= '0;
      waddr_q   <= '0;
      back_id_q <= '0;
      start_q   <= '0;
      valid_q   <= '0;
      write_q   <= '0;
      busy_q    <= '0;

      lsu_busy_q <= '0;
      src_ptr_q  <= '0;
      stride_q   <= '0;
    end else begin
      counter_q <= counter_d;
      back_id_q <= back_id_d;
      waddr_q   <= waddr_d  ; 
      start_q   <= start_d  ;
      valid_q   <= valid_d  ;
      write_q   <= write_d  ;
      busy_q    <= busy_d   ;

      lsu_busy_q <= busy;
      src_ptr_q  <= src_ptr_d;
      stride_q   <= stride_d ;
    end
  end

  quadrilatero_lsu #(
      .FIFO_DEPTH (4        ),
      .DATA_WIDTH (BUS_WIDTH)
  ) lsunit_inst (

      .clk_i                                                     ,
      .rst_ni                                                    ,
      
      // Bus interface
      .data_req_o                                                ,
      .data_addr_o                                               ,
      .data_we_o                                                 ,
      .data_be_o                                                 ,
      .data_wdata_o                                              ,
      .data_gnt_i                                                ,
      .data_rvalid_i                                             ,
      .data_rdata_i                                              ,

      //Configuration
      .start_i                      (start                      ),
      .write_i                                                   ,
      .busy_o                       (busy                       ),
      .terminate_o                  (terminate                  ),

      // Address
      .src_ptr_i                    (src_ptr                    ),
      .stride_i                     (stride                     ),
      .cols_i                       (MAX_EL_PER_ROW             ),
      .rows_i                       (n_rows_i                   ),

      // Output data
      .load_fifo_output_o           (load_fifo_data             ),
      .load_fifo_valid_o            (load_fifo_valid            ),
      .load_fifo_data_available_o   (load_fifo_data_available   ),
      .load_fifo_output_pop_i       (load_fifo_pop              ),

      // Input data
      .store_fifo_input_i           (store_fifo_data            ),
      .store_fifo_push_i            (store_fifo_push            ),
      .store_fifo_space_available_o (store_fifo_space_available ),
      .store_fifo_empty_o           (store_fifo_empty           )
  );

  //-------------------------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      finished_o <= '0;
      finished_instr_id_o <= '0;
    end else begin
      if (finished) begin
        finished_o <= '1;
        finished_instr_id_o <= back_id_q;
      end
      if (finished_ack_i) begin
        finished_o          <= '0;
        finished_instr_id_o <= '0;
      end
    end
  end
  //---------------------

  // Assertions
  if (N_ROWS < 2) begin
    $error(
        "[quadrilatero_register_lsu] N_ROWS must be at least 2.\n"
    );
  end
endmodule
