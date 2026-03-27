// Copyright 2021 Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License").
//
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
//
// You may obtain a copy of the License at:
//
//     https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof distributed under the License
// is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
//
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Arjan Bink - arjan.bink@silabs.com                         //
//                                                                            //
// Additional contributions by:                                               //
//                 Øystein Knauserud - oystein.knauserud@silabs.com          //
//                 Michael Platzer - michael.platzer@tuwien.ac.at             //
//                                                                            //
// Design Name:    Write Back stage                                           //
// Project Name:   CV32E40X                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Write back stage: Hosts write back from load/store unit    //
//                 and combined write back from ALU/MULT/DIV/CSR.             //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_wb_stage import cv32e40x_pkg::*;
#(
    parameter bit DEBUG = 1
)
(
  input  logic          clk,            // Not used in RTL; only used by assertions
  input  logic          rst_n,          // Not used in RTL; only used by assertions

  // EX/WB pipeline
  input  ex_wb_pipe_t   ex_wb_pipe_i,

  // Controller
  input  ctrl_fsm_t     ctrl_fsm_i,

  // LSU
  input  logic [31:0]   lsu_rdata_i,
  input  mpu_status_e   lsu_mpu_status_i,
  input  logic          lsu_wpt_match_i,
  input  align_status_e lsu_align_status_i,

  // Register file interface
  output logic          rf_we_wb_o,     // Register file write enable
  output rf_addr_t      rf_waddr_wb_o,  // Register file write address
  output logic [31:0]   rf_wdata_wb_o,  // Register file write data

  // LSU handshake interface
  input  logic          lsu_valid_i,
  output logic          lsu_ready_o,
  output logic          lsu_valid_o,
  input  logic          lsu_ready_i,

  // WB stalled by LSU
  output logic          data_stall_o,

  // Stage ready/valid
  output logic          wb_ready_o,
  output logic          wb_valid_o,

  // eXtension interface
  if_xif.cpu_result     xif_result_if,

  // Sticky WB outputs
  output logic          wpt_match_wb_o,
  output mpu_status_e   mpu_status_wb_o,
  output align_status_e align_status_wb_o,

  // From cs_registers
  input logic [31:0]    clic_pa_i,
  input logic           clic_pa_valid_i,

  output logic          last_op_o,
  output logic          abort_op_o
);

  logic                 instr_valid;
  logic                 wb_valid;
  logic                 lsu_exception;

  // eXtension interface signals
  logic                 xif_waiting;
  logic                 xif_exception;

  // Flops for making volatile LSU outputs sticky until wb_valid
  mpu_status_e          lsu_mpu_status_q;
  logic                 lsu_wpt_match_q;
  align_status_e        lsu_align_status_q;
  logic                 lsu_valid_q;

  mpu_status_e          lsu_mpu_status;
  logic                 lsu_wpt_match;
  align_status_e        lsu_align_status;
  logic                 lsu_valid;
  // WB stage has two halt sources, ctrl_fsm_i.halt_wb and ctrl_fsm_i.halt_limited_wb. The limited halt is only set during
  // the SLEEP state, and is used to prevent timing paths from interrupt inputs to obi outputs when waking up from SLEEP.
  assign instr_valid = ex_wb_pipe_i.instr_valid && !ctrl_fsm_i.kill_wb && !ctrl_fsm_i.halt_wb && !ctrl_fsm_i.halt_limited_wb;

  assign lsu_exception = (lsu_mpu_status != MPU_OK) || (lsu_align_status != ALIGN_OK);


  //////////////////////////////////////////////////////////////////////////////
  // Register file interface
  //
  // Note that write back is not suppressed during bus errors (in order to prevent
  // a timing path from the late arriving data_err_i into the register file).
  //
  // Note that the register file is only written for the last part of a split misaligned load.
  // (rf_we suppressed in ex_stage for the first part, lsu aggregates data for second part)
  //
  // Note that the register file is written multiple times in case waited loads (in
  // order to prevent a timing path from the late arriving data_rvalid_i into the
  // register file.
  //
  // In case of MPU/PMA error, the register file should not be written.
  // rf_we_wb_o is deasserted if lsu_mpu_status is not equal to MPU_OK

  // TODO: Could use result interface.we into account if out of order completion is allowed.
  assign rf_we_wb_o     = ex_wb_pipe_i.rf_we && !lsu_exception && !xif_waiting && !xif_exception && !lsu_wpt_match && instr_valid;
  // TODO: Could use result interface.rd into account if out of order completion is allowed.
  assign rf_waddr_wb_o  = ex_wb_pipe_i.rf_waddr;
  // TODO: Could use result interface.rd into account if out of order completion is allowed.
  // Not using any flopped/sticky version of lsu_rdata_i. The sticky bits are only needed for MPU errors and watchpoint triggers.
  // Any true load that succeeds will write the RF and will never be halted or killed by the controller. (wb_valid during the same cycle as lsu_valid_i).
  assign rf_wdata_wb_o  = ex_wb_pipe_i.lsu_en ? lsu_rdata_i               :
                         (ex_wb_pipe_i.xif_en ? xif_result_if.result.data :
                         clic_pa_valid_i      ? clic_pa_i                 :
                         ex_wb_pipe_i.rf_wdata);

  //////////////////////////////////////////////////////////////////////////////
  // LSU inputs are valid when LSU is enabled; LSU outputs need to remain valid until downstream stage is ready

  // Does not depend on local instr_valid (i.e. kept high for stalls and kills)
  // Ok, as controller will never kill ongoing LSU instructions, and thus
  // the lsu valid_1_o which lsu_valid_o factors into should not be affected.
  assign lsu_valid_o = ex_wb_pipe_i.lsu_en && ex_wb_pipe_i.instr_valid;
  assign lsu_ready_o = 1'b1; // Always ready (there is no downstream stage)

  //////////////////////////////////////////////////////////////////////////////
  // Stage ready/valid

  // Using both ctrl_fsm_i.halt_wb and ctrl_fsm_i.halt_limited_wb to halt.
  assign wb_ready_o = ctrl_fsm_i.kill_wb || (lsu_ready_i && !xif_waiting && !ctrl_fsm_i.halt_wb && !ctrl_fsm_i.halt_limited_wb);

  // wb_valid
  //
  // - Will be 0 for interrupted instruction and debug entry
  // - Will be 1 for synchronous exceptions (which is easier to deal with for RVFI); this implies that wb_valid
  //   cannot be used to increment the minstret CSR (as that should not increment for e.g. ecall, ebreak, etc.)
  // - Will be 1 for both phases of a split misaligned load/store that completes without MPU errors.
  //   If an MPU error occurs, wb_valid will be 1 due to lsu_exception (for any phase where the error occurs)
  // - Will be 0 for CLIC pointer fetches todo: Do we need wb_valid=1 for faulted pointer fetches for RVFI?
  assign wb_valid = ((!ex_wb_pipe_i.lsu_en && !xif_waiting) ||    // Non-LSU instructions have valid result in WB, also for exceptions, unless we are waiting for a coprocessor
                     ( ex_wb_pipe_i.lsu_en && lsu_valid   )       // LSU instructions have valid result based on data_rvalid_i or the flopped version in case of watchpoint triggers.
                                                                  // todo: ideally a similar line is added here that delays signaling wb_valid until a WFI really retires.
                                                                  // This should be checked for bad timing paths. Currently RVFI contains a wb_valid_adjusted signal/hack to achieve the same
                    ) && instr_valid;

  // Letting all suboperations signal wb_valid
  assign wb_valid_o = wb_valid;

  // Signal that WB stage contains the last operation of an instruction
  assign last_op_o = ex_wb_pipe_i.last_op;

  // Append any MPU exception to abort_op
  // An abort_op_o = 1 will terminate a sequence, either to take an exception or debug due to trigger match.
  assign abort_op_o = ex_wb_pipe_i.abort_op || ( ex_wb_pipe_i.lsu_en && lsu_exception) || (ex_wb_pipe_i.lsu_en && lsu_wpt_match);

  // Export signal indicating WB stage stalled by load/store
  assign data_stall_o = ex_wb_pipe_i.lsu_en && !lsu_valid && instr_valid;

  // Flops for sticky LSU signals
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      lsu_valid_q <= 1'b0;
      lsu_wpt_match_q <= 1'b0;
      lsu_mpu_status_q <= MPU_OK;
      lsu_align_status_q <= ALIGN_OK;
    end else begin
      if (wb_valid || ctrl_fsm_i.kill_wb) begin
        // Clear sticky LSU bits when WB is done
        lsu_valid_q <= 1'b0;
        lsu_wpt_match_q <= 1'b0;
        lsu_mpu_status_q <= MPU_OK;
        lsu_align_status_q <= ALIGN_OK;
      end else begin
        if (lsu_valid_i) begin
          lsu_valid_q <= 1'b1;
          lsu_wpt_match_q <= lsu_wpt_match;
          lsu_mpu_status_q <= lsu_mpu_status;
          lsu_align_status_q <= lsu_align_status;
        end
      end
    end
  end

  assign lsu_valid        = lsu_valid_q ? lsu_valid_q        : lsu_valid_i;
  assign lsu_wpt_match    = lsu_valid_q ? lsu_wpt_match_q    : lsu_wpt_match_i;
  assign lsu_mpu_status   = lsu_valid_q ? lsu_mpu_status_q   : lsu_mpu_status_i;
  assign lsu_align_status = lsu_valid_q ? lsu_align_status_q : lsu_align_status_i;

  assign wpt_match_wb_o = lsu_wpt_match;
  assign mpu_status_wb_o = lsu_mpu_status;
  assign align_status_wb_o = lsu_align_status;
  //---------------------------------------------------------------------------
  // eXtension interface
  //---------------------------------------------------------------------------

  // TODO: How to handle conflicting values of ex_wb_pipe_i.rf_waddr and xif_result_if.result.rd?
  // TODO: How to handle conflicting values of ex_wb_pipe_i.rf_we (based on xif_issue_if.issue_resp.writeback in ID) and xif_result_if.result.we?
  // TODO: Check whether result IDs match the instruction IDs propagated along the pipeline
  // TODO: Implement writeback to extension context status into mstatus (ecswe, ecsdata)

  // Need to wait for the result
  assign xif_waiting = ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.xif_en && !xif_result_if.result_valid;

  // Coprocessor signals a synchronous exception
  // TODO: Maybe do something when an exception occurs (other than just inhibiting writeback)
  assign xif_exception = ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.xif_en && xif_result_if.result_valid && xif_result_if.result.exc;

  // todo: Handle xif_result_if.result.err as NMI (do not factor into xif_exception as that signal is for synchronous exceptions)

  assign xif_result_if.result_ready = ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.xif_en;

endmodule
