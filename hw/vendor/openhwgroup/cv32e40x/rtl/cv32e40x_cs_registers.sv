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
// Engineer:       Sven Stucki - svstucki@student.ethz.ch                     //
//                                                                            //
// Additional contributions by:                                               //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Andrea Bettati - andrea.bettati@studenti.unipr.it          //
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
//                 Øivind Ekelund - oivind.ekelund@silabs.com                 //
//                                                                            //
// Design Name:    Control and Status Registers                               //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Control and Status Registers (CSRs)                        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_cs_registers import cv32e40x_pkg::*;
#(
  parameter rv32_e       RV32                 = RV32I,
  parameter a_ext_e      A_EXT                = A_NONE,
  parameter m_ext_e      M_EXT                = M,
  parameter bit          X_EXT                = 0,
  parameter logic [31:0] X_MISA               =  32'h00000000,
  parameter logic [1:0]  X_ECS_XS             =  2'b00, // todo: implement related mstatus bitfields (but only if X_EXT = 1)
  parameter bit          ZC_EXT               = 0,
  parameter bit          CLIC                 = 0,
  parameter int unsigned CLIC_ID_WIDTH        = 5,
  parameter int unsigned CLIC_INTTHRESHBITS   = 8,
  parameter int unsigned NUM_MHPMCOUNTERS     = 1,
  parameter bit          DEBUG                = 1,
  parameter int          DBG_NUM_TRIGGERS     = 1, // todo: implement support for DBG_NUM_TRIGGERS != 1
  parameter int unsigned MTVT_ADDR_WIDTH      = 26
)
(
  // Clock and Reset
  input  logic                          clk,
  input  logic                          rst_n,

  // Configuration
  input  logic [31:0]                   mhartid_i,
  input  logic  [3:0]                   mimpid_patch_i,
  input  logic [31:0]                   mtvec_addr_i,
  input  logic                          csr_mtvec_init_i,

  // CSRs
  output dcsr_t                         dcsr_o,
  output logic [31:0]                   dpc_o,
  output logic [JVT_ADDR_WIDTH-1:0]     jvt_addr_o,
  output logic [5:0]                    jvt_mode_o,
  output mcause_t                       mcause_o,
  output logic [63:0]                   mcycle_o,
  output logic [31:0]                   mepc_o,
  output logic [31:0]                   mie_o,
  output mintstatus_t                   mintstatus_o,
  output logic [7:0]                    mintthresh_o,
  output mstatus_t                      mstatus_o,
  output logic [24:0]                   mtvec_addr_o,
  output logic  [1:0]                   mtvec_mode_o,
  output logic [MTVT_ADDR_WIDTH-1:0]    mtvt_addr_o,

  output privlvl_t                      priv_lvl_o,

  // ID/EX pipeline
  input id_ex_pipe_t                    id_ex_pipe_i,
  output logic                          csr_illegal_o,

  // EX/WB pipeline
  input  ex_wb_pipe_t                   ex_wb_pipe_i,

  // From controller_fsm
  input  ctrl_fsm_t                     ctrl_fsm_i,

  // To controller_bypass
  output logic                          csr_counter_read_o,
  output logic                          csr_mnxti_read_o,

  // Interface to CSRs (SRAM like)
  output logic [31:0]                   csr_rdata_o,

  // Interrupts
  input  logic [31:0]                   mip_i,
  input  logic                          mnxti_irq_pending_i,
  input  logic [CLIC_ID_WIDTH-1:0]    mnxti_irq_id_i,
  input  logic [7:0]                    mnxti_irq_level_i,
  output logic                          clic_pa_valid_o,        // CSR read data is an address to a function pointer
  output logic [31:0]                   clic_pa_o,              // Address to CLIC function pointer
  output logic                          csr_irq_enable_write_o, // An irq enable write is being performed in WB

  // Time input
  input  logic [63:0]                   time_i,

  // CSR write strobes
  output logic                          csr_wr_in_wb_flush_o,

  // Debug
  input  logic [31:0]                   pc_if_i,
  input  logic                          ptr_in_if_i,
  input  privlvl_t                      priv_lvl_if_i,
  output logic                          trigger_match_if_o,
  output logic                          trigger_match_ex_o,
  output logic                          etrigger_wb_o,
  input  logic                          lsu_valid_ex_i,
  input  logic [31:0]                   lsu_addr_ex_i,
  input  logic                          lsu_we_ex_i,
  input  logic [3:0]                    lsu_be_ex_i,
  input  lsu_atomic_e                   lsu_atomic_ex_i
);

  localparam logic [31:0] CORE_MISA =
    (32'(A_EXT == A)      <<  0) | // A - Atomic Instructions extension
    (32'(1)               <<  2) | // C - Compressed extension
    (32'(RV32 == RV32E)   <<  4) | // E - RV32E/64E base ISA
    (32'(RV32 == RV32I)   <<  8) | // I - RV32I/64I/128I base ISA
    (32'(M_EXT == M)      << 12) | // M - Integer Multiply/Divide extension
    (32'(0)               << 20) | // U - User mode implemented
    (32'(1)               << 23) | // X - Non-standard extensions present
    (32'(MXL)             << 30);  // M-XLEN

  localparam logic [31:0] MISA_VALUE = CORE_MISA | (X_EXT ? X_MISA : 32'h0000_0000);

  // Set mask for minththresh based on number of bits implemented (CLIC_INTTHRESHBITS)
  localparam CSR_MINTTHRESH_MASK = ((2 ** CLIC_INTTHRESHBITS )-1) << (8 - CLIC_INTTHRESHBITS);

  // CSR update logic
  logic [31:0]                  csr_wdata_int;
  logic [31:0]                  csr_rdata_int;
  logic                         csr_we_int;

  csr_opcode_e                  csr_op;
  csr_num_e                     csr_waddr;
  csr_num_e                     csr_raddr;
  logic [31:0]                  csr_wdata;
  logic                         csr_en_gated;

  logic                         illegal_csr_read;                               // Current CSR cannot be read
  logic                         illegal_csr_write;                              // Current CSR cannot be written

  logic                         instr_valid;                                    // Local instr_valid

  logic                         unused_signals;

  // Interrupt control signals
  logic [31:0]                  mepc_q, mepc_n, mepc_rdata;
  logic                         mepc_we;

  // Trigger
  // Trigger CSR write enables are decoded in cs_registers, all other (WARL behavior, write data and trigger matches)
  // are handled within cv32e40x_debug_triggers
  logic [31:0]                  tselect_rdata;
  logic                         tselect_we;

  logic [31:0]                  tdata1_rdata;
  logic                         tdata1_we;

  logic [31:0]                  tdata2_rdata;
  logic                         tdata2_we;

  logic [31:0]                  tdata3_rdata;
  logic                         tdata3_we;

  logic [31:0]                  tinfo_rdata;
  logic                         tinfo_we;

  logic [31:0]                  tcontrol_rdata;
  logic                         tcontrol_we;

  // Debug
  dcsr_t                        dcsr_q, dcsr_n, dcsr_rdata;
  logic                         dcsr_we;

  logic [31:0]                  dpc_q, dpc_n, dpc_rdata;
  logic                         dpc_we;

  logic [31:0]                  dscratch0_q, dscratch0_n, dscratch0_rdata;
  logic                         dscratch0_we;

  logic [31:0]                  dscratch1_q, dscratch1_n, dscratch1_rdata;
  logic                         dscratch1_we;

  logic [31:0]                  mscratch_q, mscratch_n, mscratch_rdata;
  logic                         mscratch_we;

  jvt_t                         jvt_q, jvt_n, jvt_rdata;
  logic                         jvt_we;

  mstatus_t                     mstatus_q, mstatus_n, mstatus_rdata;
  logic                         mstatus_we;

  logic [31:0]                  mstatush_n, mstatush_rdata;                     // No CSR module instance
  logic                         mstatush_we;                                    // Not used in RTL (used by RVFI)

  logic [31:0]                  misa_n, misa_rdata;                             // No CSR module instance
  logic                         misa_we;                                        // Not used in RTL (used by RVFI)

  mcause_t                      mcause_q, mcause_n, mcause_rdata;
  logic                         mcause_we;

  mtvec_t                       mtvec_q, mtvec_n, mtvec_rdata;
  logic                         mtvec_we;

  mtvt_t                        mtvt_q, mtvt_n, mtvt_rdata;
  logic                         mtvt_we;

  logic [31:0]                  mnxti_n, mnxti_rdata;                           // No CSR module instance
  logic                         mnxti_we;

  mintstatus_t                  mintstatus_q, mintstatus_n, mintstatus_rdata;
  logic                         mintstatus_we;

  logic [31:0]                  mintthresh_q, mintthresh_n, mintthresh_rdata;
  logic                         mintthresh_we;

  logic [31:0]                  mscratchcsw_n, mscratchcsw_rdata;
  logic                         mscratchcsw_we;

  logic [31:0]                  mscratchcswl_n, mscratchcswl_rdata;
  logic                         mscratchcswl_we;

  logic [31:0]                  mip_n, mip_rdata;                               // No CSR module instance
  logic                         mip_we;                                         // Not used in RTL (used by RVFI)

  logic [31:0]                  mie_q, mie_n, mie_rdata;                        // Bits are masked according to IRQ_MASK
  logic                         mie_we;

  logic [31:0]                  mvendorid_n, mvendorid_rdata;                   // No CSR module instance
  logic                         mvendorid_we;                                   // Always 0 (MRO), not used in RTL (used by RVFI)

  logic [31:0]                  marchid_n, marchid_rdata;                       // No CSR module instance
  logic                         marchid_we;                                     // Always 0 (MRO), not used in RTL (used by RVFI)

  logic [31:0]                  mimpid_n, mimpid_rdata;                         // No CSR module instance
  logic                         mimpid_we;                                      // Always 0 (MRO), not used in RTL (used by RVFI)

  logic [31:0]                  mhartid_n, mhartid_rdata;                       // No CSR module instance
  logic                         mhartid_we;                                     // Always 0 (MRO), not used in RTL (used by RVFI)

  logic [31:0]                  mconfigptr_n, mconfigptr_rdata;                 // No CSR module instance
  logic                         mconfigptr_we;                                  // Always 0 (MRO), not used in RTL (used by RVFI)

  logic [31:0]                  mtval_n, mtval_rdata;                           // No CSR module instance
  logic                         mtval_we;                                       // Not used in RTL (used by RVFI)

  privlvl_t                     priv_lvl_n, priv_lvl_q, priv_lvl_rdata; // todo: Use the priv_* signals as much as possible as in the 40S
  logic                         priv_lvl_we;
  logic [1:0]                   priv_lvl_q_int;

  // Detect JVT writes (requires pipeline flush)
  logic                         csr_wr_in_wb;
  logic                         jvt_wr_in_wb;

  // Special we signal for aliased writes between mstatus and mcause.
  // Only used for explicit writes to either mcause or mstatus, to signal that
  // mpp and mpie of the aliased CSR should be written.
  // All implicit writes (upon taking exceptions etc) handle the aliasing by also
  // writing mcause.mpp/mpie to mstatus and vice versa.
  logic                         mcause_alias_we;
  logic                         mstatus_alias_we;


  // Performance Counter Signals
  logic [31:0] [63:0]           mhpmcounter_q;                                  // Performance counters
  logic [31:0] [63:0]           mhpmcounter_n;                                  // Performance counters next value
  logic [31:0] [63:0]           mhpmcounter_rdata;                              // Performance counters next value
  logic [31:0] [1:0]            mhpmcounter_we;                                 // Performance counters write enable
  logic [31:0] [31:0]           mhpmevent_q, mhpmevent_n, mhpmevent_rdata;      // Event enable
  logic [31:0]                  mcountinhibit_q, mcountinhibit_n, mcountinhibit_rdata; // Performance counter inhibit
  logic [NUM_HPM_EVENTS-1:0]    hpm_events;                                     // Events for performance counters
  logic [31:0] [63:0]           mhpmcounter_increment;                          // Increment of mhpmcounter_q
  logic [31:0]                  mhpmcounter_write_lower;                        // Write 32 lower bits of mhpmcounter_q
  logic [31:0]                  mhpmcounter_write_upper;                        // Write 32 upper bits mhpmcounter_q
  logic [31:0]                  mhpmcounter_write_increment;                    // Write increment of mhpmcounter_q

  // Signal used for RVFI to set rmask, not used internally
  logic                         mscratchcsw_in_wb;
  logic                         mscratchcswl_in_wb;
  logic                         mnxti_in_wb;

  // Local instr_valid for write portion (WB)
  // Not factoring in ctrl_fsm_i.halt_limited_wb. This signal is only set during SLEEP mode, and while in SLEEP
  // there cannot be any CSR instruction in WB.
  assign instr_valid = ex_wb_pipe_i.instr_valid && !ctrl_fsm_i.kill_wb && !ctrl_fsm_i.halt_wb;

  // CSR access. Read in EX, write in WB
  // Setting csr_raddr to zero in case of unused csr to save power (alu_operand_b toggles a lot)
  assign csr_raddr = csr_num_e'((id_ex_pipe_i.csr_en && id_ex_pipe_i.instr_valid) ? id_ex_pipe_i.alu_operand_b[11:0] : 12'b0);

  // Not suppressing csr_waddr to zero when unused since its source are dedicated flipflops and would not save power as for raddr
  assign csr_waddr = csr_num_e'(ex_wb_pipe_i.csr_addr);
  assign csr_wdata = ex_wb_pipe_i.csr_wdata;

  assign csr_op    =  ex_wb_pipe_i.csr_op;

  // CSR write operations in WB, actual csr_we_int may still become 1'b0 in case of CSR_OP_READ
  assign csr_en_gated    = ex_wb_pipe_i.csr_en && instr_valid;

  ////////////////////////////////////////
  // Determine if CSR access is illegal //
  // Both read and write validity is    //
  // checked in the first (EX) stage    //
  // Invalid writes will suppress ex_wb //
  // signals and avoid writing in WB    //
  ////////////////////////////////////////
  assign illegal_csr_write = (id_ex_pipe_i.csr_op != CSR_OP_READ) &&
                             (id_ex_pipe_i.csr_en) &&
                             (csr_raddr[11:10] == 2'b11); // Priv spec section 2.1

  assign csr_illegal_o = (id_ex_pipe_i.instr_valid && id_ex_pipe_i.csr_en) ? illegal_csr_write || illegal_csr_read : 1'b0;


  ////////////////////////////////////////////
  //   ____ ____  ____    ____              //
  //  / ___/ ___||  _ \  |  _ \ ___  __ _   //
  // | |   \___ \| |_) | | |_) / _ \/ _` |  //
  // | |___ ___) |  _ <  |  _ <  __/ (_| |  //
  //  \____|____/|_| \_\ |_| \_\___|\__, |  //
  //                                |___/   //
  ////////////////////////////////////////////


  ////////////////////////////////////////////
  // CSR read logic

  always_comb
  begin
    illegal_csr_read   = 1'b0;
    csr_counter_read_o = 1'b0;
    csr_mnxti_read_o   = 1'b0;

    case (csr_raddr)
      // jvt: Jump vector table
      CSR_JVT:  begin
        if (ZC_EXT) begin
          csr_rdata_int = jvt_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mstatus
      CSR_MSTATUS: csr_rdata_int = mstatus_rdata;

      // misa
      CSR_MISA: csr_rdata_int = misa_rdata;

      // mie: machine interrupt enable
      CSR_MIE: begin
        csr_rdata_int = mie_rdata;
      end

      // mtvec: machine trap-handler base address
      CSR_MTVEC: csr_rdata_int = mtvec_rdata;

      // mtvt: machine trap-handler vector table base address
      CSR_MTVT: begin
        if (CLIC) begin
          csr_rdata_int = mtvt_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mstatush
      CSR_MSTATUSH: csr_rdata_int = mstatush_rdata;

      CSR_MCOUNTINHIBIT: csr_rdata_int = mcountinhibit_rdata;

      CSR_MHPMEVENT3,
      CSR_MHPMEVENT4,  CSR_MHPMEVENT5,  CSR_MHPMEVENT6,  CSR_MHPMEVENT7,
      CSR_MHPMEVENT8,  CSR_MHPMEVENT9,  CSR_MHPMEVENT10, CSR_MHPMEVENT11,
      CSR_MHPMEVENT12, CSR_MHPMEVENT13, CSR_MHPMEVENT14, CSR_MHPMEVENT15,
      CSR_MHPMEVENT16, CSR_MHPMEVENT17, CSR_MHPMEVENT18, CSR_MHPMEVENT19,
      CSR_MHPMEVENT20, CSR_MHPMEVENT21, CSR_MHPMEVENT22, CSR_MHPMEVENT23,
      CSR_MHPMEVENT24, CSR_MHPMEVENT25, CSR_MHPMEVENT26, CSR_MHPMEVENT27,
      CSR_MHPMEVENT28, CSR_MHPMEVENT29, CSR_MHPMEVENT30, CSR_MHPMEVENT31:
        csr_rdata_int = mhpmevent_rdata[csr_raddr[4:0]];

      // mscratch: machine scratch
      CSR_MSCRATCH: csr_rdata_int = mscratch_rdata;

      // mepc: exception program counter
      CSR_MEPC: csr_rdata_int = mepc_rdata;

      // mcause: exception cause
      CSR_MCAUSE: csr_rdata_int = mcause_rdata;

      // mtval
      CSR_MTVAL: csr_rdata_int = mtval_rdata;

      // mip: interrupt pending
      CSR_MIP: csr_rdata_int = mip_rdata;

      // mnxti: Next Interrupt Handler Address and Interrupt Enable
      CSR_MNXTI: begin
        if (CLIC) begin
          // The data read here is what will be used in the read-modify-write portion of the CSR access.
          // For mnxti, this is actually mstatus. The value written back to the GPR will be the address of
          // the function pointer to the interrupt handler. This is muxed in the WB stage.
          csr_rdata_int = mstatus_rdata;
          csr_mnxti_read_o = 1'b1;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mintstatus: Interrupt Status
      CSR_MINTSTATUS: begin
        if (CLIC) begin
          csr_rdata_int = mintstatus_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mintthresh: Interrupt-Level Threshold
      CSR_MINTTHRESH: begin
        if (CLIC) begin
          csr_rdata_int = mintthresh_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mscratchcsw: Scratch Swap for Multiple Privilege Modes
      CSR_MSCRATCHCSW: begin
        if (CLIC) begin
          // CLIC spec 13.2
          // Depending on mstatus.MPP, we return either mscratch_rdata or rs1 to rd.
          // Safe to use mstatus_rdata here (EX timing), as there is a generic stall of the ID stage
          // whenever a CSR instruction follows another CSR instruction. Alternative implementation using
          // a local forward of mstatus_rdata is identical (SEC).
          if (mstatus_rdata.mpp != PRIV_LVL_M) begin
            // Return mscratch for writing to GPR
            csr_rdata_int = mscratch_rdata;
          end else begin
            // return rs1 for writing to GPR
            csr_rdata_int = id_ex_pipe_i.alu_operand_a;
          end
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mscratchcswl: Scratch Swap for Interrupt Levels
      CSR_MSCRATCHCSWL: begin
        if (CLIC) begin
          // CLIC spec 14.1
          // Depending on mcause.pil and mintstatus.mil, either mscratch or rs1 is returned to rd.
          // Safe to use mcause_rdata and mintstatus_rdata here (EX timing), as there is a generic stall of the ID stage
          // whenever a CSR instruction follows another CSR instruction. Alternative implementation using
          // a local forward of mcause_rdata and mintstatus_rdata is identical (SEC).
          if ((mcause_rdata.mpil == '0) != (mintstatus_rdata.mil == 0)) begin
            // Return mscratch for writing to GPR
            csr_rdata_int = mscratch_rdata;
          end else begin
            // return rs1 for writing to GPR
            csr_rdata_int = id_ex_pipe_i.alu_operand_a;
          end
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TSELECT: begin
        if (DBG_NUM_TRIGGERS > 0) begin
          csr_rdata_int = tselect_rdata;
        end else begin
          csr_rdata_int = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TDATA1: begin
        if (DBG_NUM_TRIGGERS > 0) begin
          csr_rdata_int = tdata1_rdata;
        end else begin
          csr_rdata_int = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TDATA2: begin
        if (DBG_NUM_TRIGGERS > 0) begin
          csr_rdata_int = tdata2_rdata;
        end else begin
          csr_rdata_int = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TDATA3: begin
        if (DBG_NUM_TRIGGERS > 0) begin
          csr_rdata_int = tdata3_rdata;
        end else begin
          csr_rdata_int = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TINFO: begin
        if (DBG_NUM_TRIGGERS > 0) begin
          csr_rdata_int = tinfo_rdata;
        end else begin
          csr_rdata_int = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TCONTROL: begin
        if (DBG_NUM_TRIGGERS > 0) begin
          csr_rdata_int = tcontrol_rdata;
        end else begin
          csr_rdata_int = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_DCSR: begin
        if (DEBUG) begin
          csr_rdata_int = dcsr_rdata;
          illegal_csr_read = !ctrl_fsm_i.debug_mode;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_DPC: begin
        if (DEBUG) begin
          csr_rdata_int = dpc_rdata;
          illegal_csr_read = !ctrl_fsm_i.debug_mode;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_DSCRATCH0: begin
        if (DEBUG) begin
          csr_rdata_int = dscratch0_rdata;
          illegal_csr_read = !ctrl_fsm_i.debug_mode;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_DSCRATCH1: begin
        if (DEBUG) begin
          csr_rdata_int = dscratch1_rdata;
          illegal_csr_read = !ctrl_fsm_i.debug_mode;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TIME: begin
        csr_rdata_int = time_i[31:0];
      end

      CSR_TIMEH: begin
        csr_rdata_int = time_i[63:32];
      end

      // Hardware Performance Monitor
      CSR_MCYCLE,
      CSR_MINSTRET,
      CSR_MHPMCOUNTER3,
      CSR_MHPMCOUNTER4,  CSR_MHPMCOUNTER5,  CSR_MHPMCOUNTER6,  CSR_MHPMCOUNTER7,
      CSR_MHPMCOUNTER8,  CSR_MHPMCOUNTER9,  CSR_MHPMCOUNTER10, CSR_MHPMCOUNTER11,
      CSR_MHPMCOUNTER12, CSR_MHPMCOUNTER13, CSR_MHPMCOUNTER14, CSR_MHPMCOUNTER15,
      CSR_MHPMCOUNTER16, CSR_MHPMCOUNTER17, CSR_MHPMCOUNTER18, CSR_MHPMCOUNTER19,
      CSR_MHPMCOUNTER20, CSR_MHPMCOUNTER21, CSR_MHPMCOUNTER22, CSR_MHPMCOUNTER23,
      CSR_MHPMCOUNTER24, CSR_MHPMCOUNTER25, CSR_MHPMCOUNTER26, CSR_MHPMCOUNTER27,
      CSR_MHPMCOUNTER28, CSR_MHPMCOUNTER29, CSR_MHPMCOUNTER30, CSR_MHPMCOUNTER31,
      CSR_CYCLE,
      CSR_INSTRET,
      CSR_HPMCOUNTER3,
      CSR_HPMCOUNTER4,  CSR_HPMCOUNTER5,  CSR_HPMCOUNTER6,  CSR_HPMCOUNTER7,
      CSR_HPMCOUNTER8,  CSR_HPMCOUNTER9,  CSR_HPMCOUNTER10, CSR_HPMCOUNTER11,
      CSR_HPMCOUNTER12, CSR_HPMCOUNTER13, CSR_HPMCOUNTER14, CSR_HPMCOUNTER15,
      CSR_HPMCOUNTER16, CSR_HPMCOUNTER17, CSR_HPMCOUNTER18, CSR_HPMCOUNTER19,
      CSR_HPMCOUNTER20, CSR_HPMCOUNTER21, CSR_HPMCOUNTER22, CSR_HPMCOUNTER23,
      CSR_HPMCOUNTER24, CSR_HPMCOUNTER25, CSR_HPMCOUNTER26, CSR_HPMCOUNTER27,
      CSR_HPMCOUNTER28, CSR_HPMCOUNTER29, CSR_HPMCOUNTER30, CSR_HPMCOUNTER31: begin
        csr_rdata_int = mhpmcounter_rdata[csr_raddr[4:0]][31:0];
        csr_counter_read_o = 1'b1;
      end

      CSR_MCYCLEH,
      CSR_MINSTRETH,
      CSR_MHPMCOUNTER3H,
      CSR_MHPMCOUNTER4H,  CSR_MHPMCOUNTER5H,  CSR_MHPMCOUNTER6H,  CSR_MHPMCOUNTER7H,
      CSR_MHPMCOUNTER8H,  CSR_MHPMCOUNTER9H,  CSR_MHPMCOUNTER10H, CSR_MHPMCOUNTER11H,
      CSR_MHPMCOUNTER12H, CSR_MHPMCOUNTER13H, CSR_MHPMCOUNTER14H, CSR_MHPMCOUNTER15H,
      CSR_MHPMCOUNTER16H, CSR_MHPMCOUNTER17H, CSR_MHPMCOUNTER18H, CSR_MHPMCOUNTER19H,
      CSR_MHPMCOUNTER20H, CSR_MHPMCOUNTER21H, CSR_MHPMCOUNTER22H, CSR_MHPMCOUNTER23H,
      CSR_MHPMCOUNTER24H, CSR_MHPMCOUNTER25H, CSR_MHPMCOUNTER26H, CSR_MHPMCOUNTER27H,
      CSR_MHPMCOUNTER28H, CSR_MHPMCOUNTER29H, CSR_MHPMCOUNTER30H, CSR_MHPMCOUNTER31H,
      CSR_CYCLEH,
      CSR_INSTRETH,
      CSR_HPMCOUNTER3H,
      CSR_HPMCOUNTER4H,  CSR_HPMCOUNTER5H,  CSR_HPMCOUNTER6H,  CSR_HPMCOUNTER7H,
      CSR_HPMCOUNTER8H,  CSR_HPMCOUNTER9H,  CSR_HPMCOUNTER10H, CSR_HPMCOUNTER11H,
      CSR_HPMCOUNTER12H, CSR_HPMCOUNTER13H, CSR_HPMCOUNTER14H, CSR_HPMCOUNTER15H,
      CSR_HPMCOUNTER16H, CSR_HPMCOUNTER17H, CSR_HPMCOUNTER18H, CSR_HPMCOUNTER19H,
      CSR_HPMCOUNTER20H, CSR_HPMCOUNTER21H, CSR_HPMCOUNTER22H, CSR_HPMCOUNTER23H,
      CSR_HPMCOUNTER24H, CSR_HPMCOUNTER25H, CSR_HPMCOUNTER26H, CSR_HPMCOUNTER27H,
      CSR_HPMCOUNTER28H, CSR_HPMCOUNTER29H, CSR_HPMCOUNTER30H, CSR_HPMCOUNTER31H: begin
        csr_rdata_int = mhpmcounter_rdata[csr_raddr[4:0]][63:32];
        csr_counter_read_o = 1'b1;
      end

      // mvendorid: Machine Vendor ID
      CSR_MVENDORID: csr_rdata_int = mvendorid_rdata;

      // marchid: Machine Architecture ID
      CSR_MARCHID: csr_rdata_int = marchid_rdata;

      // mimpid: implementation id
      CSR_MIMPID: csr_rdata_int = mimpid_rdata;

      // mhartid: unique hardware thread id
      CSR_MHARTID: csr_rdata_int = mhartid_rdata;

      // mconfigptr: Pointer to configuration data structure
      CSR_MCONFIGPTR: csr_rdata_int = mconfigptr_rdata;

      default: begin
        csr_rdata_int    = '0;
        illegal_csr_read = 1'b1;
      end
    endcase
  end

  ////////////////////////////////////////////
  // CSR write logic

  always_comb
  begin

    jvt_n         = csr_next_value(csr_wdata_int, CSR_JVT_MASK, JVT_RESET_VAL);
    jvt_we        = 1'b0;

    mscratch_n    = csr_next_value(csr_wdata_int, CSR_MSCRATCH_MASK, MSCRATCH_RESET_VAL);
    mscratch_we   = 1'b0;

    mepc_n        = csr_next_value(csr_wdata_int, CSR_MEPC_MASK, MEPC_RESET_VAL);
    mepc_we       = 1'b0;

    dpc_n         = csr_next_value(csr_wdata_int, CSR_DPC_MASK, DPC_RESET_VAL);
    dpc_we        = 1'b0;

    dcsr_n        = csr_next_value(dcsr_t'{
                                            xdebugver : dcsr_rdata.xdebugver,
                                            ebreakm   : csr_wdata_int[15],
                                            ebreaku   : dcsr_ebreaku_resolve(dcsr_rdata.ebreaku, csr_wdata_int[DCSR_EBREAKU_BIT]),
                                            stepie    : csr_wdata_int[11],
                                            stopcount : csr_wdata_int[10],
                                            mprven    : dcsr_rdata.mprven,
                                            step      : csr_wdata_int[2],
                                            prv       : dcsr_prv_resolve(dcsr_rdata.prv, csr_wdata_int[DCSR_PRV_BIT_HIGH:DCSR_PRV_BIT_LOW]),
                                            cause     : dcsr_rdata.cause,
                                            default   : 'd0
                                          },
                                    CSR_DCSR_MASK, DCSR_RESET_VAL);
    dcsr_we       = 1'b0;

    dscratch0_n   = csr_wdata_int;
    dscratch0_we  = 1'b0;

    dscratch1_n   = csr_wdata_int;
    dscratch1_we  = 1'b0;

    tselect_we    = 1'b0;

    tdata1_we     = 1'b0;

    tdata2_we     = 1'b0;

    tdata3_we     = 1'b0;

    tinfo_we      = 1'b0;

    tcontrol_we   = 1'b0;

    // TODO: add support for SD/XS/FS/VS
    mstatus_n     = '{
                                  tw:   1'b0,
                                  mprv: mstatus_mprv_resolve(mstatus_rdata.mprv, csr_wdata_int[MSTATUS_MPRV_BIT]),
                                  mpp:  mstatus_mpp_resolve(mstatus_rdata.mpp, csr_wdata_int[MSTATUS_MPP_BIT_HIGH:MSTATUS_MPP_BIT_LOW]),
                                  mpie: csr_wdata_int[MSTATUS_MPIE_BIT],
                                  mie:  csr_wdata_int[MSTATUS_MIE_BIT],
                                  default: 'b0
                                };
    mstatus_we    = 1'b0;

    mstatush_n    = mstatush_rdata; // Read only
    mstatush_we   = 1'b0;
    mstatus_alias_we = 1'b0;

    misa_n        = misa_rdata; // Read only
    misa_we       = 1'b0;

    priv_lvl_n    = priv_lvl_rdata;
    priv_lvl_we   = 1'b0;

    mtvec_n.addr    = csr_mtvec_init_i ? mtvec_addr_i[31:7] : csr_wdata_int[31:7];
    mtvec_n.zero0   = mtvec_rdata.zero0;
    mtvec_n.submode = mtvec_rdata.submode;
    mtvec_we        = csr_mtvec_init_i;

    if (CLIC) begin
      mtvec_n.mode             = mtvec_mode_clic_resolve(mtvec_rdata.mode, csr_wdata_int[MTVEC_MODE_BIT_HIGH:MTVEC_MODE_BIT_LOW]); // mode is WARL 0x3 when using CLIC

      mtvt_n                   = {csr_wdata_int[31:(32-MTVT_ADDR_WIDTH)], {(32-MTVT_ADDR_WIDTH){1'b0}}};
      mtvt_we                  = 1'b0;

      mnxti_we                 = 1'b0;

      mintstatus_n             = mintstatus_rdata; // Read only
      mintstatus_we            = 1'b0;

      mintthresh_n             = csr_wdata_int & CSR_MINTTHRESH_MASK;
      mintthresh_we            = 1'b0;

      mscratchcsw_n            = mscratch_n; // mscratchcsw operates conditionally on mscratch
      mscratchcsw_we           = 1'b0;

      mscratchcswl_n           = mscratch_n; // mscratchcswl operates conditionally on mscratch
      mscratchcswl_we          = 1'b0;

      mie_n                    = '0;
      mie_we                   = 1'b0;

      mip_n                    = mip_rdata; // Read only;
      mip_we                   = 1'b0;

      mcause_n                 = '{
                                    irq:            csr_wdata_int[31],
                                    minhv:          csr_wdata_int[30],
                                    mpp:            mcause_mpp_resolve(mcause_rdata.mpp, csr_wdata_int[MCAUSE_MPP_BIT_HIGH:MCAUSE_MPP_BIT_LOW]),
                                    mpie:           csr_wdata_int[MCAUSE_MPIE_BIT],
                                    mpil:           csr_wdata_int[23:16],
                                    exception_code: csr_wdata_int[10:0],
                                    default:        'b0
                                  };
      mcause_we                = 1'b0;
      mcause_alias_we          = 1'b0;
    end else begin // !CLIC
      mtvec_n.mode             = csr_mtvec_init_i ? mtvec_rdata.mode : mtvec_mode_clint_resolve(mtvec_rdata.mode, csr_wdata_int[MTVEC_MODE_BIT_HIGH:MTVEC_MODE_BIT_LOW]);

      mtvt_n                   = '0;
      mtvt_we                  = 1'b0;

      mnxti_we                 = 1'b0;

      mintstatus_n             = '0;
      mintstatus_we            = 1'b0;

      mintthresh_n             = '0;
      mintthresh_we            = 1'b0;

      mscratchcsw_n            = '0;
      mscratchcsw_we           = 1'b0;

      mscratchcswl_n           = '0;
      mscratchcswl_we          = 1'b0;

      mie_n                    = csr_wdata_int & IRQ_MASK;
      mie_we                   = 1'b0;

      mip_n                    = mip_rdata; // Read only;
      mip_we                   = 1'b0;

      mcause_n                 = '{
                                    irq:            csr_wdata_int[31],
                                    exception_code: csr_wdata_int[10:0],
                                    default:        'b0
                                  };
      mcause_we                = 1'b0;
      mcause_alias_we          = 1'b0;
    end

    mtval_n         = mtval_rdata;                // Read-only
    mtval_we        = 1'b0;

    // Read-only CSRS
    mhartid_n       = mhartid_rdata;              // Read-only
    mhartid_we      = 1'b0;                       // Always 0

    mimpid_n        = mimpid_rdata;               // Read-only
    mimpid_we       = 1'b0;                       // Always 0

    mconfigptr_n    = mconfigptr_rdata;           // Read-only
    mconfigptr_we   = 1'b0;                       // Always 0

    mvendorid_n     = mvendorid_rdata;            // Read-only
    mvendorid_we    = 1'b0;                       // Always 0

    marchid_n       = marchid_rdata;              // Read-only
    marchid_we      = 1'b0;                       // Always 0

    if (csr_we_int) begin
      case (csr_waddr)

        // jvt: Jump vector table
        CSR_JVT: begin
          if (ZC_EXT) begin
            jvt_we = 1'b1;
          end
        end

        // mstatus
        CSR_MSTATUS: begin
          mstatus_we = 1'b1;
          // CLIC mode is assumed when CLIC = 1
          // For CLIC, a write to mstatus.mpp or mstatus.mpie will write to the
          // corresponding bits in mstatus as well.
          if (CLIC) begin
            mcause_alias_we = 1'b1;
          end
        end

        CSR_MISA: begin
          misa_we = 1'b1;
        end

        // mie: machine interrupt enable
        CSR_MIE: begin
          mie_we = 1'b1;
        end

        // mtvec: machine trap-handler base address
        CSR_MTVEC: begin
          mtvec_we = 1'b1;
        end

        // mtvt: machine trap-handler vector table base address
        CSR_MTVT: begin
          if (CLIC) begin
            mtvt_we = 1'b1;
          end
        end

        CSR_MSTATUSH: begin
          mstatush_we = 1'b1;
        end

        // mscratch: machine scratch
        CSR_MSCRATCH: begin
          mscratch_we = 1'b1;
        end

        // mepc: exception program counter
        CSR_MEPC: begin
          mepc_we = 1'b1;
        end

        // mcause
        CSR_MCAUSE: begin
          mcause_we = 1'b1;
          // CLIC mode is assumed when CLIC = 1
          // For CLIC, a write to mcause.mpp or mcause.mpie will write to the
          // corresponding bits in mstatus as well.
          if (CLIC) begin
            mstatus_alias_we = 1'b1;
          end
        end

        CSR_MTVAL: begin
          mtval_we = 1'b1;
        end

        // mip: machine interrupt pending
        CSR_MIP: begin
          mip_we = 1'b1;
        end

        CSR_MNXTI: begin
          if (CLIC) begin
            mnxti_we = 1'b1;

            // Writes to mnxti also writes to mstatus (uses mstatus in the RMW operation)
            // Also writing to mcause to ensure we can assert mstatus_we == mcause_we and similar for mpp/mpie.
            mstatus_we = 1'b1;
            mcause_we  = 1'b1;

            // Writes to mintstatus.mil and mcause depend on the current state of
            // clic interrupts AND the type of CSR instruction used.
            // Mcause is written unconditionally for aliasing purposes, but the mcause_n
            // is modified to reflect the side effects in case mnxti_irq_pending_i i set.
            // Side effects occur when there is an actual write to the mstatus CSR
            // This is already coded into the csr_we_int/mnxti_we
            if (mnxti_irq_pending_i) begin
              mintstatus_we = 1'b1;
            end
          end
        end

        CSR_MINTSTATUS: begin
          if (CLIC) begin
            mintstatus_we = 1'b1;
          end
        end

        CSR_MINTTHRESH: begin
          if (CLIC) begin
            mintthresh_we = 1'b1;
          end
        end

        CSR_MSCRATCHCSW: begin
          if (CLIC) begin
            // mscratchcsw operates on mscratch
            // Writing only when mstatus.mpp != PRIV_LVL_M
            if (mstatus_rdata.mpp != PRIV_LVL_M) begin
              mscratchcsw_we = 1'b1;
              mscratch_we    = 1'b1;
            end
          end
        end

        CSR_MSCRATCHCSWL: begin
          if (CLIC) begin
            // mscratchcswl operates on mscratch
            if ((mcause_rdata.mpil == '0) != (mintstatus_rdata.mil == '0)) begin
              mscratchcswl_we = 1'b1;
              mscratch_we     = 1'b1;
            end
          end
        end

        CSR_TSELECT: begin
          tselect_we = 1'b1;
        end

        CSR_TDATA1: begin
          if (ctrl_fsm_i.debug_mode) begin
            tdata1_we = 1'b1;
          end
        end

        CSR_TDATA2: begin
          if (ctrl_fsm_i.debug_mode) begin
            tdata2_we = 1'b1;
          end
        end

        CSR_TDATA3: begin
          if (ctrl_fsm_i.debug_mode) begin
            tdata3_we = 1'b1;
          end
        end

        CSR_TINFO: begin
          tinfo_we = 1'b1;
        end

        CSR_TCONTROL: begin
          tcontrol_we = 1'b1;
        end

        CSR_DCSR: begin
          dcsr_we = 1'b1;
        end

        CSR_DPC: begin
          dpc_we = 1'b1;
        end

        CSR_DSCRATCH0: begin
          dscratch0_we = 1'b1;
        end

        CSR_DSCRATCH1: begin
           dscratch1_we = 1'b1;
        end
        default:;
      endcase
    end

    // CSR side effects from other CSRs

    // CLIC mode is assumed when CLIC = 1
    if (CLIC) begin
      if (mnxti_we) begin
        // Mstatus is written as part of an mnxti access
        // Make sure we alias the mpp/mpie to mcause
        mcause_n = mcause_rdata;
        mcause_n.mpie = mstatus_n.mpie;
        mcause_n.mpp = mstatus_n.mpp;

        // mintstatus and mcause are updated if an actual mstatus write happens and
        // a higher level non-shv interrupt is pending.
        // This is already decoded into the respective _we signals below.
        if (mintstatus_we) begin
          mintstatus_n.mil = mnxti_irq_level_i;
        end
        if (mnxti_irq_pending_i) begin
          mcause_n.irq = 1'b1;
          mcause_n.exception_code = {1'b0, 10'(mnxti_irq_id_i)};
        end
      end else if (mstatus_alias_we) begin
        // In CLIC mode, writes to mcause.mpp/mpie is aliased to mstatus.mpp/mpie
        // All other mstatus bits are preserved
        mstatus_n      = mstatus_rdata; // Preserve all fields

        // Write mpie and mpp as aliased through mcause
        mstatus_n.mpie = mcause_n.mpie;
        mstatus_n.mpp  = mcause_n.mpp;

        mstatus_we = 1'b1;
      end else if (mcause_alias_we) begin
        // In CLIC mode, writes to mstatus.mpp/mpie is aliased to mcause.mpp/mpie
        // All other mcause bits are preserved
        mcause_n = mcause_rdata;
        mcause_n.mpie = mstatus_n.mpie;
        mcause_n.mpp = mstatus_n.mpp;

        mcause_we = 1'b1;
      end
      // The CLIC pointer address should always be output for an access to MNXTI,
      // but will only contain a nonzero value if a CLIC interrupt is actually pending
      // with a higher level. The valid below will be high also for the cases where
      // no side effects occur.
      clic_pa_valid_o = csr_en_gated && (csr_waddr == CSR_MNXTI);
      clic_pa_o       = mnxti_rdata;
    end else begin
      clic_pa_valid_o = 1'b0;
      clic_pa_o       = '0;
    end

    // Exception controller gets priority over other writes
    unique case (1'b1)
      ctrl_fsm_i.csr_save_cause: begin
        if (ctrl_fsm_i.debug_csr_save) begin
          // All interrupts are masked, don't update mcause, mepc, mtval, dpc and mstatus
          // dcsr.nmip is not a flop, but comes directly from the controller
          dcsr_n         = '{
            xdebugver : dcsr_rdata.xdebugver,
            ebreakm   : dcsr_rdata.ebreakm,
            ebreaku   : dcsr_rdata.ebreaku,
            stepie    : dcsr_rdata.stepie,
            stopcount : dcsr_rdata.stopcount,
            mprven    : dcsr_rdata.mprven,
            step      : dcsr_rdata.step,
            prv       : priv_lvl_rdata,                 // Privilege level at time of debug entry
            cause     : ctrl_fsm_i.debug_cause,
            default   : 'd0
          };
          dcsr_we        = 1'b1;

          dpc_n          = ctrl_fsm_i.pipe_pc;
          dpc_we         = 1'b1;

          priv_lvl_n     = PRIV_LVL_M;                  // Execute with machine mode privilege in debug mode
          priv_lvl_we    = 1'b1;
        end else begin
          priv_lvl_n     = PRIV_LVL_M;                  // Trap into machine mode
          priv_lvl_we    = 1'b1;

          mstatus_n      = mstatus_rdata;
          mstatus_n.mie  = 1'b0;
          mstatus_n.mpie = mstatus_rdata.mie;
          mstatus_n.mpp  = priv_lvl_rdata;
          mstatus_we     = 1'b1;

          mepc_n         = ctrl_fsm_i.pipe_pc;
          mepc_we        = 1'b1;

          // Save relevant fields from controller to mcause
          mcause_n.irq            = ctrl_fsm_i.csr_cause.irq;
          mcause_n.exception_code = ctrl_fsm_i.csr_cause.exception_code;


          mcause_we = 1'b1;


          if (CLIC) begin
            // mpil is saved from mintstatus
            mcause_n.mpil = mintstatus_rdata.mil;

            // Save minhv from controller
            mcause_n.minhv          = ctrl_fsm_i.csr_cause.minhv;
            // Save aliased values for mpp and mpie
            mcause_n.mpp            = mstatus_n.mpp;
            mcause_n.mpie           = mstatus_n.mpie;

            // Save new interrupt level to mintstatus
            // Horizontal synchronous exception traps do not change the interrupt level.
            // Vertical synchronous exception traps to higher privilege level use interrupt level 0.
            // All exceptions are taken in PRIV_LVL_M, so checking that we get a different privilege level is sufficient for clearing
            // mintstatus.mil.
            if (ctrl_fsm_i.csr_cause.irq) begin
              mintstatus_n.mil = ctrl_fsm_i.irq_level;
              mintstatus_we = 1'b1;
            end else if ((priv_lvl_rdata != priv_lvl_n)) begin
              mintstatus_n.mil = '0;
              mintstatus_we = 1'b1;
            end
          end else begin
            mcause_n.mpil = '0;
          end
        end
      end //ctrl_fsm_i.csr_save_cause

      ctrl_fsm_i.csr_restore_mret,
      ctrl_fsm_i.csr_restore_mret_ptr: begin // MRET
        priv_lvl_n     = privlvl_t'(mstatus_rdata.mpp);
        priv_lvl_we    = 1'b1;

        mstatus_n      = mstatus_rdata;
        mstatus_n.mie  = mstatus_rdata.mpie;
        mstatus_n.mpie = 1'b1;
        mstatus_n.mpp  = PRIV_LVL_LOWEST;
        mstatus_we     = 1'b1;

        if (CLIC) begin
          mintstatus_n.mil = mcause_rdata.mpil;
          mintstatus_we = 1'b1;

          // Save aliased values for mpp and mpie
          mcause_n = mcause_rdata;
          mcause_n.mpp = mstatus_n.mpp;
          mcause_n.mpie = mstatus_n.mpie;
          mcause_we = 1'b1;

          if (ctrl_fsm_i.csr_restore_mret_ptr) begin
            // Clear mcause.minhv if the mret also caused a successful CLIC pointer fetch
            mcause_n.minhv = 1'b0;
          end
        end
      end //ctrl_fsm_i.csr_restore_mret

      ctrl_fsm_i.csr_restore_dret: begin // DRET
        // Restore to the recorded privilege level
        priv_lvl_n = dcsr_rdata.prv;
        priv_lvl_we = 1'b1;

        // Section 4.6 of debug spec: If the new privilege mode is less privileged than M-mode, MPRV in mstatus is cleared.
        mstatus_n      = mstatus_rdata;
        mstatus_n.mprv = (privlvl_t'(dcsr_rdata.prv) == PRIV_LVL_M) ? mstatus_rdata.mprv : 1'b0;
        mstatus_we     = 1'b1;

        if (CLIC) begin
          // Not really needed, but allows for asserting mstatus_we == mcause_we to check aliasing formally
          mcause_n       = mcause_rdata;
          mcause_we      = 1'b1;
        end

      end //ctrl_fsm_i.csr_restore_dret

      // Clear mcause.minhv on successful CLIC pointer fetches
      // This only happens for CLIC pointer that did not originate from an mret.
      // In the case of mret restarting CLIC pointer fetches, minhv is cleared while
      // ctrl_fsm_i.csr_restore_mret_ptr is asserted.
      ctrl_fsm_i.csr_clear_minhv: begin
        if (CLIC) begin
          // Keep mcause values, only clear minhv bit.
          mcause_n = mcause_rdata;
          mcause_n.minhv = 1'b0;
          mcause_we = 1'b1;

          // Not really needed, but allows for asserting mstatus_we == mcause_we to check aliasing formally
          mstatus_n  = mstatus_rdata;
          mstatus_we = 1'b1;
        end
      end
      default:;
    endcase

  end

  // Mirroring mstatus_n to mnxti_n for RVFI
  assign mnxti_n = mstatus_n;

  // CSR operation logic
  // Using ex_wb_pipe_i.rf_wdata for read-modify-write since CSR was read in EX, written in WB
  always_comb
  begin
    if(!csr_en_gated) begin
      csr_wdata_int = csr_wdata;
      csr_we_int    = 1'b0;
    end else begin
      csr_we_int    = 1'b1;
      csr_wdata_int = csr_wdata;
      case (csr_op)
        CSR_OP_WRITE: csr_wdata_int = csr_wdata;
        CSR_OP_SET:   csr_wdata_int = csr_wdata | ex_wb_pipe_i.rf_wdata;
        CSR_OP_CLEAR: csr_wdata_int = (~csr_wdata) & ex_wb_pipe_i.rf_wdata;

        CSR_OP_READ: begin
          csr_wdata_int = csr_wdata;
          csr_we_int    = 1'b0;
        end
        default:;
      endcase
    end
  end

  ////////////////////////////////////////////////////////////////////////
  //
  // CSR instances

  cv32e40x_csr
  #(
    .WIDTH      (32            ),
    .MASK       (CSR_JVT_MASK  ),
    .RESETVALUE (JVT_RESET_VAL )
  )
  jvt_csr_i
  (
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .wr_data_i          ( jvt_n                 ),
    .wr_en_i            ( jvt_we                ),
    .rd_data_o          ( jvt_q                 )
  );

  generate
    if (DEBUG) begin : gen_debug_csr
      cv32e40x_csr
      #(
        .WIDTH      (32),
        .RESETVALUE (32'd0)
      )
      dscratch0_csr_i
      (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .wr_data_i          ( dscratch0_n           ),
        .wr_en_i            ( dscratch0_we          ),
        .rd_data_o          ( dscratch0_q           )
      );

      cv32e40x_csr
      #(
        .WIDTH      (32),
        .RESETVALUE (32'd0)
      )
      dscratch1_csr_i
      (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .wr_data_i          ( dscratch1_n           ),
        .wr_en_i            ( dscratch1_we          ),
        .rd_data_o          ( dscratch1_q           )
      );

      cv32e40x_csr
      #(
        .WIDTH      (32            ),
        .MASK       (CSR_DCSR_MASK ),
        .RESETVALUE (DCSR_RESET_VAL)
      )
      dcsr_csr_i
      (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .wr_data_i          ( dcsr_n                ),
        .wr_en_i            ( dcsr_we               ),
        .rd_data_o          ( dcsr_q                )
      );

      cv32e40x_csr
      #(
        .WIDTH      (32           ),
        .MASK       (CSR_DPC_MASK ),
        .RESETVALUE (DPC_RESET_VAL)
      )
      dpc_csr_i
      (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .wr_data_i          ( dpc_n                 ),
        .wr_en_i            ( dpc_we                ),
        .rd_data_o          ( dpc_q                 )
      );
    end else begin : debug_csr_tieoff
        assign dscratch0_q = 32'h0;
        assign dscratch1_q = 32'h0;
        assign dpc_q       = 32'h0;
        assign dcsr_q      = 32'h0;
    end
  endgenerate

  cv32e40x_csr
  #(
    .WIDTH      (32            ),
    .MASK       (CSR_MEPC_MASK ),
    .RESETVALUE (MEPC_RESET_VAL)
  )
  mepc_csr_i
  (
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .wr_data_i          ( mepc_n                ),
    .wr_en_i            ( mepc_we               ),
    .rd_data_o          ( mepc_q                )
  );

  cv32e40x_csr
  #(
    .WIDTH      (32                ),
    .MASK       (CSR_MSCRATCH_MASK ),
    .RESETVALUE (MSCRATCH_RESET_VAL)
  )
  mscratch_csr_i
  (
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .wr_data_i          ( mscratch_n            ),
    .wr_en_i            ( mscratch_we           ),
    .rd_data_o          ( mscratch_q            )
  );

  cv32e40x_csr
  #(
    .WIDTH      (32),
    .RESETVALUE (MSTATUS_RESET_VAL)
  )
  mstatus_csr_i
  (
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .wr_data_i          ( mstatus_n             ),
    .wr_en_i            ( mstatus_we            ),
    .rd_data_o          ( mstatus_q             )
  );



  generate
    if (CLIC) begin : clic_csrs

      assign mie_q = 32'h0;                                                     // CLIC mode is assumed when CLIC = 1

      cv32e40x_csr
      #(
        .WIDTH      (32),
        .RESETVALUE (MCAUSE_CLIC_RESET_VAL)
      )
      mcause_csr_i (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .wr_data_i          ( mcause_n              ),
        .wr_en_i            ( mcause_we             ),
        .rd_data_o          ( mcause_q              )
      );

      cv32e40x_csr
      #(
        .WIDTH      (32),
        .RESETVALUE (MTVEC_CLIC_RESET_VAL)
      )
      mtvec_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .wr_data_i      ( mtvec_n               ),
        .wr_en_i        ( mtvec_we              ),
        .rd_data_o      ( mtvec_q               )
      );

      cv32e40x_csr
      #(
        .WIDTH      (32),
        .RESETVALUE (MTVT_RESET_VAL)
      )
      mtvt_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .wr_data_i      ( mtvt_n                ),
        .wr_en_i        ( mtvt_we               ),
        .rd_data_o      ( mtvt_q                )
      );

      cv32e40x_csr
      #(
        .WIDTH      (32),
        .RESETVALUE (MINTSTATUS_RESET_VAL)
      )
      mintstatus_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .wr_data_i      ( mintstatus_n          ),
        .wr_en_i        ( mintstatus_we         ),
        .rd_data_o      ( mintstatus_q          )
      );

      cv32e40x_csr
      #(
        .WIDTH      (32),
        .RESETVALUE (32'h0)
      )
      mintthresh_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .wr_data_i      ( mintthresh_n          ),
        .wr_en_i        ( mintthresh_we         ),
        .rd_data_o      ( mintthresh_q          )
      );


    end else begin : basic_mode_csrs

      cv32e40x_csr
      #(
        .WIDTH      (32),
        .RESETVALUE (MCAUSE_BASIC_RESET_VAL)
      )
      mcause_csr_i (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .wr_data_i          ( mcause_n              ),
        .wr_en_i            ( mcause_we             ),
        .rd_data_o          ( mcause_q              )
      );

      cv32e40x_csr
      #(
        .WIDTH      (32),
        .RESETVALUE (MTVEC_BASIC_RESET_VAL)
      )
      mtvec_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .wr_data_i      ( mtvec_n               ),
        .wr_en_i        ( mtvec_we              ),
        .rd_data_o      ( mtvec_q               )
      );

      cv32e40x_csr
      #(
        .WIDTH      (32),
        .RESETVALUE (32'd0)
      )
      mie_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .wr_data_i      ( mie_n                 ),
        .wr_en_i        ( mie_we                ),
        .rd_data_o      ( mie_q                 )
      );

      assign mtvt_q              = 32'h0;

      assign mintstatus_q        = 32'h0;

      assign mintthresh_q        = 32'h0;

    end
  endgenerate

  ////////////////////////////////////////////////////////////////////////
  //
  // CSR rdata

  assign jvt_rdata          = jvt_q;
  assign dscratch0_rdata    = dscratch0_q;
  assign dscratch1_rdata    = dscratch1_q;
  assign dpc_rdata          = dpc_q;
  assign mepc_rdata         = mepc_q;
  assign mscratch_rdata     = mscratch_q;
  assign mstatus_rdata      = mstatus_q;
  assign mtvec_rdata        = mtvec_q;
  assign mtvt_rdata         = mtvt_q;
  assign mintstatus_rdata   = mintstatus_q;
  assign mie_rdata          = mie_q;

  // Implemented threshold bits are left justified, unimplemented bits are tied to 1.
  // Special case when all 8 bits are implemented to avoid zero-replication
  generate
    if (CLIC_INTTHRESHBITS < 8) begin : gen_partial_thresh
      // Unimplemented bits within [7:0] are tied to 1. Bits 31:8 always tied to 0.
      assign mintthresh_rdata   = {mintthresh_q[31:(7-(CLIC_INTTHRESHBITS-1))], {(8-CLIC_INTTHRESHBITS) {1'b1}}};
    end else begin : gen_full_thresh
      // Bits 31:8 tied to 0, all bits within [7:0] are implemented in flipflops.
      assign mintthresh_rdata   = mintthresh_q[31:0];
    end
  endgenerate

  // mnxti_rdata breaks the regular convension for CSRs. The read data used for read-modify-write is the mstatus_rdata,
  // while the value read and written back to the GPR is a pointer address if an interrupt is pending, or zero
  // if no interrupt is pending.
  assign mnxti_rdata        = mnxti_irq_pending_i ? {mtvt_addr_o, mnxti_irq_id_i, 2'b00} : 32'h00000000;

  // mscratchcsw_rdata breaks the regular convension for CSRs. Read data depends on mstatus.mpp
  // mscratch_rdata is returned if mstatus.mpp differs from PRIV_LVL_M, otherwise rs1 is returned.
  // This signal is only used by RVFI, and has WB timing (rs1 comes from ex_wb_pipe_i.csr_wdata, flopped version of id_ex_pipe.alu_operand_a)
  assign mscratchcsw_rdata  = (mstatus_rdata.mpp != PRIV_LVL_M) ? mscratch_rdata : ex_wb_pipe_i.csr_wdata;

  // mscratchcswl_rdata breaks the regular convension for CSrs. Read data depend on mcause.pil and mintstatus.mil.
  // This signal is only used by RVFI, and has WB timing (rs1 comes from ex_wb_pipe_i.csr_wdata, flopped version of id_ex_pipe.alu_operand_a)
  assign mscratchcswl_rdata = ((mcause_rdata.mpil == '0) != (mintstatus_rdata.mil == 0)) ? mscratch_rdata : ex_wb_pipe_i.csr_wdata;

  assign mip_rdata          = mip_i;
  assign misa_rdata         = MISA_VALUE;
  assign mstatush_rdata     = 32'h0;
  assign mtval_rdata        = 32'h0;
  assign mvendorid_rdata    = {MVENDORID_BANK, MVENDORID_OFFSET};
  assign marchid_rdata      = MARCHID;
  assign mimpid_rdata       = {12'b0, MIMPID_MAJOR, 4'b0, MIMPID_MINOR, 4'b0, mimpid_patch_i};
  assign mhartid_rdata      = mhartid_i;
  assign mconfigptr_rdata   = 32'h0;

  assign priv_lvl_rdata     = PRIV_LVL_M;

  // dcsr_rdata factors in the flop outputs and the nmip bit from the controller
  assign dcsr_rdata = DEBUG ? {dcsr_q[31:4], ctrl_fsm_i.pending_nmi, dcsr_q[2:0]} : 32'h0;


  assign mcause_rdata = mcause_q;


  assign csr_rdata_o = csr_rdata_int;

  // Any CSR write in WB
  assign csr_wr_in_wb = ex_wb_pipe_i.csr_en &&
                        ex_wb_pipe_i.instr_valid &&
                        ((csr_op == CSR_OP_WRITE) ||
                         (csr_op == CSR_OP_SET)   ||
                         (csr_op == CSR_OP_CLEAR));

  // Detect when a JVT write is in WB
  assign jvt_wr_in_wb = csr_wr_in_wb && (csr_waddr == CSR_JVT);

  // Output to controller to request pipeline flush
  assign csr_wr_in_wb_flush_o = jvt_wr_in_wb;

  // Signal when an interrupt may become enabled due to a CSR write
  generate
    if (CLIC) begin : clic_irq_en
      assign csr_irq_enable_write_o = mstatus_we || priv_lvl_we || mintthresh_we || mintstatus_we;
    end else begin : basic_irq_en
      assign csr_irq_enable_write_o = mie_we || mstatus_we || priv_lvl_we;
    end
  endgenerate

  ////////////////////////////////////////////////////////////////////////
  //
  // CSR outputs

  assign dcsr_o        = dcsr_rdata;
  assign dpc_o         = dpc_rdata;
  assign jvt_addr_o    = jvt_rdata.base[31:32-JVT_ADDR_WIDTH];
  assign jvt_mode_o    = jvt_rdata.mode;
  assign mcause_o      = mcause_rdata;
  assign mcycle_o      = mhpmcounter_rdata[0];
  assign mepc_o        = mepc_rdata;
  assign mie_o         = mie_rdata;
  assign mintstatus_o  = mintstatus_rdata;
  assign mintthresh_o  = mintthresh_rdata[7:0];
  assign mstatus_o     = mstatus_rdata;
  assign mtvec_addr_o  = mtvec_rdata.addr;
  assign mtvec_mode_o  = mtvec_rdata.mode;
  assign mtvt_addr_o   = mtvt_rdata.addr[31:(32-MTVT_ADDR_WIDTH)];

  assign priv_lvl_o    = priv_lvl_rdata;

  ////////////////////////////////////////////////////////////////////////
  //  ____       _                   _____     _                        //
  // |  _ \  ___| |__  _   _  __ _  |_   _| __(_) __ _  __ _  ___ _ __  //
  // | | | |/ _ \ '_ \| | | |/ _` |   | || '__| |/ _` |/ _` |/ _ \ '__| //
  // | |_| |  __/ |_) | |_| | (_| |   | || |  | | (_| | (_| |  __/ |    //
  // |____/ \___|_.__/ \__,_|\__, |   |_||_|  |_|\__, |\__, |\___|_|    //
  //                         |___/               |___/ |___/            //
  ////////////////////////////////////////////////////////////////////////

  // When DEBUG==0, DBG_NUM_TRIGGERS is assumed to be 0 as well.
  cv32e40x_debug_triggers
    #(
        .DBG_NUM_TRIGGERS (DBG_NUM_TRIGGERS),
        .A_EXT            (A_EXT)
    )
    debug_triggers_i
    (
      .clk                 ( clk                   ),
      .rst_n               ( rst_n                 ),

      // CSR inputs write inputs
      .csr_wdata_i         ( csr_wdata_int         ),
      .tselect_we_i        ( tselect_we            ),
      .tdata1_we_i         ( tdata1_we             ),
      .tdata2_we_i         ( tdata2_we             ),
      .tdata3_we_i         ( tdata3_we             ),
      .tinfo_we_i          ( tinfo_we              ),
      .tcontrol_we_i       ( tcontrol_we           ),

      // CSR read data outputs
      .tselect_rdata_o     ( tselect_rdata         ),
      .tdata1_rdata_o      ( tdata1_rdata          ),
      .tdata2_rdata_o      ( tdata2_rdata          ),
      .tdata3_rdata_o      ( tdata3_rdata          ),
      .tinfo_rdata_o       ( tinfo_rdata           ),
      .tcontrol_rdata_o    ( tcontrol_rdata        ),

      // IF stage inputs
      .pc_if_i             ( pc_if_i               ),
      .ptr_in_if_i         ( ptr_in_if_i           ),
      .priv_lvl_if_i       ( priv_lvl_if_i         ),

      // LSU inputs
      .lsu_valid_ex_i      ( lsu_valid_ex_i        ),
      .lsu_addr_ex_i       ( lsu_addr_ex_i         ),
      .lsu_we_ex_i         ( lsu_we_ex_i           ),
      .lsu_be_ex_i         ( lsu_be_ex_i           ),
      .priv_lvl_ex_i       ( id_ex_pipe_i.priv_lvl ),
      .lsu_atomic_ex_i     ( lsu_atomic_ex_i       ),

      // WB inputs
      .priv_lvl_wb_i       ( ex_wb_pipe_i.priv_lvl ),

      // Controller inputs
      .ctrl_fsm_i          ( ctrl_fsm_i            ),

      // Trigger match outputs
      .trigger_match_if_o  ( trigger_match_if_o    ),
      .trigger_match_ex_o  ( trigger_match_ex_o    ),
      .etrigger_wb_o       ( etrigger_wb_o         )
    );



  /////////////////////////////////////////////////////////////////
  //   ____            __     ____                  _            //
  // |  _ \ ___ _ __ / _|   / ___|___  _   _ _ __ | |_ ___ _ __  //
  // | |_) / _ \ '__| |_   | |   / _ \| | | | '_ \| __/ _ \ '__| //
  // |  __/  __/ |  |  _|  | |__| (_) | |_| | | | | ||  __/ |    //
  // |_|   \___|_|  |_|(_)  \____\___/ \__,_|_| |_|\__\___|_|    //
  //                                                             //
  /////////////////////////////////////////////////////////////////

  // Flop certain events to ease timing
  localparam bit [15:0] HPM_EVENT_FLOP     = 16'b1111_1111_1100_0000;

  // Calculate mask for MHPMCOUNTERS depending on how many that are implemented.
  localparam bit [28:0] MHPMCOUNTERS_MASK = (2 ** NUM_MHPMCOUNTERS) -1;
  // Set mask for mcountinhibit, include always included counters for mcycle and minstret.
  localparam bit [31:0] MCOUNTINHIBIT_MASK = (MHPMCOUNTERS_MASK << 3) | 3'b101;


  logic [15:0]          hpm_events_raw;
  logic                 all_counters_disabled;
  logic                 debug_stopcount;

  assign all_counters_disabled = &(mcountinhibit_n | ~MCOUNTINHIBIT_MASK);

  // dcsr.stopcount == 1: Don’t increment any counters while in Debug Mode.
  // The debug spec states that we should also not increment counters "on ebreak instructions that cause entry into debug mode",
  // but this implementation does not take ebreak instructions into account.
  // This is considered OK since most counter events (except wb_invalid and cycle) will be suppressed (in ctrl_fsm_i.mhpmevent) when we
  // have an ebreak causing debug mode entry in WB.
  assign debug_stopcount = dcsr_rdata.stopcount && ctrl_fsm_i.debug_mode;

  genvar                hpm_idx;
  generate
    for(hpm_idx=0; hpm_idx<16; hpm_idx++) begin
      if(HPM_EVENT_FLOP[hpm_idx]) begin: hpm_event_flop

        always_ff @(posedge clk, negedge rst_n) begin
          if (rst_n == 1'b0) begin
            hpm_events[hpm_idx] <= 1'b0;
          end else begin
            if(!all_counters_disabled) begin
              hpm_events[hpm_idx] <= hpm_events_raw[hpm_idx];
            end
          end
        end

      end
      else begin: hpm_even_no_flop
        assign hpm_events[hpm_idx] = hpm_events_raw[hpm_idx];
      end
    end
  endgenerate

  // ------------------------
  // Events to count
  assign hpm_events_raw[0]  = 1'b1;                               // Cycle counter
  assign hpm_events_raw[1]  = ctrl_fsm_i.mhpmevent.minstret;      // Instruction counter
  assign hpm_events_raw[2]  = ctrl_fsm_i.mhpmevent.compressed;    // Compressed instruction counter
  assign hpm_events_raw[3]  = ctrl_fsm_i.mhpmevent.jump;          // Nr of jumps (unconditional)
  assign hpm_events_raw[4]  = ctrl_fsm_i.mhpmevent.branch;        // Nr of branches (conditional)
  assign hpm_events_raw[5]  = ctrl_fsm_i.mhpmevent.branch_taken;  // Nr of taken branches (conditional)
  assign hpm_events_raw[6]  = ctrl_fsm_i.mhpmevent.intr_taken;    // Nr of interrupts taken (excluding NMI)
  assign hpm_events_raw[7]  = ctrl_fsm_i.mhpmevent.data_read;     // Data read. Nr of read transactions on the OBI data interface
  assign hpm_events_raw[8]  = ctrl_fsm_i.mhpmevent.data_write;    // Data write. Nr of write transactions on the OBI data interface
  assign hpm_events_raw[9]  = ctrl_fsm_i.mhpmevent.if_invalid;    // IF invalid (No valid output from IF when ID stage is ready)
  assign hpm_events_raw[10] = ctrl_fsm_i.mhpmevent.id_invalid;    // ID invalid (No valid output from ID when EX stage is ready)
  assign hpm_events_raw[11] = ctrl_fsm_i.mhpmevent.ex_invalid;    // EX invalid (No valid output from EX when WB stage is ready)
  assign hpm_events_raw[12] = ctrl_fsm_i.mhpmevent.wb_invalid;    // WB invalid (No valid output from WB)
  assign hpm_events_raw[13] = ctrl_fsm_i.mhpmevent.id_ld_stall;   // Nr of load use hazards
  assign hpm_events_raw[14] = ctrl_fsm_i.mhpmevent.id_jalr_stall; // Nr of jump (and link) register hazards
  assign hpm_events_raw[15] = ctrl_fsm_i.mhpmevent.wb_data_stall; // Nr of stall cycles caused in the WB stage by loads/stores

  // ------------------------
  // address decoder for performance counter registers
  logic mcountinhibit_we;
  logic mhpmevent_we;

  assign mcountinhibit_we = csr_we_int & (  csr_waddr == CSR_MCOUNTINHIBIT);
  assign mhpmevent_we     = csr_we_int & ( (csr_waddr == CSR_MHPMEVENT3  )||
                                           (csr_waddr == CSR_MHPMEVENT4  ) ||
                                           (csr_waddr == CSR_MHPMEVENT5  ) ||
                                           (csr_waddr == CSR_MHPMEVENT6  ) ||
                                           (csr_waddr == CSR_MHPMEVENT7  ) ||
                                           (csr_waddr == CSR_MHPMEVENT8  ) ||
                                           (csr_waddr == CSR_MHPMEVENT9  ) ||
                                           (csr_waddr == CSR_MHPMEVENT10 ) ||
                                           (csr_waddr == CSR_MHPMEVENT11 ) ||
                                           (csr_waddr == CSR_MHPMEVENT12 ) ||
                                           (csr_waddr == CSR_MHPMEVENT13 ) ||
                                           (csr_waddr == CSR_MHPMEVENT14 ) ||
                                           (csr_waddr == CSR_MHPMEVENT15 ) ||
                                           (csr_waddr == CSR_MHPMEVENT16 ) ||
                                           (csr_waddr == CSR_MHPMEVENT17 ) ||
                                           (csr_waddr == CSR_MHPMEVENT18 ) ||
                                           (csr_waddr == CSR_MHPMEVENT19 ) ||
                                           (csr_waddr == CSR_MHPMEVENT20 ) ||
                                           (csr_waddr == CSR_MHPMEVENT21 ) ||
                                           (csr_waddr == CSR_MHPMEVENT22 ) ||
                                           (csr_waddr == CSR_MHPMEVENT23 ) ||
                                           (csr_waddr == CSR_MHPMEVENT24 ) ||
                                           (csr_waddr == CSR_MHPMEVENT25 ) ||
                                           (csr_waddr == CSR_MHPMEVENT26 ) ||
                                           (csr_waddr == CSR_MHPMEVENT27 ) ||
                                           (csr_waddr == CSR_MHPMEVENT28 ) ||
                                           (csr_waddr == CSR_MHPMEVENT29 ) ||
                                           (csr_waddr == CSR_MHPMEVENT30 ) ||
                                           (csr_waddr == CSR_MHPMEVENT31 ) );

  // ------------------------
  // Increment value for performance counters
  genvar incr_gidx;
  generate
    for (incr_gidx=0; incr_gidx<32; incr_gidx++) begin : gen_mhpmcounter_increment
      assign mhpmcounter_increment[incr_gidx] = mhpmcounter_rdata[incr_gidx] + 1;
    end
  endgenerate

  // ------------------------
  // next value for performance counters and control registers
  always_comb
    begin
      mcountinhibit_n = mcountinhibit_rdata;
      mhpmevent_n     = mhpmevent_rdata;


      // Inhibit Control
      if(mcountinhibit_we)
        mcountinhibit_n = csr_wdata_int & MCOUNTINHIBIT_MASK;

      // Event Control
      if(mhpmevent_we)
        mhpmevent_n[csr_waddr[4:0]] = csr_wdata_int;
    end

  genvar wcnt_gidx;
  generate
    for (wcnt_gidx=0; wcnt_gidx<32; wcnt_gidx++) begin : gen_mhpmcounter_write

      // Write lower counter bits
      assign mhpmcounter_write_lower[wcnt_gidx] = csr_we_int && (csr_waddr == (CSR_MCYCLE + wcnt_gidx));

      // Write upper counter bits
      assign mhpmcounter_write_upper[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                  csr_we_int && (csr_waddr == (CSR_MCYCLEH + wcnt_gidx));

      // Increment counter

      if (wcnt_gidx == 0) begin : gen_mhpmcounter_mcycle
        // mcycle = mhpmcounter[0] : count every cycle (if not inhibited)
        assign mhpmcounter_write_increment[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                        !mhpmcounter_write_upper[wcnt_gidx] &&
                                                        !mcountinhibit_rdata[wcnt_gidx] &&
                                                        !debug_stopcount;
      end else if (wcnt_gidx == 2) begin : gen_mhpmcounter_minstret
        // minstret = mhpmcounter[2]  : count every retired instruction (if not inhibited)
        assign mhpmcounter_write_increment[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                        !mhpmcounter_write_upper[wcnt_gidx] &&
                                                        !mcountinhibit_rdata[wcnt_gidx] &&
                                                        !debug_stopcount &&
                                                        hpm_events[1];
      end else if( (wcnt_gidx>2) && (wcnt_gidx<(NUM_MHPMCOUNTERS+3))) begin : gen_mhpmcounter
        // add +1 if any event is enabled and active
        assign mhpmcounter_write_increment[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                        !mhpmcounter_write_upper[wcnt_gidx] &&
                                                        !mcountinhibit_rdata[wcnt_gidx] &&
                                                        !debug_stopcount &&
                                                        |(hpm_events & mhpmevent_rdata[wcnt_gidx][NUM_HPM_EVENTS-1:0]);
      end else begin : gen_mhpmcounter_not_implemented
        assign mhpmcounter_write_increment[wcnt_gidx] = 1'b0;
      end

    end
  endgenerate

  // ------------------------
  // HPM Registers
  // next value
  genvar nxt_gidx;
  generate
    for (nxt_gidx = 0; nxt_gidx < 32; nxt_gidx++) begin : gen_mhpmcounter_nextvalue
      // mcyclce  is located at index 0
      // there is no counter at index 1
      // minstret is located at index 2
      // Programable HPM counters start at index 3
      if( (nxt_gidx == 1) ||
          (nxt_gidx >= (NUM_MHPMCOUNTERS+3) ) )
        begin : gen_non_implemented
          assign mhpmcounter_n[nxt_gidx]  = 'b0;
          assign mhpmcounter_we[nxt_gidx] = 2'b0;
      end
      else begin : gen_implemented_nextvalue
        always_comb begin
          mhpmcounter_we[nxt_gidx] = 2'b0;
          mhpmcounter_n[nxt_gidx]  = mhpmcounter_rdata[nxt_gidx];
          if (mhpmcounter_write_lower[nxt_gidx]) begin
            mhpmcounter_n[nxt_gidx][31:0] = csr_wdata_int;
            mhpmcounter_we[nxt_gidx][0] = 1'b1;
          end else if (mhpmcounter_write_upper[nxt_gidx]) begin
            mhpmcounter_n[nxt_gidx][63:32] = csr_wdata_int;
            mhpmcounter_we[nxt_gidx][1] = 1'b1;
          end else if (mhpmcounter_write_increment[nxt_gidx]) begin
            mhpmcounter_we[nxt_gidx] = 2'b11;
            mhpmcounter_n[nxt_gidx] = mhpmcounter_increment[nxt_gidx];
          end
        end // always_comb
      end
    end
  endgenerate
  //  Counter Registers: mhpcounter_q[]
  genvar cnt_gidx;
  generate
    for (cnt_gidx = 0; cnt_gidx < 32; cnt_gidx++) begin : gen_mhpmcounter
      // mcyclce  is located at index 0
      // there is no counter at index 1
      // minstret is located at index 2
      // Programable HPM counters start at index 3
      if( (cnt_gidx == 1) ||
          (cnt_gidx >= (NUM_MHPMCOUNTERS+3) ) )
        begin : gen_non_implemented
        assign mhpmcounter_q[cnt_gidx] = 'b0;
      end
      else begin : gen_implemented
        always_ff @(posedge clk, negedge rst_n)
          if (!rst_n) begin
            mhpmcounter_q[cnt_gidx] <= 'b0;
          end else begin
            if (mhpmcounter_we[cnt_gidx][0]) begin
              mhpmcounter_q[cnt_gidx][31:0] <= mhpmcounter_n[cnt_gidx][31:0];
            end
            if (mhpmcounter_we[cnt_gidx][1]) begin
              mhpmcounter_q[cnt_gidx][63:32] <= mhpmcounter_n[cnt_gidx][63:32];
            end
          end
      end
      assign mhpmcounter_rdata[cnt_gidx] = mhpmcounter_q[cnt_gidx];
    end
  endgenerate

  //  Event Register: mhpevent_q[]
  genvar evt_gidx;
  generate
    for (evt_gidx = 0; evt_gidx < 32; evt_gidx++) begin : gen_mhpmevent
      // programable HPM events start at index3
      if( (evt_gidx < 3) ||
          (evt_gidx >= (NUM_MHPMCOUNTERS+3) ) )
        begin : gen_non_implemented
        assign mhpmevent_q[evt_gidx] = 'b0;
      end
      else begin : gen_implemented
        if (NUM_HPM_EVENTS < 32) begin : gen_tie_off
             assign mhpmevent_q[evt_gidx][31:NUM_HPM_EVENTS] = 'b0;
        end
        always_ff @(posedge clk, negedge rst_n)
            if (!rst_n)
                mhpmevent_q[evt_gidx][NUM_HPM_EVENTS-1:0]  <= 'b0;
            else
                mhpmevent_q[evt_gidx][NUM_HPM_EVENTS-1:0]  <= mhpmevent_n[evt_gidx][NUM_HPM_EVENTS-1:0] ;
      end
      assign mhpmevent_rdata[evt_gidx] = mhpmevent_q[evt_gidx];
    end
  endgenerate

  //  Inhibit Register: mcountinhibit_q
  //  Note: implemented counters are disabled out of reset to save power
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      mcountinhibit_q <= MCOUNTINHIBIT_MASK; // default disable
    end else begin
      mcountinhibit_q <= mcountinhibit_n;
    end
  end

  assign mcountinhibit_rdata = mcountinhibit_q;

  // Assign values used for setting rmask in RVFI
  assign mscratchcsw_in_wb  = ex_wb_pipe_i.csr_en && (csr_waddr == CSR_MSCRATCHCSW);
  assign mscratchcswl_in_wb = ex_wb_pipe_i.csr_en && (csr_waddr == CSR_MSCRATCHCSWL);
  assign mnxti_in_wb        = ex_wb_pipe_i.csr_en && (csr_waddr == CSR_MNXTI);

  // Some signals are unused on purpose (typically they are used by RVFI code). Use them here for easier LINT waiving.

  assign unused_signals = mstatush_we | misa_we | mip_we | mvendorid_we |
    marchid_we | mimpid_we | mhartid_we | mconfigptr_we | mtval_we | (|mnxti_n) | mscratchcsw_we | mscratchcswl_we |
    (|mscratchcsw_rdata) | (|mscratchcswl_rdata) | (|mscratchcsw_n) | (|mscratchcswl_n) |
    mscratchcsw_in_wb | mscratchcswl_in_wb | mnxti_in_wb;

endmodule
