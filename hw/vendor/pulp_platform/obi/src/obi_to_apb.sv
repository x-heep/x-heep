// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

`include "common_cells/assertions.svh"

/// An OBI to APB adapter.
module obi_to_apb #(
  /// The configuration of the subordinate port (input port).
  parameter      obi_pkg::obi_cfg_t ObiCfg = obi_pkg::ObiDefaultConfig,
  /// The OBI request struct for the subordinate port (input port).
  parameter type obi_req_t = logic,
  /// The OBI response struct for the subordinate port (input port).
  parameter type obi_rsp_t = logic, // OBI response struct
  /// The APB request struct for the manager port (output port).
  parameter type apb_req_t = logic, // APB request struct
  /// The APB response struct for the manager port (output port).
  parameter type apb_rsp_t = logic, // APB response struct
  /// Disable gnt/rvalid in same cycle.
  parameter bit DisableSameCycleRsp = 1'b1
) (
  input  logic clk_i,
  input  logic rst_ni,
  // Subordinate OBI port.
  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o,
  // Manager APB port.
  output apb_req_t apb_req_o,
  input  apb_rsp_t apb_rsp_i
);

  logic [ObiCfg.AddrWidth-1:0] addr;
  logic [ObiCfg.DataWidth-1:0] wdata;
  logic we;
  logic [ObiCfg.DataWidth/8-1:0] be;
  logic [2:0] prot;

  assign apb_req_o.paddr  = addr;
  assign apb_req_o.pwrite = we;
  // OBI expects '1 on writes, APB sets pstrb to '0 on reads.
  assign apb_req_o.pstrb  = we ? be : '0;
  assign apb_req_o.pwdata = wdata;
  if (ObiCfg.OptionalCfg.UseProt) begin : gen_pprot
    // Bit 2: inverted bit 0 of OBI prot
    assign apb_req_o.pprot[2] = ~prot[2];
    // Bit 1: secure access only for machine mode
    assign apb_req_o.pprot[1] = ~(prot[1] & prot[0]);
    // Bit 0: privileged for machine mode and supervisor mode
    assign apb_req_o.pprot[0] = prot[1];
  end else begin : gen_no_pprot
    // OBI does not enable prot, so we set it to priviledged, secure, instruction.
    assign apb_req_o.pprot = 3'b101;
  end

  assign obi_rsp_o.r.rdata = apb_rsp_i.prdata;
  assign obi_rsp_o.r.err   = apb_rsp_i.pslverr;
  assign obi_rsp_o.r.r_optional = '0; // No optional R feature supported at the moment.

  if (DisableSameCycleRsp) begin : gen_hs_buffers
    logic tsxn_in_progress;
    logic [ObiCfg.IdWidth-1:0] aid_q;
    logic [ObiCfg.AddrWidth-1:0] addr_q;
    logic [ObiCfg.DataWidth-1:0] wdata_q;
    logic we_q;
    logic [ObiCfg.DataWidth/8-1:0] be_q;
    logic [2:0] prot_q;

    assign apb_req_o.psel = obi_req_i.req | tsxn_in_progress;
    assign apb_req_o.penable = tsxn_in_progress;
    assign obi_rsp_o.gnt = ~tsxn_in_progress;
    assign obi_rsp_o.rvalid = apb_rsp_i.pready & tsxn_in_progress;
    // Mirror AID to RID
    assign obi_rsp_o.r.rid = aid_q;

    assign addr = tsxn_in_progress ? addr_q : obi_req_i.a.addr;
    assign wdata = tsxn_in_progress ? wdata_q : obi_req_i.a.wdata;
    assign we = tsxn_in_progress ? we_q : obi_req_i.a.we;
    assign be = tsxn_in_progress ? be_q : obi_req_i.a.be;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        tsxn_in_progress <= 1'b0;
        aid_q <= '0;
        addr_q <= '0;
        wdata_q <= '0;
        we_q <= 1'b0;
        be_q <= '0;
      end else begin
        tsxn_in_progress <= apb_req_o.psel & ~apb_rsp_i.pready;
        if (obi_req_i.req & obi_rsp_o.gnt) begin
          aid_q <= obi_req_i.a.aid;
          addr_q <= obi_req_i.a.addr;
          wdata_q <= obi_req_i.a.wdata;
          we_q <= obi_req_i.a.we;
          be_q <= obi_req_i.a.be;
        end
      end
    end
    if (ObiCfg.OptionalCfg.UseProt) begin : gen_prot
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          prot <= 3'b101; // Privileged, secure, instruction.
        end else if (obi_req_i.req & obi_rsp_o.gnt) begin
          prot <= obi_req_i.a.a_optional.prot;
        end
      end
    end else begin : gen_no_prot
      assign prot = 3'b101; // Privileged, secure, instruction.
    end

  end else begin : gen_no_hs_buffers
    logic psel_q;
    assign apb_req_o.psel = obi_req_i.req;
    assign apb_req_o.penable = psel_q;
    assign obi_rsp_o.gnt = apb_rsp_i.pready;
    assign obi_rsp_o.rvalid = apb_rsp_i.pready;
    // Mirror AID to RID
    assign obi_rsp_o.r.rid = obi_req_i.a.aid;
    assign addr = obi_req_i.a.addr;
    assign wdata = obi_req_i.a.wdata;
    assign we = obi_req_i.a.we;
    assign be = obi_req_i.a.be;
    if (ObiCfg.OptionalCfg.UseProt) begin : gen_prot
      assign prot = obi_req_i.a.a_optional.prot;
    end else begin : gen_no_prot
      assign prot = 3'b101; // Privileged, secure, instruction.
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        psel_q <= 1'b0;
      end else begin
        psel_q <= obi_req_i.req & ~apb_rsp_i.pready;
      end
    end
  end


  // ----------
  // Assertions
  // ----------

  `ASSERT_INIT(no_rready, ObiCfg.UseRReady == 0,
      "RReady not supported in OBI to APB conversion")
  `ASSERT_INIT(no_atop, ObiCfg.OptionalCfg.UseAtop == 0,
      "ATOP not supported in OBI to APB conversion")
  `ASSERT_INIT(no_memtype, ObiCfg.OptionalCfg.UseMemtype == 0,
      "Memtype not supported in OBI to APB conversion")
  `ASSERT_INIT(no_debug, ObiCfg.OptionalCfg.UseDbg == 0,
      "Debug not supported in OBI to APB conversion")
  `ASSERT_INIT(no_integrity, !ObiCfg.Integrity,
      "Integrity not supported!")
   `ASSERT_INIT(no_achk, ObiCfg.OptionalCfg.AChkWidth == 0,
      "ACHK field not supported!")
  `ASSERT_INIT(equal_wdata_width, $bits(apb_req_o.pwdata) == $bits(obi_req_i.a.wdata),
      "WDATA width mismatch between APB and OBI ports!")
  `ASSERT_INIT(equal_be_width, $bits(apb_req_o.pstrb) == $bits(obi_req_i.a.be),
      "Strobe width mismatch between APB and OBI ports!")
  `ASSERT_INIT(equal_rdata_width, $bits(apb_rsp_i.prdata) == $bits(obi_rsp_o.r.rdata),
      "RDATA width mismatch between APB and OBI ports!")
  `ASSERT_INIT(equal_addr_width, $bits(apb_req_o.paddr) == $bits(obi_req_i.a.addr),
      "Address width mismatch between APB and OBI ports!")


endmodule
