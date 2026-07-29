// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Hybrid modular redundancy Rapid Recovery control unit

module hmr_rapid_recovery_ctrl
  import rapid_recovery_pkg::*;
#(
  parameter int unsigned RFAddrWidth = 6,
  parameter     type     regfile_write_t = logic
) (
  input  logic clk_i,
  input  logic rst_ni,
  // input  logic test_en_i,

  input  logic start_recovery_i,
  output logic recovery_finished_o,

  // Signals to core
  output logic setback_o,
  output logic instr_lock_o,
  output logic debug_req_o,
  input  logic debug_halt_i,
  output logic debug_resume_o,
  output regfile_write_t recovery_regfile_waddr_o,

  // Signals to backup state
  output logic backup_enable_o,
  output logic recover_csr_enable_o,
  output logic recover_pc_enable_o,
  output logic recover_rf_enable_o
);

  typedef enum logic [1:0] {IDLE, RESET, HALT, RESTORE} recovery_mode_e;
  recovery_mode_e rec_mode_d, rec_mode_q;

  logic instr_lock_d, instr_lock_q;
  logic setback_d, setback_q;
  logic addr_gen_done;
  logic [RFAddrWidth-1:0] addr_gen_result;

  DMR_address_generator #(
    .AddrWidth ( RFAddrWidth )
  ) i_rf_address_generator (
    .clk_i,
    .rst_ni,
    .clear_i   ('0),
    .enable_i  ( recover_rf_enable_o ),
    .done_o    ( addr_gen_done ),
    .fatal_o   (),
    .address_o (addr_gen_result)
  );

  assign recovery_regfile_waddr_o.we_a = recover_rf_enable_o;
  assign recovery_regfile_waddr_o.waddr_a = addr_gen_result;
  assign recovery_regfile_waddr_o.wdata_a = '0;
  assign recovery_regfile_waddr_o.we_b = recover_rf_enable_o;
  assign recovery_regfile_waddr_o.waddr_b = 16 + addr_gen_result;
  assign recovery_regfile_waddr_o.wdata_b = '0;


  assign instr_lock_o = instr_lock_q;
  assign setback_o = setback_q;

  always_comb begin
    rec_mode_d = rec_mode_q;
    instr_lock_d = instr_lock_q;
    backup_enable_o = 1'b0;
    setback_d = 1'b0;
    debug_req_o = 1'b0;
    recover_csr_enable_o = 1'b0;
    recover_pc_enable_o = 1'b0;
    recover_rf_enable_o = 1'b0;
    debug_resume_o = 1'b0;
    recovery_finished_o = 1'b0;

    case (rec_mode_q)
      IDLE: begin
        backup_enable_o = 1'b1;
        // If requested start the routine in the reset state
        if (start_recovery_i) begin
          // Disable all backups
          backup_enable_o = 1'b0;
          rec_mode_d = RESET;
        end
      end

      RESET: begin
        // Clear the core state
        setback_d = 1'b1;
        // Lock the instruction requests
        instr_lock_d = 1'b1;
        // Go to request halt of the core
        rec_mode_d = HALT;
      end

      HALT: begin
        // Requesst a debug halt
        debug_req_o = 1'b1;
        // Wait until the core has halted
        if (debug_halt_i) begin
          rec_mode_d = RESTORE;
        end
      end

      RESTORE: begin
        // Enable CSR recovery routine
        recover_csr_enable_o = 1'b1;
        // Enable the PC recovery routine
        recover_pc_enable_o = 1'b1;
        // Enable the RF recovery routine
        recover_rf_enable_o = 1'b1;
        // If recovery routine complete, continue
        if (addr_gen_done) begin
          instr_lock_d = 1'b0;
          rec_mode_d = IDLE;
          debug_resume_o = 1'b1;
          recovery_finished_o = 1'b1;
        end
      end

      // Default: do nothing
      default: ;
    endcase
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      instr_lock_q <= 1'b0;
      rec_mode_q <= IDLE;
      setback_q <= 1'b0;
    end else begin
      instr_lock_q <= instr_lock_d;
      rec_mode_q <= rec_mode_d;
      setback_q <= setback_d;
    end
  end

endmodule
