// Copyright 2022 Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License");
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineers       Oystein Knauserud -     oystein.knauserud@silabs.com       //
//                                                                            //
// Design Name:    CLIC int controller                                        //
// Project Name:   CV32E40X                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Controller for handling CLIC interrupts                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_clic_int_controller import cv32e40x_pkg::*;
#(
  parameter int unsigned CLIC_ID_WIDTH = 5
)
(
  input  logic                       clk,
  input  logic                       rst_n,

  // CLIC interface
  input  logic                       clic_irq_i,                // CLIC interrupt pending
  input  logic [CLIC_ID_WIDTH-1:0] clic_irq_id_i,               // ID of pending interrupt
  input  logic [7:0]                 clic_irq_level_i,          // Level of pending interrupt
  input  logic [1:0]                 clic_irq_priv_i,           // Privilege level of pending interrupt (always machine mode) (not used)
  input  logic                       clic_irq_shv_i,            // Is pending interrupt vectored?

  // To controller
  output logic                       irq_req_ctrl_o,
  output logic [9:0]                 irq_id_ctrl_o,             // Max width - unused bits are tied off
  output logic                       irq_wu_ctrl_o,
  output logic                       irq_clic_shv_o,
  output logic [7:0]                 irq_clic_level_o,
  output logic [1:0]                 irq_clic_priv_o,

  // From cs_registers
  input  mstatus_t                   mstatus_i,                 // Current mstatus from CSR
  input  logic [7:0]                 mintthresh_i,              // Current interrupt threshold from CSR
  input  mintstatus_t                mintstatus_i,              // Current mintstatus from CSR
  input  mcause_t                    mcause_i,                  // Current mcause from CSR
  input  privlvl_t                   priv_lvl_i,                // Current privilege level of core

  // To cs_registers
  output logic                       mnxti_irq_pending_o,       // An interrupt is available to the mnxti CSR read
  output logic [CLIC_ID_WIDTH-1:0]   mnxti_irq_id_o,            // The id of the availble mnxti interrupt
  output logic [7:0]                 mnxti_irq_level_o          // Level of the available interrupt
);

  logic                       global_irq_enable;
  logic  [7:0]                effective_irq_level;              // Effective interrupt level

  // Flops for breaking timing path to instruction interface
  logic                       clic_irq_q;
  logic [CLIC_ID_WIDTH-1:0]   clic_irq_id_q;
  logic [7:0]                 clic_irq_level_q;
  logic                       clic_irq_shv_q;

  logic                       unused_signals;

  // Register interrupt input (on gated clock). The wake-up logic will
  // observe clic_irq_i as well, but in all other places clic_irq_q will be used to
  // avoid timing paths from clic_irq_i to instr_*_o

  always_ff @(posedge clk, negedge rst_n)
  begin
    if (rst_n == 1'b0) begin
      clic_irq_q  <= 1'b0;
    end else begin
      clic_irq_q  <= clic_irq_i;
    end
  end

  // Flop all irq inputs to break timing paths through the controller.
  always_ff @(posedge clk, negedge rst_n)
  begin
    if (rst_n == 1'b0) begin
      clic_irq_id_q     <= '0;
      clic_irq_level_q  <= '0;
      clic_irq_shv_q    <= 1'b0;
    end else begin
      if (clic_irq_i) begin
        clic_irq_id_q    <= clic_irq_id_i;
        clic_irq_level_q <= clic_irq_level_i;
        clic_irq_shv_q   <= clic_irq_shv_i;
      end
    end
  end

  // Global interrupt enable
  //
  // Machine mode interrupts are always enabled when in a lower privilege mode.

  assign global_irq_enable = mstatus_i.mie || (priv_lvl_i < PRIV_LVL_M);

  // Effective interrupt level
  //
  // The interrupt-level threshold is only valid when running in the associated privilege mode.

  assign effective_irq_level = (mintthresh_i > mintstatus_i.mil) ? mintthresh_i : mintstatus_i.mil;

  ///////////////////////////
  // Outputs to controller //
  ///////////////////////////

  // Request to take interrupt if there is a pending-and-enabled interrupt, interrupts are enabled globally,
  // and the incoming irq level is above the core's current effective interrupt level. Machine mode interrupts
  // during user mode shall always be taken if their level is > 0

  assign irq_req_ctrl_o = clic_irq_q && global_irq_enable &&
    ((priv_lvl_i == PRIV_LVL_M) ? (clic_irq_level_q > effective_irq_level) : (clic_irq_level_q > '0));

  // Pass on interrupt ID
  assign irq_id_ctrl_o = 10'(clic_irq_id_q);  // Casting into max with of 10 bits.

  // Wake-up signal based on unregistered IRQ such that wake-up can be caused if no clock is present
  //
  // Wakeup scenarios:
  //
  // - priv mode == current, irq i is max (done in external CLIC), level > max(mintstatus.mil, mintthresh.th)
  // - priv mode  > current, irq i is max (done in external CLIC), level != 0

  // todo: can we share the comparator below and flop the result for irq_req_ctrl_o?
  assign irq_wu_ctrl_o = clic_irq_i &&
    ((priv_lvl_i == PRIV_LVL_M) ? (clic_irq_level_i > effective_irq_level) : (clic_irq_level_i > '0));

  assign irq_clic_shv_o = clic_irq_shv_q;

  assign irq_clic_level_o = clic_irq_level_q;

  // Take all interrupts into machine mode. clic_irq_priv_i not used on purpose.
  assign irq_clic_priv_o = PRIV_LVL_M;

  ///////////////////////////
  // Outputs for mnxti CSR //
  ///////////////////////////

  // The outputs for mnxti will only be used within cs_registers when a CSR instruction is accessing mnxti
  // The mxnti path to interrupts does not take mstatus.mie or dcsr.stepie into account.
  assign mnxti_irq_pending_o = clic_irq_q &&
    (clic_irq_level_q > mcause_i.mpil) &&
    (clic_irq_level_q > mintthresh_i)  &&
    !clic_irq_shv_q;

  // If mnxti_irq_pending is true, the currently flopped ID and level will be sent to cs_registers
  // for use in the function pointer and CSR side effects.
  // Using native CLIC_ID_WIDTH for cleaner pointer concatenation in cs_registers.

  assign mnxti_irq_id_o    = clic_irq_id_q;
  assign mnxti_irq_level_o = clic_irq_level_q;

  // Unused signals
  //
  // clic_irq_priv_i is not used on purpose. It is required to be tied to machine mode.
  // All interrupts are taken into machine mode.

  assign unused_signals = |clic_irq_priv_i;

endmodule
