// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Self-checking unit test of dot_product_ctrl_regs (the regtool-based AXI4-Lite
// CTRL register file of the Bambu and Dynamatic flows), against the behaviour
// of the Vitis-generated dot_product_CTRL_s_axi.v it stands in for. It
// emulates the core with a tiny model (start pulse in, done/result out).
//
// Run it with (from anywhere):
//   hw/fpga/hls/common/dot_product/tb/run.sh

`include "axi/typedef.svh"

module dot_product_ctrl_regs_tb;

  typedef logic [31:0] addr_t;
  typedef logic [31:0] data_t;
  typedef logic [3:0] strb_t;
  typedef logic [0:0] id_t;
  typedef logic [0:0] user_t;

  `AXI_TYPEDEF_AW_CHAN_T(aw_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_t, id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(r_t, data_t, id_t, user_t)
  `AXI_TYPEDEF_REQ_T(axi_req_t, aw_t, w_t, ar_t)
  `AXI_TYPEDEF_RESP_T(axi_rsp_t, b_t, r_t)

  // Register offsets (same as the Vitis-generated block)
  localparam addr_t AP_CTRL = 32'h00;
  localparam addr_t GIER = 32'h04;
  localparam addr_t IER = 32'h08;
  localparam addr_t ISR = 32'h0c;
  localparam addr_t A_LO = 32'h10;
  localparam addr_t A_HI = 32'h14;
  localparam addr_t B_LO = 32'h1c;
  localparam addr_t B_HI = 32'h20;
  localparam addr_t SIZE = 32'h28;
  localparam addr_t RES_LO = 32'h30;
  localparam addr_t RES_HI = 32'h34;
  localparam addr_t RES_CTRL = 32'h38;

  localparam logic [1:0] RESP_OKAY = 2'b00;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  axi_req_t req;
  axi_rsp_t rsp;

  logic start, done, result_vld, interrupt;
  logic [31:0] a, b, size;
  logic [63:0] result;

  dot_product_ctrl_regs #(
      .axi_req_t(axi_req_t),
      .axi_rsp_t(axi_rsp_t)
  ) dut (
      .clk_i       (clk),
      .rst_ni      (rst_n),
      .axi_req_i   (req),
      .axi_rsp_o   (rsp),
      .start_o     (start),
      .done_i      (done),
      .a_o         (a),
      .b_o         (b),
      .size_o      (size),
      .result_i    (result),
      .result_vld_i(result_vld),
      .interrupt_o (interrupt)
  );

  int unsigned errors = 0;

  // ---------------------------------------------------------------------
  // Core model: on a start pulse, run for core_cycles cycles, present a
  // result with a one-cycle valid strobe, then a one-cycle done pulse.
  // ---------------------------------------------------------------------
  int unsigned core_cycles = 5;
  int unsigned start_pulses = 0;
  int unsigned run_cnt = 0;
  logic running = 1'b0;
  logic start_prev = 1'b0;

  initial begin
    done = 1'b0;
    result_vld = 1'b0;
    result = '0;
  end

  always @(posedge clk) begin
    done       <= 1'b0;
    result_vld <= 1'b0;
    start_prev <= start;
    if (start) begin
      start_pulses <= start_pulses + 1;
      // a start pulse must never be held for more than one cycle
      if (start_prev) $fatal(1, "start_o held for more than one cycle");
      if (running) $fatal(1, "start_o pulsed while the core is running");
      running <= 1'b1;
      run_cnt <= 0;
    end else if (running) begin
      run_cnt <= run_cnt + 1;
      if (run_cnt == core_cycles - 2) begin
        // result = {size, a + b}: depends on what software programmed
        result     <= {size, a + b};
        result_vld <= 1'b1;
      end
      if (run_cnt == core_cycles - 1) begin
        done    <= 1'b1;
        running <= 1'b0;
      end
    end
  end

  // ---------------------------------------------------------------------
  // AXI4-Lite master tasks. A response other than OKAY is an error unless the
  // test says it expects one (regtool register files answer SLVERR to
  // unmapped offsets and to sub-word writes that do not cover a whole register).
  // ---------------------------------------------------------------------
  initial req = '0;

  bit expect_err = 0;
  logic [1:0] last_resp;

  // aw_delay/w_delay: cycles to wait before asserting AW / W (to check both
  // arrival orders).
  task automatic axi_write(input addr_t addr, input data_t data, input strb_t strb = 4'hf,
                           input int aw_delay = 0, input int w_delay = 0);
    bit aw_done = 0, w_done = 0;
    int t = 0;
    while (!(aw_done && w_done)) begin
      @(negedge clk);
      req.aw_valid = (t >= aw_delay) && !aw_done;
      req.aw.addr  = addr;
      req.w_valid  = (t >= w_delay) && !w_done;
      req.w.data   = data;
      req.w.strb   = strb;
      @(posedge clk);
      if (req.aw_valid && rsp.aw_ready) aw_done = 1;
      if (req.w_valid && rsp.w_ready) w_done = 1;
      t++;
    end
    @(negedge clk);
    req.aw_valid = 0;
    req.w_valid  = 0;
    req.b_ready  = 1;
    do @(posedge clk); while (!rsp.b_valid);
    last_resp = rsp.b.resp;
    if (!expect_err && last_resp !== RESP_OKAY) begin
      $display("FAIL write to 0x%0h: unexpected BRESP %0d", addr, last_resp);
      errors++;
    end
    @(negedge clk);
    req.b_ready = 0;
  endtask

  task automatic axi_read(input addr_t addr, output data_t data);
    @(negedge clk);
    req.ar_valid = 1;
    req.ar.addr  = addr;
    do @(posedge clk); while (!rsp.ar_ready);
    @(negedge clk);
    req.ar_valid = 0;
    req.r_ready  = 1;
    do @(posedge clk); while (!rsp.r_valid);
    last_resp = rsp.r.resp;
    data = rsp.r.data;
    if (!expect_err && last_resp !== RESP_OKAY) begin
      $display("FAIL read from 0x%0h: unexpected RRESP %0d", addr, last_resp);
      errors++;
    end
    @(negedge clk);
    req.r_ready = 0;
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

  data_t rd;
  int unsigned pulses_before;

  // registers that must read 0 out of reset, and the unmapped (reserved) offsets
  addr_t reset_regs[11] = '{GIER, IER, ISR, A_LO, A_HI, B_LO, B_HI, SIZE, RES_LO, RES_HI, RES_CTRL};
  addr_t reserved_regs[4] = '{32'h18, 32'h24, 32'h2c, 32'h3c};

  initial begin
    // ---- reset
    wait_cycles(3);
    rst_n = 1'b1;
    wait_cycles(2);

    // ---- reset values: idle, everything else 0
    axi_read(AP_CTRL, rd);
    check("reset AP_CTRL (idle only)", rd, 32'h4);
    foreach (reset_regs[i]) begin
      axi_read(reset_regs[i], rd);
      check($sformatf("reset value of 0x%0h", reset_regs[i]), rd, 0);
    end
    check("reset: no interrupt", interrupt, 0);

    // ---- plain read/write registers
    axi_write(A_LO, 32'h1000_0100);
    axi_write(B_LO, 32'h2000_0200);
    axi_write(SIZE, 32'd16);
    axi_read(A_LO, rd);
    check("a readback", rd, 32'h1000_0100);
    axi_read(B_LO, rd);
    check("b readback", rd, 32'h2000_0200);
    axi_read(SIZE, rd);
    check("size readback", rd, 16);
    check("a output", a, 32'h1000_0100);
    check("b output", b, 32'h2000_0200);
    check("size output", size, 16);

    // ---- upper pointer words: real registers (as in Vitis), unused by the core
    axi_write(A_HI, 32'hffff_ffff);
    axi_write(B_HI, 32'h1234_5678);
    axi_read(A_HI, rd);
    check("a hi readback", rd, 32'hffff_ffff);
    axi_read(B_HI, rd);
    check("b hi readback", rd, 32'h1234_5678);
    check("a output not affected by a hi", a, 32'h1000_0100);
    axi_write(A_HI, 32'h0);
    axi_write(B_HI, 32'h0);

    // ---- GIER / IER: only their implemented bits are stored
    axi_write(GIER, 32'hffff_ffff);
    axi_read(GIER, rd);
    check("GIER", rd, 32'h1);
    axi_write(IER, 32'hffff_ffff);
    axi_read(IER, rd);
    check("IER", rd, 32'h3);
    axi_write(GIER, 32'h0);
    axi_write(IER, 32'h0);

    // ---- sub-word writes: a 32-bit register needs all four byte strobes
    // (regtool's rule, for every X-HEEP peripheral) -- the write is rejected
    // and the register is left alone
    expect_err = 1;
    axi_write(SIZE, 32'hAABB_CCDD, 4'b1001);
    check("partial write to a 32-bit register: error response", last_resp !== RESP_OKAY, 1);
    expect_err = 0;
    axi_read(SIZE, rd);
    check("partial write left size alone", rd, 16);
    // ...while the byte-wide control registers only need byte 0
    axi_write(GIER, 32'h1, 4'b0001);
    axi_read(GIER, rd);
    check("byte-0 write to GIER", rd, 32'h1);
    axi_write(GIER, 32'h0, 4'b0001);

    // ---- read-only registers ignore writes
    axi_write(RES_LO, 32'hdead_beef);
    axi_read(RES_LO, rd);
    check("result is read-only", rd, 0);

    // ---- one run: separate AW-first arrival for the start write
    pulses_before = start_pulses;
    axi_write(AP_CTRL, 32'h1, 4'hf, 0, 3);  // AW immediately, W 3 cycles later
    wait_cycles(1);
    axi_read(AP_CTRL, rd);
    check("busy: not idle, not done", rd & 32'hf, 32'h0);
    while (!(rd & 32'h2)) axi_read(AP_CTRL, rd);
    // that read returned done|ready|idle (COR) -- and must clear them
    check("done: done+ready+idle", rd & 32'hf, 32'hE);
    check("exactly one start pulse", start_pulses - pulses_before, 1);
    axi_read(AP_CTRL, rd);
    check("done/ready cleared on read, idle stays", rd & 32'hf, 32'h4);
    axi_read(ISR, rd);
    check("interrupts not enabled: ISR stays clear", rd, 0);
    check("interrupts not enabled: no interrupt", interrupt, 0);

    // ---- result registers + result_ctrl clear-on-read
    axi_read(RES_LO, rd);
    check("result lo = a+b", rd, 32'h3000_0300);
    axi_read(RES_HI, rd);
    check("result hi = size", rd, 16);
    axi_read(RES_CTRL, rd);
    check("result_ctrl valid", rd, 1);
    axi_read(RES_CTRL, rd);
    check("result_ctrl cleared on read", rd, 0);

    // ---- W-first arrival for a second run, and a different core latency
    core_cycles   = 2;
    pulses_before = start_pulses;
    axi_write(AP_CTRL, 32'h1, 4'hf, 3, 0);  // W immediately, AW 3 cycles later
    wait_cycles(8);
    axi_read(AP_CTRL, rd);
    check("2nd run done", rd & 32'hf, 32'hE);
    check("2nd run: one start pulse", start_pulses - pulses_before, 1);

    // ---- writing 0 to ap_start does nothing
    pulses_before = start_pulses;
    axi_write(AP_CTRL, 32'h0);
    wait_cycles(4);
    check("write 0 to ap_start: no start", start_pulses - pulses_before, 0);

    // ---- interrupt: ap_done enabled only, then cleared by writing 1 to ISR
    core_cycles = 4;
    axi_write(IER, 32'h1);  // ap_done only
    axi_write(GIER, 32'h1);
    axi_write(AP_CTRL, 32'h1);
    wait_cycles(12);
    check("interrupt raised", interrupt, 1);
    axi_read(ISR, rd);
    check("ISR: ap_done only", rd, 32'h1);
    axi_write(ISR, 32'h1);
    axi_read(ISR, rd);
    check("ISR cleared by write 1", rd, 0);
    check("interrupt dropped", interrupt, 0);
    axi_read(AP_CTRL, rd);  // consume done/ready
    axi_write(GIER, 32'h0);
    axi_write(IER, 32'h0);

    // ---- auto_restart: keeps going until it is cleared
    pulses_before = start_pulses;
    axi_write(AP_CTRL, 32'h81);  // ap_start + auto_restart
    axi_read(AP_CTRL, rd);
    check("auto_restart readable", rd & 32'h80, 32'h80);
    wait_cycles(20);
    if (start_pulses - pulses_before < 3) begin
      $display("FAIL auto_restart: only %0d start pulses", start_pulses - pulses_before);
      errors++;
    end
    axi_write(AP_CTRL, 32'h00);  // clear auto_restart (ap_start write of 0 is a no-op)
    wait_cycles(20);
    pulses_before = start_pulses;
    wait_cycles(20);
    check("auto_restart cleared: no more starts", start_pulses - pulses_before, 0);
    axi_read(AP_CTRL, rd);
    axi_read(AP_CTRL, rd);
    check("idle again after auto_restart", rd & 32'h8f, 32'h4);

    // ---- race: software polls AP_CTRL in every clock cycle of the run, so one
    // poll lands in the very cycle of the core's done pulse. Software's
    // clear-on-read wins over the hardware set in that cycle (prim_subreg_arb),
    // and done must still be seen (this used to hang the system simulation).
    core_cycles = 8;
    for (int off = 0; off < 16; off++) begin
      bit seen_done = 0;
      axi_write(AP_CTRL, 32'h1);
      wait_cycles(off);
      for (int i = 0; i < 40 && !seen_done; i++) begin
        axi_read(AP_CTRL, rd);
        seen_done |= rd[1];
      end
      if (!seen_done) begin
        $display("FAIL race: ap_done lost, first poll %0d cycles after the start write", off);
        errors++;
      end
      wait_cycles(20);
      axi_read(AP_CTRL, rd);  // consume what is left of this run
      axi_read(AP_CTRL, rd);
      // the set is repeated until it sticks, but it must never come back after
      // software has consumed it
      check($sformatf("race, offset %0d: no phantom done/ready", off), rd & 32'hf, 32'h4);
      axi_read(RES_CTRL, rd);  // consume result-valid
    end

    // ---- reserved offsets are unmapped: bus error
    expect_err = 1;
    foreach (reserved_regs[i]) begin
      axi_read(reserved_regs[i], rd);
      check($sformatf("read of reserved 0x%0h: error response", reserved_regs[i]),
            last_resp !== RESP_OKAY, 1);
      axi_write(reserved_regs[i], 32'h1);
      check($sformatf("write to reserved 0x%0h: error response", reserved_regs[i]),
            last_resp !== RESP_OKAY, 1);
    end
    expect_err = 0;

    if (errors == 0) $display("dot_product_ctrl_regs_tb: PASS");
    else $display("dot_product_ctrl_regs_tb: FAIL (%0d error(s))", errors);
    $finish;
  end

  // watchdog
  initial begin
    #400000;
    $display("dot_product_ctrl_regs_tb: FAIL (timeout)");
    $finish;
  end

endmodule
