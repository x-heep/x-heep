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
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
//                 Michael Platzer - michael.platzer@tuwien.ac.at             //
//                                                                            //
// Design Name:    Top level module                                           //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Top level module of the RISC-V core.                       //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_core import cv32e40x_pkg::*;
#(
  parameter                             LIB                                     = 0,
  parameter rv32_e                      RV32                                    = RV32I,
  parameter a_ext_e                     A_EXT                                   = A_NONE,
  parameter b_ext_e                     B_EXT                                   = B_NONE,
  parameter m_ext_e                     M_EXT                                   = M,
  parameter bit                         DEBUG                                   = 1,
  parameter logic [31:0]                DM_REGION_START                         = 32'hF0000000,
  parameter logic [31:0]                DM_REGION_END                           = 32'hF0003FFF,
  parameter int                         DBG_NUM_TRIGGERS                        = 1,
  parameter int                         PMA_NUM_REGIONS                         = 0,
  parameter pma_cfg_t                   PMA_CFG[PMA_NUM_REGIONS-1:0]            = '{default:PMA_R_DEFAULT},
  parameter bit                         CLIC                                    = 0,
  parameter int unsigned                CLIC_ID_WIDTH                           = 5,
  parameter int unsigned                CLIC_INTTHRESHBITS                      = 8,
  parameter bit                         X_EXT                                   = 0,
  parameter int unsigned                X_NUM_RS                                = 2,
  parameter int unsigned                X_ID_WIDTH                              = 4,
  parameter int unsigned                X_MEM_WIDTH                             = 32,
  parameter int unsigned                X_RFR_WIDTH                             = 32,
  parameter int unsigned                X_RFW_WIDTH                             = 32,
  parameter logic [31:0]                X_MISA                                  = 32'h00000000,
  parameter logic [1:0]                 X_ECS_XS                                = 2'b00,
  parameter int unsigned                NUM_MHPMCOUNTERS                        = 1
)
(
  // Clock and reset
  input  logic                          clk_i,
  input  logic                          rst_ni,
  input  logic                          scan_cg_en_i,   // Enable all clock gates for testing

  // Static configuration
  input  logic [31:0]                   boot_addr_i,
  input  logic [31:0]                   dm_exception_addr_i,
  input  logic [31:0]                   dm_halt_addr_i,
  input  logic [31:0]                   mhartid_i,
  input  logic  [3:0]                   mimpid_patch_i,
  input  logic [31:0]                   mtvec_addr_i,

  // Instruction memory interface
  output logic                          instr_req_o,
  input  logic                          instr_gnt_i,
  input  logic                          instr_rvalid_i,
  output logic [31:0]                   instr_addr_o,
  output logic [1:0]                    instr_memtype_o,
  output logic [2:0]                    instr_prot_o,
  output logic                          instr_dbg_o,
  input  logic [31:0]                   instr_rdata_i,
  input  logic                          instr_err_i,

  // Data memory interface
  output logic                          data_req_o,
  input  logic                          data_gnt_i,
  input  logic                          data_rvalid_i,
  output logic [31:0]                   data_addr_o,
  output logic [3:0]                    data_be_o,
  output logic                          data_we_o,
  output logic [31:0]                   data_wdata_o,
  output logic [1:0]                    data_memtype_o,
  output logic [2:0]                    data_prot_o,
  output logic                          data_dbg_o,
  output logic [5:0]                    data_atop_o,
  input  logic [31:0]                   data_rdata_i,
  input  logic                          data_err_i,
  input  logic                          data_exokay_i,

  // Cycle count
  output logic [63:0]                   mcycle_o,

  // Time input
  input  logic [63:0]                   time_i,

  // eXtension interface
  if_xif.cpu_compressed                 xif_compressed_if,
  if_xif.cpu_issue                      xif_issue_if,
  if_xif.cpu_commit                     xif_commit_if,
  if_xif.cpu_mem                        xif_mem_if,
  if_xif.cpu_mem_result                 xif_mem_result_if,
  if_xif.cpu_result                     xif_result_if,

  // Basic interrupt architecture
  input  logic [31:0]                   irq_i,

  // Event wakeup signals
  input  logic                          wu_wfe_i,   // Wait-for-event wakeup

  // CLIC interrupt architecture
  input  logic                          clic_irq_i,
  input  logic [CLIC_ID_WIDTH-1:0]      clic_irq_id_i,
  input  logic [ 7:0]                   clic_irq_level_i,
  input  logic [ 1:0]                   clic_irq_priv_i,
  input  logic                          clic_irq_shv_i,

  // Fence.i flush handshake
  output logic                          fencei_flush_req_o,
  input  logic                          fencei_flush_ack_i,

  // Debug interface
  input  logic                          debug_req_i,
  output logic                          debug_havereset_o,
  output logic                          debug_running_o,
  output logic                          debug_halted_o,
  output logic                          debug_pc_valid_o,
  output logic [31:0]                   debug_pc_o,

  // CPU control signals
  input  logic                          fetch_enable_i,
  output logic                          core_sleep_o
);

  // Number of register file read ports
  // Core will only use two, but X_EXT may mandate 2 or 3
  localparam int unsigned REGFILE_NUM_READ_PORTS = X_EXT ? X_NUM_RS : 2;

  // Zc is always present
  localparam bit ZC_EXT = 1;

  // Determine alignedness of mtvt
  // mtvt[31:N] holds mtvt table entry
  // mtvt[N-1:0] is tied to zero.
  localparam int unsigned MTVT_LSB = ((CLIC_ID_WIDTH + 2) < 6) ? 6 : (CLIC_ID_WIDTH + 2);
  localparam int unsigned MTVT_ADDR_WIDTH = 32 - MTVT_LSB;

  logic         clk;                    // Gated clock
  logic         fetch_enable;

  logic [31:0]  pc_if;                  // Program counter in IF stage
  logic         ptr_in_if;              // IF stage contains a pointer
  privlvl_t     priv_lvl_if;            // IF stage privilege level

  // Jump and branch target and decision (EX->IF)
  logic [31:0] jump_target_id;
  logic [31:0] branch_target_ex;
  logic        branch_decision_ex;

  // Busy signals
  logic        if_busy;
  logic        lsu_busy;       // LSU is busy, outstanding OBI or new transaction being initiated
  logic        lsu_bus_busy;   // LSU has outstanding transactions on the OBI bus
  logic        lsu_interruptible;

  // ID/EX pipeline
  id_ex_pipe_t id_ex_pipe;

  // EX/WB pipeline
  ex_wb_pipe_t ex_wb_pipe;

  // IF/ID pipeline
  if_id_pipe_t if_id_pipe;

  // Controller
  ctrl_byp_t   ctrl_byp;
  ctrl_fsm_t   ctrl_fsm;

  // Gated debug_req_i signal depending on DEBUG parameter
  logic        debug_req_gated;

  // Register File Write Back
  logic        rf_we_wb;
  rf_addr_t    rf_waddr_wb;
  logic [31:0] rf_wdata_wb;

  // Forwarding RF from EX
  logic [31:0] rf_wdata_ex;

  // Detect last_op
  logic        last_op_if;
  logic        last_op_id;
  logic        last_op_ex;
  logic        last_op_wb;

  // Abort_op bits
  logic        abort_op_if;
  logic        abort_op_id;
  logic        abort_op_wb;

  // First op bits
  logic        first_op_if;
  logic        first_op_id;
  logic        first_op_ex;

  // Register file signals from ID/decoder to controller
  logic [REGFILE_NUM_READ_PORTS-1:0] rf_re_id;
  rf_addr_t    rf_raddr_id[REGFILE_NUM_READ_PORTS];

  // Register file read data
  rf_data_t    rf_rdata_id[REGFILE_NUM_READ_PORTS];

  // Register file write interface
  rf_addr_t    rf_waddr[REGFILE_NUM_WRITE_PORTS];
  rf_data_t    rf_wdata[REGFILE_NUM_WRITE_PORTS];
  logic        rf_we   [REGFILE_NUM_WRITE_PORTS];

  // CSR control
  logic [24:0] mtvec_addr;
  logic [1:0]  mtvec_mode;

  // JVT
  logic [JVT_ADDR_WIDTH-1:0]  jvt_addr;
  logic [5:0]                 jvt_mode;

  logic [MTVT_ADDR_WIDTH-1:0] mtvt_addr;

  logic [7:0]  mintthresh;
  mintstatus_t mintstatus;

  mcause_t     mcause;

  logic [31:0] csr_rdata;
  logic csr_counter_read;
  logic csr_wr_in_wb_flush;
  logic csr_irq_enable_write;

  privlvl_t     priv_lvl;

  logic         csr_mnxti_read;

  // CLIC signals for returning pointer addresses
  // when mnxti is accessed
  logic        csr_clic_pa_valid;   // A CSR access to mnxti has a valid ponter address
  logic [31:0] csr_clic_pa;         // Pointer address returned by accessing mnxti

  // LSU
  logic        lsu_split_ex;
  logic        lsu_first_op_ex;
  logic        lsu_last_op_ex;
  lsu_atomic_e lsu_atomic_ex;
  mpu_status_e lsu_mpu_status_wb;
  logic        lsu_wpt_match_wb;
  align_status_e lsu_align_status_wb;
  logic [31:0] lsu_rdata_wb;
  logic [1:0]  lsu_err_wb;
  lsu_atomic_e lsu_atomic_wb;

  logic        lsu_valid_0;             // Handshake with EX
  logic        lsu_ready_ex;
  logic        lsu_valid_ex;
  logic        lsu_ready_0;

  logic        lsu_valid_1;             // Handshake with WB
  logic        lsu_ready_wb;
  logic        lsu_valid_wb;
  logic        lsu_ready_1;

  // LSU signals to trigger module
  logic [31:0] lsu_addr_ex;
  logic        lsu_we_ex;
  logic [3:0]  lsu_be_ex;

  logic        data_stall_wb;

  logic        wpt_match_wb;       // Sticky wpt_match from WB stage
  mpu_status_e mpu_status_wb;      // Sticky mpu_status from WB stage
  align_status_e align_status_wb;  // Sticky align_status from WB stage

  // Stage ready signals
  logic        id_ready;
  logic        ex_ready;
  logic        wb_ready;

  // Stage valid signals
  logic        if_valid;
  logic        id_valid;
  logic        ex_valid;
  logic        wb_valid;

  // Interrupts
  mstatus_t    mstatus;
  logic [31:0] mepc, dpc;
  logic [31:0] mie;
  logic [31:0] mip;

  // Signal from IF to init mtvec at boot time
  logic        csr_mtvec_init_if;

  // debug mode and dcsr configuration
  // From cs_registers
  dcsr_t       dcsr;

  // trigger match detected in trigger module (using IF timing)
  logic        trigger_match_if;
  // trigger match detected in trigger module (using EX/LSU timing)
  logic        trigger_match_ex;
  // trigger match detected in trigger module (using WB timing, etrigger)
  logic        etrigger_wb;

  // Controller <-> decoder
  logic        alu_jmp_id;
  logic        alu_jmpr_id;
  logic        alu_en_id;
  logic        sys_en_id;
  logic        sys_mret_insn_id;
  logic        csr_en_raw_id;
  csr_opcode_e csr_op_id;
  logic        csr_illegal;

  // CSR illegal in EX due to offloading and pipeline accept
  logic        xif_csr_error_ex;

  // irq signals
  // TODO:AB Should find a proper suffix for signals from interrupt_controller
  logic        irq_req_ctrl;
  logic [9:0]  irq_id_ctrl;
  logic        irq_wu_ctrl;

  // CLIC specific irq signals
  logic                       irq_clic_shv;
  logic [7:0]                 irq_clic_level;
  logic [1:0]                 irq_clic_priv;
  logic                       mnxti_irq_pending;
  logic [CLIC_ID_WIDTH-1:0]   mnxti_irq_id;
  logic [7:0]                 mnxti_irq_level;

  // Used (only) by verification environment
  logic        irq_ack;
  logic [9:0]  irq_id;
  logic [7:0]  irq_level;       // Only applicable if CLIC = 1
  logic [1:0]  irq_priv;        // Only applicable if CLIC = 1
  logic        irq_shv;         // Only applicable if CLIC = 1
  logic        dbg_ack;

  // eXtension interface signals
  logic        xif_offloading_id;

  // Internal OBI interfaces
  if_c_obi #(.REQ_TYPE(obi_inst_req_t), .RESP_TYPE(obi_inst_resp_t))  m_c_obi_instr_if();
  if_c_obi #(.REQ_TYPE(obi_data_req_t), .RESP_TYPE(obi_data_resp_t))  m_c_obi_data_if();

  // Connect toplevel OBI signals to internal interfaces
  assign instr_req_o                         = m_c_obi_instr_if.s_req.req;
  // Address is made word aligned late so that full address can be used in RVFI
  assign instr_addr_o                        = {m_c_obi_instr_if.req_payload.addr[31:2], 2'b0};
  assign instr_memtype_o                     = m_c_obi_instr_if.req_payload.memtype;
  assign instr_prot_o                        = m_c_obi_instr_if.req_payload.prot;
  assign instr_dbg_o                         = m_c_obi_instr_if.req_payload.dbg;
  assign m_c_obi_instr_if.s_gnt.gnt          = instr_gnt_i;
  assign m_c_obi_instr_if.s_rvalid.rvalid    = instr_rvalid_i;
  assign m_c_obi_instr_if.resp_payload.rdata = instr_rdata_i;
  assign m_c_obi_instr_if.resp_payload.err   = instr_err_i;

  assign data_req_o                          = m_c_obi_data_if.s_req.req;
  assign data_we_o                           = m_c_obi_data_if.req_payload.we;
  assign data_be_o                           = m_c_obi_data_if.req_payload.be;
  assign data_addr_o                         = m_c_obi_data_if.req_payload.addr;
  assign data_memtype_o                      = m_c_obi_data_if.req_payload.memtype;
  assign data_prot_o                         = m_c_obi_data_if.req_payload.prot;
  assign data_dbg_o                          = m_c_obi_data_if.req_payload.dbg;
  assign data_wdata_o                        = m_c_obi_data_if.req_payload.wdata;
  assign data_atop_o                         = m_c_obi_data_if.req_payload.atop;
  assign m_c_obi_data_if.s_gnt.gnt           = data_gnt_i;
  assign m_c_obi_data_if.s_rvalid.rvalid     = data_rvalid_i;
  assign m_c_obi_data_if.resp_payload.rdata  = data_rdata_i;
  assign m_c_obi_data_if.resp_payload.err    = data_err_i;
  assign m_c_obi_data_if.resp_payload.exokay = data_exokay_i;

  assign debug_havereset_o = ctrl_fsm.debug_havereset;
  assign debug_halted_o    = ctrl_fsm.debug_halted;
  assign debug_running_o   = ctrl_fsm.debug_running;
  assign debug_pc_valid_o  = ctrl_fsm.mhpmevent.minstret;
  assign debug_pc_o        = ex_wb_pipe.pc;

  // Used (only) by verification environment
  assign irq_ack   = ctrl_fsm.irq_ack;
  assign irq_id    = ctrl_fsm.irq_id;
  assign irq_level = ctrl_fsm.irq_level;
  assign irq_priv  = ctrl_fsm.irq_priv;
  assign irq_shv   = ctrl_fsm.irq_shv;
  assign dbg_ack   = ctrl_fsm.dbg_ack;

  // Gate off the internal debug_request signal if debug support is not configured.
  assign debug_req_gated = DEBUG ? debug_req_i : 1'b0;

  //////////////////////////////////////////////////////////////////////////////////////////////
  //   ____ _            _      __  __                                                   _    //
  //  / ___| | ___   ___| | __ |  \/  | __ _ _ __   __ _  __ _  ___ _ __ ___   ___ _ __ | |_  //
  // | |   | |/ _ \ / __| |/ / | |\/| |/ _` | '_ \ / _` |/ _` |/ _ \ '_ ` _ \ / _ \ '_ \| __| //
  // | |___| | (_) | (__|   <  | |  | | (_| | | | | (_| | (_| |  __/ | | | | |  __/ | | | |_  //
  //  \____|_|\___/ \___|_|\_\ |_|  |_|\__,_|_| |_|\__,_|\__, |\___|_| |_| |_|\___|_| |_|\__| //
  //                                                     |___/                                //
  //////////////////////////////////////////////////////////////////////////////////////////////

  cv32e40x_sleep_unit
  #(
    .LIB                        ( LIB                  )
  )
  sleep_unit_i
  (
    // Clock, reset interface
    .clk_ungated_i              ( clk_i                ),       // Ungated clock
    .rst_n                      ( rst_ni               ),
    .clk_gated_o                ( clk                  ),       // Gated clock
    .scan_cg_en_i               ( scan_cg_en_i         ),

    // Core sleep
    .core_sleep_o               ( core_sleep_o         ),

    // Fetch enable
    .fetch_enable_i             ( fetch_enable_i       ),
    .fetch_enable_o             ( fetch_enable         ),

    // Core status
    .if_busy_i                  ( if_busy              ),
    .lsu_busy_i                 ( lsu_busy             ),

    // Inputs from controller (including busy)
    .ctrl_fsm_i                 ( ctrl_fsm             )
  );

  //////////////////////////////////////////////////
  //   ___ _____   ____ _____  _    ____ _____    //
  //  |_ _|  ___| / ___|_   _|/ \  / ___| ____|   //
  //   | || |_    \___ \ | | / _ \| |  _|  _|     //
  //   | ||  _|    ___) || |/ ___ \ |_| | |___    //
  //  |___|_|     |____/ |_/_/   \_\____|_____|   //
  //                                              //
  //////////////////////////////////////////////////

  cv32e40x_if_stage
  #(
    .RV32                ( RV32                     ),
    .A_EXT               ( A_EXT                    ),
    .B_EXT               ( B_EXT                    ),
    .X_EXT               ( X_EXT                    ),
    .X_ID_WIDTH          ( X_ID_WIDTH               ),
    .PMA_NUM_REGIONS     ( PMA_NUM_REGIONS          ),
    .PMA_CFG             ( PMA_CFG                  ),
    .MTVT_ADDR_WIDTH     ( MTVT_ADDR_WIDTH          ),
    .CLIC                ( CLIC                     ),
    .CLIC_ID_WIDTH       ( CLIC_ID_WIDTH            ),
    .ZC_EXT              ( ZC_EXT                   ),
    .M_EXT               ( M_EXT                    ),
    .DEBUG               ( DEBUG                    ),
    .DM_REGION_START     ( DM_REGION_START          ),
    .DM_REGION_END       ( DM_REGION_END            )
  )
  if_stage_i
  (
    .clk                 ( clk                      ),
    .rst_n               ( rst_ni                   ),

    .boot_addr_i         ( boot_addr_i              ), // Boot address
    .branch_target_ex_i  ( branch_target_ex         ), // Branch target address
    .dm_exception_addr_i ( dm_exception_addr_i      ), // Debug mode exception address
    .dm_halt_addr_i      ( dm_halt_addr_i           ), // Debug mode halt address
    .dpc_i               ( dpc                      ), // Debug PC (restore upon return from debug)
    .jump_target_id_i    ( jump_target_id           ), // Jump target address
    .mepc_i              ( mepc                     ), // Exception PC (restore upon return from exception/interrupt)
    .mtvec_addr_i        ( mtvec_addr               ), // Exception/interrupt address (MSBs only)
    .mtvt_addr_i         ( mtvt_addr                ), // CLIC vector base
    .jvt_mode_i          ( jvt_mode                 ),

    .m_c_obi_instr_if    ( m_c_obi_instr_if         ), // Instruction bus interface

    .if_id_pipe_o        ( if_id_pipe               ),

    .ctrl_fsm_i          ( ctrl_fsm                 ),
    .trigger_match_i     ( trigger_match_if         ),

    .pc_if_o             ( pc_if                    ),
    .csr_mtvec_init_o    ( csr_mtvec_init_if        ),
    .if_busy_o           ( if_busy                  ),
    .ptr_in_if_o         ( ptr_in_if                ),
    .priv_lvl_if_o       ( priv_lvl_if              ),

    .first_op_o          ( first_op_if              ),
    .last_op_o           ( last_op_if               ),
    .abort_op_o          ( abort_op_if              ),

    // Pipeline handshakes
    .if_valid_o          ( if_valid                 ),
    .id_ready_i          ( id_ready                 ),

    // eXtension interface
    .xif_compressed_if   ( xif_compressed_if        ),
    .xif_offloading_id_i ( xif_offloading_id        )
  );

  /////////////////////////////////////////////////
  //   ___ ____    ____ _____  _    ____ _____   //
  //  |_ _|  _ \  / ___|_   _|/ \  / ___| ____|  //
  //   | || | | | \___ \ | | / _ \| |  _|  _|    //
  //   | || |_| |  ___) || |/ ___ \ |_| | |___   //
  //  |___|____/  |____/ |_/_/   \_\____|_____|  //
  //                                             //
  /////////////////////////////////////////////////

  cv32e40x_id_stage
  #(
    .RV32                         ( RV32                      ),
    .A_EXT                        ( A_EXT                     ),
    .B_EXT                        ( B_EXT                     ),
    .M_EXT                        ( M_EXT                     ),
    .X_EXT                        ( X_EXT                     ),
    .REGFILE_NUM_READ_PORTS       ( REGFILE_NUM_READ_PORTS    ),
    .CLIC                         ( CLIC                      )
  )
  id_stage_i
  (
    .clk                          ( clk                       ),     // Gated clock
    .rst_n                        ( rst_ni                    ),

    // Jumps and branches
    .jmp_target_o                 ( jump_target_id            ),

    // IF/ID pipeline
    .if_id_pipe_i                 ( if_id_pipe                ),

    // ID/EX pipeline
    .id_ex_pipe_o                 ( id_ex_pipe                ),

    // EX/WB pipeline
    .ex_wb_pipe_i                 ( ex_wb_pipe                ),

    // Controller
    .ctrl_byp_i                   ( ctrl_byp                  ),
    .ctrl_fsm_i                   ( ctrl_fsm                  ),

    .mcause_i                     ( mcause                    ),
    .jvt_addr_i                   ( jvt_addr                  ),

    // Register file write back and forwards
    .rf_wdata_ex_i                ( rf_wdata_ex               ),
    .rf_wdata_wb_i                ( rf_wdata_wb               ),

    .alu_jmp_o                    ( alu_jmp_id                ),
    .alu_jmpr_o                   ( alu_jmpr_id               ),
    .sys_mret_insn_o              ( sys_mret_insn_id          ),
    .csr_en_raw_o                 ( csr_en_raw_id             ),
    .csr_op_o                     ( csr_op_id                 ),
    .alu_en_o                     ( alu_en_id                 ),
    .sys_en_o                     ( sys_en_id                 ),

    .first_op_o                   ( first_op_id               ),
    .last_op_o                    ( last_op_id                ),
    .abort_op_o                   ( abort_op_id               ),

    .rf_re_o                      ( rf_re_id                  ),
    .rf_raddr_o                   ( rf_raddr_id               ),
    .rf_rdata_i                   ( rf_rdata_id               ),

    // Pipeline handshakes
    .id_ready_o                   ( id_ready                  ),
    .id_valid_o                   ( id_valid                  ),
    .ex_ready_i                   ( ex_ready                  ),

    // eXtension interface
    .xif_issue_if                 ( xif_issue_if              ),
    .xif_offloading_o             ( xif_offloading_id         )
  );

  /////////////////////////////////////////////////////
  //   _______  __  ____ _____  _    ____ _____      //
  //  | ____\ \/ / / ___|_   _|/ \  / ___| ____|     //
  //  |  _|  \  /  \___ \ | | / _ \| |  _|  _|       //
  //  | |___ /  \   ___) || |/ ___ \ |_| | |___      //
  //  |_____/_/\_\ |____/ |_/_/   \_\____|_____|     //
  //                                                 //
  /////////////////////////////////////////////////////

  cv32e40x_ex_stage
  #(
    .X_EXT                      ( X_EXT                        ),
    .B_EXT                      ( B_EXT                        ),
    .M_EXT                      ( M_EXT                        )
  )
  ex_stage_i
  (
    .clk                        ( clk                          ),
    .rst_n                      ( rst_ni                       ),

    // ID/EX pipeline
    .id_ex_pipe_i               ( id_ex_pipe                   ),

    // EX/WB pipeline
    .ex_wb_pipe_o               ( ex_wb_pipe                   ),

    // From controller FSM
    .ctrl_fsm_i                 ( ctrl_fsm                     ),

    // CSR interface
    .csr_rdata_i                ( csr_rdata                    ),
    .csr_illegal_i              ( csr_illegal                  ),
    .csr_mnxti_read_i           ( csr_mnxti_read               ),

    // Branch decision
    .branch_decision_o          ( branch_decision_ex           ),
    .branch_target_o            ( branch_target_ex             ),

    .xif_csr_error_o            ( xif_csr_error_ex             ),

    // Register file forwarding
    .rf_wdata_o                 ( rf_wdata_ex                  ),

    // LSU interface
    .lsu_valid_i                ( lsu_valid_0                  ),
    .lsu_ready_o                ( lsu_ready_ex                 ),
    .lsu_valid_o                ( lsu_valid_ex                 ),
    .lsu_ready_i                ( lsu_ready_0                  ),
    .lsu_split_i                ( lsu_split_ex                 ),
    .lsu_last_op_i              ( lsu_last_op_ex               ),
    .lsu_first_op_i             ( lsu_first_op_ex              ),

    // Pipeline handshakes
    .ex_ready_o                 ( ex_ready                     ),
    .ex_valid_o                 ( ex_valid                     ),
    .wb_ready_i                 ( wb_ready                     ),
    .last_op_o                  ( last_op_ex                   ),
    .first_op_o                 ( first_op_ex                  )
  );

  ////////////////////////////////////////////////////////////////////////////////////////
  //    _     ___    _    ____    ____ _____ ___  ____  _____   _   _ _   _ ___ _____   //
  //   | |   / _ \  / \  |  _ \  / ___|_   _/ _ \|  _ \| ____| | | | | \ | |_ _|_   _|  //
  //   | |  | | | |/ _ \ | | | | \___ \ | || | | | |_) |  _|   | | | |  \| || |  | |    //
  //   | |__| |_| / ___ \| |_| |  ___) || || |_| |  _ <| |___  | |_| | |\  || |  | |    //
  //   |_____\___/_/   \_\____/  |____/ |_| \___/|_| \_\_____|  \___/|_| \_|___| |_|    //
  //                                                                                    //
  ////////////////////////////////////////////////////////////////////////////////////////

  cv32e40x_load_store_unit
  #(
    .A_EXT                 (A_EXT               ),
    .X_EXT                 (X_EXT               ),
    .X_ID_WIDTH            (X_ID_WIDTH          ),
    .PMA_NUM_REGIONS       (PMA_NUM_REGIONS     ),
    .PMA_CFG               (PMA_CFG             ),
    .DBG_NUM_TRIGGERS      (DBG_NUM_TRIGGERS    ),
    .DEBUG                 (DEBUG               ),
    .DM_REGION_START       (DM_REGION_START     ),
    .DM_REGION_END         (DM_REGION_END       )
  )
  load_store_unit_i
  (
    .clk                   ( clk                ),
    .rst_n                 ( rst_ni             ),

    // ID/EX pipeline
    .id_ex_pipe_i          ( id_ex_pipe         ),

    // Controller
    .ctrl_fsm_i            ( ctrl_fsm           ),

    // Data OBI interface
    .m_c_obi_data_if       ( m_c_obi_data_if    ),

    // Control signals
    .busy_o                ( lsu_busy           ),
    .bus_busy_o            ( lsu_bus_busy       ),
    .interruptible_o       ( lsu_interruptible  ),

    // Trigger match
    .trigger_match_0_i     ( trigger_match_ex   ),

    // Stage 0 outputs (EX)
    .lsu_split_0_o         ( lsu_split_ex       ),
    .lsu_first_op_0_o      ( lsu_first_op_ex    ),
    .lsu_last_op_0_o       ( lsu_last_op_ex     ),
    .lsu_atomic_0_o        ( lsu_atomic_ex      ),

    // Outputs to trigger module
    .lsu_addr_o            ( lsu_addr_ex        ),
    .lsu_we_o              ( lsu_we_ex          ),
    .lsu_be_o              ( lsu_be_ex          ),

    // Stage 1 outputs (WB)
    // lsu_err_1_o has WB timing and is used by the controller. Does not go through the wb_stage, and does not have
    // any sticky bits associated with it. The sticky bits for LSU related signals within the WB stage are only needed
    // for MPU errors and watchpoint triggers. All LSU instructions that gets through the WPT and MPU will retire immediately
    // when data_rvalid arrives. data_err_i will always come from the bus.
    .lsu_err_1_o           ( lsu_err_wb         ),
    .lsu_rdata_1_o         ( lsu_rdata_wb       ),
    .lsu_mpu_status_1_o    ( lsu_mpu_status_wb  ),
    .lsu_wpt_match_1_o     ( lsu_wpt_match_wb   ),
    .lsu_align_status_1_o  ( lsu_align_status_wb),
    .lsu_atomic_1_o        ( lsu_atomic_wb      ),

    // Valid/ready
    .valid_0_i             ( lsu_valid_ex       ), // First LSU stage (EX)
    .ready_0_o             ( lsu_ready_0        ),
    .valid_0_o             ( lsu_valid_0        ),
    .ready_0_i             ( lsu_ready_ex       ),

    .valid_1_i             ( lsu_valid_wb       ), // Second LSU stage (WB)
    .ready_1_o             ( lsu_ready_1        ),
    .valid_1_o             ( lsu_valid_1        ),
    .ready_1_i             ( lsu_ready_wb       ),

    // eXtension interface
    .xif_mem_if            ( xif_mem_if         ),
    .xif_mem_result_if     ( xif_mem_result_if  )
  );

  ////////////////////////////////////////////////////////////////////////////////////////
  // Write back stage                                                                   //
  ////////////////////////////////////////////////////////////////////////////////////////

  cv32e40x_wb_stage
  #(
      .DEBUG                    ( DEBUG                        )
  )
  wb_stage_i
  (
    .clk                        ( clk                          ), // Not used in RTL; only used by assertions
    .rst_n                      ( rst_ni                       ), // Not used in RTL; only used by assertions

    // EX/WB pipeline
    .ex_wb_pipe_i               ( ex_wb_pipe                   ),

    // Controller
    .ctrl_fsm_i                 ( ctrl_fsm                     ),

    // LSU
    .lsu_rdata_i                ( lsu_rdata_wb                 ),
    .lsu_mpu_status_i           ( lsu_mpu_status_wb            ),
    .lsu_wpt_match_i            ( lsu_wpt_match_wb             ),
    .lsu_align_status_i         ( lsu_align_status_wb          ),

    // Write back to register file
    .rf_we_wb_o                 ( rf_we_wb                     ),
    .rf_waddr_wb_o              ( rf_waddr_wb                  ),
    .rf_wdata_wb_o              ( rf_wdata_wb                  ),

    // LSU handshakes
    .lsu_valid_i                ( lsu_valid_1                  ),
    .lsu_ready_o                ( lsu_ready_wb                 ),
    .lsu_valid_o                ( lsu_valid_wb                 ),
    .lsu_ready_i                ( lsu_ready_1                  ),

    .data_stall_o               ( data_stall_wb                ),

    // Valid/ready
    .wb_ready_o                 ( wb_ready                     ),
    .wb_valid_o                 ( wb_valid                     ),

    // eXtension interface
    .xif_result_if              ( xif_result_if                ),

    .wpt_match_wb_o             ( wpt_match_wb                 ),
    .mpu_status_wb_o            ( mpu_status_wb                ),
    .align_status_wb_o          ( align_status_wb              ),

    // CSR/CLIC pointer inputs
    .clic_pa_valid_i            ( csr_clic_pa_valid            ),
    .clic_pa_i                  ( csr_clic_pa                  ),

    .last_op_o                  ( last_op_wb                   ),
    .abort_op_o                 ( abort_op_wb                  )
  );

  //////////////////////////////////////
  //        ____ ____  ____           //
  //       / ___/ ___||  _ \ ___      //
  //      | |   \___ \| |_) / __|     //
  //      | |___ ___) |  _ <\__ \     //
  //       \____|____/|_| \_\___/     //
  //                                  //
  //   Control and Status Registers   //
  //////////////////////////////////////

  cv32e40x_cs_registers
  #(
    .RV32                       ( RV32                   ),
    .A_EXT                      ( A_EXT                  ),
    .M_EXT                      ( M_EXT                  ),
    .X_EXT                      ( X_EXT                  ),
    .X_MISA                     ( X_MISA                 ),
    .X_ECS_XS                   ( X_ECS_XS               ),
    .ZC_EXT                     ( ZC_EXT                 ),
    .CLIC                       ( CLIC                   ),
    .CLIC_ID_WIDTH              ( CLIC_ID_WIDTH          ),
    .CLIC_INTTHRESHBITS         ( CLIC_INTTHRESHBITS     ),
    .DEBUG                      ( DEBUG                  ),
    .DBG_NUM_TRIGGERS           ( DBG_NUM_TRIGGERS       ),
    .NUM_MHPMCOUNTERS           ( NUM_MHPMCOUNTERS       ),
    .MTVT_ADDR_WIDTH            ( MTVT_ADDR_WIDTH        )
  )
  cs_registers_i
  (
    .clk                        ( clk                    ),
    .rst_n                      ( rst_ni                 ),

    // Configuration
    .mhartid_i                  ( mhartid_i              ),
    .mimpid_patch_i             ( mimpid_patch_i         ),
    .mtvec_addr_i               ( mtvec_addr_i[31:0]     ),
    .csr_mtvec_init_i           ( csr_mtvec_init_if      ),

    // CSRs
    .dcsr_o                     ( dcsr                   ),
    .dpc_o                      ( dpc                    ),
    .jvt_addr_o                 ( jvt_addr               ),
    .jvt_mode_o                 ( jvt_mode               ),
    .mcause_o                   ( mcause                 ),
    .mcycle_o                   ( mcycle_o               ),
    .mepc_o                     ( mepc                   ),
    .mie_o                      ( mie                    ),
    .mintstatus_o               ( mintstatus             ),
    .mintthresh_o               ( mintthresh             ),
    .mstatus_o                  ( mstatus                ),
    .mtvec_addr_o               ( mtvec_addr             ),
    .mtvec_mode_o               ( mtvec_mode             ),
    .mtvt_addr_o                ( mtvt_addr              ),

    .priv_lvl_o                 ( priv_lvl               ),

    // ID/EX pipeline
    .id_ex_pipe_i               ( id_ex_pipe             ),
    .csr_illegal_o              ( csr_illegal            ),

    // EX/WB pipeline
    .ex_wb_pipe_i               ( ex_wb_pipe             ),

    // From controller_fsm
    .ctrl_fsm_i                 ( ctrl_fsm               ),

    // To controller_bypass
    .csr_counter_read_o         ( csr_counter_read       ),
    .csr_mnxti_read_o           ( csr_mnxti_read         ),
    .csr_irq_enable_write_o     ( csr_irq_enable_write   ),

    // Interface to CSRs (SRAM like)
    .csr_rdata_o                ( csr_rdata              ),

    // Interrupts
    .mip_i                      ( mip                    ),
    .mnxti_irq_pending_i        ( mnxti_irq_pending      ),
    .mnxti_irq_id_i             ( mnxti_irq_id           ),
    .mnxti_irq_level_i          ( mnxti_irq_level        ),
    .clic_pa_valid_o            ( csr_clic_pa_valid      ),
    .clic_pa_o                  ( csr_clic_pa            ),

    // Time input
    .time_i                     ( time_i                 ),

    // CSR write strobes
    .csr_wr_in_wb_flush_o       ( csr_wr_in_wb_flush     ),

    // Debug
    .trigger_match_if_o         ( trigger_match_if       ),
    .trigger_match_ex_o         ( trigger_match_ex       ),
    .etrigger_wb_o              ( etrigger_wb            ),
    .pc_if_i                    ( pc_if                  ),
    .ptr_in_if_i                ( ptr_in_if              ),
    .priv_lvl_if_i              ( priv_lvl_if            ),
    .lsu_valid_ex_i             ( lsu_valid_ex           ),
    .lsu_addr_ex_i              ( lsu_addr_ex            ),
    .lsu_we_ex_i                ( lsu_we_ex              ),
    .lsu_be_ex_i                ( lsu_be_ex              ),
    .lsu_atomic_ex_i            ( lsu_atomic_ex          )
  );

  ////////////////////////////////////////////////////////////////////
  //    ____ ___  _   _ _____ ____   ___  _     _     _____ ____    //
  //   / ___/ _ \| \ | |_   _|  _ \ / _ \| |   | |   | ____|  _ \   //
  //  | |  | | | |  \| | | | | |_) | | | | |   | |   |  _| | |_) |  //
  //  | |__| |_| | |\  | | | |  _ <| |_| | |___| |___| |___|  _ <   //
  //   \____\___/|_| \_| |_| |_| \_\\___/|_____|_____|_____|_| \_\  //
  //                                                                //
  ////////////////////////////////////////////////////////////////////

  cv32e40x_controller
  #(
    .X_EXT                          ( X_EXT                  ),
    .A_EXT                          ( A_EXT                  ),
    .REGFILE_NUM_READ_PORTS         ( REGFILE_NUM_READ_PORTS ),
    .CLIC                           ( CLIC                   ),
    .CLIC_ID_WIDTH                  ( CLIC_ID_WIDTH          ),
    .DEBUG                          ( DEBUG                  )
  )
  controller_i
  (
    .clk                            ( clk                    ),         // Gated clock
    .rst_n                          ( rst_ni                 ),

    .fetch_enable_i                 ( fetch_enable           ),

    // From ID/EX pipeline
    .id_ex_pipe_i                   ( id_ex_pipe             ),

    .csr_counter_read_i             ( csr_counter_read       ),
    .csr_mnxti_read_i               ( csr_mnxti_read         ),
    .csr_irq_enable_write_i         ( csr_irq_enable_write   ),

    // From EX/WB pipeline
    .ex_wb_pipe_i                   ( ex_wb_pipe             ),
    .mpu_status_wb_i                ( mpu_status_wb          ),
    .wpt_match_wb_i                 ( wpt_match_wb           ),
    .align_status_wb_i              ( align_status_wb        ),

    // last_op bits
    .last_op_id_i                   ( last_op_id             ),
    .last_op_ex_i                   ( last_op_ex             ),
    .last_op_wb_i                   ( last_op_wb             ),

    .abort_op_id_i                  ( abort_op_id            ),
    .abort_op_wb_i                  ( abort_op_wb            ),

    .if_valid_i                     ( if_valid               ),
    .pc_if_i                        ( pc_if                  ),
    .last_op_if_i                   ( last_op_if             ),
    .abort_op_if_i                  ( abort_op_if            ),

    // from IF/ID pipeline
    .if_id_pipe_i                   ( if_id_pipe             ),

    .alu_jmp_id_i                   ( alu_jmp_id             ),
    .alu_jmpr_id_i                  ( alu_jmpr_id            ),
    .alu_en_id_i                    ( alu_en_id              ),
    .sys_en_id_i                    ( sys_en_id              ),
    .sys_mret_id_i                  ( sys_mret_insn_id       ),
    .csr_en_raw_id_i                ( csr_en_raw_id          ),
    .csr_op_id_i                    ( csr_op_id              ),
    .first_op_id_i                  ( first_op_id            ),

    // LSU
    .data_stall_wb_i                ( data_stall_wb          ),
    .lsu_err_wb_i                   ( lsu_err_wb             ),
    .lsu_busy_i                     ( lsu_busy               ),
    .lsu_bus_busy_i                 ( lsu_bus_busy           ),
    .lsu_interruptible_i            ( lsu_interruptible      ),
    .lsu_valid_wb_i                 ( lsu_valid_wb           ),
    .lsu_atomic_ex_i                ( lsu_atomic_ex          ),
    .lsu_atomic_wb_i                ( lsu_atomic_wb          ),

    // jump/branch control
    .branch_decision_ex_i           ( branch_decision_ex     ),

    // Interrupt signals
    .irq_wu_ctrl_i                  ( irq_wu_ctrl            ),
    .irq_req_ctrl_i                 ( irq_req_ctrl           ),
    .irq_id_ctrl_i                  ( irq_id_ctrl            ),
    .irq_clic_shv_i                 ( irq_clic_shv           ),
    .irq_clic_level_i               ( irq_clic_level         ),
    .irq_clic_priv_i                ( irq_clic_priv          ),

    .wu_wfe_i                       ( wu_wfe_i               ),

    // From CSR registers
    .mtvec_mode_i                   ( mtvec_mode             ),
    .mcause_i                       ( mcause                 ),
    .mintstatus_i                   ( mintstatus             ),

    // Trigger module
    .etrigger_wb_i                  ( etrigger_wb            ),

    // CSR write strobes
    .csr_wr_in_wb_flush_i           ( csr_wr_in_wb_flush     ),

    // Debug signals
    .debug_req_i                    ( debug_req_gated        ),
    .dcsr_i                         ( dcsr                   ),

    // Register File read, write back and forwards
    .rf_re_id_i                     ( rf_re_id               ),
    .rf_raddr_id_i                  ( rf_raddr_id            ),

    // Fencei flush handshake
    .fencei_flush_ack_i             ( fencei_flush_ack_i     ),
    .fencei_flush_req_o             ( fencei_flush_req_o     ),

    // Data OBI interface
    .m_c_obi_data_if                ( m_c_obi_data_if        ),

    .id_ready_i                     ( id_ready               ),
    .id_valid_i                     ( id_valid               ),
    .ex_ready_i                     ( ex_ready               ),
    .ex_valid_i                     ( ex_valid               ),
    .wb_ready_i                     ( wb_ready               ),
    .wb_valid_i                     ( wb_valid               ),

    .ctrl_byp_o                     ( ctrl_byp               ),
    .ctrl_fsm_o                     ( ctrl_fsm               ),

    // eXtension interface
    .xif_commit_if                  ( xif_commit_if          ),
    .xif_csr_error_i                ( xif_csr_error_ex       )
  );

  ////////////////////////////////////////////////////////////////////////
  //  _____      _       _____             _             _ _            //
  // |_   _|    | |     /  __ \           | |           | | |           //
  //   | | _ __ | |_    | /  \/ ___  _ __ | |_ _ __ ___ | | | ___ _ __  //
  //   | || '_ \| __|   | |    / _ \| '_ \| __| '__/ _ \| | |/ _ \ '__| //
  //  _| || | | | |_ _  | \__/\ (_) | | | | |_| | | (_) | | |  __/ |    //
  //  \___/_| |_|\__(_)  \____/\___/|_| |_|\__|_|  \___/|_|_|\___|_|    //
  //                                                                    //
  ////////////////////////////////////////////////////////////////////////

  generate
    if (CLIC) begin : gen_clic_interrupt
      assign mip          = '0;

      cv32e40x_clic_int_controller
      #(
          .CLIC_ID_WIDTH (CLIC_ID_WIDTH)
      )
      clic_int_controller_i
      (
        .clk                  ( clk                ),
        .rst_n                ( rst_ni             ),

        // CLIC interface
        .clic_irq_i           ( clic_irq_i         ),
        .clic_irq_id_i        ( clic_irq_id_i      ),
        .clic_irq_level_i     ( clic_irq_level_i   ),
        .clic_irq_priv_i      ( clic_irq_priv_i    ),
        .clic_irq_shv_i       ( clic_irq_shv_i     ),

        // To controller
        .irq_req_ctrl_o       ( irq_req_ctrl       ),
        .irq_id_ctrl_o        ( irq_id_ctrl        ),
        .irq_wu_ctrl_o        ( irq_wu_ctrl        ),
        .irq_clic_shv_o       ( irq_clic_shv       ),
        .irq_clic_level_o     ( irq_clic_level     ),
        .irq_clic_priv_o      ( irq_clic_priv      ),

        // From cs_registers
        .mstatus_i            ( mstatus            ),
        .mintthresh_i         ( mintthresh         ),
        .mintstatus_i         ( mintstatus         ),
        .mcause_i             ( mcause             ),
        .priv_lvl_i           ( priv_lvl           ),

        // To cs_registers
        .mnxti_irq_pending_o  ( mnxti_irq_pending  ),
        .mnxti_irq_id_o       ( mnxti_irq_id       ),
        .mnxti_irq_level_o    ( mnxti_irq_level    )
      );
    end else begin : gen_basic_interrupt
      cv32e40x_int_controller
      int_controller_i
      (
        .clk                  ( clk                ),
        .rst_n                ( rst_ni             ),

        // External interrupt lines
        .irq_i                ( irq_i              ),

        // To controller
        .irq_req_ctrl_o       ( irq_req_ctrl       ),
        .irq_id_ctrl_o        ( irq_id_ctrl[4:0]   ),
        .irq_wu_ctrl_o        ( irq_wu_ctrl        ),

        // To with cs_registers
        .mie_i                ( mie                ),
        .mstatus_i            ( mstatus            ),
        .priv_lvl_i           ( priv_lvl           ),

        // To/from with cs_registers
        .mip_o                ( mip                )
      );

      // Tie off unused irq_id_ctrl bits
      assign irq_id_ctrl[9:5] = 5'b00000;

      // CLIC shv not used in basic mode
      assign irq_clic_shv = 1'b0;
      assign irq_clic_level = 8'h00;
      assign irq_clic_priv = 2'b0;

      // CLIC mnxti not used in basic mode
      assign mnxti_irq_pending = 1'b0;
      assign mnxti_irq_id      = '0;
      assign mnxti_irq_level   = '0;
    end
  endgenerate

  /////////////////////////////////////////////////////////
  //  ____  _____ ____ ___ ____ _____ _____ ____  ____   //
  // |  _ \| ____/ ___|_ _/ ___|_   _| ____|  _ \/ ___|  //
  // | |_) |  _|| |  _ | |\___ \ | | |  _| | |_) \___ \  //
  // |  _ <| |__| |_| || | ___) || | | |___|  _ < ___) | //
  // |_| \_\_____\____|___|____/ |_| |_____|_| \_\____/  //
  //                                                     //
  /////////////////////////////////////////////////////////

  // Connect register file write port(s) to regfile inputs
  assign rf_we[0]    = rf_we_wb;
  assign rf_waddr[0] = rf_waddr_wb;
  assign rf_wdata[0] = rf_wdata_wb;

  cv32e40x_register_file_wrapper
  #(
    .REGFILE_NUM_READ_PORTS       ( REGFILE_NUM_READ_PORTS ),
    .RV32                         ( RV32                   )
  )
  register_file_wrapper_i
  (
    .clk                ( clk         ),
    .rst_n              ( rst_ni      ),

    // Read ports
    .raddr_i            ( rf_raddr_id ),
    .rdata_o            ( rf_rdata_id ),

    // Write ports
    .waddr_i            ( rf_waddr    ),
    .wdata_i            ( rf_wdata    ),
    .we_i               ( rf_we       )
  );

endmodule
