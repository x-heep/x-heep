// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Matthias Baer - baermatt@student.ethz.ch                   //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Robert Balas - balasr@iis.ee.ethz.ch                       //
//                 Andrea Bettati - andrea.bettati@studenti.unipr.it          //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                                                                            //
// Design Name:    Main controller                                            //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Main CPU controller of the processor                       //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_controller import cv32e40x_pkg::*;
#(
  parameter bit          X_EXT                  = 0,
  parameter a_ext_e      A_EXT                  = A_NONE,
  parameter int unsigned REGFILE_NUM_READ_PORTS = 2,
  parameter bit          CLIC                   = 0,
  parameter int unsigned CLIC_ID_WIDTH          = 5,
  parameter bit          DEBUG                  = 1
)
(
  input  logic        clk,                        // Gated clock
  input  logic        rst_n,

  input  logic        fetch_enable_i,             // Start the decoding

  input  logic        if_valid_i,

  // From IF stage
  input  logic [31:0] pc_if_i,
  input  logic        last_op_if_i,
  input  logic        abort_op_if_i,

  // from IF/ID pipeline
  input  if_id_pipe_t if_id_pipe_i,
  input  logic        alu_jmp_id_i,               // Jump (JAL, JALR)
  input  logic        alu_jmpr_id_i,              // Jump register (JALR)
  input  logic        alu_en_id_i,
  input  logic        sys_en_id_i,
  input  logic        sys_mret_id_i,
  input  logic        csr_en_raw_id_i,
  input  csr_opcode_e csr_op_id_i,
  input  logic        first_op_id_i,
  input  logic        last_op_id_i,
  input  logic        abort_op_id_i,

  input  id_ex_pipe_t id_ex_pipe_i,

  input  ex_wb_pipe_t ex_wb_pipe_i,
  input  mpu_status_e mpu_status_wb_i,            // MPU status (WB stage)
  input  logic        wpt_match_wb_i,             // LSU watchpoint trigger in WB
  input  align_status_e align_status_wb_i,        // Aligned status (atomics and mret pointers) in WB

  // Last operation bits
  input  logic        last_op_ex_i,               // EX contains the last operation of an instruction
  input  logic        last_op_wb_i,               // WB contains the last operation of an instruction

  input  logic        abort_op_wb_i,

  // LSU
  input  logic        data_stall_wb_i,            // WB stalled by LSU
  input  logic [1:0]  lsu_err_wb_i,               // LSU bus error in WB stage
  input  logic        lsu_busy_i,                 // LSU is busy with outstanding transfers or is initiating a new transfer
  input  logic        lsu_bus_busy_i,             // LSU is busy with outstanding transfers
  input  logic        lsu_interruptible_i,        // LSU may be interrupted
  input  logic        lsu_valid_wb_i,             // LSU is valid in WB (factors in rvalid from either OBI bus or write buffer)
  input  lsu_atomic_e lsu_atomic_ex_i,
  input  lsu_atomic_e lsu_atomic_wb_i,

  // jump/branch signals
  input  logic        branch_decision_ex_i,       // branch decision signal from EX ALU

  // Interrupt Controller Signals
  input  logic        irq_req_ctrl_i,
  input  logic [9:0]  irq_id_ctrl_i,
  input  logic        irq_wu_ctrl_i,
  input  logic        irq_clic_shv_i,
  input  logic [7:0]  irq_clic_level_i,
  input  logic [1:0]  irq_clic_priv_i,

  input  logic        wu_wfe_i,

  input logic  [1:0]  mtvec_mode_i,
  input  mcause_t     mcause_i,
  input  mintstatus_t mintstatus_i,

  input  logic        etrigger_wb_i,

  input  logic        csr_wr_in_wb_flush_i,

  // Debug Signal
  input  logic        debug_req_i,
  input  dcsr_t       dcsr_i,


  // CSR raddr in ex
  input  logic        csr_counter_read_i,         // A performance counter is read in CSR (EX)
  input  logic        csr_mnxti_read_i,           // MNXTI is read in CSR (EX)

  input  logic        csr_irq_enable_write_i,     // An interrupt may be enabled by a write (WB)

  input logic [REGFILE_NUM_READ_PORTS-1:0] rf_re_id_i,
  input rf_addr_t     rf_raddr_id_i[REGFILE_NUM_READ_PORTS],

  input  logic        id_ready_i,               // ID stage is ready
  input  logic        id_valid_i,               // ID stage is done
  input  logic        ex_ready_i,               // EX stage is ready
  input  logic        ex_valid_i,               // EX stage is done
  input  logic        wb_ready_i,               // WB stage is ready
  input  logic        wb_valid_i,               // WB stage is done

  // Data OBI interface monitor
  if_c_obi.monitor    m_c_obi_data_if,

  // Outputs
  output ctrl_byp_t   ctrl_byp_o,
  output ctrl_fsm_t   ctrl_fsm_o,               // FSM outputs

  // Fencei flush handshake
  output logic        fencei_flush_req_o,
  input logic         fencei_flush_ack_i,

  // eXtension interface
  if_xif.cpu_commit   xif_commit_if,
  input               xif_csr_error_i
);

  // Main FSM and debug FSM
  cv32e40x_controller_fsm
  #(
    .X_EXT                       ( X_EXT                    ),
    .CLIC                        ( CLIC                     ),
    .CLIC_ID_WIDTH               ( CLIC_ID_WIDTH            ),
    .DEBUG                       ( DEBUG                    )
  )
  controller_fsm_i
  (
    // Clocks and reset
    .clk                         ( clk                      ),
    .rst_n                       ( rst_n                    ),

    .fetch_enable_i              ( fetch_enable_i           ),

    .ctrl_byp_i                  ( ctrl_byp_o               ),

    .if_valid_i                  ( if_valid_i               ),
    .pc_if_i                     ( pc_if_i                  ),
    .last_op_if_i                ( last_op_if_i             ),
    .abort_op_if_i               ( abort_op_if_i            ),

    // From ID stage
    .if_id_pipe_i                ( if_id_pipe_i             ),
    .id_ready_i                  ( id_ready_i               ),
    .id_valid_i                  ( id_valid_i               ),
    .alu_jmp_id_i                ( alu_jmp_id_i             ),
    .sys_mret_id_i               ( sys_mret_id_i            ),
    .alu_en_id_i                 ( alu_en_id_i              ),
    .sys_en_id_i                 ( sys_en_id_i              ),
    .first_op_id_i               ( first_op_id_i            ),
    .last_op_id_i                ( last_op_id_i             ),
    .abort_op_id_i               ( abort_op_id_i            ),

    // From EX stage
    .id_ex_pipe_i                ( id_ex_pipe_i             ),
    .branch_decision_ex_i        ( branch_decision_ex_i     ),
    .ex_ready_i                  ( ex_ready_i               ),
    .ex_valid_i                  ( ex_valid_i               ),
    .last_op_ex_i                ( last_op_ex_i             ),

    // From WB stage
    .ex_wb_pipe_i                ( ex_wb_pipe_i             ),
    .lsu_err_wb_i                ( lsu_err_wb_i             ),
    .mpu_status_wb_i             ( mpu_status_wb_i          ),
    .align_status_wb_i           ( align_status_wb_i        ),
    .data_stall_wb_i             ( data_stall_wb_i          ),
    .wb_ready_i                  ( wb_ready_i               ),
    .wb_valid_i                  ( wb_valid_i               ),
    .last_op_wb_i                ( last_op_wb_i             ),
    .abort_op_wb_i               ( abort_op_wb_i            ),
    .lsu_valid_wb_i              ( lsu_valid_wb_i           ),
    .wpt_match_wb_i              ( wpt_match_wb_i           ),

    .lsu_interruptible_i         ( lsu_interruptible_i      ),

    // CSR write strobes
    .csr_wr_in_wb_flush_i        ( csr_wr_in_wb_flush_i     ),

    // Interrupt Controller Signals
    .irq_req_ctrl_i              ( irq_req_ctrl_i           ),
    .irq_id_ctrl_i               ( irq_id_ctrl_i            ),
    .irq_wu_ctrl_i               ( irq_wu_ctrl_i            ),
    .irq_clic_shv_i              ( irq_clic_shv_i           ),
    .irq_clic_level_i            ( irq_clic_level_i         ),
    .irq_clic_priv_i             ( irq_clic_priv_i          ),

    .wu_wfe_i                    ( wu_wfe_i                 ),

    .mtvec_mode_i                ( mtvec_mode_i             ),

    .etrigger_wb_i               ( etrigger_wb_i            ),

    // Debug Signal
    .debug_req_i                 ( debug_req_i              ),
    .dcsr_i                      ( dcsr_i                   ),
    .mcause_i                    ( mcause_i                 ),
    .mintstatus_i                ( mintstatus_i             ),

    // Fencei flush handshake
    .fencei_flush_ack_i          ( fencei_flush_ack_i       ),
    .fencei_flush_req_o          ( fencei_flush_req_o       ),

    .lsu_busy_i                  ( lsu_busy_i               ),

   // Data OBI interface monitor
    .m_c_obi_data_if             ( m_c_obi_data_if          ),

    // Outputs
    .ctrl_fsm_o                  ( ctrl_fsm_o               ),

    // eXtension interface
    .xif_commit_if               ( xif_commit_if            ),
    .xif_csr_error_i             ( xif_csr_error_i          )
  );


  // Hazard/bypass/stall control instance
  cv32e40x_controller_bypass
  #(
    .REGFILE_NUM_READ_PORTS     ( REGFILE_NUM_READ_PORTS   ),
    .A_EXT                      ( A_EXT                    )
  )
  bypass_i
  (
    // From controller_fsm
    .if_id_pipe_i               ( if_id_pipe_i             ),
    .id_ex_pipe_i               ( id_ex_pipe_i             ),
    .ex_wb_pipe_i               ( ex_wb_pipe_i             ),

    // From ID
    .rf_re_id_i                 ( rf_re_id_i               ),
    .rf_raddr_id_i              ( rf_raddr_id_i            ),
    .alu_jmpr_id_i              ( alu_jmpr_id_i            ),
    .sys_mret_id_i              ( sys_mret_id_i            ),
    .csr_en_raw_id_i            ( csr_en_raw_id_i          ),
    .csr_op_id_i                ( csr_op_id_i              ),

    // From EX
    .csr_counter_read_i         ( csr_counter_read_i       ),
    .csr_mnxti_read_i           ( csr_mnxti_read_i         ),

    // From WB
    .wb_ready_i                 ( wb_ready_i               ),
    .csr_irq_enable_write_i     ( csr_irq_enable_write_i   ),

    // From LSU
    .lsu_atomic_ex_i            ( lsu_atomic_ex_i          ),
    .lsu_atomic_wb_i            ( lsu_atomic_wb_i          ),
    .lsu_bus_busy_i             ( lsu_bus_busy_i           ),

    // Outputs
    .ctrl_byp_o                 ( ctrl_byp_o               )
  );

endmodule
