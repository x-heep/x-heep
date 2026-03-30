/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Claire Xenia Wolf <claire@yosyshq.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

//`timescale 1 ns / 1 ps

//
// Simple SPI flash simulation model
//
// This model samples io input signals 1ns before the SPI clock edge and
// updates output signals 1ns after the SPI clock edge.
//
// Supported commands:
//    AB, B9, FF, 03, BB, EB, ED, 06, 02, 32, 20, FF
// 
// Partially supported commands:
//    05      (only Write-Enable Latch and BUSY bit support)
//    31, 35  (only Quad-Enable bit support)
//
// Well written SPI flash data sheets:
//    Cypress S25FL064L http://www.cypress.com/file/316661/download
//    Cypress S25FL128L http://www.cypress.com/file/316171/download
//
// SPI flash used on iCEBreaker board:
//    https://www.winbond.com/resource-files/w25q128jv%20dtr%20revb%2011042016.pdf
//

// This file is a copy of https://github.com/YosysHQ/picorv32/blob/main/picosoc/spiflash.v
// with hash commit f00a88c36eaab478b64ee27d8162e421049bcc66

// Additional Contribution
// Davide Schiavone davide.schiavone@epfl.ch
// Converted to SystemVerilog and made it compatible with Verilator for Single-Mode SPI
// Memory Init is done in a separated task not part of this file
// CAREFULL!!!! DUAL and QUAD SPI Flash Model doesnt work with Verilator
// This is because it requires to model Hi-Z, which are not supported (yet?)

module spiflash (
    input wire csb,
    input wire clk,
    inout wire io0,  // MOSI
    inout wire io1,  // MISO
    inout wire io2,
    inout wire io3
);
  localparam verbose = 0;
  localparam integer latency = 4;
  localparam integer sector_size = 4096;  // 4 KB
  localparam integer busy_cycles = 100;

  logic [7:0] buffer;
  integer bitcount = 0;
  integer bytecount = 0;
  integer dummycount = 0;
  integer erase_addr = 0;
  integer erase_offset = 0;

  logic [7:0] spi_cmd;
  logic [7:0] xip_cmd = 0;
  logic [23:0] spi_addr;

  logic [7:0] spi_in;
  logic [7:0] spi_out;
  logic spi_io_vld;

  logic powered_up = 0;
  logic write_enable = 0;
  logic write_enable_reset = 0;
  logic quad_enable = 0;

  logic command_pending = 0;
  integer current_busy_cycles = 0;

  localparam [3:0] mode_spi = 1;
  localparam [3:0] mode_dspi_rd = 2;
  localparam [3:0] mode_dspi_wr = 3;
  localparam [3:0] mode_qspi_rd = 4;
  localparam [3:0] mode_qspi_wr = 5;
  localparam [3:0] mode_qspi_ddr_rd = 6;
  localparam [3:0] mode_qspi_ddr_wr = 7;

  logic [3:0] mode = 0;
  logic [3:0] next_mode = 0;

  logic io0_oe = 0;
  logic io1_oe = 0;
  logic io2_oe = 0;
  logic io3_oe = 0;

  logic io0_dout = 0;
  logic io1_dout = 0;
  logic io2_dout = 0;
  logic io3_dout = 0;

  assign io0 = io0_oe ? io0_dout : 1'bz;
  assign io1 = io1_oe ? io1_dout : 1'bz;
  assign io2 = io2_oe ? io2_dout : 1'bz;
  assign io3 = io3_oe ? io3_dout : 1'bz;

  wire io0_delayed;
  wire io1_delayed;
  wire io2_delayed;
  wire io3_delayed;

  assign io0_delayed = io0;
  assign io1_delayed = io1;
  assign io2_delayed = io2;
  assign io3_delayed = io3;

  // 16 MB (128Mb) Flash
  logic [7:0] memory[16*1024*1024];

  task spi_action;
    begin
      spi_in = buffer;

      if (bytecount == 1) begin
        spi_cmd = buffer;

        // Only commands that can be executed while busy (Section 7.1.1):
        // - read status register ('h05, 'h35, 'h15)
        // - erase / program suspend ('h75)
        if (current_busy_cycles > 0 
            && spi_cmd != 'h05 && spi_cmd != 'h35 && spi_cmd != 'h15
            && spi_cmd != 'h75
        ) begin
          spi_cmd = 8'h00;
        end else begin
          if (spi_cmd == 8'hab) powered_up = 1;

          if (spi_cmd == 8'hb9) powered_up = 0;

          if (spi_cmd == 8'hff) xip_cmd = 0;

          if (spi_cmd == 8'h06) write_enable = 1;
        end
      end

      if (powered_up && spi_cmd == 'h03) begin
        if (bytecount == 2) spi_addr[23:16] = buffer;

        if (bytecount == 3) spi_addr[15:8] = buffer;

        if (bytecount == 4) spi_addr[7:0] = buffer;

        if (bytecount >= 4) begin
          buffer   = memory[spi_addr];
          spi_addr = spi_addr + 1;
        end
      end

      if (powered_up && spi_cmd == 'h05) begin
        if (bytecount == 1) begin
          // Simplified model:
          // - protect bits always 0
          buffer = {6'b000000, write_enable, (current_busy_cycles != 0)};
        end
      end

      if (powered_up && spi_cmd == 'h35) begin
        if (bytecount == 1) begin
          // Simplified model:
          // - All bits to 0 except QE bit
          buffer = {6'b000000, quad_enable, 1'b0};
        end
      end

      if (powered_up && spi_cmd == 'h31) begin
        if (bytecount == 2) begin
          // Simplified model:
          // - All bits to 0 except QE bit
          if (buffer[1] == 1'b1) quad_enable = buffer[1];
        end
      end

      if (powered_up && spi_cmd == 'hff) begin
        quad_enable = 1'b0;
      end

      if (powered_up && write_enable && spi_cmd == 'h02) begin
        if (bytecount == 1) begin
          write_enable_reset = 1;
          command_pending = 1;
        end

        if (bytecount == 2) spi_addr[23:16] = buffer;

        if (bytecount == 3) spi_addr[15:8] = buffer;

        if (bytecount == 4) spi_addr[7:0] = buffer;

        if (bytecount >= 5 && bytecount <= 260) begin
          memory[spi_addr] = buffer;
          spi_addr = spi_addr + 1;
        end
      end

      if (powered_up && write_enable && spi_cmd == 'h20) begin
        if (bytecount == 1) begin
          write_enable_reset = 1;
          command_pending = 1;
        end

        if (bytecount == 2) spi_addr[23:16] = buffer;

        if (bytecount == 3) spi_addr[15:8] = buffer;

        if (bytecount == 4) begin
          spi_addr[7:0] = buffer;

          erase_addr = spi_addr & 24'hfff000;
          for (erase_offset = 0; erase_offset < sector_size; erase_offset = erase_offset + 1) begin
            memory[erase_addr+erase_offset] = 8'hff;
          end
        end
      end

      if (powered_up && spi_cmd == 'hbb) begin
        if (bytecount == 1) mode = mode_dspi_rd;

        if (bytecount == 2) spi_addr[23:16] = buffer;

        if (bytecount == 3) spi_addr[15:8] = buffer;

        if (bytecount == 4) spi_addr[7:0] = buffer;

        if (bytecount == 5) begin
          xip_cmd = (buffer == 8'ha5) ? spi_cmd : 8'h00;
          mode = mode_dspi_wr;
          dummycount = latency;
        end

        if (bytecount >= 5) begin
          buffer   = memory[spi_addr];
          spi_addr = spi_addr + 1;
        end
      end

      if (powered_up && quad_enable && spi_cmd == 'heb) begin
        if (bytecount == 1) mode = mode_qspi_rd;

        if (bytecount == 2) spi_addr[23:16] = buffer;

        if (bytecount == 3) spi_addr[15:8] = buffer;

        if (bytecount == 4) spi_addr[7:0] = buffer;

        if (bytecount == 5) begin
          xip_cmd = (buffer == 8'ha5) ? spi_cmd : 8'h00;
          mode = mode_qspi_wr;
          dummycount = latency;
        end

        if (bytecount >= 5) begin
          buffer   = memory[spi_addr];
          spi_addr = spi_addr + 1;
        end
      end

      if (powered_up && write_enable && quad_enable && spi_cmd == 'h32) begin
        if (bytecount == 1) begin
          write_enable_reset = 1;
          command_pending = 1;
        end

        if (bytecount == 2) spi_addr[23:16] = buffer;

        if (bytecount == 3) spi_addr[15:8] = buffer;

        if (bytecount == 4) begin
          spi_addr[7:0] = buffer;
          mode = mode_qspi_rd;
        end

        if (bytecount >= 5 && bytecount <= 260) begin
          memory[spi_addr] = buffer;
          spi_addr = spi_addr + 1;
        end
      end

      if (powered_up && quad_enable && spi_cmd == 'hed) begin
        if (bytecount == 1) next_mode = mode_qspi_ddr_rd;

        if (bytecount == 2) spi_addr[23:16] = buffer;

        if (bytecount == 3) spi_addr[15:8] = buffer;

        if (bytecount == 4) spi_addr[7:0] = buffer;

        if (bytecount == 5) begin
          xip_cmd = (buffer == 8'ha5) ? spi_cmd : 8'h00;
          mode = mode_qspi_ddr_wr;
          dummycount = latency;
        end

        if (bytecount >= 5) begin
          buffer   = memory[spi_addr];
          spi_addr = spi_addr + 1;
        end
      end

      spi_out = buffer;
      spi_io_vld = 1;

      if (verbose) begin
        if (bytecount == 1) $write("<SPI-START>");
        $write("<SPI:%02x:%02x>", spi_in, spi_out);
      end

    end
  endtask

  task ddr_rd_edge;
    begin
      buffer   = {buffer[3:0], io3_delayed, io2_delayed, io1_delayed, io0_delayed};
      bitcount = bitcount + 4;
      if (bitcount == 8) begin
        bitcount  = 0;
        bytecount = bytecount + 1;
        spi_action;
      end
    end
  endtask

  task ddr_wr_edge;
    begin
      io0_oe   = 1;
      io1_oe   = 1;
      io2_oe   = 1;
      io3_oe   = 1;

      io0_dout = buffer[4];
      io1_dout = buffer[5];
      io2_dout = buffer[6];
      io3_dout = buffer[7];

      buffer   = {buffer[3:0], 4'h0};
      bitcount = bitcount + 4;
      if (bitcount == 8) begin
        bitcount  = 0;
        bytecount = bytecount + 1;
        spi_action;
      end
    end
  endtask

  always @(posedge csb or negedge csb) begin
    if (csb) begin
      if (verbose) begin
        $display("");
        $fflush();
      end
      if (write_enable_reset) begin
        write_enable = 0;
        write_enable_reset = 0;
      end
      if (command_pending) begin
        current_busy_cycles = busy_cycles;
        command_pending = 0;
      end
      buffer = 0;
      bitcount = 0;
      bytecount = 0;
      mode = mode_spi;
      io0_oe = 0;
      io1_oe = 0;
      io2_oe = 0;
      io3_oe = 0;
    end
    if (xip_cmd != 0) begin
      buffer = xip_cmd;
      bitcount = 0;
      bytecount = 1;
      spi_action;  // This looks like a task or function call; keep as-is
    end
  end

  always @(posedge csb or negedge csb or posedge clk or negedge clk) begin
    spi_io_vld = 0;
    if (!csb && !clk) begin
      if (dummycount > 0) begin
        io0_oe = 0;
        io1_oe = 0;
        io2_oe = 0;
        io3_oe = 0;
      end else
        case (mode)
          mode_spi: begin
            io0_oe   = 0;
            io1_oe   = 1;
            io2_oe   = 0;
            io3_oe   = 0;
            io1_dout = buffer[7];
          end
          mode_dspi_rd: begin
            io0_oe = 0;
            io1_oe = 0;
            io2_oe = 0;
            io3_oe = 0;
          end
          mode_dspi_wr: begin
            io0_oe   = 1;
            io1_oe   = 1;
            io2_oe   = 0;
            io3_oe   = 0;
            io0_dout = buffer[6];
            io1_dout = buffer[7];
          end
          mode_qspi_rd: begin
            io0_oe = 0;
            io1_oe = 0;
            io2_oe = 0;
            io3_oe = 0;
          end
          mode_qspi_wr: begin
            io0_oe   = 1;
            io1_oe   = 1;
            io2_oe   = 1;
            io3_oe   = 1;
            io0_dout = buffer[4];
            io1_dout = buffer[5];
            io2_dout = buffer[6];
            io3_dout = buffer[7];
          end
          mode_qspi_ddr_rd: begin
            ddr_rd_edge;
          end
          mode_qspi_ddr_wr: begin
            ddr_wr_edge;
          end
          default: begin
          end
        endcase
      if (next_mode != 0) begin
        case (next_mode)
          mode_qspi_ddr_rd: begin
            io0_oe = 0;
            io1_oe = 0;
            io2_oe = 0;
            io3_oe = 0;
          end
          mode_qspi_ddr_wr: begin
            io0_oe   = 1;
            io1_oe   = 1;
            io2_oe   = 1;
            io3_oe   = 1;
            io0_dout = buffer[4];
            io1_dout = buffer[5];
            io2_dout = buffer[6];
            io3_dout = buffer[7];
          end
          default: begin
          end
        endcase
        mode = next_mode;
        next_mode = 0;
      end
    end
  end

  always @(posedge clk) begin
    if (current_busy_cycles > 0) current_busy_cycles = current_busy_cycles - 1;

    if (!csb) begin
      if (dummycount > 0) begin
        dummycount = dummycount - 1;
      end else
        case (mode)
          mode_spi: begin
            buffer   = {buffer, io0};
            bitcount = bitcount + 1;
            if (bitcount == 8) begin
              bitcount  = 0;
              bytecount = bytecount + 1;
              spi_action;
            end
          end
          mode_dspi_rd, mode_dspi_wr: begin
            buffer   = {buffer, io1, io0};
            bitcount = bitcount + 2;
            if (bitcount == 8) begin
              bitcount  = 0;
              bytecount = bytecount + 1;
              spi_action;
            end
          end
          mode_qspi_rd, mode_qspi_wr: begin
            buffer   = {buffer, io3, io2, io1, io0};
            bitcount = bitcount + 4;
            if (bitcount == 8) begin
              bitcount  = 0;
              bytecount = bytecount + 1;
              spi_action;
            end
          end
          mode_qspi_ddr_rd: begin
            ddr_rd_edge;
          end
          mode_qspi_ddr_wr: begin
            ddr_wr_edge;
          end
          default: begin
          end
        endcase
    end
  end

endmodule
