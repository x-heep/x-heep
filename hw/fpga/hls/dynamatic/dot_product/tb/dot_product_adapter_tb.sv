// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Self-checking test of the Dynamatic flow's dot_product_hls_adapter, with
// the real Dynamatic-generated circuit (rtl/hls/) and the shared regtool
// register file inside: it drives the CTRL port over AXI4-Lite like X-HEEP
// software does, and serves gmem_a/gmem_b from a memory model that accepts
// requests and returns data with random delays (the latency and backpressure
// a one-cycle BRAM port could not take, which is what the adapter's operand
// buffers are for). It checks the register map, start/done/idle, the 64-bit
// signed result against a reference (sizes 0..MaxLen, plus a clamped one),
// what is fetched from memory, auto-restart, and a sweep of software polls
// across every cycle alignment with the done event (the sticky-done race).
//
// Run it with (from anywhere):
//   hw/fpga/hls/dynamatic/dot_product/tb/run.sh

`include "axi/typedef.svh"

// AXI4 read-only memory: in-order responses, random AR backpressure and R
// latency when 'random_delays' is set. Each beat returns the 32-bit word at
// its address. Every request must lie within [lo, hi).
module dot_product_adapter_tb_mem #(
    parameter type req_t = logic,
    parameter type rsp_t = logic
) (
    input  logic        clk_i,
    input  logic        random_delays,
    input  logic [31:0] lo,
    input  logic [31:0] hi,
    input  req_t        req_i,
    output rsp_t        rsp_o
);

  int unsigned mem[int unsigned];  // word address -> data
  int unsigned beats = 0;  // R beats sent
  int unsigned errors = 0;

  typedef struct {
    logic [31:0] addr;
    int unsigned len;
    longint unsigned due;
  } burst_t;
  burst_t q[$];
  int unsigned beat = 0;
  longint unsigned cycle = 0;

  initial rsp_o = '0;

  always @(posedge clk_i) begin
    cycle <= cycle + 1;

    // AR: record accepted requests (ar_ready was decided at the last edge)
    if (req_i.ar_valid && rsp_o.ar_ready) begin
      burst_t b;
      b.addr = req_i.ar.addr[31:0];
      b.len  = int'(req_i.ar.len) + 1;
      b.due  = cycle + (random_delays ? 64'($urandom_range(0, 6)) : 64'd1);
      if (req_i.ar.addr[63:32] != 0 || req_i.ar.addr[1:0] != 0 || req_i.ar.size != 3'd2 ||
          req_i.ar.burst != axi_pkg::BURST_INCR) begin
        $display("FAIL mem: bad AR (addr 0x%0h, size %0d, burst %0d)", req_i.ar.addr,
                 req_i.ar.size, req_i.ar.burst);
        errors++;
      end
      if (b.addr < lo || b.addr + 4 * b.len > hi) begin
        $display("FAIL mem: read of 0x%0h (%0d beats) outside [0x%0h, 0x%0h)", b.addr, b.len, lo,
                 hi);
        errors++;
      end
      q.push_back(b);
    end
    if (req_i.aw_valid || req_i.w_valid) begin
      $display("FAIL mem: write request on a read-only port");
      errors++;
    end

    // R: the current beat was accepted at this edge
    if (rsp_o.r_valid && req_i.r_ready) begin
      beats++;
      if (beat + 1 == q[0].len) begin
        void'(q.pop_front());
        beat = 0;
      end else begin
        beat++;
      end
    end

    rsp_o.ar_ready <= random_delays ? ($urandom_range(0, 3) != 0) : 1'b1;
    if (rsp_o.r_valid && !req_i.r_ready) begin
      // a beat that was not taken stays as it is (AXI rule)
    end else if (q.size() > 0 && q[0].due <= cycle && !(random_delays && $urandom_range(
            0, 3
        ) == 0)) begin
      logic [31:0] a;
      a = q[0].addr + 4 * beat;
      rsp_o.r_valid <= 1'b1;
      rsp_o.r.data  <= mem.exists(a >> 2) ? mem[a>>2] : 32'hdead_beef;
      rsp_o.r.last  <= (beat + 1 == q[0].len);
      rsp_o.r.resp  <= '0;
      rsp_o.r.id    <= '0;
    end else begin
      rsp_o.r_valid <= 1'b0;
    end
  end

endmodule

module dot_product_adapter_tb;

  // Same AXI structs as hw/fpga/hls/common/dot_product/dot_product_xheep_wrapper.sv
  typedef logic [31:0] ctrl_addr_t;
  typedef logic [31:0] data_t;
  typedef logic [3:0] strb_t;
  typedef logic [0:0] id_t;
  typedef logic [0:0] user_t;
  typedef logic [63:0] gmem_addr_t;

  `AXI_TYPEDEF_AW_CHAN_T(ctrl_aw_t, ctrl_addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(ctrl_w_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(ctrl_b_t, id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ctrl_ar_t, ctrl_addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(ctrl_r_t, data_t, id_t, user_t)
  `AXI_TYPEDEF_REQ_T(ctrl_req_t, ctrl_aw_t, ctrl_w_t, ctrl_ar_t)
  `AXI_TYPEDEF_RESP_T(ctrl_rsp_t, ctrl_b_t, ctrl_r_t)

  `AXI_TYPEDEF_AW_CHAN_T(gmem_aw_t, gmem_addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(gmem_w_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(gmem_b_t, id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(gmem_ar_t, gmem_addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(gmem_r_t, data_t, id_t, user_t)
  `AXI_TYPEDEF_REQ_T(gmem_req_t, gmem_aw_t, gmem_w_t, gmem_ar_t)
  `AXI_TYPEDEF_RESP_T(gmem_rsp_t, gmem_b_t, gmem_r_t)

  // Register offsets (same as the Vitis-generated block)
  localparam ctrl_addr_t AP_CTRL = 32'h00;
  localparam ctrl_addr_t A_LO = 32'h10;
  localparam ctrl_addr_t B_LO = 32'h1c;
  localparam ctrl_addr_t SIZE = 32'h28;
  localparam ctrl_addr_t RES_LO = 32'h30;
  localparam ctrl_addr_t RES_HI = 32'h34;
  localparam ctrl_addr_t RES_CTRL = 32'h38;

  localparam int unsigned MaxLen = 1024;  // DOT_PRODUCT_DYNAMATIC_MAX_LEN
  localparam logic [31:0] ABase = 32'h1000_0000;
  localparam logic [31:0] BBase = 32'h2000_4000;
  localparam logic [1:0] RESP_OKAY = 2'b00;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  ctrl_req_t ctrl_req;
  ctrl_rsp_t ctrl_rsp;
  gmem_req_t a_req, b_req;
  gmem_rsp_t a_rsp, b_rsp;

  logic random_delays = 1'b1;
  logic [31:0] a_lo, a_hi, b_lo, b_hi;

  dot_product_hls_adapter #(
      .ctrl_axi_req_t(ctrl_req_t),
      .ctrl_axi_rsp_t(ctrl_rsp_t),
      .gmem_axi_req_t(gmem_req_t),
      .gmem_axi_rsp_t(gmem_rsp_t)
  ) dut (
      .clk_i           (clk),
      .rst_ni          (rst_n),
      .ctrl_axi_req_i  (ctrl_req),
      .ctrl_axi_rsp_o  (ctrl_rsp),
      .gmem_a_axi_req_o(a_req),
      .gmem_a_axi_rsp_i(a_rsp),
      .gmem_b_axi_req_o(b_req),
      .gmem_b_axi_rsp_i(b_rsp)
  );

  dot_product_adapter_tb_mem #(
      .req_t(gmem_req_t),
      .rsp_t(gmem_rsp_t)
  ) mem_a (
      .clk_i(clk),
      .random_delays(random_delays),
      .lo(a_lo),
      .hi(a_hi),
      .req_i(a_req),
      .rsp_o(a_rsp)
  );

  dot_product_adapter_tb_mem #(
      .req_t(gmem_req_t),
      .rsp_t(gmem_rsp_t)
  ) mem_b (
      .clk_i(clk),
      .random_delays(random_delays),
      .lo(b_lo),
      .hi(b_hi),
      .req_i(b_req),
      .rsp_o(b_rsp)
  );

  int unsigned errors = 0;

  // Start pulses issued by the register file (to count runs)
  int unsigned starts = 0;
  always @(posedge clk) if (rst_n && dut.core_start) starts++;

  longint unsigned cycles = 0;
  always @(posedge clk) cycles++;

  // ---------------------------------------------------------------------
  // AXI4-Lite master tasks
  // ---------------------------------------------------------------------
  initial ctrl_req = '0;

  bit expect_err = 0;
  logic [1:0] last_resp;

  task automatic axi_write(input ctrl_addr_t addr, input data_t data, input strb_t strb = 4'hf);
    bit aw_done = 0, w_done = 0;
    while (!(aw_done && w_done)) begin
      @(negedge clk);
      ctrl_req.aw_valid = !aw_done;
      ctrl_req.aw.addr  = addr;
      ctrl_req.w_valid  = !w_done;
      ctrl_req.w.data   = data;
      ctrl_req.w.strb   = strb;
      @(posedge clk);
      if (ctrl_req.aw_valid && ctrl_rsp.aw_ready) aw_done = 1;
      if (ctrl_req.w_valid && ctrl_rsp.w_ready) w_done = 1;
    end
    @(negedge clk);
    ctrl_req.aw_valid = 0;
    ctrl_req.w_valid  = 0;
    ctrl_req.b_ready  = 1;
    do @(posedge clk); while (!ctrl_rsp.b_valid);
    last_resp = ctrl_rsp.b.resp;
    if (!expect_err && last_resp !== RESP_OKAY) begin
      $display("FAIL write to 0x%0h: unexpected BRESP %0d", addr, last_resp);
      errors++;
    end
    @(negedge clk);
    ctrl_req.b_ready = 0;
  endtask

  task automatic axi_read(input ctrl_addr_t addr, output data_t data);
    @(negedge clk);
    ctrl_req.ar_valid = 1;
    ctrl_req.ar.addr  = addr;
    do @(posedge clk); while (!ctrl_rsp.ar_ready);
    @(negedge clk);
    ctrl_req.ar_valid = 0;
    ctrl_req.r_ready  = 1;
    do @(posedge clk); while (!ctrl_rsp.r_valid);
    last_resp = ctrl_rsp.r.resp;
    data = ctrl_rsp.r.data;
    if (!expect_err && last_resp !== RESP_OKAY) begin
      $display("FAIL read from 0x%0h: unexpected RRESP %0d", addr, last_resp);
      errors++;
    end
    @(negedge clk);
    ctrl_req.r_ready = 0;
  endtask

  task automatic check(input string what, input logic [63:0] got, input logic [63:0] exp);
    if (got !== exp) begin
      $display("FAIL %s: got 0x%0h, expected 0x%0h", what, got, exp);
      errors++;
    end
  endtask

  task automatic wait_cycles(input int n);
    repeat (n) @(posedge clk);
  endtask

  // ---------------------------------------------------------------------
  // Test data: vectors in the memory models, and the expected result
  // ---------------------------------------------------------------------
  int signed va[MaxLen], vb[MaxLen];

  // kind 0: small positive; 1: full 32-bit signed range (products need 64
  // bits, the sum wraps modulo 2^64 like the hardware's)
  task automatic fill_vectors(input int kind);
    for (int i = 0; i < MaxLen; i++) begin
      if (kind == 0) begin
        va[i] = i + 1;
        vb[i] = 16 - i;
      end else begin
        va[i] = $urandom();
        vb[i] = $urandom();
      end
      mem_a.mem[(ABase>>2)+i] = va[i];
      mem_b.mem[(BBase>>2)+i] = vb[i];
    end
  endtask

  function automatic longint expected(input int unsigned n);
    longint acc = 0;
    for (int unsigned i = 0; i < n && i < MaxLen; i++) acc += longint'(va[i]) * longint'(vb[i]);
    return acc;
  endfunction

  data_t rd;

  // One run as software does it: program a/b/size, start, poll done, read
  // the result. Checks the result, its valid bit and what was fetched.
  task automatic run_and_check(input int unsigned size, input string what);
    int unsigned n;
    int unsigned beats_a, beats_b;
    longint unsigned t0;
    longint res;
    n = (size > MaxLen) ? MaxLen : size;
    a_lo = ABase;
    a_hi = ABase + 4 * n;
    b_lo = BBase;
    b_hi = BBase + 4 * n;
    beats_a = mem_a.beats;
    beats_b = mem_b.beats;
    axi_write(A_LO, ABase);
    axi_write(B_LO, BBase);
    axi_write(SIZE, size);
    t0 = cycles;
    axi_write(AP_CTRL, 32'h1);
    do axi_read(AP_CTRL, rd); while (!rd[1]);
    $display("%s: %0d element(s), done seen after %0d cycles", what, n, cycles - t0);
    check({what, ": AP_CTRL at done (done+ready+idle)"}, rd & 32'hf, 32'he);
    axi_read(RES_LO, rd);
    res[31:0] = rd;
    axi_read(RES_HI, rd);
    res[63:32] = rd;
    check({what, ": result"}, res, expected(size));
    axi_read(RES_CTRL, rd);
    check({what, ": result valid"}, rd, 1);
    check({what, ": words of a fetched"}, mem_a.beats - beats_a, n);
    check({what, ": words of b fetched"}, mem_b.beats - beats_b, n);
    axi_read(AP_CTRL, rd);
    check({what, ": idle after the run, done/ready cleared"}, rd & 32'hf, 32'h4);
  endtask

  int unsigned starts_before;

  initial begin
    a_lo = 0;
    a_hi = 0;
    b_lo = 0;
    b_hi = 0;
    fill_vectors(0);

    wait_cycles(3);
    rst_n = 1'b1;
    wait_cycles(2);

    // ---- reset state
    axi_read(AP_CTRL, rd);
    check("reset AP_CTRL (idle only)", rd, 32'h4);
    axi_read(RES_CTRL, rd);
    check("reset RESULT_CTRL", rd, 0);

    // ---- the run of example_dot_product_hls: 16 elements, result 816
    run_and_check(16, "size 16");
    axi_read(RES_LO, rd);
    check("size 16: result is 816", rd, 816);

    // ---- full-range signed data, assorted sizes
    fill_vectors(1);
    run_and_check(0, "size 0");
    run_and_check(1, "size 1");
    run_and_check(2, "size 2");
    run_and_check(7, "size 7");
    run_and_check(100, "size 100");
    run_and_check(1 + $urandom_range(0, 1000), "random size");
    run_and_check(MaxLen, "size MaxLen");
    run_and_check(MaxLen + 1000, "size above MaxLen (clamped)");

    // ---- arguments are sampled at start: rewriting them mid-run has no effect
    a_lo = ABase;
    a_hi = ABase + 4 * 50;
    b_lo = BBase;
    b_hi = BBase + 4 * 50;
    axi_write(SIZE, 50);
    axi_write(AP_CTRL, 32'h1);
    axi_write(SIZE, 3);
    axi_write(A_LO, 32'h0);
    do axi_read(AP_CTRL, rd); while (!rd[1]);
    axi_read(RES_LO, rd);
    check("args rewritten mid-run: result lo", rd, expected(50) & 64'hffff_ffff);
    axi_read(RES_CTRL, rd);
    axi_write(A_LO, ABase);

    // ---- auto_restart: back-to-back runs straight out of DONE
    axi_write(SIZE, 5);
    a_hi = ABase + 4 * 5;
    b_hi = BBase + 4 * 5;
    starts_before = starts;
    axi_write(AP_CTRL, 32'h81);
    wait_cycles(400);
    axi_write(AP_CTRL, 32'h00);  // clear auto_restart
    wait_cycles(100);
    if (starts - starts_before < 3) begin
      $display("FAIL auto_restart: only %0d runs", starts - starts_before);
      errors++;
    end
    axi_read(AP_CTRL, rd);
    axi_read(AP_CTRL, rd);
    check("idle again after auto_restart", rd & 32'h8f, 32'h4);
    axi_read(RES_LO, rd);
    check("auto_restart: result", rd, expected(5) & 64'hffff_ffff);
    axi_read(RES_CTRL, rd);

    // ---- race: software polls AP_CTRL back to back from every offset after
    // the start, so that over the sweep a poll lands in every cycle around the
    // done event. Software's clear-on-read wins over a same-cycle hardware set
    // in the register file; done must be seen anyway, and only once.
    random_delays = 1'b0;  // the same run length every time
    axi_write(SIZE, 4);
    a_hi = ABase + 4 * 4;
    b_hi = BBase + 4 * 4;
    for (int off = 0; off < 24; off++) begin
      bit seen_done = 0;
      axi_write(AP_CTRL, 32'h1);
      wait_cycles(off);
      for (int i = 0; i < 200 && !seen_done; i++) begin
        axi_read(AP_CTRL, rd);
        seen_done |= rd[1];
      end
      if (!seen_done) begin
        $display("FAIL race: ap_done lost, first poll %0d cycles after the start write", off);
        errors++;
      end
      wait_cycles(20);
      axi_read(AP_CTRL, rd);
      axi_read(AP_CTRL, rd);
      check($sformatf("race, offset %0d: no phantom done/ready", off), rd & 32'hf, 32'h4);
      axi_read(RES_CTRL, rd);
    end
    random_delays = 1'b1;

    // ---- the register file's bus errors: unmapped offset, sub-word write
    expect_err = 1;
    axi_read(32'h18, rd);
    check("read of reserved 0x18: error response", last_resp !== RESP_OKAY, 1);
    axi_write(SIZE, 32'h1, 4'b0011);
    check("partial write to SIZE: error response", last_resp !== RESP_OKAY, 1);
    expect_err = 0;

    errors += mem_a.errors + mem_b.errors;
    if (errors == 0) $display("dot_product_adapter_tb: PASS");
    else $display("dot_product_adapter_tb: FAIL (%0d error(s))", errors);
    $finish;
  end

  // watchdog
  initial begin
    #5000000;
    $display("dot_product_adapter_tb: FAIL (timeout)");
    $finish;
  end

endmodule
