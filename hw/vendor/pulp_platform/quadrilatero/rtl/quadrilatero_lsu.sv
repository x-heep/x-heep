// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

module quadrilatero_lsu #(
    parameter int unsigned FIFO_DEPTH = 4,
    parameter int unsigned DATA_WIDTH = 32

) (
    input  logic                      clk_i                       ,
    input  logic                      rst_ni                      ,

    // Bus interface
    output logic                      data_req_o                  ,
    output logic [              31:0] data_addr_o                 ,
    output logic                      data_we_o                   ,
    output logic [DATA_WIDTH/8 - 1:0] data_be_o                   ,
    output logic [    DATA_WIDTH-1:0] data_wdata_o                ,
    input  logic                      data_gnt_i                  ,
    input  logic                      data_rvalid_i               ,
    input  logic [    DATA_WIDTH-1:0] data_rdata_i                ,

    // Configuration
    input  logic                      start_i                     ,  // start transfer (MUST BE A PULSE!!!!!)
    input  logic                      write_i                     ,  // write transaction
    output logic                      busy_o                      ,  // lsu available
    output logic                      terminate_o                 ,  // lsu done

    // Address
    input  logic [              31:0] src_ptr_i                   ,  // base address
    input  logic [              31:0] stride_i                    ,  // stride to move in memory from one row to the next one
    input  logic [              31:0] rows_i                      ,  // how many rows we need to fetch
    input  logic [              31:0] cols_i                      ,

    // Output data
    output logic [    DATA_WIDTH-1:0] load_fifo_output_o          ,
    output logic                      load_fifo_valid_o           ,
    output logic                      load_fifo_data_available_o  ,
    input  logic                      load_fifo_output_pop_i      ,

    // Input data
    input  logic [    DATA_WIDTH-1:0] store_fifo_input_i          ,
    input  logic                      store_fifo_push_i           ,
    output logic                      store_fifo_space_available_o,
    output logic                      store_fifo_empty_o


);

  localparam int unsigned DEPTH           = (FIFO_DEPTH > 0) ? FIFO_DEPTH - 1     : 0;
  localparam int unsigned Addr_Fifo_Depth = (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1;
  localparam int unsigned LastFifoUsage   = DEPTH - 1;


  logic                       terminate         ;

  logic [               31:0] rows_q            ;
  logic [               31:0] rows_d            ;
  logic [               31:0] cols_q            ;
  logic [               31:0] cols_d            ;
  logic [               31:0] src_ptr_inc       ;
  logic [               31:0] addr              ;
  logic [               31:0] addr_op2          ;  
  logic [               31:0] ptr_q             ;
  logic [               31:0] ptr_d             ;

  logic                       data_in_req       ;
  logic                       data_in_we        ;
  logic [   DATA_WIDTH/8-1:0] data_in_be        ;
  logic [               31:0] data_in_addr      ;
  logic                       data_in_rvalid    ;
  logic [     DATA_WIDTH-1:0] data_in_rdata     ;

  logic [     DATA_WIDTH-1:0] load_fifo_input   ;
  logic [     DATA_WIDTH-1:0] load_fifo_data_out;
  logic                       rd_valid_q        ;
  logic                       rd_valid_d        ;
  logic [     DATA_WIDTH-1:0] rd_head_q         ;
  logic [     DATA_WIDTH-1:0] rd_head_d         ;
  logic                       data_we_q         ;
  logic                       data_we_d         ;
  logic                       rvalid            ;
  logic                       load_fifo_pop     ;
  logic                       load_fifo_push    ;
  logic [Addr_Fifo_Depth-1:0] load_fifo_usage   ;
  logic                       load_fifo_alm_full;
  logic                       load_fifo_full    ;
  logic                       load_fifo_empty   ;

  logic                       data_out_req      ;
  logic                       data_out_we       ;
  logic [   DATA_WIDTH/8-1:0] data_out_be       ;
  logic [               31:0] data_out_addr     ;
  logic                       data_out_gnt      ;
  logic [     DATA_WIDTH-1:0] data_out_wdata    ;

  logic                       store_fifo_full   ;
  logic                       store_fifo_empty  ;
  logic [     DATA_WIDTH-1:0] store_fifo_output ;
  logic                       store_fifo_pop    ;


  enum {
    LSU_READY,
    LSU_RUNNING
  }
      lsu_state_q, lsu_state_d;


  always_comb begin : FSM_block
    lsu_state_d  = lsu_state_q;

    case (lsu_state_q)
      LSU_READY: begin
        if (start_i & |cols_i & |rows_i) begin
          lsu_state_d  = LSU_RUNNING;
        end
      end
      LSU_RUNNING: begin
        if (terminate && !start_i) begin
          lsu_state_d = LSU_READY;
        end
      end
    endcase
  end
  
  always_comb begin : ctrl_block
    terminate         = (|rows_q == '0 && |cols_q == '0 && data_gnt_i && data_req_o && (lsu_state_q == LSU_RUNNING)); 
    load_fifo_valid_o = rd_valid_d;
    busy_o            = (lsu_state_q == LSU_RUNNING) & ~terminate;
    terminate_o       = terminate;
  end

  always_comb begin : addr_block
    src_ptr_inc = DATA_WIDTH / 8;
    addr_op2    = (cols_q == '0)      ? stride_i  : src_ptr_inc;
    addr        = (start_i || ((rows_q == rows_i - 1) && (cols_q == cols_i - 1)))  ? src_ptr_i : ptr_q + addr_op2;
    ptr_d       = (data_gnt_i && data_req_o) ? addr : ptr_q; 
  end

  always_comb begin : counters_block 
      rows_d = rows_q;
      cols_d = cols_q;

      if(start_i) begin
        if(data_gnt_i && data_req_o) begin
          if(cols_i > 1) begin
            rows_d = rows_i - 1;
            cols_d = cols_i - 2;
          end else if (rows_i > 1) begin
            rows_d = rows_i - 2;
            cols_d = cols_i - 1;
          end
        end else begin
          rows_d = rows_i - 1;
          cols_d = cols_i - 1;
        end
      end else if (data_gnt_i && data_req_o) begin
        if (cols_q > 0) cols_d = cols_q - 1;
        else if (rows_q > 0) begin
          cols_d = cols_i - 1;
          rows_d = rows_q - 1;
        end
      end
  end

  always_comb begin : read_obi
    data_in_req    = '0;
    data_in_we     = '0;
    data_in_be     = '0;
    data_in_addr   = '0;

    if (load_fifo_full == 1'b0 && load_fifo_alm_full == 1'b0) begin
      data_in_req  = ~write_i & (start_i | lsu_state_q == LSU_RUNNING);
      data_in_we   = 1'b0                                             ;
      data_in_be   = '1                                               ;  
      data_in_addr = addr                                             ;
    end
  end

  always_comb begin : write_obi
    data_out_req    = '0               ;
    data_out_we     = '0               ; 
    data_out_be     = '0               ;
    data_out_addr   = '0               ;
    data_out_wdata  = store_fifo_output;

    if (!store_fifo_empty) begin
      data_out_req  = start_i | lsu_state_q == LSU_RUNNING;
      // data_out_we   = 1'b1                                ;
      data_out_we   = start_i | lsu_state_q == LSU_RUNNING;
      data_out_be   = '1                                  ;   
      data_out_addr = addr                                ;
    end
  end

  always_comb begin : obi_channel_signals
    data_in_rvalid     = 1'b0          ;
    data_wdata_o       = data_out_wdata;
    data_out_gnt       = data_gnt_i    ;
    data_in_rdata      = data_rdata_i  ;

    if(store_fifo_empty) begin  // read transaction active
        data_req_o     = data_in_req   ;
        data_we_o      = data_in_we    ;
        data_be_o      = data_in_be    ;
        data_addr_o    = data_in_addr  ;
        data_in_rvalid = data_rvalid_i ;
    end else begin  // write transaction active
        data_req_o     = data_out_req  ;
        data_we_o      = data_out_we   ;
        data_be_o      = data_out_be   ;
        data_addr_o    = data_out_addr ;
    end
  end

  always_comb begin : load_fifo_block
    data_we_d          = data_gnt_i && data_req_o && data_we_o;
    rvalid             = data_in_rvalid &~ data_we_q          ;

    load_fifo_alm_full = (load_fifo_usage == LastFifoUsage[Addr_Fifo_Depth-1:0]);
    load_fifo_input    = data_in_rdata;
    load_fifo_push     = (rvalid & rd_valid_q & ~load_fifo_output_pop_i) | (rvalid & ~load_fifo_empty);
    load_fifo_pop      = load_fifo_output_pop_i & ~load_fifo_empty;

    rd_valid_d     = (rvalid & ~rd_valid_q)      ? 1'b1 :  
                     (load_fifo_output_pop_i & 
                      load_fifo_empty & ~rvalid) ? 1'b0 : rd_valid_q;

    rd_head_d      = (load_fifo_output_pop_i & load_fifo_empty & rvalid) ||
                     (rvalid & ~rd_valid_q)                                  ? load_fifo_input    :
                     (load_fifo_output_pop_i & ~load_fifo_empty)             ? load_fifo_data_out : rd_head_q;

    load_fifo_output_o         = rd_head_q ;
    load_fifo_data_available_o = rd_valid_q;
  end

  always_comb begin : store_fifo_block
    store_fifo_pop               = data_out_gnt & data_out_req;
    store_fifo_empty_o           = store_fifo_empty;
    store_fifo_space_available_o = ~store_fifo_full;
  end

  fifo_v3 #(
      .FALL_THROUGH (1'b0       ),
      .DEPTH        (DEPTH      ),
      .DATA_WIDTH   (DATA_WIDTH )
  ) load_lsu_fifo_i (
      .clk_i                             ,
      .rst_ni                            ,
      .flush_i      (1'b0               ),
      .testmode_i   (1'b0               ),

      // status flags
      .full_o       (load_fifo_full     ),
      .empty_o      (load_fifo_empty    ),
      .usage_o      (load_fifo_usage    ),

      // as long as the queue is not full we can push new data
      .data_i       (load_fifo_input    ),
      .push_i       (load_fifo_push     ),

      // as long as the queue is not empty we can pop new elements
      .data_o       (load_fifo_data_out ),
      .pop_i        (load_fifo_pop      )
  );

  fifo_v3 #(
      .DEPTH(FIFO_DEPTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) store_lsu_fifo_i (
      .clk_i                           ,
      .rst_ni                          ,
      .flush_i    (1'b0               ),
      .testmode_i (1'b0               ),
      // status flags
      .full_o     (store_fifo_full    ),
      .empty_o    (store_fifo_empty   ),
      .usage_o    (                   ),
      // as long as the queue is not full we can push new data
      .data_i     (store_fifo_input_i ),
      .push_i     (store_fifo_push_i  ),
      // as long as the queue is not empty we can pop new elements
      .data_o     (store_fifo_output  ),
      .pop_i      (store_fifo_pop     )
  );

  always_ff @(posedge clk_i, negedge rst_ni) begin : seq_block
    if (~rst_ni) begin
      lsu_state_q       <= LSU_READY;
      ptr_q             <= '0       ;
      rows_q            <= '0       ;
      cols_q            <= '0       ;
      rd_head_q         <= '0       ;
      rd_valid_q        <= '0       ;
      data_we_q         <= '0       ;
    end else begin
      lsu_state_q       <= lsu_state_d;
      ptr_q             <= ptr_d      ;
      rows_q            <= rows_d     ;
      cols_q            <= cols_d     ;
      rd_head_q         <= rd_head_d  ;
      rd_valid_q        <= rd_valid_d ;
      data_we_q         <= data_we_d  ;
    end
  end

endmodule
