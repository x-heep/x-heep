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
// Engineer:       Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Additional contributions by:                                               //
//                                                                            //
// Design Name:    Interrupt Controller                                       //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Basic Interrupt Controller                                 //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_int_controller import cv32e40x_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // External interrupt lines
  input  logic [31:0] irq_i,                    // Level-triggered interrupt inputs

  // To controller
  output logic        irq_req_ctrl_o,
  output logic  [4:0] irq_id_ctrl_o,
  output logic        irq_wu_ctrl_o,

  // From cs_registers
  input  logic [31:0] mie_i,                    // MIE CSR
  input  mstatus_t    mstatus_i,                // MSTATUS CSR
  input  privlvl_t    priv_lvl_i,               // Current privilege level of core

  // To cs_registers
  output logic [31:0] mip_o                     // MIP CSR
);

  logic        global_irq_enable;
  logic [31:0] irq_local_qual;
  logic [31:0] irq_q;

  // Register all interrupt inputs (on gated clock). The wake-up logic will
  // observe irq_i as well, but in all other places irq_q will be used to
  // avoid timing paths from irq_i to instr_*_o

  always_ff @(posedge clk, negedge rst_n)
  begin
    if (rst_n == 1'b0) begin
      irq_q <= '0;
    end else begin
      irq_q <= irq_i & IRQ_MASK;
    end
  end

  // MIP CSR
  assign mip_o = irq_q;

  // Qualify registered IRQ with MIE CSR to compute locally enabled IRQs
  assign irq_local_qual = irq_q & mie_i;

  // Wake-up signal based on unregistered IRQ such that wake-up can be caused if no clock is present
  assign irq_wu_ctrl_o = |(irq_i & mie_i);

  // Global interrupt enable
  assign global_irq_enable = mstatus_i.mie || (priv_lvl_i < PRIV_LVL_M);

  // Request to take interrupt if there is a locally enabled interrupt while interrupts are also enabled globally
  assign irq_req_ctrl_o = (|irq_local_qual) && global_irq_enable;

  // Interrupt Encoder
  //
  // - sets correct id to request to ID
  // - encodes priority order

  always_comb
  begin
    if      (irq_local_qual[31]) irq_id_ctrl_o = 5'd31;                         // Custom irq_i[31]
    else if (irq_local_qual[30]) irq_id_ctrl_o = 5'd30;                         // Custom irq_i[30]
    else if (irq_local_qual[29]) irq_id_ctrl_o = 5'd29;                         // Custom irq_i[29]
    else if (irq_local_qual[28]) irq_id_ctrl_o = 5'd28;                         // Custom irq_i[28]
    else if (irq_local_qual[27]) irq_id_ctrl_o = 5'd27;                         // Custom irq_i[27]
    else if (irq_local_qual[26]) irq_id_ctrl_o = 5'd26;                         // Custom irq_i[26]
    else if (irq_local_qual[25]) irq_id_ctrl_o = 5'd25;                         // Custom irq_i[25]
    else if (irq_local_qual[24]) irq_id_ctrl_o = 5'd24;                         // Custom irq_i[24]
    else if (irq_local_qual[23]) irq_id_ctrl_o = 5'd23;                         // Custom irq_i[23]
    else if (irq_local_qual[22]) irq_id_ctrl_o = 5'd22;                         // Custom irq_i[22]
    else if (irq_local_qual[21]) irq_id_ctrl_o = 5'd21;                         // Custom irq_i[21]
    else if (irq_local_qual[20]) irq_id_ctrl_o = 5'd20;                         // Custom irq_i[20]
    else if (irq_local_qual[19]) irq_id_ctrl_o = 5'd19;                         // Custom irq_i[19]
    else if (irq_local_qual[18]) irq_id_ctrl_o = 5'd18;                         // Custom irq_i[18]
    else if (irq_local_qual[17]) irq_id_ctrl_o = 5'd17;                         // Custom irq_i[17]
    else if (irq_local_qual[16]) irq_id_ctrl_o = 5'd16;                         // Custom irq_i[16]

    // Reserved: irq_local_qual[15], irq_id_ctrl_o = 5'd15
    // Reserved: irq_local_qual[14], irq_id_ctrl_o = 5'd14
    // Reserved: irq_local_qual[13], irq_id_ctrl_o = 5'd13
    // Reserved: irq_local_qual[12], irq_id_ctrl_o = 5'd12

    else if (irq_local_qual[CSR_MEIX_BIT]) irq_id_ctrl_o = CSR_MEIX_BIT;        // MEI, irq_i[11]
    else if (irq_local_qual[CSR_MSIX_BIT]) irq_id_ctrl_o = CSR_MSIX_BIT;        // MSI, irq_i[3]
    else                                   irq_id_ctrl_o = CSR_MTIX_BIT;        // MTI, irq_i[7]

    // Reserved: irq_local_qual[10], irq_id_ctrl_o = 5'd10
    // Reserved: irq_local_qual[ 2], irq_id_ctrl_o = 5'd2
    // Reserved: irq_local_qual[ 6], irq_id_ctrl_o = 5'd6

    // Reserved: irq_local_qual[ 9], irq_id_ctrl_o = 5'd9, SEI
    // Reserved: irq_local_qual[ 1], irq_id_ctrl_o = 5'd1, SSI
    // Reserved: irq_local_qual[ 5], irq_id_ctrl_o = 5'd5, STI

    // Reserved: irq_local_qual[ 8], irq_id_ctrl_o = 5'd8, UEI
    // Reserved: irq_local_qual[ 0], irq_id_ctrl_o = 5'd0, USI
    // Reserved: irq_local_qual[ 4], irq_id_ctrl_o = 5'd4, UTI

  end

endmodule
