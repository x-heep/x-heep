// Copyright 2022 Silicon Labs, Inc.
//
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License");
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/SHL-2.0/
//
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Authors:        Oivind Ekelund - oivind.ekelund@silabs.com                 //
//                                                                            //
// Description:    RVFI tracer.                                               //
//                 Parses itb file and generates trace based on retired       //
//                 instruction address                                        //
//                 The path of the .itb file is given using the plusarg       //
//                 defined by ITB_PLUSARG                                     //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module rvfi_sim_trace
  import cv32e40x_rvfi_pkg::*;
  #(parameter string ITB_PLUSARG = "itb_file",
    parameter string LOGFILE_PATH_PLUSARG = "log_file",
    parameter logic  ITRACE_ENABLE = 1)
  (
   input logic        rvfi_valid,
   input logic [31:0] rvfi_pc_rdata,
   input logic [4:0]  rvfi_rs1_addr,
   input logic [31:0] rvfi_rs1_rdata,
   input logic [4:0]  rvfi_rs2_addr,
   input logic [31:0] rvfi_rs2_rdata,
   input logic [4:0]  rvfi_rd_addr,
   input logic [31:0] rvfi_rd_wdata,
   input logic [32*NMEM-1:0] rvfi_mem_addr ,
   input logic [ 4*NMEM-1:0] rvfi_mem_rmask,
   input logic [ 4*NMEM-1:0] rvfi_mem_wmask,
   input logic [32*NMEM-1:0] rvfi_mem_rdata,
   input logic [32*NMEM-1:0] rvfi_mem_wdata
   );

  typedef struct      {
    bit [32*16-1:0]  c_file;
    bit [32*16-1:0]  c_func;
    int              c_line;
    logic [31:0]     addr;
    logic [31:0]     mcode;
    bit [32*16-1:0]  asm;
  } trace_t;

  localparam trace_t TRACE_UNKNOWN = '{c_func : "NA",
                                       c_file : "NA",
                                       c_line : -1,
                                       addr   : 'x,
                                       mcode  : 'x,
                                       asm    : "NA"};

  trace_t itrace, tmp_trace;
  trace_t imap[int];
  int                 file, logfile;
  int                 elements_found, asmlen;
  string              filename, logfilename, line;
  string              asms[5];
  string              asm_string, rvfi_info_string;
  bit                 itb_file_ok, logfile_ok, enable_log_write;

  // Populate itrace based on retired instruction
  // todo: update tracer to support Zc sequences
  //       Currently only the lower index of rvfi_mem is used, and no usage of rvfi_gpr*
  generate
  begin
    if (ITRACE_ENABLE) begin
      always @ (rvfi_valid, rvfi_pc_rdata) begin
        if (rvfi_valid) begin
          if (^rvfi_pc_rdata !== 1'bx && imap.exists(rvfi_pc_rdata)) begin
            // Pick trace from instruction map
            itrace = imap[rvfi_pc_rdata];
            if (logfile_ok) begin
              rvfi_info_string = $sformatf(
                "0x%8h | x%-2d (0x%8h) | x%-2d (0x%8h) | x%-2d (0x%8h) | 0x%8h | 0x%4b | 0x%8h | 0x%4b | 0x%8h ||",
                                                                rvfi_pc_rdata,
                                                                rvfi_rs1_addr, rvfi_rs1_rdata,
                                                                rvfi_rs2_addr, rvfi_rs2_rdata,
                                                                rvfi_rd_addr, rvfi_rd_wdata,
                                                                rvfi_mem_addr[31:0],
                                                                rvfi_mem_rmask[3:0], rvfi_mem_rdata[31:0],
                                                                rvfi_mem_wmask[3:0], rvfi_mem_wdata[31:0]);
              asm_string = $sformatf("%-s %-s",  rvfi_info_string, string'(itrace.asm));
              $fdisplay(logfile, asm_string);
              asm_string = "";
            end
          end
          else begin
            itrace = TRACE_UNKNOWN;
          end
        end
      end

      // Parse the listing file
      initial begin
        enable_log_write = 1'b1;

        $display("RISC-V Trace: Using itb path defined by plusarg: %s", ITB_PLUSARG);

        if (!$value$plusargs({LOGFILE_PATH_PLUSARG,"=%s"}, logfilename)) begin
          $display($sformatf("Not generating instruction trace log file, please supply +%0s=<PATH> if desired.", LOGFILE_PATH_PLUSARG));
          enable_log_write = 1'b0;
        end

        if (!$value$plusargs({ITB_PLUSARG,"=%s"}, filename)) begin
          $display("RISC-V Trace: No instruction table file found.");
        end
        else begin

          file = $fopen(filename, "r");
          if (enable_log_write == 1'b1) begin
            logfile = $fopen(logfilename, "w");
            if (logfile == 0) begin
              $warning("Failed to open log file: %0s", logfilename);
              logfile_ok = 1'b0;
            end
            else begin
              logfile_ok = 1'b1;
              $fdisplay(logfile, {$sformatf("%-10s | %-3s (%-10s) | %-3s (%-10s) | %-3s (%-10s) | ",
                                  "pc", "rs1", "   data", "rs2", "   data", "rd", "   data"),
                                  $sformatf("%-10s | %-6s | %-10s | %-6s | %-10s ||  Assembly",
                                  "memaddr", "rmask", "rdata", "wmask", "wdata")
                      });
              $fdisplay(logfile, {"==================================================================",
                                  "=========================================================================="});
            end
          end

          if (file == 0) begin
            $display("RISC-V Trace: Failed to open instruction table file %s", filename);
            itb_file_ok = 1'b0;
          end
          else begin

            $display("RISC-V Trace: Loading instruction table file %s", filename);
            itb_file_ok = 1'b1;

            // Iterate through itb file
            while ($fgets(line, file)) begin
              // Skip comments
              if(line[0] != "#") begin

                // Search for expected pattern in line
                elements_found = $sscanf(line, "%d %s %s %d %h %d %s %s %s %s %s",
                                         tmp_trace.addr, tmp_trace.c_func, tmp_trace.c_file, tmp_trace.c_line, tmp_trace.mcode, asmlen, asms[0], asms[1], asms[2], asms[3], asms[4]);

                if (elements_found > 6) begin
                  // Fetch assembly instruction
                  for (int i=0; i < asmlen; i++) begin
                    if(asms[i] == "#") break; // Disregard comments

                    // Concatenate assembly instruction
                    $cast(tmp_trace.asm,  $sformatf("%-0s %-0s", tmp_trace.asm, asms[i]));
                  end

                  imap[tmp_trace.addr] = tmp_trace;
                  tmp_trace.asm = "";
                end
              end
            end
          end
          $fclose(file);
          $display("RISC-V Trace: Loaded %d instructions.", imap.size());
        end
      end

      final begin
        if (logfile_ok) begin
          $fclose(logfile);
        end
      end
    end
  end
  endgenerate
endmodule
