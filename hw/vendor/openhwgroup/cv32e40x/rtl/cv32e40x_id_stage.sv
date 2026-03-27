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
// Engineer:       Renzo Andri - andrire@student.ethz.ch                      //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
//                 Michael Platzer - michael.platzer@tuwien.ac.at             //
//                                                                            //
// Design Name:    Instruction Decode Stage                                   //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decode stage of the core. It decodes the instructions      //
//                 and hosts the register file.                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_id_stage import cv32e40x_pkg::*;
#(
  parameter rv32_e       RV32                   = RV32I,
  parameter a_ext_e      A_EXT                  = A_NONE,
  parameter b_ext_e      B_EXT                  = B_NONE,
  parameter m_ext_e      M_EXT                  = M,
  parameter bit          X_EXT                  = 0,
  parameter int unsigned REGFILE_NUM_READ_PORTS = 2,
  parameter bit          CLIC                   = 1
)
(
  input  logic        clk,                    // Gated clock
  input  logic        rst_n,

  // Jumps and branches
  output logic [31:0] jmp_target_o,

  // IF/ID pipeline
  input  if_id_pipe_t if_id_pipe_i,

  // ID/EX pipeline
  output id_ex_pipe_t id_ex_pipe_o,

  // EX/WB pipeline
  input  ex_wb_pipe_t ex_wb_pipe_i,

  // Controller
  input  ctrl_byp_t   ctrl_byp_i,
  input  ctrl_fsm_t   ctrl_fsm_i,

  input  mcause_t     mcause_i,
  input  logic [JVT_ADDR_WIDTH-1:0] jvt_addr_i,

  // Register file write data from WB stage
  input  logic [31:0] rf_wdata_wb_i,

  // Register file write data from EX stage
  input  logic [31:0] rf_wdata_ex_i,

  output logic        alu_jmp_o,        // Jump (JAL, JALR)
  output logic        alu_jmpr_o,       // Jump register (JALR)

  output logic        sys_mret_insn_o,

  output logic        csr_en_raw_o,
  output csr_opcode_e csr_op_o,

  output logic        alu_en_o,
  output logic        sys_en_o,

  output logic        first_op_o,
  output logic        last_op_o,
  output logic        abort_op_o,

  // RF interface -> controller
  output logic [REGFILE_NUM_READ_PORTS-1:0] rf_re_o,
  output rf_addr_t    rf_raddr_o[REGFILE_NUM_READ_PORTS],

  // Register file
  input  rf_data_t    rf_rdata_i[REGFILE_NUM_READ_PORTS],

  // Stage ready/valid
  output logic        id_ready_o,     // ID stage is ready for new data
  output logic        id_valid_o,     // ID stage has valid (non-bubble) data for next stage
  input  logic        ex_ready_i,     // EX stage is ready for new data

  // eXtension interface
  if_xif.cpu_issue    xif_issue_if,
  output logic        xif_offloading_o
);

  // Source/Destination register instruction index
  localparam REG_S1_MSB = 19;
  localparam REG_S1_LSB = 15;

  localparam REG_S2_MSB = 24;
  localparam REG_S2_LSB = 20;

  localparam REG_S3_MSB = 31;
  localparam REG_S3_LSB = 27;

  localparam REG_D_MSB  = 11;
  localparam REG_D_LSB  = 7;

  logic [31:0] instr;
  logic [15:0] c_instr;                         // Compressed instruction

  // Register Read/Write Control
  logic [1:0]           rf_re;                  // Decoder only supports rs1, rs2
  logic                 rf_we;
  logic                 rf_we_dec;
  rf_addr_t             rf_waddr;
  logic [REGFILE_NUM_READ_PORTS-1:0] rf_illegal_raddr;

  // ALU Control
  logic                 alu_en;
  logic                 alu_bch;
  logic                 alu_jmp;
  logic                 alu_jmpr;
  alu_opcode_e          alu_operator;

  // Multiplier Control
  logic                 mul_en;                 // Multiplication is used instead of ALU
  mul_opcode_e          mul_operator;           // Multiplication operation selection
  logic [1:0]           mul_signed_mode;        // Signed mode multiplication at the output of the controller, and before the pipe registers

  // Divider control
  logic                 div_en;
  div_opcode_e          div_operator;

  // LSU
  logic                 lsu_en;
  logic                 lsu_we;
  logic [1:0]           lsu_size;
  logic                 lsu_sext;
  logic [5:0]           lsu_atop;               // Atomic memory instruction

  // CSR
  logic                 csr_en;
  logic                 csr_en_raw;
  csr_opcode_e          csr_op;

  // SYS
  logic                 sys_en;
  logic                 sys_fence_insn;
  logic                 sys_fencei_insn;
  logic                 sys_ecall_insn;
  logic                 sys_ebrk_insn;
  logic                 sys_mret_insn;
  logic                 sys_dret_insn;
  logic                 sys_wfi_insn;
  logic                 sys_wfe_insn;

  // Operands and forwarding
  logic [31:0]          operand_a;
  logic [31:0]          operand_b;
  logic [31:0]          operand_c;
  logic [31:0]          operand_a_fw;
  logic [31:0]          operand_b_fw;
  logic [31:0]          jalr_fw;
  alu_op_a_mux_e        alu_op_a_mux_sel;
  alu_op_b_mux_e        alu_op_b_mux_sel;
  op_c_mux_e            op_c_mux_sel;
  imm_a_mux_e           imm_a_mux_sel;
  imm_b_mux_e           imm_b_mux_sel;
  bch_jmp_mux_e         bch_jmp_mux_sel;

  // Immediates
  logic [31:0]          imm_a;                  // Immediate for operand A
  logic [31:0]          imm_b;                  // Immediate for operand B
  logic [31:0]          imm_i_type;
  logic [31:0]          imm_s_type;
  logic [31:0]          imm_sb_type;
  logic [31:0]          imm_u_type;
  logic [31:0]          imm_uj_type;
  logic [31:0]          imm_z_type;
  logic [31:0]          imm_ciw_type;
  logic [31:0]          imm_cl_type;

  // Branch target address
  logic [31:0]          bch_target;

  // Stall for multicycle ID instructions
  logic                 multi_cycle_id_stall;

  logic                 illegal_insn;

  // Local instruction valid qualifier
  logic                 instr_valid;

  // eXtension interface signals
  logic                 xif_en;
  logic                 xif_waiting;
  logic                 xif_insn_accept;
  logic                 xif_insn_reject;
  logic                 xif_we;
  logic                 xif_exception;
  logic                 xif_dualwrite;
  logic                 xif_loadstore;

  // Signal for detection of first operation (of two) of table jumps.
  logic                 tbljmp_first;

  // Current index for JVT instructions
  logic [7:0]           jvt_index;

  assign instr_valid = if_id_pipe_i.instr_valid && !ctrl_fsm_i.kill_id && !ctrl_fsm_i.halt_id;

  assign sys_mret_insn_o = sys_mret_insn;

  assign instr = if_id_pipe_i.instr.bus_resp.rdata;
  assign c_instr = if_id_pipe_i.compressed_instr;

  // Immediate extraction and sign extension
  assign imm_i_type   = { {20 {instr[31]}}, instr[31:20] };
  assign imm_s_type   = { {20 {instr[31]}}, instr[31:25], instr[11:7] };
  assign imm_sb_type  = { {19 {instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0 };
  assign imm_u_type   = { instr[31:12], 12'b0 };
  assign imm_uj_type  = { {12 {instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0 };

  // Immediate extraction and sign extension (compressed instructions)
  assign imm_ciw_type = { 22'b0, c_instr[10:7], c_instr[12:11], c_instr[5], c_instr[6], 2'b0 };
  assign imm_cl_type  = { 25'b0, c_instr[5], c_instr[12:10], c_instr[6], 2'b0 };

/*
  assign imm_cfldsp_type = {22'b0, c_instr[4:2], c_instr[12], c_instr[6:5], 3'b0};
  assign imm_caddi_type  = {{22{c_instr[12]}}, c_instr[12:12], c_instr[4:3], c_instr[5:5], c_instr[2:2], c_instr[6:6], 4'b0};
  assign imm_clwsp_type  = {24'b0, c_instr[3:2], c_instr[12:12], c_instr[6:4], 2'b0};
  assign imm_cld_type    = {24'b0, c_instr[6:5], c_instr[12:10], 3'b0};
  assign imm_cswsp_type  = {24'b0, c_instr[8:7], c_instr[12:9], 2'b0};
  assign imm_fsdp_type   = {24'b0, c_instr[9:7], c_instr[12:10], 2'b0};
  assign imm_csrli_type  = {26'b0, c_instr[12:12], c_instr[6:2]};
  assign imm_candi_type  = {{26{c_instr[12]}}, c_instr[12:12], c_instr[6:2]};
  assign imm_cbeq_type   = {{23{c_instr[12]}}, c_instr[12:12], c_instr[6:5], c_instr[2:2], c_instr[11:10], c_instr[4:3], 1'b0};
  assign imm_clui_type   = {{14{c_instr[12]}}, c_instr[12:12], c_instr[6:2], 12'b0};
  assign imm_clsb_type   = {28'd0, c_instr[10], c_instr[6:5], c_instr[11]};
  assign imm_clsh_type   = {27'd0, c_instr[11:10], c_instr[6:5], 1'b0};
*/



  // Immediate for CSR manipulation (zero extended)
  assign imm_z_type  = { 27'b0, instr[REG_S1_MSB:REG_S1_LSB] };

  //---------------------------------------------------------------------------
  // Source register selection
  //---------------------------------------------------------------------------
  assign rf_raddr_o[0] = instr[REG_S1_MSB:REG_S1_LSB];
  assign rf_raddr_o[1] = instr[REG_S2_MSB:REG_S2_LSB];

  // Assign rs3 address if Xif mandates three read ports
  generate
    if(REGFILE_NUM_READ_PORTS == 3) begin : gen_rs3_raddr
      assign rf_raddr_o[2] = instr[REG_S3_MSB:REG_S3_LSB];
    end
  endgenerate

  //---------------------------------------------------------------------------
  // Destination register seclection
  //---------------------------------------------------------------------------
  assign rf_waddr = instr[REG_D_MSB:REG_D_LSB];

  // Detect first half of table jumps
  assign tbljmp_first = if_id_pipe_i.instr_meta.tbljmp ? !if_id_pipe_i.last_op : 1'b0;

  //////////////////////////////////////////////////////////////////
  //      _                         _____                    _    //
  //     | |_   _ _ __ ___  _ __   |_   _|_ _ _ __ __ _  ___| |_  //
  //  _  | | | | | '_ ` _ \| '_ \    | |/ _` | '__/ _` |/ _ \ __| //
  // | |_| | |_| | | | | | | |_) |   | | (_| | | | (_| |  __/ |_  //
  //  \___/ \__,_|_| |_| |_| .__/    |_|\__,_|_|  \__, |\___|\__| //
  //                       |_|                    |___/           //
  //////////////////////////////////////////////////////////////////

  assign jvt_index = if_id_pipe_i.instr.bus_resp.rdata[19:12];

  cv32e40x_pc_target cv32e40x_pc_target_i
  (
    .bch_jmp_mux_sel_i ( bch_jmp_mux_sel ),
    .pc_id_i           ( if_id_pipe_i.pc ),
    .imm_uj_type_i     ( imm_uj_type     ),
    .imm_sb_type_i     ( imm_sb_type     ),
    .imm_i_type_i      ( imm_i_type      ),
    .jalr_fw_i         ( jalr_fw         ),
    .jvt_addr_i        ( jvt_addr_i      ),
    .jvt_index_i       ( jvt_index       ),
    .bch_target_o      ( bch_target      ),
    .jmp_target_o      ( jmp_target_o    )
  );

  ////////////////////////////////////////////////////////
  //   ___                                 _      _     //
  //  / _ \ _ __   ___ _ __ __ _ _ __   __| |    / \    //
  // | | | | '_ \ / _ \ '__/ _` | '_ \ / _` |   / _ \   //
  // | |_| | |_) |  __/ | | (_| | | | | (_| |  / ___ \  //
  //  \___/| .__/ \___|_|  \__,_|_| |_|\__,_| /_/   \_\ //
  //       |_|                                          //
  ////////////////////////////////////////////////////////

  // Operand A Mux
  always_comb begin : operand_a_mux
    case (alu_op_a_mux_sel)
      OP_A_REGA_OR_FWD:  operand_a = operand_a_fw;
      OP_A_CURRPC:       operand_a = if_id_pipe_i.pc;
      OP_A_IMM:          operand_a = imm_a;
      default:           operand_a = operand_a_fw;
    endcase; // case (alu_op_a_mux_sel)
  end

  always_comb begin : immediate_a_mux
    unique case (imm_a_mux_sel)
      IMMA_Z:      imm_a = imm_z_type;
      IMMA_ZERO:   imm_a = '0;
      default:     imm_a = '0;
    endcase
  end

  // Operand A forwarding mux
  always_comb begin : operand_a_fw_mux
    case (ctrl_byp_i.operand_a_fw_mux_sel)
      SEL_FW_EX:    operand_a_fw = rf_wdata_ex_i;
      SEL_FW_WB:    operand_a_fw = rf_wdata_wb_i;
      SEL_REGFILE:  operand_a_fw = rf_rdata_i[0];
      default:      operand_a_fw = rf_rdata_i[0];
    endcase;
  end

  always_comb begin: jalr_fw_mux
    case (ctrl_byp_i.jalr_fw_mux_sel)
      SELJ_FW_WB:   jalr_fw = ex_wb_pipe_i.rf_wdata;  // todo: This won't allow forwarding from the XIF.
      SELJ_REGFILE: jalr_fw = rf_rdata_i[0];
      default:      jalr_fw = rf_rdata_i[0];
    endcase
  end

  //////////////////////////////////////////////////////
  //   ___                                 _   ____   //
  //  / _ \ _ __   ___ _ __ __ _ _ __   __| | | __ )  //
  // | | | | '_ \ / _ \ '__/ _` | '_ \ / _` | |  _ \  //
  // | |_| | |_) |  __/ | | (_| | | | | (_| | | |_) | //
  //  \___/| .__/ \___|_|  \__,_|_| |_|\__,_| |____/  //
  //       |_|                                        //
  //////////////////////////////////////////////////////

  // Immediate Mux for operand B
  always_comb begin : immediate_b_mux
    unique case (imm_b_mux_sel)
      IMMB_I:      imm_b = imm_i_type;
      IMMB_S:      imm_b = imm_s_type;
      IMMB_U:      imm_b = imm_u_type;
      IMMB_PCINCR: imm_b = if_id_pipe_i.instr_meta.compressed ? 32'h2 : 32'h4;
      IMMB_CIW:    imm_b = imm_ciw_type;
      IMMB_CL:     imm_b = imm_cl_type;
      default:     imm_b = imm_i_type;
    endcase
  end

  // Operand B Mux
  always_comb begin : operand_b_mux
    case (alu_op_b_mux_sel)
      OP_B_REGB_OR_FWD:  operand_b = operand_b_fw;
      OP_B_IMM:          operand_b = imm_b;
      default:           operand_b = operand_b_fw;
    endcase // case (alu_op_b_mux_sel)
  end

  // Operand B forwarding mux
  always_comb begin : operand_b_fw_mux
    case (ctrl_byp_i.operand_b_fw_mux_sel)
      SEL_FW_EX:    operand_b_fw = rf_wdata_ex_i;
      SEL_FW_WB:    operand_b_fw = rf_wdata_wb_i;
      SEL_REGFILE:  operand_b_fw = rf_rdata_i[1];
      default:      operand_b_fw = rf_rdata_i[1];
    endcase;
  end

  //////////////////////////////////////////////////////
  //   ___                                 _    ____  //
  //  / _ \ _ __   ___ _ __ __ _ _ __   __| |  / ___| //
  // | | | | '_ \ / _ \ '__/ _` | '_ \ / _` | | |     //
  // | |_| | |_) |  __/ | | (_| | | | | (_| | | |___  //
  //  \___/| .__/ \___|_|  \__,_|_| |_|\__,_|  \____| //
  //       |_|                                        //
  //////////////////////////////////////////////////////

  // ALU OP C Mux
  always_comb begin : operand_c_mux
    case (op_c_mux_sel)
      OP_C_REGB_OR_FWD:  operand_c = operand_b_fw;
      OP_C_BCH:          operand_c = bch_target;
      default:           operand_c = operand_b_fw;
    endcase // case (op_c_mux_sel)
  end


  ///////////////////////////////////////////////
  //  ____  _____ ____ ___  ____  _____ ____   //
  // |  _ \| ____/ ___/ _ \|  _ \| ____|  _ \  //
  // | | | |  _|| |  | | | | | | |  _| | |_) | //
  // | |_| | |__| |__| |_| | |_| | |___|  _ <  //
  // |____/|_____\____\___/|____/|_____|_| \_\ //
  //                                           //
  ///////////////////////////////////////////////

  cv32e40x_decoder
  #(
    .RV32                            ( RV32                      ),
    .REGFILE_NUM_READ_PORTS          ( REGFILE_NUM_READ_PORTS    ),
    .A_EXT                           ( A_EXT                     ),
    .B_EXT                           ( B_EXT                     ),
    .M_EXT                           ( M_EXT                     ),
    .CLIC                            ( CLIC                      )
  )
  decoder_i
  (
    // controller related signals
    .deassert_we_i                   ( ctrl_byp_i.deassert_we    ),

    // SYS signals
    .sys_en_o                        ( sys_en                    ),
    .illegal_insn_o                  ( illegal_insn              ),
    .sys_ebrk_insn_o                 ( sys_ebrk_insn             ),
    .sys_mret_insn_o                 ( sys_mret_insn             ),
    .sys_dret_insn_o                 ( sys_dret_insn             ),
    .sys_ecall_insn_o                ( sys_ecall_insn            ),
    .sys_wfi_insn_o                  ( sys_wfi_insn              ),
    .sys_wfe_insn_o                  ( sys_wfe_insn              ),
    .sys_fence_insn_o                ( sys_fence_insn            ),
    .sys_fencei_insn_o               ( sys_fencei_insn           ),

    // from IF/ID pipeline
    .if_id_pipe_i                    ( if_id_pipe_i              ),

    // ALU
    .alu_en_o                        ( alu_en                    ),
    .alu_bch_o                       ( alu_bch                   ),
    .alu_jmp_o                       ( alu_jmp                   ),
    .alu_jmpr_o                      ( alu_jmpr                  ),
    .alu_operator_o                  ( alu_operator              ),
    .alu_op_a_mux_sel_o              ( alu_op_a_mux_sel          ),
    .alu_op_b_mux_sel_o              ( alu_op_b_mux_sel          ),

    // MUL
    .mul_en_o                        ( mul_en                    ),
    .mul_operator_o                  ( mul_operator              ),
    .mul_signed_mode_o               ( mul_signed_mode           ),

    // DIV
    .div_en_o                        ( div_en                    ),
    .div_operator_o                  ( div_operator              ),

    // CSR
    .csr_en_o                        ( csr_en                    ),
    .csr_en_raw_o                    ( csr_en_raw                ),
    .csr_op_o                        ( csr_op                    ),

    // LSU
    .lsu_en_o                        ( lsu_en                    ),
    .lsu_we_o                        ( lsu_we                    ),
    .lsu_size_o                      ( lsu_size                  ),
    .lsu_sext_o                      ( lsu_sext                  ),
    .lsu_atop_o                      ( lsu_atop                  ),

    // Register file control signals
    .rf_re_o                         ( rf_re                     ),
    .rf_we_o                         ( rf_we_dec                 ),
    .rf_raddr_i                      ( rf_raddr_o                ),
    .rf_waddr_i                      ( rf_waddr                  ),
    .rf_illegal_raddr_o              ( rf_illegal_raddr          ),

    // Mux selects
    .imm_a_mux_sel_o                 ( imm_a_mux_sel             ),
    .imm_b_mux_sel_o                 ( imm_b_mux_sel             ),
    .op_c_mux_sel_o                  ( op_c_mux_sel              ),
    .bch_jmp_mux_sel_o               ( bch_jmp_mux_sel           ),

    // From controller fsm
    .ctrl_fsm_i                      ( ctrl_fsm_i                ),

    // Table jump related signals
    .tbljmp_first_i                  ( tbljmp_first              )
  );

  // Speculatively read all source registers for illegal instr, might be required by coprocessor
  // Non-offloaded instructions will use maximum two read ports (rf_re from decoder is two bits, rf_re_o may be two or three bits wide)
  // Todo: Too conservative, causes load_use stalls on offloaded instruction when the operands may not be needed at all.
  //       issue_valid depends on halt_id (and data_rvalid) via the local instr_valid.
  //       Can issue_valid be made fast by using the registered instr_valid and only factor in kill_id and not halt_id?
  //       Maybe it is ok to have a late issue_valid, as accept signal will depend on late rs_valid anyway?
  assign rf_re_o        = illegal_insn ? '1 : REGFILE_NUM_READ_PORTS'(rf_re);

  // Register writeback is enabled either by the decoder or by the XIF
  assign rf_we          = rf_we_dec || xif_we;


  /////////////////////////////////////////////////////////////////////////////////
  //   ___ ____        _______  __  ____ ___ ____  _____ _     ___ _   _ _____   //
  //  |_ _|  _ \      | ____\ \/ / |  _ \_ _|  _ \| ____| |   |_ _| \ | | ____|  //
  //   | || | | |_____|  _|  \  /  | |_) | || |_) |  _| | |    | ||  \| |  _|    //
  //   | || |_| |_____| |___ /  \  |  __/| ||  __/| |___| |___ | || |\  | |___   //
  //  |___|____/      |_____/_/\_\ |_|  |___|_|   |_____|_____|___|_| \_|_____|  //
  //                                                                             //
  /////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk, negedge rst_n)
  begin : ID_EX_PIPE_REGISTERS
    if (rst_n == 1'b0)
    begin
      id_ex_pipe_o.instr_valid            <= 1'b0;
      id_ex_pipe_o.alu_en                 <= 1'b0;
      id_ex_pipe_o.alu_bch                <= 1'b0;
      id_ex_pipe_o.alu_jmp                <= 1'b0;
      id_ex_pipe_o.alu_operator           <= ALU_SLTU;
      id_ex_pipe_o.alu_operand_a          <= 32'b0; // todo: path from data_rdata_i through WB to id_ex_pipe_o_reg_alu_operand_a seems longer than needed (too many gates in ID)
      id_ex_pipe_o.alu_operand_b          <= 32'b0;

      id_ex_pipe_o.operand_c              <= 32'b0;

      id_ex_pipe_o.mul_en                 <= 1'b0;
      id_ex_pipe_o.mul_operator           <= MUL_M32;
      id_ex_pipe_o.mul_signed_mode        <= 2'b0;

      id_ex_pipe_o.div_en                 <= 1'b0;
      id_ex_pipe_o.div_operator           <= DIV_DIVU;

      id_ex_pipe_o.muldiv_operand_a       <= 32'b0;
      id_ex_pipe_o.muldiv_operand_b       <= 32'b0;

      id_ex_pipe_o.csr_en                 <= 1'b0;
      id_ex_pipe_o.csr_op                 <= CSR_OP_READ;

      id_ex_pipe_o.lsu_en                 <= 1'b0;
      id_ex_pipe_o.lsu_we                 <= 1'b0;
      id_ex_pipe_o.lsu_size               <= 2'b0;
      id_ex_pipe_o.lsu_sext               <= 1'b0;
      id_ex_pipe_o.lsu_atop               <= 6'b0;

      id_ex_pipe_o.sys_en                <= 1'b0;
      id_ex_pipe_o.sys_dret_insn         <= 1'b0;
      id_ex_pipe_o.sys_ebrk_insn         <= 1'b0;
      id_ex_pipe_o.sys_ecall_insn        <= 1'b0;
      id_ex_pipe_o.sys_fence_insn        <= 1'b0;
      id_ex_pipe_o.sys_fencei_insn       <= 1'b0;
      id_ex_pipe_o.sys_mret_insn         <= 1'b0;
      id_ex_pipe_o.sys_wfi_insn          <= 1'b0;
      id_ex_pipe_o.sys_wfe_insn          <= 1'b0;

      id_ex_pipe_o.xif_en                 <= 1'b0;
      id_ex_pipe_o.xif_meta               <= '0;

      id_ex_pipe_o.priv_lvl               <= PRIV_LVL_M;
      id_ex_pipe_o.illegal_insn           <= 1'b0;

      id_ex_pipe_o.rf_we                  <= 1'b0;
      id_ex_pipe_o.rf_waddr               <= '0;

        // Exceptions and debug
      id_ex_pipe_o.pc                     <= 32'b0;
      id_ex_pipe_o.instr                  <= INST_RESP_RESET_VAL;
      id_ex_pipe_o.instr_meta             <= '0;
      id_ex_pipe_o.trigger_match          <= 1'b0;

      id_ex_pipe_o.first_op               <= 1'b0;
      id_ex_pipe_o.last_op                <= 1'b0;
      id_ex_pipe_o.abort_op               <= 1'b0;
    end else begin
      // normal pipeline unstall case
      if (id_valid_o && ex_ready_i) begin
        id_ex_pipe_o.priv_lvl     <= if_id_pipe_i.priv_lvl;
        id_ex_pipe_o.instr_valid  <= 1'b1;
        id_ex_pipe_o.last_op      <= last_op_o;
        id_ex_pipe_o.first_op     <= first_op_o;
        id_ex_pipe_o.abort_op     <= abort_op_o;

        // Operands
        if (alu_op_a_mux_sel != OP_A_NONE) begin
          id_ex_pipe_o.alu_operand_a        <= operand_a;               // Used by most ALU, CSR and LSU instructions
        end
        if (alu_op_b_mux_sel != OP_B_NONE) begin
          id_ex_pipe_o.alu_operand_b        <= operand_b;               // Used by most ALU, CSR and LSU instructions
        end

        if (op_c_mux_sel != OP_C_NONE)
        begin
          id_ex_pipe_o.operand_c            <= operand_c;               // Used by LSU stores and some ALU instructions
        end

        id_ex_pipe_o.alu_en                 <= alu_en;
        if (alu_en) begin                                               // Branch comparison and jump link computation are done in ALU
          id_ex_pipe_o.alu_bch              <= alu_bch;
          id_ex_pipe_o.alu_jmp              <= alu_jmp;
        end
        if (alu_en || div_en) begin                                     // ALU and DIV use alu_operator (DIV uses the shifter in the ALU)
          id_ex_pipe_o.alu_operator         <= alu_operator;
        end

        id_ex_pipe_o.div_en                 <= div_en;
        if (div_en) begin
          id_ex_pipe_o.div_operator         <= div_operator;
        end

        id_ex_pipe_o.mul_en                 <= mul_en;
        if (mul_en) begin
          id_ex_pipe_o.mul_operator         <= mul_operator;
          id_ex_pipe_o.mul_signed_mode      <= mul_signed_mode;
        end

        if (mul_en || div_en) begin
          id_ex_pipe_o.muldiv_operand_a     <= operand_a_fw;            // Only register file operand (or forward) is required
          id_ex_pipe_o.muldiv_operand_b     <= operand_b_fw;            // Only register file operand (or forward) is required
        end

        id_ex_pipe_o.csr_en                 <= csr_en;
        if (csr_en) begin
          id_ex_pipe_o.csr_op               <= csr_op;
        end

        id_ex_pipe_o.lsu_en                 <= lsu_en;
        if (lsu_en) begin
          id_ex_pipe_o.lsu_we               <= lsu_we;
          id_ex_pipe_o.lsu_size             <= lsu_size;
          id_ex_pipe_o.lsu_sext             <= lsu_sext;
          id_ex_pipe_o.lsu_atop             <= lsu_atop;
        end

        // Special instructions
        id_ex_pipe_o.sys_en                 <= sys_en;
        if (sys_en) begin
          id_ex_pipe_o.sys_dret_insn        <= sys_dret_insn;
          id_ex_pipe_o.sys_ebrk_insn        <= sys_ebrk_insn;
          id_ex_pipe_o.sys_ecall_insn       <= sys_ecall_insn;
          id_ex_pipe_o.sys_fence_insn       <= sys_fence_insn;
          id_ex_pipe_o.sys_fencei_insn      <= sys_fencei_insn;
          id_ex_pipe_o.sys_mret_insn        <= sys_mret_insn;
          id_ex_pipe_o.sys_wfi_insn         <= sys_wfi_insn;
          id_ex_pipe_o.sys_wfe_insn         <= sys_wfe_insn;
        end

        id_ex_pipe_o.illegal_insn           <= illegal_insn && !xif_insn_accept;

        id_ex_pipe_o.rf_we                  <= rf_we;
        if (rf_we) begin
          id_ex_pipe_o.rf_waddr             <= rf_waddr;
        end

        // Exceptions and debug
        id_ex_pipe_o.pc                     <= if_id_pipe_i.pc;
        id_ex_pipe_o.instr_meta             <= if_id_pipe_i.instr_meta;

        if (if_id_pipe_i.instr_meta.compressed) begin
          // Overwrite instruction word in case of compressed instruction
          id_ex_pipe_o.instr.bus_resp.rdata <= {16'h0, if_id_pipe_i.compressed_instr};
          id_ex_pipe_o.instr.bus_resp.err   <= if_id_pipe_i.instr.bus_resp.err;
          id_ex_pipe_o.instr.mpu_status     <= if_id_pipe_i.instr.mpu_status;
          id_ex_pipe_o.instr.align_status   <= if_id_pipe_i.instr.align_status;
        end else begin
          id_ex_pipe_o.instr                <= if_id_pipe_i.instr;
        end

        id_ex_pipe_o.trigger_match          <= if_id_pipe_i.trigger_match;

        // eXtension interface
        id_ex_pipe_o.xif_en                 <= xif_en;
        id_ex_pipe_o.xif_meta.id            <= if_id_pipe_i.xif_id;
        id_ex_pipe_o.xif_meta.exception     <= xif_exception;
        id_ex_pipe_o.xif_meta.loadstore     <= xif_loadstore;
        id_ex_pipe_o.xif_meta.dualwrite     <= xif_dualwrite;
        id_ex_pipe_o.xif_meta.accepted      <= xif_insn_accept;

      end else if (ex_ready_i) begin
        id_ex_pipe_o.instr_valid            <= 1'b0;
      end
    end
  end

  assign alu_jmp_o    = alu_jmp;
  assign alu_jmpr_o   = alu_jmpr;

  assign csr_en_raw_o = csr_en_raw;
  assign csr_op_o = csr_op;

  assign alu_en_o     = alu_en;
  assign sys_en_o     = sys_en;

  // stall control for multicyle ID instructions (currently only misaligned LSU)
  assign multi_cycle_id_stall = 1'b0; //todo:ok Zce push/pop will use this

  // Stage ready/valid
  //
  // Most stall conditions are factored into halt_id (and will force both ready and valid to 0).
  //
  // Multi-cycle instruction related stalls are different; in that case ready will be 0 (as ID already
  // contains the instruction following the multicycle instruction.
  // todo: update when Zce is included. Currently, no multi cycle ID stalls are possible.

  assign id_ready_o = ctrl_fsm_i.kill_id || (!multi_cycle_id_stall && ex_ready_i && !ctrl_fsm_i.halt_id && !xif_waiting);

  // multi_cycle_id_stall is currently tied to 1'b0. Will be used for Zce push/pop instructions.
  assign id_valid_o = (instr_valid && !xif_waiting) || (multi_cycle_id_stall && !ctrl_fsm_i.kill_id && !ctrl_fsm_i.halt_id);

  assign first_op_o  = if_id_pipe_i.first_op;
  // An mret with mcause.minhv set and mcause.mpp = PRIV_LVL_M will cause a pointer fetch, and that pointer fetch is the last operation of the mret.
  // Mrets with the mcause conditions not true will be normal single operation instructions.
  // Using CSR signals below is safe, as any implicit or explicit CSR read in ID stage is halted if there is an implicit or explicit CSR write
  // in either EX or WB at the same time.
  assign last_op_o   = (sys_en && sys_mret_insn && mcause_i.minhv && (mcause_i.mpp == PRIV_LVL_M)) ? 1'b0 : if_id_pipe_i.last_op;
  assign abort_op_o  = if_id_pipe_i.abort_op || ctrl_byp_i.id_stage_abort;
  //---------------------------------------------------------------------------
  // eXtension interface
  //---------------------------------------------------------------------------

  generate
    if (X_EXT) begin : x_ext

      // remember whether an instruction was accepted or rejected (required if EX stage is not ready)
      // TODO: check whether this state machine should be put back in its initial state when the instruction in ID gets killed
      logic xif_accepted_q, xif_rejected_q;

      assign xif_en = xif_insn_accept || xif_insn_reject;

      always_ff @(posedge clk, negedge rst_n) begin : ID_XIF_STATE_REGISTERS
        if (rst_n == 1'b0) begin
          xif_accepted_q <= 1'b0;
          xif_rejected_q <= 1'b0;
        end else begin
          if ( (id_valid_o && ex_ready_i) || ctrl_fsm_i.kill_id ) begin
            xif_accepted_q <= 1'b0;
            xif_rejected_q <= 1'b0;
          end else begin
            xif_accepted_q <= xif_insn_accept;
            xif_rejected_q <= xif_insn_reject;
          end
        end
      end

      // attempt to offload every valid instruction that is considered illegal by the decoder
      // Also attempt to offload any CSR instruction. The validity of such instructions are only
      // checked in the EX stage.
      // Instructions with deassert_we set to 1 from the controller bypass logic will not be attempted offloaded.
      assign xif_issue_if.issue_valid     = instr_valid && (illegal_insn || csr_en) &&
                                            !(xif_accepted_q || xif_rejected_q || ctrl_byp_i.deassert_we);

      // Keep xif_offloading_o high after an offloaded instruction was accepted or rejected to get
      // a new instruction ID from the IF stage
      assign xif_offloading_o             = xif_issue_if.issue_valid || xif_accepted_q || xif_rejected_q;

      assign xif_issue_if.issue_req.instr = instr;
      assign xif_issue_if.issue_req.mode  = PRIV_LVL_M;
      assign xif_issue_if.issue_req.id    = if_id_pipe_i.xif_id;

      always_comb begin
        xif_issue_if.issue_req.rs       = '0;
        xif_issue_if.issue_req.rs_valid = '0;
        if (xif_issue_if.X_NUM_RS > 0) begin
          xif_issue_if.issue_req.rs      [0] = operand_a_fw;
          xif_issue_if.issue_req.rs_valid[0] = !rf_illegal_raddr[0];
        end
        if (xif_issue_if.X_NUM_RS > 1) begin
          xif_issue_if.issue_req.rs      [1] = operand_b_fw;
          xif_issue_if.issue_req.rs_valid[1] = !rf_illegal_raddr[1];
        end
        // TODO: implement forwarding for other operands than rs1 and rs2
        for (integer i = 2; i < xif_issue_if.X_NUM_RS && i < REGFILE_NUM_READ_PORTS; i++) begin
          xif_issue_if.issue_req.rs      [i] = rf_rdata_i[i];
          xif_issue_if.issue_req.rs_valid[i] = !rf_illegal_raddr[i];
        end
      end

      assign xif_issue_if.issue_req.ecs       = 6'b111111; // todo: hookup to related mstatus bits (for now just reporting all state as dirty)
                                                           // and make sure that instruction after ecs update sees correct bits
      assign xif_issue_if.issue_req.ecs_valid = 1'b1; // todo: needs to take into account if mstatus extension context writes are in flight
                                                      // todo: use xif_issue_if.issue_resp.ecswrite

      // need to wait if the coprocessor is not ready and has not already accepted or rejected the instruction
      assign xif_waiting = xif_issue_if.issue_valid && !xif_issue_if.issue_ready && !xif_accepted_q && !xif_rejected_q;

      // an instruction was offloaded successfully if the coprocessor accepts it (or has accepted it)
      assign xif_insn_accept = (xif_issue_if.issue_valid && xif_issue_if.issue_ready &&  xif_issue_if.issue_resp.accept) || xif_accepted_q;
      assign xif_insn_reject = (xif_issue_if.issue_valid && xif_issue_if.issue_ready && !xif_issue_if.issue_resp.accept) || xif_rejected_q;

      // TODO: These may be missed if issue_valid retracts before ID goes to EX. Need to check for sticky accept as well
      assign xif_we        = xif_issue_if.issue_valid && xif_issue_if.issue_resp.writeback;
      assign xif_exception = xif_issue_if.issue_valid && xif_issue_if.issue_resp.exc;
      assign xif_dualwrite = xif_issue_if.issue_valid && xif_issue_if.issue_resp.dualwrite;
      assign xif_loadstore = xif_issue_if.issue_valid && xif_issue_if.issue_resp.loadstore;

    end else begin : no_x_ext

      // Drive all eXtension interface signals and outputs low if X_EXT == 0
      assign xif_en                           = 1'b0;
      assign xif_waiting                      = 1'b0;
      assign xif_insn_accept                  = 1'b0;
      assign xif_insn_reject                  = 1'b0;
      assign xif_we                           = 1'b0;
      assign xif_exception                    = 1'b0;
      assign xif_dualwrite                    = 1'b0;
      assign xif_loadstore                    = 1'b0;

      assign xif_issue_if.issue_valid         = 1'b0;
      assign xif_issue_if.issue_req.instr     = '0;
      assign xif_issue_if.issue_req.mode      = '0;
      assign xif_issue_if.issue_req.id        = '0;
      assign xif_issue_if.issue_req.rs        = '0;
      assign xif_issue_if.issue_req.rs_valid  = '0;
      assign xif_issue_if.issue_req.ecs       = '0;
      assign xif_issue_if.issue_req.ecs_valid = '0;

    end
  endgenerate

endmodule
