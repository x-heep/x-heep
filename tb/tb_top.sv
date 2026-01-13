// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module tb_top #(
    parameter FPU_SS_ZFINX                = 0,
    parameter JTAG_DPI                    = 0,
    parameter USE_EXTERNAL_DEVICE_EXAMPLE = 1
);

  // comment to record execution trace
  //`define TRACE_EXECUTION

  const time CLK_PHASE_HI = 5ns;
  const time CLK_PHASE_LO = 5ns;
  localparam CLK_FREQUENCY_KHz = 100_000;
  const time CLK_PERIOD = CLK_PHASE_HI + CLK_PHASE_LO;

  const time STIM_APPLICATION_DEL = CLK_PERIOD * 0.1;
  const time RESP_ACQUISITION_DEL = CLK_PERIOD * 0.9;
  const time RESET_DEL = STIM_APPLICATION_DEL;
  const int  RESET_WAIT_CYCLES = 50;

  // clock and reset for tb
  logic      clk = 'b1;
  logic      rst_n = 'b0;
  // wire for inout connections
  wire clk_w, rst_n_w;

  // Boot selection (0:jtag or 1:flash)
  logic boot_sel;
  // SPI selection (0:ot-qspi or 1:memory mapped flash, only valid if boot_sel is 1)
  logic execute_from_flash;
  // wire for inout connections
  wire boot_sel_w, execute_from_flash_w;

  // cycle counter
  int unsigned        cycle_cnt_q;

  // testbench result
  wire                exit_valid;
  logic        [31:0] exit_value;

  // jtag signals
  wire                jtag_tck;
  wire                jtag_trst_n;
  wire                jtag_tms;
  wire                jtag_tdi;
  wire                jtag_tdo;

  // allow vcd dump
  initial begin
    if ($test$plusargs("vcd")) begin
      $dumpfile("waveform.vcd");
      $dumpvars(0, tb_top);
    end
  end

  // we either load the provided firmware or execute a small test program that
  // doesn't do more than an infinite loop with some I/O
  initial begin : load_prog
    automatic string firmware, arg_boot_sel, arg_execute_from_flash;

    if ($value$plusargs("firmware=%s", firmware)) begin
      $display("[TESTBENCH]: loading firmware %0s", firmware);
    end else begin
      $display("[TESTBENCH]: no firmware specified");
      if (JTAG_DPI == 0) begin
        $finish;
      end
    end

    boot_sel = 0;
    if ($test$plusargs("boot_sel")) begin
      $value$plusargs("boot_sel=%s", arg_boot_sel);
      if (arg_boot_sel == "1") begin
        $display("[TESTBENCH]: Booting from flash");
        boot_sel = 1;
      end else if (arg_boot_sel == "0") begin
        $display("[TESTBENCH]: Booting from jtag");
        boot_sel = 0;
      end else begin
        $display(
            "[TESTBENCH]: Wrong Boot Option specified (jtag, flash) - using jtag (boot_sel=0)");
        boot_sel = 0;
      end
    end else begin
      $display("[TESTBENCH]: No Boot Option specified, using jtag (boot_sel=0)");
      boot_sel = 0;
    end

    execute_from_flash = 0;
    if (boot_sel == 1) begin
      if ($test$plusargs("execute_from_flash")) begin
        $value$plusargs("execute_from_flash=%s", arg_execute_from_flash);
        if (arg_execute_from_flash == "1") begin
          $display("[TESTBENCH]: Using YosysHQ memory mapped SPI");
          execute_from_flash = 1;
        end else if (arg_execute_from_flash == "0") begin
          $display("[TESTBENCH]: Using OpenTitan SPI");
          execute_from_flash = 0;
        end else begin
          $display(
              "[TESTBENCH]: Wrong SPI Option specified (execute from flash, load flash in-memory) - using execute from flash (execute_from_flash=1)");
          execute_from_flash = 1;
        end
      end else begin
        $display(
            "[TESTBENCH]: No SPI Option specified, using execute from flash (execute_from_flash=1)");
        execute_from_flash = 1;
      end
    end

    testharness_i.load_flash_hex(firmware);

    wait (rst_n == 1'b1);

    // wait a few cycles
    repeat (RESET_WAIT_CYCLES) begin
      @(posedge clk);
    end

    if (JTAG_DPI == 0 && boot_sel == 0) begin
      testharness_i.tb_loadHEX(firmware);
      #CLK_PHASE_HI testharness_i.tb_set_exit_loop();
      #CLK_PHASE_LO if ($test$plusargs("verbose")) $display("[TESTBENCH] %t: memory loaded", $time);
    end else begin
      if ($test$plusargs("verbose")) $display("[TESTBENCH] %t: waiting for GDB...", $time);
    end

  end

  // clock generation
  initial begin : clock_gen
    forever begin
      #CLK_PHASE_HI clk = 1'b0;
      #CLK_PHASE_LO clk = 1'b1;
    end
  end : clock_gen

  // reset generation
  initial begin : reset_gen
    rst_n = 1'b0;

    // wait a few cycles
    repeat (RESET_WAIT_CYCLES) begin
      @(posedge clk);
    end

    // start running
    #RESET_DEL rst_n = 1'b1;

    if ($test$plusargs("verbose")) $display("reset deasserted", $time);

  end : reset_gen

  // set timing format
  initial begin : timing_format
    $timeformat(-9, 0, "ns", 9);
  end : timing_format

  // abort after n cycles, if we want to
  always_ff @(posedge clk, negedge rst_n) begin
    automatic int maxcycles;
    if ($value$plusargs("maxcycles=%d", maxcycles)) begin
      if (~rst_n) begin
        cycle_cnt_q <= 0;
      end else begin
        cycle_cnt_q <= cycle_cnt_q + 1;
        if (cycle_cnt_q >= maxcycles) begin
          $fatal(2, "Simulation aborted due to maximum cycle limit");
        end
      end
    end
  end

  // check if we succeded
  always_ff @(posedge clk, negedge rst_n) begin
    if (exit_valid) begin
      if (exit_value == 0) $display("EXIT SUCCESS");
      else $display("EXIT FAILURE: %d", exit_value);
      $finish;
    end
  end

  assign clk_w = clk;
  assign rst_n_w = rst_n;
  assign boot_sel_w = boot_sel;
  assign execute_from_flash_w = execute_from_flash;

  // wrapper for riscv, the memory system and stdout peripheral
  testharness #(
      .FPU_SS_ZFINX               (FPU_SS_ZFINX),
      .JTAG_DPI                   (JTAG_DPI),
      .USE_EXTERNAL_DEVICE_EXAMPLE(USE_EXTERNAL_DEVICE_EXAMPLE),
      .CLK_FREQUENCY              (CLK_FREQUENCY_KHz)
  ) testharness_i (
      .clk_i               (clk_w),
      .rst_ni              (rst_n_w),
      .boot_select_i       (boot_sel_w),
      .execute_from_flash_i(execute_from_flash_w),
      .exit_valid_o        (exit_valid),
      .exit_value_o        (exit_value),
      .jtag_tck_i          (jtag_tck),
      .jtag_trst_ni        (jtag_trst_n),
      .jtag_tms_i          (jtag_tms),
      .jtag_tdi_i          (jtag_tdi),
      .jtag_tdo_o          (jtag_tdo)
  );


endmodule  // tb_top
