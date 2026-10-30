// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Dynamatic flavour of 'dot_product_hls_adapter': hooks the Dynamatic-generated
// 'dot_product' circuit onto the PULP AXI structs used by the tool-independent
// hw/fpga/hls/common/dot_product/dot_product_xheep_wrapper.sv.
//
// A Dynamatic circuit has neither the CTRL register file nor the AXI masters
// that the other flows' cores have. Its top level (dot_product_wrapper) only
// has handshake (valid/ready) channels -- start, size and one start token per
// memory in; the result, end and one end token per memory out -- plus one
// BRAM-like port per array argument, which expects the read data exactly one
// cycle after the read enable. So this adapter does more than the other two:
//
//  1. CTRL: the regtool-generated register file shared with the Bambu flow
//     (dot_product_ctrl_regs), same register map as Vitis'.
//  2. gmem_a / gmem_b: on start, the two operand buffers fetch min(size,
//     MaxLen) words of a and b from X-HEEP's memory over their own AXI4 read
//     master (in parallel), into local RAMs. A fixed one-cycle read latency
//     cannot be met over AXI/OBI, and the circuit cannot be stalled (no clock
//     enable, non-elastic memory interface), hence the copy.
//  3. Once both are filled, the circuit gets its input tokens (start, the
//     clamped size, a/b memory start) and reads its arrays from the local RAMs.
//     When it has produced all its outputs (the result, end, a/b memory end),
//     the result and done go to the register file.
//
// Only one run is in flight at a time: the register file only issues a start
// while the previous run is not done.

module dot_product_hls_adapter #(
    parameter type ctrl_axi_req_t = logic,
    parameter type ctrl_axi_rsp_t = logic,
    parameter type gmem_axi_req_t = logic,
    parameter type gmem_axi_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // CTRL: AXI4-Lite slave (register file: start/done, a, b, size, result)
    input  ctrl_axi_req_t ctrl_axi_req_i,
    output ctrl_axi_rsp_t ctrl_axi_rsp_o,

    // gmem_a / gmem_b: the operand fetch's two AXI4 read masters
    output gmem_axi_req_t gmem_a_axi_req_o,
    input  gmem_axi_rsp_t gmem_a_axi_rsp_i,
    output gmem_axi_req_t gmem_b_axi_req_o,
    input  gmem_axi_rsp_t gmem_b_axi_rsp_i
);

  // Size of the kernel's arrays (DOT_PRODUCT_DYNAMATIC_MAX_LEN in
  // hw/fpga/hls/common/dot_product/dot_product.h), hence of the operand
  // buffers. It also sets the width of the circuit's address ports, so a
  // mismatch fails the width lint below.
  localparam int unsigned MaxLen = 1024;
  localparam int unsigned IdxWidth = $clog2(MaxLen);

  // ---------------------------------------------------------------------
  // CTRL register file <-> run control
  // ---------------------------------------------------------------------
  logic        core_start;
  logic        core_done;
  logic [31:0] core_a;
  logic [31:0] core_b;
  logic [31:0] core_size;
  logic [63:0] core_result;
  logic        core_result_vld;

  dot_product_ctrl_regs #(
      .axi_req_t(ctrl_axi_req_t),
      .axi_rsp_t(ctrl_axi_rsp_t)
  ) ctrl_regs_i (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .axi_req_i   (ctrl_axi_req_i),
      .axi_rsp_o   (ctrl_axi_rsp_o),
      .start_o     (core_start),
      .done_i      (core_done),
      .a_o         (core_a),
      .b_o         (core_b),
      .size_o      (core_size),
      .result_i    (core_result),
      .result_vld_i(core_result_vld),
      .interrupt_o ()                  // like the other flows, the interrupt is not used
  );

  // ---------------------------------------------------------------------
  // Run sequence: IDLE -> FETCH (operand buffers) -> RUN (circuit) -> DONE
  // ---------------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE,
    FETCH,
    RUN,
    DONE
  } state_e;

  state_e state_q, state_d;

  // Number of elements: 'size' clamped to the size of the kernel's arrays,
  // sampled at start (like the other flows' cores do with their arguments).
  logic [IdxWidth:0] len_d, len_q;
  assign len_d = (core_size > MaxLen) ? (IdxWidth + 1)'(MaxLen) : core_size[IdxWidth:0];

  logic a_filled, b_filled;

  // Circuit handshakes: inputs offered (and outputs accepted) once per run
  logic size_valid, size_ready, start_valid, start_ready;
  logic a_start_valid, a_start_ready, b_start_valid, b_start_ready;
  logic out0_valid, out0_ready, end_valid, end_ready;
  logic a_end_valid, a_end_ready, b_end_valid, b_end_ready;
  logic [63:0] out0;

  // Inputs already taken by the circuit / outputs already received, this run
  logic sent_size_q, sent_start_q, sent_a_start_q, sent_b_start_q;
  logic got_out0_q, got_end_q, got_a_end_q, got_b_end_q;
  logic [63:0] result_q;

  logic run;
  assign run = (state_q == RUN);

  assign size_valid = run & ~sent_size_q;
  assign start_valid = run & ~sent_start_q;
  assign a_start_valid = run & ~sent_a_start_q;
  assign b_start_valid = run & ~sent_b_start_q;
  assign out0_ready = run & ~got_out0_q;
  assign end_ready = run & ~got_end_q;
  assign a_end_ready = run & ~got_a_end_q;
  assign b_end_ready = run & ~got_b_end_q;

  always_comb begin
    state_d = state_q;
    unique case (state_q)
      IDLE: if (core_start) state_d = FETCH;
      FETCH: if (a_filled && b_filled) state_d = RUN;
      RUN: if (got_out0_q && got_end_q && got_a_end_q && got_b_end_q) state_d = DONE;
      DONE: state_d = IDLE;
      default: state_d = IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q        <= IDLE;
      len_q          <= '0;
      sent_size_q    <= 1'b0;
      sent_start_q   <= 1'b0;
      sent_a_start_q <= 1'b0;
      sent_b_start_q <= 1'b0;
      got_out0_q     <= 1'b0;
      got_end_q      <= 1'b0;
      got_a_end_q    <= 1'b0;
      got_b_end_q    <= 1'b0;
      result_q       <= '0;
    end else begin
      state_q <= state_d;
      if (core_start) begin
        len_q          <= len_d;
        sent_size_q    <= 1'b0;
        sent_start_q   <= 1'b0;
        sent_a_start_q <= 1'b0;
        sent_b_start_q <= 1'b0;
        got_out0_q     <= 1'b0;
        got_end_q      <= 1'b0;
        got_a_end_q    <= 1'b0;
        got_b_end_q    <= 1'b0;
      end else begin
        if (size_valid && size_ready) sent_size_q <= 1'b1;
        if (start_valid && start_ready) sent_start_q <= 1'b1;
        if (a_start_valid && a_start_ready) sent_a_start_q <= 1'b1;
        if (b_start_valid && b_start_ready) sent_b_start_q <= 1'b1;
        if (out0_valid && out0_ready) begin
          got_out0_q <= 1'b1;
          result_q   <= out0;
        end
        if (end_valid && end_ready) got_end_q <= 1'b1;
        if (a_end_valid && a_end_ready) got_a_end_q <= 1'b1;
        if (b_end_valid && b_end_ready) got_b_end_q <= 1'b1;
      end
    end
  end

  assign core_done = (state_q == DONE);
  assign core_result_vld = (state_q == DONE);
  assign core_result = result_q;

  // ---------------------------------------------------------------------
  // Operand buffers: fetch a/b over gmem_a/gmem_b, then serve the circuit
  // ---------------------------------------------------------------------
  logic a_ce, b_ce;
  logic [IdxWidth-1:0] a_addr, b_addr;
  logic [31:0] a_rdata, b_rdata;

  dot_product_operand_buffer #(
      .Depth    (MaxLen),
      .axi_req_t(gmem_axi_req_t),
      .axi_rsp_t(gmem_axi_rsp_t)
  ) a_buffer_i (
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),
      .fill_i   (core_start),
      .base_i   (core_a),
      .len_i    (len_d),
      .filled_o (a_filled),
      .axi_req_o(gmem_a_axi_req_o),
      .axi_rsp_i(gmem_a_axi_rsp_i),
      .ce_i     (a_ce),
      .addr_i   (a_addr),
      .rdata_o  (a_rdata)
  );

  dot_product_operand_buffer #(
      .Depth    (MaxLen),
      .axi_req_t(gmem_axi_req_t),
      .axi_rsp_t(gmem_axi_rsp_t)
  ) b_buffer_i (
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),
      .fill_i   (core_start),
      .base_i   (core_b),
      .len_i    (len_d),
      .filled_o (b_filled),
      .axi_req_o(gmem_b_axi_req_o),
      .axi_rsp_i(gmem_b_axi_rsp_i),
      .ce_i     (b_ce),
      .addr_i   (b_addr),
      .rdata_o  (b_rdata)
  );

  // ---------------------------------------------------------------------
  // Dynamatic-generated circuit (its top level, with BRAM-style ports).
  //  - rst is synchronous and active high.
  //  - Port 1 of each array is the read port (ce1/address1 -> din1 one cycle
  //    later). Port 0 is the write port, which a const array never uses
  //    (Dynamatic gives it a load-only memory controller that ties it off).
  // ---------------------------------------------------------------------
  // verilator lint_off UNUSEDSIGNAL
  logic a_ce0, a_we0, a_we1, b_ce0, b_we0, b_we1;
  logic [IdxWidth-1:0] a_address0, b_address0;
  logic [31:0] a_dout0, a_dout1, b_dout0, b_dout1;
  // verilator lint_on UNUSEDSIGNAL

  dot_product_wrapper dot_product_i (
      .clk(clk_i),
      .rst(~rst_ni),

      .start_valid(start_valid),
      .start_ready(start_ready),
      .size       (32'(len_q)),
      .size_valid (size_valid),
      .size_ready (size_ready),
      .out0       (out0),
      .out0_valid (out0_valid),
      .out0_ready (out0_ready),
      .end_valid  (end_valid),
      .end_ready  (end_ready),

      .a_start_valid(a_start_valid),
      .a_start_ready(a_start_ready),
      .a_end_valid  (a_end_valid),
      .a_end_ready  (a_end_ready),
      .a_ce0        (a_ce0),
      .a_we0        (a_we0),
      .a_address0   (a_address0),
      .a_dout0      (a_dout0),
      .a_din0       (32'b0),
      .a_ce1        (a_ce),
      .a_we1        (a_we1),
      .a_address1   (a_addr),
      .a_dout1      (a_dout1),
      .a_din1       (a_rdata),

      .b_start_valid(b_start_valid),
      .b_start_ready(b_start_ready),
      .b_end_valid  (b_end_valid),
      .b_end_ready  (b_end_ready),
      .b_ce0        (b_ce0),
      .b_we0        (b_we0),
      .b_address0   (b_address0),
      .b_dout0      (b_dout0),
      .b_din0       (32'b0),
      .b_ce1        (b_ce),
      .b_we1        (b_we1),
      .b_address1   (b_addr),
      .b_dout1      (b_dout1),
      .b_din1       (b_rdata)
  );

  // ---------------------------------------------------------------------
  // What this sequence assumes, checked in simulation:
  //  - the register file only starts a run while the previous one is over;
  //  - the circuit only reads its arrays, and only produces outputs, between
  //    getting its start tokens and handing back all its outputs (RUN) --
  //    so that it never sees an operand buffer being filled;
  //  - it produces each output once per run;
  //  - it never uses the write port of its (const) arrays.
  // ---------------------------------------------------------------------
`ifndef SYNTHESIS
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      if (core_start && state_q != IDLE) $fatal(1, "%m: start while a run is in progress");
      if (!run && (a_ce || b_ce))
        $fatal(1, "%m: the circuit read an operand buffer outside of a run");
      if (!run && (out0_valid || end_valid || a_end_valid || b_end_valid))
        $fatal(1, "%m: the circuit produced an output outside of a run");
      if ((got_out0_q && out0_valid) || (got_end_q && end_valid) ||
          (got_a_end_q && a_end_valid) || (got_b_end_q && b_end_valid))
        $fatal(1, "%m: the circuit produced an output twice in one run");
      if (a_ce0 || a_we0 || a_we1 || b_ce0 || b_we0 || b_we1)
        $fatal(1, "%m: the circuit used the write port of an array");
    end
  end
`endif

endmodule : dot_product_hls_adapter
