// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Local copy of one operand vector of the Dynamatic 'dot_product' circuit.
//
// Dynamatic gives each array argument of the kernel a BRAM-like memory port
// with a fixed one-cycle read latency and no way to stall the circuit (its
// memory interfaces are not elastic, and its RTL has no clock enable), so the
// circuit cannot read X-HEEP's memory directly over AXI/OBI. This block is
// what the circuit reads instead:
//
//   1. fill_i: fetch len_i 32-bit words from base_i over the AXI4 master port
//      (single-beat INCR reads, as many in flight as the interconnect
//      accepts) and write them into a local RAM; filled_o goes high once the
//      last word has been written.
//   2. Then the circuit reads the RAM through its BRAM port (ce_i/addr_i in,
//      rdata_o one cycle later), exactly like the BRAM Dynamatic expects.
//
// The two phases never overlap (the adapter only starts the circuit once both
// operand buffers are filled), so the RAM is a single-port X-HEEP
// sram_wrapper. Only the AXI read channels are used.

module dot_product_operand_buffer #(
    // Number of 32-bit words (the size of the kernel's array argument)
    parameter int unsigned Depth = 1024,
    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic,
    localparam int unsigned IdxWidth = $clog2(Depth)
) (
    input logic clk_i,
    input logic rst_ni,

    // Fill: fetch len_i words starting at byte address base_i
    input  logic                fill_i,   // one-cycle pulse
    input  logic [        31:0] base_i,
    input  logic [IdxWidth : 0] len_i,    // 0..Depth
    output logic                filled_o,

    // AXI4 read master (fetch)
    output axi_req_t axi_req_o,
    // verilator lint_off UNUSEDSIGNAL
    // (only the R channel is read, and from it only data/valid)
    input  axi_rsp_t axi_rsp_i,
    // verilator lint_on UNUSEDSIGNAL

    // Circuit side: Dynamatic's BRAM read port
    input  logic                ce_i,
    input  logic [IdxWidth-1:0] addr_i,
    output logic [        31:0] rdata_o
);

  logic [31:0] base_q;
  logic [IdxWidth:0] len_q;
  logic [IdxWidth:0] ar_cnt_q;  // read requests issued
  logic [IdxWidth:0] r_cnt_q;  // words received
  logic busy_q;

  logic ar_fire;
  logic r_fire;

  assign ar_fire = axi_req_o.ar_valid & axi_rsp_i.ar_ready;
  assign r_fire  = busy_q & axi_rsp_i.r_valid;  // always ready while busy

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      base_q   <= '0;
      len_q    <= '0;
      ar_cnt_q <= '0;
      r_cnt_q  <= '0;
      busy_q   <= 1'b0;
    end else begin
      if (fill_i) begin
        base_q   <= base_i;
        len_q    <= len_i;
        ar_cnt_q <= '0;
        r_cnt_q  <= '0;
        busy_q   <= 1'b1;
      end else if (busy_q) begin
        if (ar_fire) ar_cnt_q <= ar_cnt_q + 1'b1;
        if (r_fire) r_cnt_q <= r_cnt_q + 1'b1;
        if (r_cnt_q == len_q) busy_q <= 1'b0;
      end
    end
  end

  assign filled_o = ~busy_q;

  // ---------------------------------------------------------------------
  // AXI4 read requests: one 32-bit beat per word, address base + 4 * index.
  // The address is zero-extended to the wrapper's 64-bit struct address (its
  // width is part of the adapter contract: a change there fails the width
  // lint here).
  // ---------------------------------------------------------------------
  always_comb begin
    axi_req_o          = '0;
    axi_req_o.ar.addr  = {32'b0, base_q + {{(29 - IdxWidth) {1'b0}}, ar_cnt_q, 2'b00}};
    axi_req_o.ar.len   = '0;
    axi_req_o.ar.size  = 3'd2;  // 4 bytes
    axi_req_o.ar.burst = axi_pkg::BURST_INCR;
    axi_req_o.ar_valid = busy_q & (ar_cnt_q != len_q);
    axi_req_o.r_ready  = busy_q;
  end

  // ---------------------------------------------------------------------
  // RAM: written by the fetch, then read by the circuit (read data one cycle
  // after the request, as the circuit expects). The two never overlap, so a
  // single-port X-HEEP sram_wrapper is enough; which implementation it is
  // (behavioural, FPGA block RAM, ASIC macro) is chosen by the build target.
  //
  // Why they never overlap. Dynamatic's circuit-interface specification
  // (docs/DeveloperGuide/DesignDecisionProposals/CircuitInterface.md in its
  // repository) says that a circuit only accesses an array between consuming
  // its <array>_start token and producing its <array>_end token, and the
  // adapter only sends a_start/b_start once the buffers are filled, and only
  // fills them again after a_end/b_end. The memory controller of the current
  // Dynamatic only partly enforces that, though: <array>_start does not gate
  // its loads, and its <array>_end does not wait for loads in flight
  // ('allRequestsDone' is tied to 1, with a note in its source saying so). What
  // guarantees it here is the dataflow graph of this kernel (see
  // dot_product_proj/out/comp/handshake_export.mlir): its only two loads, one
  // per array, take their address from the loop index, which cannot exist
  // before the circuit consumes its 'start' and 'size' tokens (sent with
  // a_start/b_start), and their data feeds the accumulator, hence the result,
  // which the adapter waits for (together with every end token) before it can
  // start another fill. A kernel change that adds a load whose value does not
  // reach the result would void this. The check below makes a violation fatal
  // in simulation; in hardware it could only return wrong data to the circuit,
  // never corrupt the RAM (while filling, the address comes from the fill).
  // ---------------------------------------------------------------------
`ifndef SYNTHESIS
  always_ff @(posedge clk_i) begin
    if (rst_ni && busy_q && ce_i) begin
      $fatal(1, "%m: the circuit read the operand RAM while it was being filled");
    end
  end
`endif

  logic                ram_req;
  logic [IdxWidth-1:0] ram_addr;
  // verilator lint_off UNUSEDSIGNAL
  logic                ram_pwrgate_ack_n;  // no power gating here
  // verilator lint_on UNUSEDSIGNAL

  assign ram_req  = r_fire | ce_i;
  assign ram_addr = busy_q ? r_cnt_q[IdxWidth-1:0] : addr_i;

  sram_wrapper #(
      .NumWords (Depth),
      .DataWidth(32'd32)
  ) ram_i (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .req_i           (ram_req),
      .we_i            (r_fire),
      .addr_i          (ram_addr),
      .wdata_i         (axi_rsp_i.r.data),
      .be_i            (4'b1111),
      .pwrgate_ni      (1'b1),
      .pwrgate_ack_no  (ram_pwrgate_ack_n),
      .set_retentive_ni(1'b1),
      .rdata_o         (rdata_o)
  );

endmodule : dot_product_operand_buffer
