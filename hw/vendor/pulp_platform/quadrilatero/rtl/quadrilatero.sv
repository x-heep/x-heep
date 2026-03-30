// Copyright 2024 EPFL
// Solderpad Hardware License,Version 2.1,see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

module quadrilatero
  import quadrilatero_pkg::*;
  import xif_pkg::*;
  #(
      parameter INPUT_BUFFER_DEPTH = 4,  // 0 means no input buffer 
      parameter RES_IF_FIFO_DEPTH  = 8,
      parameter FPU = 1
  ) (
    // Clock and Reset
    input  logic                                    clk_i               ,
    input  logic                                    rst_ni              ,

    // Memory Interface to OBI
    output logic                                    mem_req_o           ,
    output logic                                    mem_we_o            ,
    output logic [quadrilatero_pkg::BUS_WIDTH/8 -1:0] mem_be_o            ,
    output logic [                            31:0] mem_addr_o          ,
    output logic [quadrilatero_pkg::BUS_WIDTH  -1 :0] mem_wdata_o         ,
    input  logic                                    mem_gnt_i           ,
    input  logic                                    mem_rvalid_i        ,
    input  logic [quadrilatero_pkg::BUS_WIDTH - 1:0]  mem_rdata_i         ,

    // Compressed Interface
    input  logic                                    x_compressed_valid_i,  // unused
    output logic                                    x_compressed_ready_o,  // unused
    input  x_compressed_req_t                       x_compressed_req_i  ,  // unused
    output x_compressed_resp_t                      x_compressed_resp_o ,  // unused

    // Issue Interface
    input  logic                                    x_issue_valid_i     ,
    output logic                                    x_issue_ready_o     ,
    input  x_issue_req_t                            x_issue_req_i       ,
    output x_issue_resp_t                           x_issue_resp_o      ,  // careful the output does not care if issue valid is 1... don't know if the CPU cares about it 

    // Commit Interface
    input  logic                                    x_commit_valid_i    ,
    input  x_commit_t                               x_commit_i          ,

    // Memory Request/Response Interface
    output logic                                    x_mem_valid_o       ,  // unused 
    input  logic                                    x_mem_ready_i       ,  // unused 
    output x_mem_req_t                              x_mem_req_o         ,  // unused 
    input  x_mem_resp_t                             x_mem_resp_i        ,  // unused 

    // Memory Result Interface
    input  logic                                    x_mem_result_valid_i,  // unused
    input  x_mem_result_t                           x_mem_result_i      ,  // unused

    // Result Interface (we are allowed to return results out of order. Don't bother tracking the original order)
    output logic                                    x_result_valid_o    ,
    input  logic                                    x_result_ready_i    ,
    output x_result_t                               x_result_o
);

//*************************************************************************************************
//*************************************************************************************************
//*****************                                                              ******************
//*****************                   SIGNALS DECLARATION                        ******************
//*****************                                                              ******************
//*************************************************************************************************
//*************************************************************************************************

  // Input Buffer
  offloaded_data_t in_buf_push_data ;
  offloaded_data_t in_buf_pop_data  ;
  logic            in_buf_push_valid;
  logic            in_buf_push_ready;  // not fifo full
  logic            in_buf_pop_valid ;  // not fifo empty
  logic            in_buf_pop_ready ;


  // Commit Interface
  logic [$clog2(INPUT_BUFFER_DEPTH)-1:0] accepted_instruction_count;
  logic                                  commit_valid              ;
  logic [xif_pkg::X_ID_WIDTH-1:0]        commit_id_q               ;
  logic [xif_pkg::X_ID_WIDTH-1:0]        commit_id_d               ;
  logic [$clog2(INPUT_BUFFER_DEPTH):0]   uncommited_instr_q        ;
  logic [$clog2(INPUT_BUFFER_DEPTH):0]   uncommited_instr_d        ;
  logic                                  head_instr_committed      ;  // If we have in the fifo more instructions that those uncommitted 
                                                                     // it means the instruction at the head has been committed and can be dispatched

  // Decoder
  logic [31:0]                                                                         instr                         ;
  logic [ 1:0]                                                                         decoder_n_matrix_operands_read;
  logic                                                                                decoder_rf_writeback          ;
  logic                                                                                decoder_instr_valid           ;
  logic                                                                                decoder_is_store_out          ;
  logic                                                                                decoder_is_float_out          ;
  quadrilatero_pkg::execution_units_t                                                    decoder_exec_unit             ;
  quadrilatero_pkg::datatype_t                                                           decoder_datatype_out          ;
  logic[quadrilatero_pkg::MAX_NUM_READ_OPERANDS-1:0][$clog2(quadrilatero_pkg::N_REGS)-1:0] decoder_rf_read_regs          ;
  logic                                           [$clog2(quadrilatero_pkg::N_REGS)-1:0] decoder_rf_writeback_reg      ;

  // Dispatcher
  logic                                                                                         dispatcher_rf_writeback          ;
  logic                                                                                         dispatcher_is_store_out          ;
  logic                                                                                         dispatcher_is_float_out          ;
  logic                                                                                         dispatcher_instr_valid           ;
  logic                                                                                         dispatcher_instr_ready           ;
  quadrilatero_pkg::rw_queue_t                               [quadrilatero_pkg::N_REGS-1        :0] dispatcher_rw_queue_entry        ;
  logic                                                    [quadrilatero_pkg::N_REGS-1        :0] dispatcher_rw_queue_push         ;
  logic                                                    [quadrilatero_pkg::N_REGS-1        :0] dispatcher_rw_queue_full         ;
  logic [$clog2(quadrilatero_pkg::MAX_NUM_READ_OPERANDS)-1:0]                                     dispatcher_n_matrix_operands_read;
  logic [xif_pkg::X_NUM_RS  -1:0][xif_pkg::X_RFR_WIDTH-1:0]                                     dispatcher_rs                    ;
  logic [xif_pkg::X_NUM_RS  -1:0]                                                               dispatcher_rs_valid              ;
  logic [xif_pkg::X_ID_WIDTH-1:0]                                                               dispatcher_id                    ;
  logic [quadrilatero_pkg::MAX_NUM_READ_OPERANDS-1        :0][$clog2(quadrilatero_pkg::N_REGS)-1:0] dispatcher_rf_read_regs          ;
  logic                                                    [$clog2(quadrilatero_pkg::N_REGS)-1:0] dispatcher_rf_writeback_reg      ;
  logic                                                    [$clog2(quadrilatero_pkg::N_REGS)-1:0] dispatcher_reg_ms1               ;
  logic                                                    [$clog2(quadrilatero_pkg::N_REGS)-1:0] dispatcher_reg_ms2               ;
  logic                                                    [$clog2(quadrilatero_pkg::N_REGS)-1:0] dispatcher_reg_ms3               ;
  logic                                                    [$clog2(quadrilatero_pkg::N_REGS)-1:0] dispatcher_reg_md                ;
  logic [quadrilatero_pkg::NUM_EXEC_UNITS-1               :0]                                     dispatcher_issue_queue_full      ;
  logic [quadrilatero_pkg::NUM_EXEC_UNITS-1               :0]                                     dispatcher_dispatch              ;
  quadrilatero_pkg::execution_units_t                                                             dispatcher_exec_unit             ;
  quadrilatero_pkg::datatype_t                                                                    dispatcher_instr_datatype_out    ;
  logic [xif_pkg::X_NUM_RS  -1:0                          ][xif_pkg::X_RFR_WIDTH-1:0          ] dispatcher_rs_out                ;  // Register file source operands for the offloaded instruction
  logic [xif_pkg::X_NUM_RS  -1:0                          ]                                     dispatcher_rs_valid_out          ;  // Validity of the register file source operand(s)
  logic [xif_pkg::X_ID_WIDTH-1:0                          ]                                     dispatcher_instr_id_out          ;


  // RF Sequencer
  logic [quadrilatero_pkg::READ_PORTS-1    :0][$clog2(quadrilatero_pkg::N_REGS)-1:0] rf_seq_raddr_from_fu   ;
  logic [quadrilatero_pkg::READ_PORTS-1    :0][$clog2(quadrilatero_pkg::N_ROWS)-1:0] rf_seq_rrowaddr_from_fu;
  logic [quadrilatero_pkg::READ_PORTS-1    :0][quadrilatero_pkg::RLEN-1:0]           rf_seq_rdata_from_fu   ;
  logic [quadrilatero_pkg::READ_PORTS-1    :0]                                     rf_seq_rvalid_from_fu  ;
  logic [quadrilatero_pkg::READ_PORTS-1    :0]                                     rf_seq_rlast_from_fu   ;
  logic [quadrilatero_pkg::READ_PORTS-1    :0]                                     rf_seq_rready_from_fu  ;
  logic [quadrilatero_pkg::READ_PORTS-1    :0][xif_pkg::X_ID_WIDTH-1:0]            rf_seq_rd_id_from_fu   ;

  logic [quadrilatero_pkg::WRITE_PORTS-1   :0][$clog2(quadrilatero_pkg::N_REGS)-1:0] rf_seq_waddr_from_fu   ;
  logic [quadrilatero_pkg::WRITE_PORTS-1   :0][$clog2(quadrilatero_pkg::N_ROWS)-1:0] rf_seq_wrowaddr_from_fu;
  logic [quadrilatero_pkg::WRITE_PORTS-1   :0][quadrilatero_pkg::RLEN-1:0]           rf_seq_wdata_from_fu   ;
  logic [quadrilatero_pkg::WRITE_PORTS-1   :0]                                     rf_seq_we_from_fu      ;
  logic [quadrilatero_pkg::WRITE_PORTS-1   :0]                                     rf_seq_wlast_from_fu   ;
  logic [quadrilatero_pkg::WRITE_PORTS-1   :0]                                     rf_seq_wready_from_fu  ;
  logic [quadrilatero_pkg::WRITE_PORTS-1   :0][xif_pkg::X_ID_WIDTH-1:0]            rf_seq_wr_id_from_fu   ;

  logic [quadrilatero_pkg::RF_READ_PORTS-1 :0][$clog2(quadrilatero_pkg::N_REGS)-1:0] rf_seq_raddr_to_rf     ;
  logic [quadrilatero_pkg::RF_READ_PORTS-1 :0][$clog2(quadrilatero_pkg::N_ROWS)-1:0] rf_seq_rrowaddr_to_rf  ;
  logic [quadrilatero_pkg::RF_READ_PORTS-1 :0][quadrilatero_pkg::RLEN-1:0]           rf_seq_rdata_to_rf     ;

  logic [quadrilatero_pkg::RF_WRITE_PORTS-1:0][$clog2(quadrilatero_pkg::N_REGS)-1:0] rf_seq_waddr_to_rf     ;
  logic [quadrilatero_pkg::RF_WRITE_PORTS-1:0][$clog2(quadrilatero_pkg::N_ROWS)-1:0] rf_seq_wrowaddr_to_rf  ;
  logic [quadrilatero_pkg::RF_WRITE_PORTS-1:0][quadrilatero_pkg::RLEN-1:0]           rf_seq_wdata_to_rf     ;
  logic [quadrilatero_pkg::RF_WRITE_PORTS-1:0]                                     rf_seq_we_to_rf        ;

  quadrilatero_pkg::rw_queue_t                [quadrilatero_pkg::N_REGS-1:0]         rf_seq_rw_queue_entry  ;
  logic                                     [quadrilatero_pkg::N_REGS-1:0]         rf_seq_rw_queue_push   ;
  logic                                     [quadrilatero_pkg::N_REGS-1:0]         rf_seq_rw_queue_full   ;


  // Systolic Array Controller
  logic                      sa_ctrl_issue_queue_full;
  logic                      sa_ctrl_dispatch        ;
  logic                      sa_ctrl_wl_ready        ;
  logic                      sa_ctrl_start           ;
  quadrilatero_pkg::sa_instr_t sa_ctrl_dispatched_instr;
  quadrilatero_pkg::sa_instr_t sa_ctrl_issued_instr    ;


  // Systolic Array
  logic                                      sa_weight_rdata_valid;
  logic                                      sa_weight_rdata_ready;
  logic                                      sa_weight_rlast      ;
  logic [xif_pkg::X_ID_WIDTH-1:0]            sa_input_id          ;
  logic [quadrilatero_pkg::RLEN-1:0]           sa_weight_rdata      ;
  logic [$clog2(quadrilatero_pkg::N_REGS)-1:0] sa_weight_raddr      ;
  logic [$clog2(quadrilatero_pkg::N_ROWS)-1:0] sa_weight_rrowaddr   ;

  logic                                      sa_data_rdata_valid  ;
  logic                                      sa_data_rdata_ready  ;
  logic                                      sa_data_rlast        ;
  logic [xif_pkg::X_ID_WIDTH-1:0]            sa_output_id         ;
  logic [quadrilatero_pkg::RLEN-1:0]           sa_data_rdata        ;
  logic [$clog2(quadrilatero_pkg::N_REGS)-1:0] sa_data_raddr        ;
  logic [$clog2(quadrilatero_pkg::N_ROWS)-1:0] sa_data_rrowaddr     ;

  logic                                      sa_acc_rdata_valid   ;
  logic                                      sa_acc_rdata_ready   ;
  logic                                      sa_acc_rlast         ;
  logic [quadrilatero_pkg::RLEN-1:0]           sa_acc_rdata         ;
  logic [$clog2(quadrilatero_pkg::N_REGS)-1:0] sa_acc_raddr         ;
  logic [$clog2(quadrilatero_pkg::N_ROWS)-1:0] sa_acc_rrowaddr      ;

  logic                                      sa_res_we            ;
  logic                                      sa_res_wready        ;
  logic                                      sa_res_wlast         ;
  logic [quadrilatero_pkg::RLEN-1:0]           sa_res_wdata         ;
  logic [$clog2(quadrilatero_pkg::N_REGS)-1:0] sa_res_waddr         ;
  logic [$clog2(quadrilatero_pkg::N_ROWS)-1:0] sa_res_wrowaddr      ;

  logic                                      sa_finished          ;
  logic                                      sa_finished_ack      ;
  logic [xif_pkg::X_ID_WIDTH-1:0]            sa_finished_instr_id ;


  // LSU Controller
  logic                       lsu_ctrl_issue_queue_full ;
  logic                       lsu_ctrl_dispatch         ;
  logic                       lsu_ctrl_busy             ;
  logic                       lsu_ctrl_start            ;
  quadrilatero_pkg::lsu_instr_t lsu_ctrl_dispatched_instr ;
  quadrilatero_pkg::lsu_conf_t  lsu_ctrl_csr_config       ;
  quadrilatero_pkg::lsu_instr_t lsu_ctrl_issued_instr     ;
  quadrilatero_pkg::lsu_conf_t  lsu_ctrl_issued_instr_conf;


  // LSU
  logic                                      lsu_data_req         ;
  logic                                      lsu_data_gnt         ;
  logic                                      lsu_data_rvalid      ;
  logic [31:0]                               lsu_data_addr        ;
  logic                                      lsu_data_we          ;
  logic [quadrilatero_pkg::BUS_WIDTH/8-1:0]    lsu_data_be          ;
  logic [quadrilatero_pkg::BUS_WIDTH  -1:0]    lsu_data_rdata       ;
  logic [quadrilatero_pkg::BUS_WIDTH  -1:0]    lsu_data_wdata       ;

  logic                                      lsu_we               ;
  logic                                      lsu_wlast            ;
  logic                                      lsu_wready           ;
  logic [xif_pkg::X_ID_WIDTH-1:0]            lsu_id               ;
  logic [quadrilatero_pkg::RLEN-1:0]           lsu_wdata            ;
  logic [$clog2(quadrilatero_pkg::N_REGS)-1:0] lsu_waddr            ;
  logic [$clog2(quadrilatero_pkg::N_ROWS)-1:0] lsu_wrowaddr         ;

  logic                                      lsu_rlast            ;
  logic                                      lsu_rready           ;
  logic                                      lsu_rvalid           ;
  logic [quadrilatero_pkg::RLEN-1:0]           lsu_rdata            ;
  logic [$clog2(quadrilatero_pkg::N_REGS)-1:0] lsu_raddr            ;
  logic [$clog2(quadrilatero_pkg::N_ROWS)-1:0] lsu_rrowaddr         ;

  logic                                      lsu_busy             ;
  logic                                      lsu_finished         ;
  logic                                      lsu_finished_ack     ;
  logic [xif_pkg::X_ID_WIDTH-1:0]            lsu_finished_instr_id;


  // Permutation Unit
  logic                                      perm_unit_finished         ;
  logic                                      perm_unit_finished_ack     ;
  logic                                      perm_start                 ;
  logic                                      perm_busy                  ;
  logic                                      perm_unit_we               ;
  logic                                      perm_unit_wlast            ;
  logic                                      perm_unit_wready           ;
  logic [xif_pkg::X_ID_WIDTH-1:0]            perm_unit_id               ;
  logic [xif_pkg::X_ID_WIDTH-1:0]            perm_unit_instr_id         ;
  logic [xif_pkg::X_ID_WIDTH-1:0]            perm_unit_finished_instr_id;
  logic [quadrilatero_pkg::RLEN-1:0]           perm_unit_wdata            ;
  logic [$clog2(quadrilatero_pkg::N_REGS)-1:0] perm_unit_waddr            ;
  logic [$clog2(quadrilatero_pkg::N_ROWS)-1:0] perm_unit_wrowaddr         ;
  logic [$clog2(quadrilatero_pkg::N_REGS)-1:0] perm_unit_reg              ;


  // Result Interface
  logic                                               x_res_almost_full ;
  logic                                               x_res_full        ;
  logic                                               x_res_empty       ;
  logic [$clog2(RES_IF_FIFO_DEPTH)-1:0]               x_res_usage       ;
  logic [xif_pkg::X_ID_WIDTH-1:0]                     x_res_data_in     ;
  logic [xif_pkg::X_ID_WIDTH-1:0]                     x_res_data_out    ;
  logic                                               x_res_push        ;
  logic                                               x_res_pop         ;
  logic [NUM_EXEC_UNITS-1:0]                          x_res_finished    ;
  logic [NUM_EXEC_UNITS-1:0]                          x_res_finished_ack;
  logic [NUM_EXEC_UNITS-1:0][xif_pkg::X_ID_WIDTH-1:0] x_res_finished_id ;
  logic [$clog2(quadrilatero_pkg::NUM_EXEC_UNITS)-1:0]  x_res_selected_fu ;



//*************************************************************************************************
//*************************************************************************************************
//*****************                                                              ******************
//*****************                      IMPLEMENTATION                          ******************
//*****************                                                              ******************
//*************************************************************************************************
//*************************************************************************************************


  //******************************
  //***  COMPRESSED INTERFACE  ***
  //******************************

  always_comb begin : unused_compressed
    // We don't handle compressed instructions,so we never accept them
    x_compressed_ready_o       = x_compressed_valid_i;
    x_compressed_resp_o.accept = 1'b0                ;
    x_compressed_resp_o.instr  = 32'hf00dbabe        ;
  end


  //**************************
  //***  MEMORY INTERFACE  ***
  //**************************

  always_comb begin : unused_mem_interface
    // We don't use the mem_interface
    x_mem_valid_o = '0;
    x_mem_req_o   = '0;
  end


  //******************************************
  //***  ISSUE INTERFACE and INPUT BUFFER  ***
  //******************************************

  always_comb begin: issue_interface_block

    // From X_ISSUE Interface
    in_buf_push_valid           = x_issue_valid_i & in_buf_push_ready & x_issue_resp_o.accept;
    in_buf_push_data.rs         = x_issue_req_i.rs                                           ;
    in_buf_push_data.rs_valid   = x_issue_req_i.rs_valid                                     ;
    in_buf_push_data.instr_data = x_issue_req_i.instr                                        ;
    in_buf_push_data.id         = x_issue_req_i.id                                           ;
    in_buf_push_data.mode       = x_issue_req_i.mode                                         ;

    // To X_ISSUE Interface
    x_issue_ready_o = in_buf_push_ready;  // when not full
  end

  // Handles the Issue Interface handshake
  quadrilatero_xif_decoder xif_decoder_inst (
      .instr_i        (x_issue_req_i.instr),
      .x_issue_resp_o
  );

  generate // input buffer
    if (INPUT_BUFFER_DEPTH > 0) begin : gen_input_stream_fifo

      stream_fifo #(
          .FALL_THROUGH(1  ),
          .DATA_WIDTH  (32 ),
          .DEPTH       (INPUT_BUFFER_DEPTH        ),
          .T           (offloaded_data_t          )
      ) input_stream_fifo_i (
          .clk_i                                   ,
          .rst_ni                                  ,
          .flush_i     (1'b0                      ),
          .testmode_i  (1'b0                      ),
          .usage_o     (accepted_instruction_count),

          .data_i      (in_buf_push_data          ),
          .valid_i     (in_buf_push_valid         ),
          .ready_o     (in_buf_push_ready         ),  // not full

          .data_o      (in_buf_pop_data           ),
          .valid_o     (in_buf_pop_valid          ),  // not empty
          .ready_i     (in_buf_pop_ready          )
      );
    end else begin : gen_no_input_stream_fifo
      // THIS CASE IS WRONG. FIX BACKPRESSURE

      assign in_buf_pop_data   = in_buf_push_data;
      assign in_buf_push_ready = 1'b1;
      assign in_buf_pop_valid  = x_issue_valid_i;

    end
  endgenerate


  //**************************
  //***  COMMIT INTERFACE  ***
  //**************************

  always_ff @(posedge clk_i or negedge rst_ni) begin:commit_seq_block
    if (!rst_ni) begin
      commit_id_q        <= 'hB;
      uncommited_instr_q <= '0;
    end else begin
      commit_id_q        <= commit_id_d       ;
      uncommited_instr_q <= uncommited_instr_d;
    end
  end
   
  always_comb begin: commit_interface_block
    // From XIF 
    commit_valid = (commit_id_q != x_commit_i.id) & x_commit_valid_i & x_issue_ready_o;
    commit_id_d  = commit_valid ? x_commit_i.id : commit_id_q;

    // To Input Buffer
    case ({commit_valid,x_issue_ready_o && x_issue_valid_i})
      2'b00: uncommited_instr_d =  uncommited_instr_q                                                  ;  // neither new instruction nor now commit
      2'b01: uncommited_instr_d = (uncommited_instr_q==INPUT_BUFFER_DEPTH) ? 0 : uncommited_instr_q + 1;  // new instruction
      2'b10: uncommited_instr_d = (uncommited_instr_q==0) ? INPUT_BUFFER_DEPTH : uncommited_instr_q - 1;  // committed instruction
      2'b11: uncommited_instr_d =  uncommited_instr_q                                                  ;  // both new instruction and one is commited
    endcase

    head_instr_committed = in_buf_push_ready ? uncommited_instr_q < {1'b0,accepted_instruction_count} 
                                             : uncommited_instr_q < INPUT_BUFFER_DEPTH                ;
    // head_instr_committed = 1'b1;
  end


  //*****************
  //***  DECODER  ***
  //*****************

  assign instr = in_buf_pop_data.instr_data;

  quadrilatero_decoder #() decoder_inst (
      .instr_i                   (instr                         ),

      // Signals to the controller
      .n_matrix_operands_read_o  (decoder_n_matrix_operands_read),  // how many RF operands are read from RF
      .rf_writeback_o            (decoder_rf_writeback          ),
      .rf_writeback_reg_o        (decoder_rf_writeback_reg      ),
      .rf_read_regs_o            (decoder_rf_read_regs          ),

      .exec_unit_o               (decoder_exec_unit             ),
      .instr_valid_o             (decoder_instr_valid           ),
      .datatype_o                (decoder_datatype_out          ),
      .is_store_o                (decoder_is_store_out          ),
      .is_float_o                (decoder_is_float_out          )
  );


  //********************
  //***  DISPATCHER  ***
  //********************

  always_comb begin: dispatcher_block

    // To input buffer
    in_buf_pop_ready = dispatcher_instr_ready && head_instr_committed;
    
    // From Decoder
    dispatcher_instr_valid            = decoder_instr_valid && in_buf_pop_valid && head_instr_committed;
    
    dispatcher_n_matrix_operands_read = decoder_n_matrix_operands_read;                        
    dispatcher_exec_unit              = decoder_exec_unit             ;
    dispatcher_rf_writeback           = decoder_rf_writeback          ;
    dispatcher_rf_read_regs           = decoder_rf_read_regs          ;
    dispatcher_rf_writeback_reg       = decoder_rf_writeback_reg      ;
    dispatcher_rs                     = in_buf_pop_data.rs            ;                        
    dispatcher_rs_valid               = in_buf_pop_data.rs_valid      ;                        
    dispatcher_id                     = in_buf_pop_data.id            ;  

    // From RF Sequencer and Execution Units
    dispatcher_rw_queue_full                                       = rf_seq_rw_queue_full      ;
    dispatcher_issue_queue_full[quadrilatero_pkg::FU_SYSTOLIC_ARRAY] = sa_ctrl_issue_queue_full  ;
    dispatcher_issue_queue_full[quadrilatero_pkg::FU_LSU]            = lsu_ctrl_issue_queue_full ;
    dispatcher_issue_queue_full[quadrilatero_pkg::FU_RF]             = perm_busy              ;

  end

  quadrilatero_dispatcher #(
      .N_REGS           (quadrilatero_pkg::N_REGS         ),
      .NUM_EXEC_UNITS   (quadrilatero_pkg::NUM_EXEC_UNITS )
  ) disp_inst (
      .clk_i                                                         ,
      .rst_ni                                                        ,

      .rw_queue_entry_o           (dispatcher_rw_queue_entry        ),
      .rw_queue_push_o            (dispatcher_rw_queue_push         ),

      // Inputs from RF Sequencer
      .rw_queue_full_i            (dispatcher_rw_queue_full         ),

      // Instruction from Decoder
      .rs_i                       (dispatcher_rs                    ),
      .rs_valid_i                 (dispatcher_rs_valid              ),
      .instr_id_i                 (dispatcher_id                    ),
      .n_matrix_operands_read_i   (dispatcher_n_matrix_operands_read),  // how many reads to RF
      .datatype_i                 (decoder_datatype_out             ),
      .is_store_i                 (decoder_is_store_out             ),
      .is_float_i                 (decoder_is_float_out             ),
      .rf_read_regs_i             (dispatcher_rf_read_regs          ),  // which registers to read from 
      .rf_writeback_i             (dispatcher_rf_writeback          ),  // whether we need to write to the register file
      .rf_writeback_reg_i         (dispatcher_rf_writeback_reg      ),  // which register to writeback to 
      .exec_unit_i                (dispatcher_exec_unit             ),  // which exec unit
      .instr_valid_i              (dispatcher_instr_valid           ),
      .rs_o                       (dispatcher_rs_out                ),
      .rs_valid_o                 (dispatcher_rs_valid_out          ),  // FIXTHIS: this never gets used by the exec units. 
      .instr_id_o                 (dispatcher_instr_id_out          ),
      .datatype_o                 (dispatcher_instr_datatype_out    ),
      .is_store_o                 (dispatcher_is_store_out          ),
      .is_float_o                 (dispatcher_is_float_out          ),
      .reg_ms1_o                  (dispatcher_reg_ms1               ),
      .reg_ms2_o                  (dispatcher_reg_ms2               ),
      .reg_ms3_o                  (dispatcher_reg_ms3               ),
      .reg_md_o                   (dispatcher_reg_md                ),

      // Backpressure towards Decoder
      .instr_ready_o              (dispatcher_instr_ready           ),

      // Outputs towards Execution Units
      .issue_queue_full_i         (dispatcher_issue_queue_full      ),
      .dispatch_o                 (dispatcher_dispatch              )
  );


  //******************************
  //***  REGISTER FILE BLOCKS  ***
  //******************************

  always_comb begin: rf_seq_block

    // From Dispatcher
    rf_seq_rw_queue_entry = dispatcher_rw_queue_entry;
    rf_seq_rw_queue_push  = dispatcher_rw_queue_push ;

    // Systolic Array: Weight Read Port
    rf_seq_raddr_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY_W] = sa_weight_raddr      ;
    rf_seq_rrowaddr_from_fu[quadrilatero_pkg::SYSTOLIC_ARRAY_W] = sa_weight_rrowaddr   ;
    rf_seq_rlast_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY_W] = sa_weight_rlast      ;
    rf_seq_rready_from_fu  [quadrilatero_pkg::SYSTOLIC_ARRAY_W] = sa_weight_rdata_ready;
    rf_seq_rd_id_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY_W] = sa_input_id          ;

    // Systolic Array: Data Read Port
    rf_seq_raddr_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY_D] = sa_data_raddr        ;
    rf_seq_rrowaddr_from_fu[quadrilatero_pkg::SYSTOLIC_ARRAY_D] = sa_data_rrowaddr     ;
    rf_seq_rlast_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY_D] = sa_data_rlast        ;
    rf_seq_rready_from_fu  [quadrilatero_pkg::SYSTOLIC_ARRAY_D] = sa_data_rdata_ready  ;
    rf_seq_rd_id_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY_D] = sa_input_id          ;

    // Systolic Array: Accumulator Read Port
    rf_seq_raddr_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY_A] = sa_acc_raddr         ;
    rf_seq_rrowaddr_from_fu[quadrilatero_pkg::SYSTOLIC_ARRAY_A] = sa_acc_rrowaddr      ;
    rf_seq_rlast_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY_A] = sa_acc_rlast         ;
    rf_seq_rready_from_fu  [quadrilatero_pkg::SYSTOLIC_ARRAY_A] = sa_data_rdata_ready  ;
    rf_seq_rd_id_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY_A] = sa_input_id          ;

    // LSU Read Port
    rf_seq_raddr_from_fu   [quadrilatero_pkg::LSU_R           ] = lsu_raddr            ;
    rf_seq_rrowaddr_from_fu[quadrilatero_pkg::LSU_R           ] = lsu_rrowaddr         ;
    rf_seq_rlast_from_fu   [quadrilatero_pkg::LSU_R           ] = lsu_rlast            ;
    rf_seq_rready_from_fu  [quadrilatero_pkg::LSU_R           ] = lsu_rready           ;
    rf_seq_rd_id_from_fu   [quadrilatero_pkg::LSU_R           ] = lsu_id               ;


    // Systolic Array: Accumulator Write Port
    rf_seq_waddr_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY]   = sa_res_waddr         ;
    rf_seq_wrowaddr_from_fu[quadrilatero_pkg::SYSTOLIC_ARRAY]   = sa_res_wrowaddr      ;
    rf_seq_wdata_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY]   = sa_res_wdata         ;
    rf_seq_we_from_fu      [quadrilatero_pkg::SYSTOLIC_ARRAY]   = sa_res_we            ;
    rf_seq_wlast_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY]   = sa_res_wlast         ;
    rf_seq_wr_id_from_fu   [quadrilatero_pkg::SYSTOLIC_ARRAY]   = sa_output_id         ;

    // LSU Write Port
    rf_seq_waddr_from_fu   [quadrilatero_pkg::LSU_W         ]   = lsu_waddr            ;
    rf_seq_wrowaddr_from_fu[quadrilatero_pkg::LSU_W         ]   = lsu_wrowaddr         ;
    rf_seq_wdata_from_fu   [quadrilatero_pkg::LSU_W         ]   = lsu_wdata            ;
    rf_seq_we_from_fu      [quadrilatero_pkg::LSU_W         ]   = lsu_we               ;
    rf_seq_wlast_from_fu   [quadrilatero_pkg::LSU_W         ]   = lsu_wlast            ;
    rf_seq_wr_id_from_fu   [quadrilatero_pkg::LSU_W         ]   = lsu_id               ;

    // RF Exec Unit Write Port
    rf_seq_waddr_from_fu   [quadrilatero_pkg::RF_W          ]   = perm_unit_waddr   ;
    rf_seq_wrowaddr_from_fu[quadrilatero_pkg::RF_W          ]   = perm_unit_wrowaddr;
    rf_seq_wdata_from_fu   [quadrilatero_pkg::RF_W          ]   = perm_unit_wdata   ;
    rf_seq_we_from_fu      [quadrilatero_pkg::RF_W          ]   = perm_unit_we      ;
    rf_seq_wlast_from_fu   [quadrilatero_pkg::RF_W          ]   = perm_unit_wlast   ;
    rf_seq_wr_id_from_fu   [quadrilatero_pkg::RF_W          ]   = perm_unit_id      ;
  end

  quadrilatero_rf_sequencer #(
      .READ_PORTS       (quadrilatero_pkg::READ_PORTS     ),
      .WRITE_PORTS      (quadrilatero_pkg::WRITE_PORTS    ),
      .N_REGS           (quadrilatero_pkg::N_REGS         ),
      .N_ROWS           (quadrilatero_pkg::N_ROWS         ),
      .RLEN             (quadrilatero_pkg::RLEN           ),
      .RF_READ_PORTS    (quadrilatero_pkg::RF_READ_PORTS  ),
      .RF_WRITE_PORTS   (quadrilatero_pkg::RF_WRITE_PORTS ),
      .N_ENTRIES        (2       )
  ) rf_seq_inst (

      .clk_i                                      ,
      .rst_ni                                     ,

      // Input from FUs
      .raddr_i           (rf_seq_raddr_from_fu   ),
      .rrowaddr_i        (rf_seq_rrowaddr_from_fu),
      .rdata_o           (rf_seq_rdata_from_fu   ),
      .rvalid_o          (rf_seq_rvalid_from_fu  ),
      .rlast_i           (rf_seq_rlast_from_fu   ),
      .rready_i          (rf_seq_rready_from_fu  ),
      .rd_id_i           (rf_seq_rd_id_from_fu   ),

      .waddr_i           (rf_seq_waddr_from_fu   ),
      .wrowaddr_i        (rf_seq_wrowaddr_from_fu),
      .wdata_i           (rf_seq_wdata_from_fu   ),
      .we_i              (rf_seq_we_from_fu      ),
      .wlast_i           (rf_seq_wlast_from_fu   ),
      .wready_o          (rf_seq_wready_from_fu  ),
      .wr_id_i           (rf_seq_wr_id_from_fu   ),

      // Outputs to RF
      .raddr_o           (rf_seq_raddr_to_rf     ),
      .rrowaddr_o        (rf_seq_rrowaddr_to_rf  ),
      .rdata_i           (rf_seq_rdata_to_rf     ),

      .waddr_o           (rf_seq_waddr_to_rf     ),
      .wrowaddr_o        (rf_seq_wrowaddr_to_rf  ),
      .wdata_o           (rf_seq_wdata_to_rf     ),
      .we_o              (rf_seq_we_to_rf        ),

      .rw_queue_entry_i  (rf_seq_rw_queue_entry  ),
      .rw_queue_push_i   (rf_seq_rw_queue_push   ),

      .rw_queue_full_o   (rf_seq_rw_queue_full   )
  );

  quadrilatero_regfile #(
      .READ_PORTS   (quadrilatero_pkg::RF_READ_PORTS ),
      .WRITE_PORTS  (quadrilatero_pkg::RF_WRITE_PORTS),
      .N_REGS       (quadrilatero_pkg::N_REGS        ),
      .RLEN         (quadrilatero_pkg::RLEN          )
  ) regfile_inst (
      .clk_i                             ,
      .rst_ni                            ,

      .raddr_i      (rf_seq_raddr_to_rf   ),
      .rrowaddr_i   (rf_seq_rrowaddr_to_rf),
      .rdata_o      (rf_seq_rdata_to_rf   ),

      .waddr_i      (rf_seq_waddr_to_rf   ),
      .wrowaddr_i   (rf_seq_wrowaddr_to_rf),
      .wdata_i      (rf_seq_wdata_to_rf   ),
      .we_i         (rf_seq_we_to_rf      )
  );


  //*******************************
  //***  SYSTOLIC ARRAY BLOCKS  ***
  //*******************************

  always_comb begin: sa_block

    // From Dispatcher
    sa_ctrl_dispatch                          = dispatcher_dispatch[quadrilatero_pkg::FU_SYSTOLIC_ARRAY];
    sa_ctrl_dispatched_instr.data_reg         = dispatcher_reg_ms1                                    ;
    sa_ctrl_dispatched_instr.weight_reg       = dispatcher_reg_ms2                                    ;
    sa_ctrl_dispatched_instr.acc_reg          = dispatcher_reg_ms3                                    ;
    sa_ctrl_dispatched_instr.id               = dispatcher_instr_id_out                               ;
    sa_ctrl_dispatched_instr.sa_ctrl.datatype = dispatcher_instr_datatype_out                         ;
    sa_ctrl_dispatched_instr.sa_ctrl.is_float = dispatcher_is_float_out                               ;

    // From Register File 
    sa_data_rdata_valid   = rf_seq_rvalid_from_fu[quadrilatero_pkg::SYSTOLIC_ARRAY_D];
    sa_weight_rdata_valid = rf_seq_rvalid_from_fu[quadrilatero_pkg::SYSTOLIC_ARRAY_W];
    sa_acc_rdata_valid    = rf_seq_rvalid_from_fu[quadrilatero_pkg::SYSTOLIC_ARRAY_A];
    sa_res_wready         = rf_seq_wready_from_fu[quadrilatero_pkg::SYSTOLIC_ARRAY  ];
    sa_data_rdata         = rf_seq_rdata_from_fu [quadrilatero_pkg::SYSTOLIC_ARRAY_D];
    sa_weight_rdata       = rf_seq_rdata_from_fu [quadrilatero_pkg::SYSTOLIC_ARRAY_W];
    sa_acc_rdata          = rf_seq_rdata_from_fu [quadrilatero_pkg::SYSTOLIC_ARRAY_A];
  end

  quadrilatero_systolic_array_controller #(
      .N_SLOTS            (2 ),
      .DATA_WIDTH         (32)
  ) sa_controller_inst (
      .clk_i                                                     ,
      .rst_ni                                                    ,

      .issue_queue_full_o (sa_ctrl_issue_queue_full             ),
      .dispatch_i         (sa_ctrl_dispatch                     ),
      .dispatched_instr_i (sa_ctrl_dispatched_instr             ),

      // To Systolic Array
      .wl_ready_i         (sa_ctrl_wl_ready & ~x_res_almost_full),  // WL stage is ready for new instruction
      .start_o            (sa_ctrl_start                        ),  // WL will start executing new instruction
      .issued_instr_o     (sa_ctrl_issued_instr                 )   // issued instruction
  );

  quadrilatero_systolic_array #(
      .MESH_WIDTH(MESH_WIDTH),
      .FPU        (FPU      )
  ) sa_inst (
      .clk_i                                                   ,
      .rst_ni                                                  ,

      .start_i                (sa_ctrl_start                  ),
      .sa_ready_o             (sa_ctrl_wl_ready               ),

      .data_reg_i             (sa_ctrl_issued_instr.data_reg  ),  // data register
      .acc_reg_i              (sa_ctrl_issued_instr.acc_reg   ),  // accumulator register
      .weight_reg_i           (sa_ctrl_issued_instr.weight_reg),  // weight register
      .id_i                   (sa_ctrl_issued_instr.id        ),  // id of instruction
      .sa_ctrl_i              (sa_ctrl_issued_instr.sa_ctrl   ),

      // Data Read Register Port 
      .data_raddr_o           (sa_data_raddr                  ),
      .data_rrowaddr_o        (sa_data_rrowaddr               ),
      .data_rdata_i           (sa_data_rdata                  ),
      .data_rdata_valid_i     (sa_data_rdata_valid            ),
      .data_rdata_ready_o     (sa_data_rdata_ready            ),  // unused
      .data_rlast_o           (sa_data_rlast                  ),

      // Weight Read Register Port
      .weight_raddr_o         (sa_weight_raddr                ),
      .weight_rrowaddr_o      (sa_weight_rrowaddr             ),
      .weight_rdata_i         (sa_weight_rdata                ),
      .weight_rdata_valid_i   (sa_weight_rdata_valid          ),
      .weight_rdata_ready_o   (sa_weight_rdata_ready          ),
      .weight_rlast_o         (sa_weight_rlast                ),

      // Accumulator Read Register Port
      .acc_raddr_o            (sa_acc_raddr                   ),
      .acc_rrowaddr_o         (sa_acc_rrowaddr                ),
      .acc_rdata_i            (sa_acc_rdata                   ),
      .acc_rdata_valid_i      (sa_acc_rdata_valid             ),
      .acc_rdata_ready_o      (sa_acc_rdata_ready             ),
      .acc_rlast_o            (sa_acc_rlast                   ),

      // Accumulator Out Write Register Port
      .res_waddr_o            (sa_res_waddr                   ),
      .res_wrowaddr_o         (sa_res_wrowaddr                ),
      .res_wdata_o            (sa_res_wdata                   ),
      .res_we_o               (sa_res_we                      ),
      .res_wlast_o            (sa_res_wlast                   ),
      .res_wready_i           (sa_res_wready                  ),

      .sa_input_id_o          (sa_input_id                    ),
      .sa_output_id_o         (sa_output_id                   ),

      .finished_o             (sa_finished                    ),
      .finished_ack_i         (sa_finished_ack                ),
      .finished_instr_id_o    (sa_finished_instr_id           )
  );
 

  //********************
  //***  LSU BLOCKS  ***
  //********************

  always_comb begin: lsu_block

    // From Dispatcher
    lsu_ctrl_dispatch                     = dispatcher_dispatch[quadrilatero_pkg::FU_LSU]                      ;
    lsu_ctrl_dispatched_instr.stride      = dispatcher_rs_out[1]                                             ;
    lsu_ctrl_dispatched_instr.addr        = dispatcher_rs_out[0]                                             ;
    lsu_ctrl_dispatched_instr.id          = dispatcher_instr_id_out                                          ;  // instruction id
    lsu_ctrl_dispatched_instr.is_store    = dispatcher_is_store_out                                          ;
    lsu_ctrl_dispatched_instr.operand_reg = (dispatcher_is_store_out) ? dispatcher_reg_ms1: dispatcher_reg_md;  // destination register

    // FIX THIS : extract from CSR
    lsu_ctrl_csr_config.n_col_bytes = quadrilatero_pkg::RLEN / 8       ;  // all bytes
    lsu_ctrl_csr_config.n_rows      = quadrilatero_pkg::MESH_WIDTH     ;  // hardcoded full matrix

    // OBI Interface signals
    lsu_data_gnt    = mem_gnt_i      ;
    lsu_data_rdata  = mem_rdata_i    ;
    lsu_data_rvalid = mem_rvalid_i   ;
    mem_req_o       = lsu_data_req   ;
    mem_we_o        = lsu_data_we    ;
    mem_be_o        = lsu_data_be    ;
    mem_addr_o      = lsu_data_addr  ;
    mem_wdata_o     = lsu_data_wdata ;

    // From Register File
    lsu_wready = rf_seq_wready_from_fu[quadrilatero_pkg::LSU_W];
    lsu_rvalid = rf_seq_rvalid_from_fu[quadrilatero_pkg::LSU_R];
    lsu_rdata  = rf_seq_rdata_from_fu [quadrilatero_pkg::LSU_R];
  end

  quadrilatero_register_lsu_controller #(
      .N_SLOTS(3)
  ) reg_loader_ctrl_inst (
      .clk_i                                              ,
      .rst_ni                                             ,

      .issue_queue_full_o   (lsu_ctrl_issue_queue_full   ),
      .dispatch_i           (lsu_ctrl_dispatch           ),
      .dispatched_instr_i   (lsu_ctrl_dispatched_instr   ),
      .csr_config_i         (lsu_ctrl_csr_config         ),  // csr matrix configuration 

      // To Register Loader
      .busy_i               (lsu_busy | x_res_almost_full),  // Load Unit busy
      .start_o              (lsu_ctrl_start              ),  // 
      .issued_instr_o       (lsu_ctrl_issued_instr       ),  // issued instruction
      .issued_instr_conf_o  (lsu_ctrl_issued_instr_conf  )    // issued instruction configuration
  );

  quadrilatero_register_lsu #(
      .BUS_WIDTH            (quadrilatero_pkg::BUS_WIDTH),
      .N_REGS               (quadrilatero_pkg::N_REGS   ),
      .N_ROWS               (quadrilatero_pkg::N_ROWS   )
  ) regloader_i (
      .clk_i                                                         ,
      .rst_ni                                                        ,

      // Data interface
      .data_req_o           (lsu_data_req                           ),
      .data_gnt_i           (lsu_data_gnt                           ),
      .data_rvalid_i        (lsu_data_rvalid                        ),

      .data_addr_o          (lsu_data_addr                          ),
      .data_we_o            (lsu_data_we                            ),
      .data_be_o            (lsu_data_be                            ),
      .data_rdata_i         (lsu_data_rdata                         ),
      .data_wdata_o         (lsu_data_wdata                         ),

      // Register Write Port for Load Unit
      .waddr_o              (lsu_waddr                              ),
      .wrowaddr_o           (lsu_wrowaddr                           ),
      .wdata_o              (lsu_wdata                              ),
      .we_o                 (lsu_we                                 ),
      .wlast_o              (lsu_wlast                              ),
      .wready_i             (lsu_wready                             ),

      // Register Read Port for Store Unit
      .raddr_o              (lsu_raddr                              ),
      .rrowaddr_o           (lsu_rrowaddr                           ),
      .rdata_i              (lsu_rdata                              ),
      .rdata_valid_i        (lsu_rvalid                             ),
      .rdata_ready_o        (lsu_rready                             ),
      .rlast_o              (lsu_rlast                              ),

      // Configuration Signals
      .stride_i             (lsu_ctrl_issued_instr.stride           ),  // stride value
      .address_i            (lsu_ctrl_issued_instr.addr             ),  // address value
      .operand_reg_i        (lsu_ctrl_issued_instr.operand_reg      ),  // destination register
      .instr_id_i           (lsu_ctrl_issued_instr.id               ),  // id of the instruction
      .start_i              (lsu_ctrl_start                         ),  // start loading
      .write_i              (lsu_ctrl_issued_instr.is_store         ),

      // Coming from CSR
      .n_bytes_cols_i       (lsu_ctrl_issued_instr_conf.n_col_bytes ),
      .n_rows_i             (lsu_ctrl_issued_instr_conf.n_rows      ),
      .busy_o               (lsu_busy                               ),
      .lsu_id_o             (lsu_id                                 ),

      // Finished instruction
      .finished_o           (lsu_finished                           ),
      .finished_ack_i       (lsu_finished_ack                       ),
      .finished_instr_id_o  (lsu_finished_instr_id                  )
  );


  //*********************
  //***  PERM BLOCK  ***
  //*********************

  always_comb begin: perm_block
    // From Dispatcher
    perm_unit_reg      = dispatcher_reg_md;
    perm_unit_instr_id = dispatcher_instr_id_out;
    perm_start         = dispatcher_dispatch[quadrilatero_pkg::FU_RF];

    // From Register File
    perm_unit_wready   = rf_seq_wready_from_fu[quadrilatero_pkg::RF_W];
  end

  quadrilatero_perm_unit #(
      .DEPTH        (2                     ),
      .RLEN         (quadrilatero_pkg::RLEN  ),
      .N_REGS       (quadrilatero_pkg::N_REGS),
      .N_ROWS       (quadrilatero_pkg::N_ROWS)
  ) perm_unit_i (
      .clk_i                                                 ,
      .rst_ni                                                ,

      // Register Write Port
      .waddr_o              (perm_unit_waddr             ),
      .wrowaddr_o           (perm_unit_wrowaddr          ),
      .wdata_o              (perm_unit_wdata             ),
      .we_o                 (perm_unit_we                ),
      .wlast_o              (perm_unit_wlast             ),
      .wready_i             (perm_unit_wready            ),

      // Configuration Signals
      .operand_reg_i        (perm_unit_reg               ),  // destination register
      .instr_id_i           (perm_unit_instr_id          ),  // id of the instruction
      .start_i              (perm_start                  ),  // start loading
      .busy_o               (perm_busy                   ),

      .id_o                 (perm_unit_id                ),
      // Finished instruction
      .finished_o           (perm_unit_finished          ),
      .finished_ack_i       (perm_unit_finished_ack      ),
      .finished_instr_id_o  (perm_unit_finished_instr_id )
  );

  
  //*********************************************
  //***  FINISH SIGNALS and RESULT INTERFACE  ***
  //*********************************************

  always_comb begin: finish_block
    // Finished Signal from Functional Units
    x_res_finished[quadrilatero_pkg::FU_SYSTOLIC_ARRAY] = sa_finished          ;
    x_res_finished[quadrilatero_pkg::FU_LSU           ] = lsu_finished         ;
    x_res_finished[quadrilatero_pkg::FU_RF            ] = perm_unit_finished   ;

    // Finished ID Signals from Functional Units
    x_res_finished_id[quadrilatero_pkg::FU_SYSTOLIC_ARRAY] = sa_finished_instr_id          ;
    x_res_finished_id[quadrilatero_pkg::FU_LSU           ] = lsu_finished_instr_id         ;
    x_res_finished_id[quadrilatero_pkg::FU_RF            ] = perm_unit_finished_instr_id   ;

    // Finished Acknowledge Signals to Functional Units
    sa_finished_ack           = x_res_finished_ack[quadrilatero_pkg::FU_SYSTOLIC_ARRAY] & ~x_res_full;
    lsu_finished_ack          = x_res_finished_ack[quadrilatero_pkg::FU_LSU           ] & ~x_res_full;
    perm_unit_finished_ack    = x_res_finished_ack[quadrilatero_pkg::FU_RF            ] & ~x_res_full;
  end

  quadrilatero_fixed_prio_arbiter #(
      .PORTS    (quadrilatero_pkg::NUM_EXEC_UNITS)
  ) res_arb_inst (
      .req_i    (x_res_finished                ),
      .grant_o  (x_res_finished_ack            )
  );

  onehot_to_bin #(
      .ONEHOT_WIDTH(quadrilatero_pkg::NUM_EXEC_UNITS)
  ) onehot2bin_res (
      .onehot      (x_res_finished_ack            ),
      .bin         (x_res_selected_fu             )
  );

  always_comb begin: result_interface_block
    // Output Buffer Signals
    x_res_data_in      = x_res_finished_id[x_res_selected_fu]                                                        ;
    x_res_push         = |x_res_finished_ack                                                                         ;
    x_res_almost_full  = x_res_usage > $clog2(RES_IF_FIFO_DEPTH)'(RES_IF_FIFO_DEPTH - quadrilatero_pkg::NUM_EXEC_UNITS);
    x_res_pop          = !x_res_empty && x_result_ready_i                                                            ;

    // Result Interface Outputs
    x_result_valid_o   = !x_res_empty  ;
    x_result_o.id      = x_res_data_out;
    x_result_o.data    = '0            ;
    x_result_o.rd      = '0            ;
    x_result_o.we      = '0            ;
    x_result_o.ecsdata = '0            ;
    x_result_o.ecswe   = '0            ;
    x_result_o.exc     = '0            ;
    x_result_o.exccode = '0            ;
    x_result_o.err     = '0            ;
    x_result_o.dbg     = '0            ;
  end

  // Results XIF interface fifo
  fifo_v3 #(
      .FALL_THROUGH(0),
      .DATA_WIDTH  (xif_pkg::X_ID_WIDTH            ),
      .DEPTH       (RES_IF_FIFO_DEPTH              ),
      .dtype       (logic [xif_pkg::X_ID_WIDTH-1:0])
  ) issue_queue_inst (
      .clk_i                                        ,
      .rst_ni                                       ,

      .flush_i     (1'b0                           ),
      .testmode_i  (1'b0                           ),

      .usage_o     (x_res_usage                    ),
      .full_o      (x_res_full                     ),
      .empty_o     (x_res_empty                    ),

      .data_i      (x_res_data_in                  ),  // data to push into the queue
      .push_i      (x_res_push                     ),  // data is valid and can be pushed to the queue
      .data_o      (x_res_data_out                 ),  // output data
      .pop_i       (x_res_pop                      )        // pop head from queue
  );

endmodule
