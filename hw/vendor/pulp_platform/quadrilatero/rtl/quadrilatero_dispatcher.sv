// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

module quadrilatero_dispatcher #(
    parameter N_REGS = 8,
    parameter NUM_EXEC_UNITS = 3
) (
    input logic clk_i,
    input logic rst_ni,

    // Outputs to RF sequencer
    // We can share the entry as we fetch 1 instruction at a time
    // NOTE: Actually maybe it's better to have more ports so that we can push all operands and not waste cycles
    // NOTE: probably the 'lost'cycles are not lost because we can directly push the instruction to the queue even while pushing the operands and they can start execution and if needed stall since no entry in the rw_queue will be found
    output quadrilatero_pkg::rw_queue_t [N_REGS-1:0] rw_queue_entry_o,
    output logic [N_REGS-1:0] rw_queue_push_o,

    // Inputs from RF Sequencer
    input logic [N_REGS-1:0] rw_queue_full_i,


    // Instruction from Decoder
    input logic [xif_pkg::X_ID_WIDTH-1:0] instr_id_i,  // id of the instruction
    input logic [xif_pkg::X_NUM_RS  -1:0][xif_pkg::X_RFR_WIDTH-1:0] rs_i,        // Register file source operands for the offloaded instruction
    input logic [xif_pkg::X_NUM_RS  -1:0]                  rs_valid_i,  // Validity of the register file source operand(s)
    input quadrilatero_pkg::datatype_t datatype_i,


    input logic [$clog2(quadrilatero_pkg::MAX_NUM_READ_OPERANDS)-1:0] n_matrix_operands_read_i,  // how many reads to RF

    // IMPORTANT: Make sure the order of pushing does not impact or deadlock
    input logic [quadrilatero_pkg::MAX_NUM_READ_OPERANDS-1:0][$clog2(N_REGS)-1:0] rf_read_regs_i,  // which registers to read from 
    input logic rf_writeback_i,  // whether we need to write to the register file
    input logic [$clog2(N_REGS)-1:0] rf_writeback_reg_i,  // which register to writeback to 
    input quadrilatero_pkg::execution_units_t exec_unit_i,  // which exec unit
    input logic is_store_i,  // store to memory operation
    input logic is_float_i,  // float to arithmetic operation

    input logic instr_valid_i,
    output logic [xif_pkg::X_ID_WIDTH-1:0] instr_id_o,  // id of the instruction out
    output logic [xif_pkg::X_NUM_RS  -1:0][xif_pkg::X_RFR_WIDTH-1:0] rs_o,        // Register file source operands for the offloaded instruction
    output logic [xif_pkg::X_NUM_RS  -1:0]                  rs_valid_o,  // Validity of the register file source operand(s)
    output quadrilatero_pkg::datatype_t datatype_o,
    output logic is_store_o,
    output logic is_float_o,


    output logic [$clog2(N_REGS)-1:0] reg_ms1_o, 
    output logic [$clog2(N_REGS)-1:0] reg_ms2_o, 
    output logic [$clog2(N_REGS)-1:0] reg_ms3_o, 
    output logic [$clog2(N_REGS)-1:0] reg_md_o ,

    // Backpressure towards Decoder
    output logic instr_ready_o,

    // Outputs towards Execution Units
    input  logic [NUM_EXEC_UNITS-1:0] issue_queue_full_i,
    output logic [NUM_EXEC_UNITS-1:0] dispatch_o


);

//------------------------------------------------------------------------------

  typedef enum logic {
    IDLE,
    PUSH_OPERANDS
  } dispatcher_state_e;

  dispatcher_state_e              state_q, state_d;
  logic                           instr_ready;
  logic                           can_issue_instr;

  logic [NUM_EXEC_UNITS-1:0]                                dispatch_d;
  logic [NUM_EXEC_UNITS-1:0]                                dispatch_q;

  logic [xif_pkg::X_ID_WIDTH-1:0]                           instr_id_d;  // id of the instruction out
  logic [xif_pkg::X_NUM_RS  -1:0][xif_pkg::X_RFR_WIDTH-1:0] rs_d      ;  // Register file source operands for the offloaded instruction
  logic [xif_pkg::X_NUM_RS  -1:0]                           rs_valid_d;  // Validity of the register file source operand(s)
  quadrilatero_pkg::datatype_t                                datatype_d;
  logic                                                     is_store_d;
  logic                                                     is_float_d;
  logic [xif_pkg::X_ID_WIDTH-1:0]                           instr_id_q;  // id of the instruction out
  logic [xif_pkg::X_NUM_RS  -1:0][xif_pkg::X_RFR_WIDTH-1:0] rs_q      ;  // Register file source operands for the offloaded instruction
  logic [xif_pkg::X_NUM_RS  -1:0]                           rs_valid_q;  // Validity of the register file source operand(s)
  quadrilatero_pkg::datatype_t                                datatype_q;
  logic                                                     is_store_q;
  logic                                                     is_float_q;
  
  logic [2:0][$clog2(N_REGS)-1:0] rreg_d    ;
  logic      [$clog2(N_REGS)-1:0] wreg_d    ;
  logic [2:0][$clog2(N_REGS)-1:0] rreg_q    ;
  logic      [$clog2(N_REGS)-1:0] wreg_q    ;
  
  logic ld_eq2  ;
  logic ld_eq3  ;
  logic ld_eqw  ;
  logic ld_full1;
  logic ld_full2;
  logic ld_full3;
  logic ld_fullw;
  logic ld_reg1 ;
  logic ld_reg2 ;
  logic ld_reg3 ;
  logic ld_regw ;

  logic push_operand1_d;
  logic push_operand2_d;
  logic push_operand3_d;
  logic push_operandw_d;
  logic push_operand1_q;
  logic push_operand2_q;
  logic push_operand3_q;
  logic push_operandw_q;

  logic back_push_op1_d;
  logic back_push_op2_d;
  logic back_push_op3_d;
  logic back_push_opw_d;
  logic back_push_op1_q;
  logic back_push_op2_q;
  logic back_push_op3_q;
  logic back_push_opw_q;

  logic reg1_valid;
  logic reg2_valid;
  logic reg3_valid;
  logic regw_valid;

  logic [N_REGS-1:0] rvalid;
  logic [N_REGS-1:0] wready;

  logic      en_cnt;
  logic      done  ;
  logic[2:0] delta ;
  logic[2:0] outstanding_op_d;
  logic[2:0] outstanding_op_q;
 

//------------------------------------------------------------------------------

  assign can_issue_instr = instr_valid_i && ~issue_queue_full_i[exec_unit_i];
  assign instr_ready     = can_issue_instr && (state_q == IDLE | done);

  always_comb begin: internal_signals_block
    reg1_valid = (push_operand1_q) ? push_operand1_q : back_push_op1_q ;
    reg2_valid = (push_operand2_q) ? push_operand2_q : back_push_op2_q ;
    reg3_valid = (push_operand3_q) ? push_operand3_q : back_push_op3_q ;
    regw_valid = (push_operandw_q) ? push_operandw_q : back_push_opw_q ;

    ld_eq2   =  (rreg_q[0] == rreg_q[1]) & (reg1_valid & reg2_valid);
    ld_eq3   = ((rreg_q[0] == rreg_q[2]) & (reg1_valid & reg3_valid) |
                (rreg_q[1] == rreg_q[2]) & (reg2_valid & reg3_valid) );
    ld_eqw   = ld_eq2 | ld_eq3;

    ld_full1 = rw_queue_full_i[rreg_q[0]];
    ld_full2 = rw_queue_full_i[rreg_q[1]];
    ld_full3 = rw_queue_full_i[rreg_q[2]];
    ld_fullw = rw_queue_full_i[wreg_q   ];

    ld_reg1  = ld_full1         ;
    ld_reg2  = ld_full2 | ld_eq2;
    ld_reg3  = ld_full3 | ld_eq3;
    ld_regw  = ld_fullw | ld_eqw;
  
    delta = 3'b0;
    for(int ii = 0; ii < N_REGS; ii++) begin
      delta += {2'b0, rw_queue_entry_o[ii].rvalid};
      delta += {2'b0, rw_queue_entry_o[ii].wready};
    end

    done  = (delta == outstanding_op_q);
  end

  always_comb begin: next_value
    rreg_d    = (instr_ready || state_q==IDLE) ? rf_read_regs_i     : rreg_q;
    wreg_d    = (instr_ready || state_q==IDLE) ? rf_writeback_reg_i : wreg_q;

    rs_d       = (instr_ready || state_q==IDLE) ? rs_i       : rs_q      ;
    rs_valid_d = (instr_ready || state_q==IDLE) ? rs_valid_i : rs_valid_q;
    instr_id_d = (instr_ready || state_q==IDLE) ? instr_id_i : instr_id_q;
    datatype_d = (instr_ready || state_q==IDLE) ? datatype_i : datatype_q;
    is_store_d = (instr_ready || state_q==IDLE) ? is_store_i : is_store_q;
    is_float_d = (instr_ready || state_q==IDLE) ? is_float_i : is_float_q;

    dispatch_d              = '0         ;
    dispatch_d[exec_unit_i] = instr_ready;

    push_operandw_d = rf_writeback_i                 & instr_ready;
    push_operand1_d = (n_matrix_operands_read_i > 0) & instr_ready;
    push_operand2_d = (n_matrix_operands_read_i > 1) & instr_ready;
    push_operand3_d = (n_matrix_operands_read_i > 2) & instr_ready;

    back_push_op1_d = ld_reg1 ? reg1_valid : 1'b0;
    back_push_op2_d = ld_reg2 ? reg2_valid : 1'b0;
    back_push_op3_d = ld_reg3 ? reg3_valid : 1'b0;
    back_push_opw_d = ld_regw ? regw_valid : 1'b0;
    
    outstanding_op_d = {1'b0,n_matrix_operands_read_i} + {2'b0, rf_writeback_i};
  end
  
  always_comb begin: rw_queue_block
    rvalid = '0;
    wready = '0;
    rvalid[rreg_q[0]] |= reg1_valid &~ ld_reg1;
    rvalid[rreg_q[1]] |= reg2_valid &~ ld_reg2;
    rvalid[rreg_q[2]] |= reg3_valid &~ ld_reg3;
    wready[wreg_q   ] = regw_valid &~ ld_regw;
    for(int ii = 0; ii < N_REGS; ii++) begin
      rw_queue_entry_o[ii].rvalid = rvalid[ii];
      rw_queue_entry_o[ii].wready = wready[ii];
      rw_queue_entry_o[ii].id     = instr_id_q;
      rw_queue_push_o [ii]        = rw_queue_entry_o[ii].rvalid | rw_queue_entry_o[ii].wready;
    end
  end

  always_comb begin: fsm_block
    en_cnt = 1'b0;
    case (state_q)
      IDLE: begin
        if (can_issue_instr) begin
          state_d = PUSH_OPERANDS;
        end else begin
          state_d = IDLE         ;  //@ loopback
        end
      end
      PUSH_OPERANDS: begin
        en_cnt = 1'b1;
        if (done && !instr_ready) begin
          state_d = IDLE;
        end else begin
          state_d = PUSH_OPERANDS         ;  //@ loopback
        end
      end
      default: state_d = IDLE;
    endcase
  end

  delta_counter #(
      .WIDTH(3),
      .STICKY_OVERFLOW(1'b0)
  ) delta_counter_i(
      .clk_i      ,
      .rst_ni     ,
      .clear_i    (1'b0)            ,      // synchronous clear
      .en_i       (en_cnt)          ,      // enable the counter
      .load_i     (instr_ready)     ,      // load a new value
      .down_i     (1'b1)            ,      // downcount, default is up
      .delta_i    (delta)           ,
      .d_i        (outstanding_op_d),
      .q_o        (outstanding_op_q),
      .overflow_o ()
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin : seq_block
    if (!rst_ni) begin
      rreg_q          <= '0;
      wreg_q          <= '0;
      dispatch_q      <= '0;
      rs_q            <= '0;
      rs_valid_q      <= '0;
      instr_id_q      <= '0;
      datatype_q      <= quadrilatero_pkg::SIZE_32;
      is_store_q      <= '0;
      is_float_q      <= '0;

      back_push_op1_q <= 1'b0;
      back_push_op2_q <= 1'b0;
      back_push_op3_q <= 1'b0;
      back_push_opw_q <= 1'b0;
      push_operand1_q <= 1'b0;
      push_operand2_q <= 1'b0;
      push_operand3_q <= 1'b0;
      push_operandw_q <= 1'b0;
      state_q         <= IDLE;
    end else begin
      rreg_q          <= rreg_d    ;
      wreg_q          <= wreg_d    ;
      dispatch_q      <= dispatch_d;
      rs_q            <= rs_d      ;
      rs_valid_q      <= rs_valid_d;
      instr_id_q      <= instr_id_d;
      datatype_q      <= datatype_d;
      is_store_q      <= is_store_d;
      is_float_q      <= is_float_d;

      back_push_op1_q <= back_push_op1_d;
      back_push_op2_q <= back_push_op2_d;
      back_push_op3_q <= back_push_op3_d;
      back_push_opw_q <= back_push_opw_d;
      push_operand1_q <= push_operand1_d;
      push_operand2_q <= push_operand2_d;
      push_operand3_q <= push_operand3_d;
      push_operandw_q <= push_operandw_d;
      state_q         <= state_d        ;
    end
  end

  // Output assignments
  assign instr_ready_o = instr_ready;
  assign dispatch_o    = dispatch_q;
  assign rs_o          = rs_q       ;
  assign rs_valid_o    = rs_valid_q ;
  assign instr_id_o    = instr_id_q ;
  assign datatype_o    = datatype_q ;
  assign is_store_o    = is_store_q ;
  assign is_float_o    = is_float_q ;

  assign reg_ms1_o     = rreg_q[0]  ; 
  assign reg_ms2_o     = rreg_q[1]  ; 
  assign reg_ms3_o     = rreg_q[2]  ; 
  assign reg_md_o      = wreg_q     ;

  // Assertions 
  if (quadrilatero_pkg::MAX_NUM_READ_OPERANDS != 3) begin
    $error(
        "[dispatcher] The quadrilatero_pkg::MAX_NUM_READ_OPERANDS needs to be 3 for the current implementation.\n"
    );
  end
endmodule
