// Copyright 2022 Silicon Labs, Inc.
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
// Engineer:       Øystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Design Name:    cv32e40x_clic_int_controller_sva                           //
// Project Name:   CV32E40X                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Assertions reltated to the CLIC interrupt controller       //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_clic_int_controller_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
  (
   input logic        clk,
   input logic        rst_n,

   input logic        irq_req_ctrl_o,
   input logic        clic_irq_q,
   input logic [7:0]  clic_irq_level_q,

   input logic        ctrl_pending_interrupt,
   input logic        ctrl_interrupt_allowed,
   input logic        ctrl_pending_nmi,
   input logic        ctrl_pending_async_debug,
   input ctrl_state_e ctrl_fsm_cs,

   input ctrl_fsm_t   ctrl_fsm,
   input dcsr_t       dcsr

   );


  // Check that a pending interrupt is taken as soon as possible after being enabled
   property p_clic_enable;
    @(posedge clk) disable iff (!rst_n)
    ( !irq_req_ctrl_o
       ##1
       irq_req_ctrl_o && $stable(clic_irq_q) && $stable(clic_irq_level_q) && !(ctrl_fsm.debug_mode || (dcsr.step && !dcsr.stepie))
       |-> (ctrl_pending_interrupt && ctrl_interrupt_allowed));
  endproperty;

  a_clic_enable: assert property(p_clic_enable)
    else `uvm_error("core", "Interrupt not taken soon enough after enabling");

  // Check that only NMI and external debug take presedence over interrupts after being enabled by mret or CSR writes
  property p_irq_pri;
    @(posedge clk) disable iff (!rst_n)
    ( !irq_req_ctrl_o            // No interrupt pending
      ##1                        // Next cycle
      irq_req_ctrl_o && $stable(clic_irq_q) && $stable(clic_irq_level_q) && !(ctrl_fsm.debug_mode || (dcsr.step && !dcsr.stepie)) && // Interrupt pending but irq inputs are unchanged
      (ctrl_fsm_cs != DEBUG_TAKEN) &&  // Make sure we are not handling a debug entry already (could be a single stepped mret enabling interrupts for instance)
      !(ctrl_pending_nmi || ctrl_pending_async_debug)   // No pending events with higher priority than interrupts are taking place
      |->
      ctrl_fsm.irq_ack  // We must take the interrupt if enabled (mret or CSR write) and no NMI or external debug is pending
    );
  endproperty;

  a_irq_pri: assert property(p_irq_pri)
    else `uvm_error("core", "Interrupt not taken soon enough after enabling")

  // Check a pending interrupt that is disabled is actually not taken
  property p_clic_disable;
    @(posedge clk) disable iff (!rst_n)
    (  irq_req_ctrl_o
        ##1
        !irq_req_ctrl_o && $stable(clic_irq_q) && $stable(clic_irq_level_q)
        |-> !(ctrl_pending_interrupt && ctrl_interrupt_allowed));
  endproperty;

  a_clic_disable: assert property(p_clic_disable)
    else `uvm_error("core", "Interrupt taken after disabling");
endmodule // cv32e40x_cs_registers_sva

