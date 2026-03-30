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
//                                                                            //
// Authors:        Sven Stucki - svstucki@student.ethz.ch                     //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Andrea Bettati - andrea.bettati@studenti.unipr.it          //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Description:    RTL assertions for the cs_registers module                 //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_cs_registers_sva
  import uvm_pkg::*;
  import cv32e40x_pkg::*;
#(
    parameter bit CLIC  = 0,
    parameter bit DEBUG = 1
  )

  (
   input logic        clk,
   input logic        rst_n,
   input ctrl_fsm_t   ctrl_fsm_i,
   input ctrl_state_e ctrl_fsm_cs,
   input id_ex_pipe_t id_ex_pipe_i,
   input ex_wb_pipe_t ex_wb_pipe_i,
   input logic [31:0] csr_rdata_o,
   input logic        csr_we_int,
   input logic [1:0]  mtvec_mode_o,
   input logic        wb_valid_i,
   input logic        mnxti_we,
   input logic        mintstatus_we,
   input logic        mcause_we,
   input logic [31:0] clic_pa_o,
   input logic        clic_pa_valid_o,
   input mintstatus_t mintstatus_q,
   input privlvl_t    priv_lvl_n,
   input privlvl_t    priv_lvl_q,
   input logic [31:0] mscratch_q,
   input mcause_t     mcause_q,
   input mstatus_t    mstatus_q,
   input csr_num_e    csr_waddr,
   input logic        mscratch_we,
   input logic        instr_valid,
   input csr_opcode_e csr_op,
   input logic        etrigger_wb_o,
   input logic        mepc_we,
   input logic [31:0] mepc_n,
   input logic [24:0] mtvec_addr_o,
   input logic [31:0] dpc_n,
   input logic        dpc_we,
   input mstatus_t    mstatus_n,
   input mcause_t     mcause_n,
   input logic        mstatus_we,
   input logic [31:0] csr_wdata,
   input jvt_t        jvt_q,
   input logic [31:0] dscratch0_q,
   input logic [31:0] dscratch1_q,
   input dcsr_t       dcsr_q,
   input logic [31:0] dpc_q,
   input logic [31:0] mepc_q,
   input mtvec_t      mtvec_q,
   input logic [31:0] mintthresh_q,
   input logic [31:0] mie_q,
   input mtvt_t       mtvt_q
   );


   // CSR file shall not be written when WB is halted or killed
  a_csr_halt_kill:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_i.kill_wb || ctrl_fsm_i.halt_wb)
                  |-> !csr_we_int)
    else `uvm_error("wb_stage", "Register file written while WB is halted or killed")

  if (CLIC) begin
    // Assert that mtvec[1:0] are always 2'b11
    a_mtvec_mode_clic:
    assert property (@(posedge clk) disable iff (!rst_n)
                    1'b1 |-> mtvec_mode_o == 2'b11)
      else `uvm_error("cs_registers", "mtvec_mode is not 2'b11 in CLIC mode")

    // Accesses to MNXTI are stalled in EX if there is a LSU instruction in WB.
    // Thus no mnxti should be in WB (clic_pa_valid_o) the cycle after an LSU instruction
    // is done in WB.
    property p_no_mnxti_after_lsu;
      @(posedge clk) disable iff (!rst_n)
      (  wb_valid_i && ex_wb_pipe_i.lsu_en && ex_wb_pipe_i.instr_valid
        |=>
        !clic_pa_valid_o);
    endproperty;

    a_no_mnxti_after_lsu: assert property(p_no_mnxti_after_lsu)
      else `uvm_error("cs_registers", "Mnxti should not we in WB the cycle after an LSU instruction");


    // Check that horizontal traps keep the current interrupt level
    property p_htrap_interrupt_level;
      @(posedge clk) disable iff (!rst_n)
      (  ctrl_fsm_i.csr_save_cause && !ctrl_fsm_i.debug_csr_save && !ctrl_fsm_i.csr_cause.irq && (priv_lvl_n == priv_lvl_q)
         |=>
         $stable(mintstatus_q.mil));

    endproperty;

    a_htrap_interrupt_level: assert property(p_htrap_interrupt_level)
      else `uvm_error("cs_registers", "Horizontal trap taken caused interrupt level to change");

    // Check that mscratch do not update due to mscratchcsw if the conditions are not right
    property p_mscratchcsw_mscratch;
      @(posedge clk) disable iff (!rst_n)
      (  ex_wb_pipe_i.csr_en && (csr_waddr == CSR_MSCRATCHCSW) && (mstatus_q.mpp == PRIV_LVL_M)
        |=> $stable(mscratch_q));
    endproperty;

    a_mscratchcsw_mscratch: assert property(p_mscratchcsw_mscratch)
      else `uvm_error("cs_registers", "Mscratch not stable after mscratwchsw with mpp=M");

    // Check that mscratch do not update due to mscratchcswl if the conditions are not right
    property p_mscratchcswl_mscratch;
      @(posedge clk) disable iff (!rst_n)
      (  ex_wb_pipe_i.csr_en && (csr_waddr == CSR_MSCRATCHCSWL) && !((mcause_q.mpil == '0) != (mintstatus_q.mil == '0))
        |=> $stable(mscratch_q));
    endproperty;

    a_mscratchcswl_mscratch: assert property(p_mscratchcswl_mscratch)
      else `uvm_error("cs_registers", "Mscratch not stable after mscratwchswl");

    // Check that mscratch is written by mscratchcswl when the conditions are right
    property p_mscratchcswl_mscratch_we;
      @(posedge clk) disable iff (!rst_n)
      (  ex_wb_pipe_i.csr_en && (csr_waddr == CSR_MSCRATCHCSWL) && ((mcause_q.mpil == '0) != (mintstatus_q.mil == '0))
         && (csr_op != CSR_OP_READ) && instr_valid
        |-> mscratch_we);
    endproperty;

    a_mscratchcswl_mscratch_we: assert property(p_mscratchcswl_mscratch_we)
      else `uvm_error("cs_registers", "Mscratch not written by mscratchcswl");

    property p_mstatus_mcause_we;
      @(posedge clk) disable iff (!rst_n)
      (
        1'b1
        |->
        mstatus_we == mcause_we
      );
    endproperty;
    a_mstatus_mcause_we: assert property(p_mstatus_mcause_we)
      else `uvm_error("cs_registers", "mcause and mstatus not written at the same time")

    property p_mcause_mstatus_alias;
      @(posedge clk) disable iff (!rst_n)
      (
        1'b1
        |->
        (mstatus_q.mpp == mcause_q.mpp) &&
        (mstatus_q.mpie == mcause_q.mpie)
      );
    endproperty;
    a_mcause_mstatus_alias: assert property(p_mcause_mstatus_alias)
      else `uvm_error("cs_registers", "mcause.mpp and mcause.mpie not aliased correctly")

  end

  // Check that no csr instruction can be in WB during sleep when ctrl_fsm.halt_limited_wb is set
  property p_halt_limited_wb;
    @(posedge clk) disable iff (!rst_n)
    (  ctrl_fsm_i.halt_limited_wb |-> !(ex_wb_pipe_i.csr_en && ex_wb_pipe_i.instr_valid));
  endproperty;

  a_halt_limited_wb: assert property(p_halt_limited_wb)
    else `uvm_error("cs_registers", "CSR in WB while halt_limited_wb is set");


  // Check csr_clear_minhv cannot happen at the same time as csr_save_cause or csr_restore_dret (would cause mcause_we conflict)
  property p_minhv_unique;
    @(posedge clk) disable iff (!rst_n)
    (  ctrl_fsm_i.csr_clear_minhv -> !(ctrl_fsm_i.csr_save_cause || ctrl_fsm_i.csr_restore_dret));
  endproperty;

  a_minhv_unique: assert property(p_minhv_unique)
    else `uvm_error("cs_registers", "csr_save_cause at the same time as csr_clear_minhv.");


  /////////////////////////////////////////////////////////////////////////////////////////
  // Asserts to check that the CSR flops remain unchanged if a set/clear has all_zero rs1
  /////////////////////////////////////////////////////////////////////////////////////////
  a_set_clear_jvt_q:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (csr_waddr == CSR_JVT) &&
                  ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                  !(|csr_wdata) &&
                  ex_wb_pipe_i.csr_en &&
                  !ctrl_fsm_i.kill_wb
                  |=>
                  $stable(jvt_q))
    else `uvm_error("cs_registers", "jvt_q changed after set/clear with rs1==0")

  a_set_clear_mepc_q:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (csr_waddr == CSR_MEPC) &&
                  ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                  !(|csr_wdata) &&
                  ex_wb_pipe_i.csr_en &&
                  !ctrl_fsm_i.kill_wb
                  |=>
                  $stable(mepc_q))
    else `uvm_error("cs_registers", "mepc_q changed after set/clear with rs1==0")
  a_set_clear_mscratch_q:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (csr_waddr == CSR_MSCRATCH) &&
                  ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                  !(|csr_wdata) &&
                  ex_wb_pipe_i.csr_en &&
                  !ctrl_fsm_i.kill_wb
                  |=>
                  $stable(mscratch_q))
    else `uvm_error("cs_registers", "mscratch_q changed after set/clear with rs1==0")
  a_set_clear_mstatus_q:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (csr_waddr == CSR_MSTATUS) &&
                  ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                  !(|csr_wdata) &&
                  ex_wb_pipe_i.csr_en &&
                  !ctrl_fsm_i.kill_wb
                  |=>
                  $stable(mstatus_q))
    else `uvm_error("cs_registers", "mstatus_q changed after set/clear with rs1==0")
  a_set_clear_mcause_q:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (csr_waddr == CSR_MCAUSE) &&
                  ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                  !(|csr_wdata) &&
                  ex_wb_pipe_i.csr_en &&
                  !ctrl_fsm_i.kill_wb
                  |=>
                  $stable(mcause_q))
    else `uvm_error("cs_registers", "mcause_q changed after set/clear with rs1==0")
  a_set_clear_mtvec_q:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (csr_waddr == CSR_MTVEC) &&
                  ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                  !(|csr_wdata) &&
                  ex_wb_pipe_i.csr_en &&
                  !ctrl_fsm_i.kill_wb
                  |=>
                  $stable(mtvec_q))
    else `uvm_error("cs_registers", "mtvec_q changed after set/clear with rs1==0")

  if (CLIC) begin
    a_set_clear_mtvt_q:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (csr_waddr == CSR_MTVT) &&
                    ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                    !(|csr_wdata) &&
                    ex_wb_pipe_i.csr_en &&
                    !ctrl_fsm_i.kill_wb
                    |=>
                    $stable(mtvt_q))
      else `uvm_error("cs_registers", "mtvt_q changed after set/clear with rs1==0")

    a_set_clear_mintthresh_q:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (csr_waddr == CSR_MINTTHRESH) &&
                    ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                    !(|csr_wdata) &&
                    ex_wb_pipe_i.csr_en &&
                    !ctrl_fsm_i.kill_wb
                    |=>
                    $stable(mintthresh_q))
      else `uvm_error("cs_registers", "mintthresh_q changed after set/clear with rs1==0")
  end

  a_set_clear_mie_q:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (csr_waddr == CSR_MIE) &&
                  ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                  !(|csr_wdata) &&
                  ex_wb_pipe_i.csr_en &&
                  !ctrl_fsm_i.kill_wb
                  |=>
                  $stable(mie_q))
    else `uvm_error("cs_registers", "mie_q changed after set/clear with rs1==0")


generate
  if (DEBUG) begin
    a_set_clear_dscratch0_q:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (csr_waddr == CSR_DSCRATCH0) &&
                    ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                    !(|csr_wdata) &&
                    ex_wb_pipe_i.csr_en &&
                    !ctrl_fsm_i.kill_wb
                    |=>
                    $stable(dscratch0_q))
      else `uvm_error("cs_registers", "dscratch0_q changed after set/clear with rs1==0")
    a_set_clear_dscratch1_q:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (csr_waddr == CSR_DSCRATCH1) &&
                    ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                    !(|csr_wdata) &&
                    ex_wb_pipe_i.csr_en &&
                    !ctrl_fsm_i.kill_wb
                    |=>
                    $stable(dscratch1_q))
      else `uvm_error("cs_registers", "dscratch1_q changed after set/clear with rs1==0")
    a_set_clear_dcsr_q:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (csr_waddr == CSR_DCSR) &&
                    ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                    !(|csr_wdata) &&
                    ex_wb_pipe_i.csr_en &&
                    !ctrl_fsm_i.kill_wb
                    |=>
                    $stable(dcsr_q))
      else `uvm_error("cs_registers", "dcsr_q changed after set/clear with rs1==0")
    a_set_clear_dpc_q:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (csr_waddr == CSR_DPC) &&
                    ((csr_op == CSR_OP_SET) || (csr_op == CSR_OP_CLEAR)) &&
                    !(|csr_wdata) &&
                    ex_wb_pipe_i.csr_en &&
                    !ctrl_fsm_i.kill_wb
                    |=>
                    $stable(dpc_q))
      else `uvm_error("cs_registers", "dpc_q changed after set/clear with rs1==0")

    // Exception trigger shall have mepc written to oldest instruction
    property p_etrigger_mepc_write;
      @(posedge clk) disable iff (!rst_n)
      (  (ctrl_fsm_cs == FUNCTIONAL) && etrigger_wb_o && !(ctrl_fsm_i.halt_wb || ctrl_fsm_i.kill_wb)
          |->
          (mepc_we && (mepc_n == ctrl_fsm_i.pipe_pc)));
    endproperty;

    a_etrigger_mepc_write: assert property(p_etrigger_mepc_write)
      else `uvm_error("cs_registers", "mepc not written with ctrl_fsm.pipe_pc when etrigger fires.");

    // Exception trigger shall cause dpc to point to first handler instruction and no instruction shall signal wb_valid the cycle after (while in DEBUG_TAKEN state)
    // Excluding external debug and interrupts (halt_wb, kill_wb) as they (currently) both take priority over etrigger
    // Also checking that WB stage is empty after an exception trigger has been taken.
    // todo: update when debug causes are updated, trigger match will not be highest priority
    property p_etrigger_dpc_write;
      logic [24:0] mtvec_at_trap;
      @(posedge clk) disable iff (!rst_n)
      (  ((ctrl_fsm_cs == FUNCTIONAL) && etrigger_wb_o && !(ctrl_fsm_i.halt_wb || ctrl_fsm_i.kill_wb), mtvec_at_trap = mtvec_addr_o)
          |=>
          (!wb_valid_i && !ex_wb_pipe_i.instr_valid && dpc_we && (dpc_n == {mtvec_at_trap, {7'd0}}) && (ctrl_fsm_cs == DEBUG_TAKEN)));
    endproperty;

    a_etrigger_dpc_write: assert property(p_etrigger_dpc_write)
      else `uvm_error("cs_registers", "dpc not written with first handler instruction when etrigger fires.");

  end
endgenerate

endmodule

