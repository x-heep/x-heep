// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Nils Wistoff <nwistoff@iis.ee.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

// An APB to OBI adapter. Generic bridge that performs protocol conversion
// without address-specific transformations.
module apb_to_obi #(
  /// The configuration of the manager port (output port).
  parameter      obi_pkg::obi_cfg_t ObiCfg,
  /// The APB request struct for the subordinate port (input port).
  parameter type apb_req_t, 
  /// The APB response struct for the subordinate port (input port).
  parameter type apb_rsp_t, 
  /// The OBI request struct for the manager port (output port).
  parameter type obi_req_t,
  /// The OBI response struct for the manager port (output port).
  parameter type obi_rsp_t  
) (
  input  logic clk_i,
  input  logic rst_ni,
  // Subordinate APB port.
  input  apb_req_t apb_req_i,
  output apb_rsp_t apb_rsp_o,
  // Manager OBI port.
  output obi_req_t obi_req_o,
  input  obi_rsp_t obi_rsp_i
);

  typedef enum logic {RESP, ADDR} obi_phase_e;
  obi_phase_e obi_phase_d, obi_phase_q;

  // ---------------
  // Request Signals (APB request to OBI)
  // ---------------

  // create OBI struct from APB inputs
  obi_req_t obi_req_next;
  always_comb begin
    // Default all fields
    obi_req_next = '0;

    // Direct address pass-through (wrapper handles any translation)
    obi_req_next.addr  = apb_req_i.paddr;
    obi_req_next.we    = apb_req_i.pwrite;
    // APB sets pstrb to '0 on reads. OBI expects '1.
    obi_req_next.be    = apb_req_i.pwrite ? apb_req_i.pstrb : '1;
    obi_req_next.wdata = apb_req_i.pwdata;
    // Only one outstanding transaction supported by APB
    // obi_req_next.aid   = '0; // not considered in our case

  end

  // Forward OBI fields to the output
  assign obi_req_o.addr = obi_req_next.addr;
  assign obi_req_o.we = obi_req_next.we;
  assign obi_req_o.be = obi_req_next.be;
  assign obi_req_o.wdata = obi_req_next.wdata;

  // ----------------
  // Response Signals (OBI answer to APB)
  // ----------------

  // forward OBI response to APB bus
  assign apb_rsp_o.prdata  = obi_rsp_i.rdata;
  assign apb_rsp_o.pslverr = 1'b0; // we dont have a OBI error signal in our system

  // ----------
  // Handshakes
  // ----------

  always_comb begin : obi_fsm
    obi_req_o.req    = 1'b0;
    apb_rsp_o.pready = 1'b0;
    obi_phase_d      = obi_phase_q;
    unique case (obi_phase_q)
      // Address phase (or idle).
      ADDR: begin
        // Need to wait for APB access phase to sample valid strobe and wdata.
        obi_req_o.req = apb_req_i.psel; // we have a requist when the peripheral select of X-Heep is 1
        // Downstream A handshake completed.
        if (obi_req_o.req && obi_rsp_i.gnt) obi_phase_d = RESP; // go to next stage if OBI says guaranteed and APB is giving a valid address
      end
      // Response phase.
      RESP: begin
        // Downstream R handshake completed.
        if (obi_rsp_i.rvalid) begin  // if OBI has avbailable response signal
          apb_rsp_o.pready = 1'b1; // give ready signal to APB bus
          obi_phase_d = ADDR;
        end
      end
      default: obi_phase_d = ADDR;
    endcase
  end

  `FF(obi_phase_q, obi_phase_d, ADDR, clk_i, rst_ni) // update the state machine on next cycle

  // // Cycle-accurate transaction trace (simulation-only).
  // always_ff @(posedge clk_i or negedge rst_ni) begin
  //   if (!rst_ni) begin
  //   end else begin
  //     if (apb_req_i.psel && apb_req_i.penable) begin
  //       $display("[%0t][apb_to_obi][APB] paddr=0x%08x pwrite=%0b pstrb=0x%0x pwdata=0x%08x (paddr[23:0]=0x%06x)", $time, apb_req_i.paddr, apb_req_i.pwrite, apb_req_i.pstrb, apb_req_i.pwdata, apb_req_i.paddr[23:0]);
  //       $display("[%0t][apb_to_obi][OBI-A] req=%0b addr=0x%0h be=0x%0x we=%0b gnt=%0b", $time, obi_req_o.req, obi_req_o.addr, obi_req_o.be, obi_req_o.we, obi_rsp_i.gnt);
  //     end
  //     if (obi_rsp_i.rvalid) begin
  //       $display("[%0t][apb_to_obi][OBI-R] rvalid=1 rdata=0x%08x -> APB pready=%0b", $time, obi_rsp_i.rdata, apb_rsp_o.pready);
  //     end
  //   end
  // end

  // ----------
  // Assertions
  // ----------
/*
`ifndef OBI_ASSERTS_OFF
  `ASSERT(penable, obi_phase_q == RESP |-> apb_req_i.penable, clk_i, !rst_ni,
      "APB PENABLE must be asserted during OBI RESP phase!")
  `ASSERT_INIT(no_integrity, !ObiCfg.Integrity,
      "Integrity not supported!")
  `ASSERT_INIT(no_achk, ObiCfg.OptionalCfg.AChkWidth == 0,
      "ACHK field not supported!")
  `ASSERT_INIT(equal_wdata_width, $bits(apb_req_i.pwdata) == $bits(obi_req_o.a.wdata),
      "WDATA width mismatch between APB and OBI ports!")
  `ASSERT_INIT(equal_be_width, $bits(apb_req_i.pstrb) == $bits(obi_req_o.a.be),
      "Strobe width mismatch between APB and OBI ports!")
  `ASSERT_INIT(equal_rdata_width, $bits(apb_rsp_o.prdata) == $bits(obi_rsp_i.r.rdata),
      "RDATA width mismatch between APB and OBI ports!")
  `ASSERT_INIT(equal_addr_width, $bits(apb_req_i.paddr) == $bits(obi_req_o.addr),
      "Address width mismatch between APB and OBI ports!")
`endif
*/

endmodule
