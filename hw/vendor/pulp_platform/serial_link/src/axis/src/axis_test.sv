// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Noah Huetter <huettern@iis.ee.ethz.ch>

/// A set of testbench utilities for AXI Stream interfaces.
package axis_test;

  // import axis_pkg::*;

  /// A driver for AXI4-Stream interface.
  class axis_driver #(
      parameter int unsigned DW = 0,
      parameter int unsigned IW = 0,
      parameter int unsigned DESTW = 0,
      parameter int unsigned UW = 0,
      parameter int unsigned RW = 0,
      parameter int unsigned LW = 0,
      parameter time TA = 0ns,  // stimuli application time
      parameter time TT = 0ns  // stimuli test time
  );
    virtual AXIS_BUS_DV #(
        .AXIS_DATA_WIDTH(DW),
        .AXIS_ID_WIDTH(IW),
        .AXIS_DEST_WIDTH(DESTW),
        .AXIS_USER_WIDTH(UW),
        .AXIS_READY_WIDTH(RW),
        .AXIS_LAST_WIDTH(LW)
    ) axis;

    function new(virtual AXIS_BUS_DV #(
                 .AXIS_DATA_WIDTH(DW),
                 .AXIS_ID_WIDTH(IW),
                 .AXIS_DEST_WIDTH(DESTW),
                 .AXIS_USER_WIDTH(UW),
                 .AXIS_READY_WIDTH(RW),
                 .AXIS_LAST_WIDTH(LW)
                 ) axis);
      this.axis = axis;
    endfunction

    function void reset_master();
      axis.tvalid <= '0;
      axis.tdata <= '0;
      axis.tstrb <= '0;
      axis.tkeep <= '0;
      axis.tlast <= '0;
      axis.tid <= '0;
      axis.tdest <= '0;
      axis.tuser <= '0;
    endfunction

    function void reset_slave();
      axis.tready <= '0;
    endfunction

    task cycle_start;
      #TT;
    endtask

    task cycle_end;
      @(posedge axis.clk_i);
    endtask

    /// Issue a beat
    task send(input logic [DW-1:0] data, input logic [LW-1:0] last);
      axis.tdata <= #TA data;
      axis.tstrb <= '0;
      axis.tkeep <= '0;
      axis.tlast <= #TA last;
      axis.tid <= '0;
      axis.tdest <= '0;
      axis.tuser <= '0;
      axis.tvalid <= #TA 1;
      cycle_start();
      while (axis.tready != 1) begin
        cycle_end();
        cycle_start();
      end
      cycle_end();
      axis.tdata  <= #TA '0;
      axis.tlast  <= #TA '0;
      axis.tvalid <= #TA 0;
    endtask

    /// Wait for a beat
    task recv(output [DW-1:0] data, output logic [LW-1:0] last);
      axis.tready <= #TA 1;
      cycle_start();
      while (axis.tvalid != 1) begin
        cycle_end();
        cycle_start();
      end
      data = axis.tdata;
      last = axis.tlast;
      cycle_end();
      axis.tready <= #TA 0;
    endtask

  endclass

  /// The data transferred on a beat
  class axis_beat #(
      parameter DW = 32,
      parameter IW = 0,
      parameter DESTW = 0,
      parameter UW = 0,
      parameter RW = 0,
      parameter LW = 1
  );
    logic [DW-1:0] tdata = '0;
    logic [DW/8-1:0] tstrb = '0;
    logic [DW/8-1:0] tkeep = '0;
    logic [LW-1:0] tlast = '0;
    logic [IW-1:0] tid = '0;
    logic [DESTW-1:0] tdest = '0;
    logic [UW-1:0] tuser = '0;
  endclass


  class axis_rand_slave #(
      // AXI interface parameters
      parameter int unsigned DW = 0,
      parameter int unsigned IW = 0,
      parameter int unsigned DESTW = 0,
      parameter int unsigned UW = 0,
      parameter int unsigned RW = 0,
      parameter int unsigned LW = 0,
      // Stimuli application and test time
      parameter time TA = 2ns,
      parameter time TT = 8ns,
      // Upper and lower bounds on wait cycles
      parameter int MIN_WAIT_CYCLES = 0,
      parameter int MAX_WAIT_CYCLES = 100
  );
    typedef axis_test::axis_driver#(
        .DW(DW),
        .IW(IW),
        .DESTW(DESTW),
        .UW(UW),
        .RW(RW),
        .LW(LW)
    ) axis_driver_t;

    typedef logic [DW-1:0] data_t;
    typedef logic [LW-1:0] last_t;
    typedef logic [DW/8-1:0] strb_t;

    string        name;
    axis_driver_t drv;
    data_t        recv_queue[$];

    function new(
        virtual AXIS_BUS_DV #(
            .AXIS_DATA_WIDTH(DW),
            .AXIS_ID_WIDTH(IW),
            .AXIS_DEST_WIDTH(DESTW),
            .AXIS_USER_WIDTH(UW),
            .AXIS_READY_WIDTH(RW),
            .AXIS_LAST_WIDTH(LW)
        ) axis,
        input string name);
      this.drv  = new(axis);
      this.name = name;
      assert (DW != 0)
      else $fatal(1, "Data width must be non-zero!");
    endfunction

    function void reset();
      this.drv.reset_slave();
    endfunction

    task automatic rand_wait(input int unsigned min, max);
      int unsigned rand_success, cycles;
      rand_success = std::randomize(
          cycles
      ) with {
        cycles >= min;
        cycles <= max;
      };
      assert (rand_success)
      else $error("Failed to randomize wait cycles!");
      repeat (cycles) @(posedge this.drv.axis.clk_i);
    endtask

    task automatic recv();
      forever begin
        automatic data_t data;
        automatic last_t last;
        rand_wait(MIN_WAIT_CYCLES, MAX_WAIT_CYCLES);
        this.drv.recv(data, last);
        $display("%0t %s> Recv AR with DATA: %h LAST: %b", $time(), this.name, data, last);
        this.recv_queue.push_back(data);
      end
    endtask : recv

    task automatic run();
      fork
        recv();
      join
    endtask
  endclass


endpackage
