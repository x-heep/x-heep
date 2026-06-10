// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module sram_wrapper #(
    parameter int unsigned NumWords = 32'd1024,  // Number of Words in data array
    parameter int unsigned DataWidth = 32'd32,  // Data signal width
    // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
    parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1
) (
    input  logic                 clk_i,    // Clock
    input  logic                 rst_ni,   // Asynchronous reset active low
    // input ports
    input  logic                 req_i,    // request
    input  logic                 we_i,     // write enable
    input  logic [AddrWidth-1:0] addr_i,   // request address
    input  logic [         31:0] wdata_i,  // write data
    input  logic [          3:0] be_i,     // write byte enable
    input  logic                 set_retentive_ni, // set retentive state (unused here)
    input  logic                 pwrgate_ni,      // power gate enable active low (unused in sky130)
    output logic                 pwrgate_ack_no,  // power gate ack active low (tie-through)
    // output ports
    output logic [         31:0] rdata_o   // read data
);

  assign pwrgate_ack_no = pwrgate_ni;

  if (NumWords != 8192) begin
    $error("Bank size not implemented.");
  end

  logic [8-1:0] unused;
  logic [8-1:0] cs;

  always_comb
  begin
    cs = '0;
    cs [ addr_i[AddrWidth-1:AddrWidth-3] ] = 1'b1;
  end

  sky130_sram_4kbyte_1rw_32x1024_8
  `ifndef SYNTHESIS
  #(
    .DELAY(0),
    .VERBOSE(0),
    .T_HOLD(0)
  )
  `endif
   cut0_i (
      .clk0   (clk_i),
      .csb0   (~cs[0]),
      .web0   (~we_i),
      .wmask0 (be_i),
      .addr0  ($unsigned(addr_i[AddrWidth-3-1:0])),
      .din0   ({1'b0, wdata_i}),
      .dout0  ({unused[0], rdata_o})//,
      //.spare_wen0 (1'b0)
  );

  sky130_sram_4kbyte_1rw_32x1024_8
  `ifndef SYNTHESIS
  #(
    .DELAY(0),
    .VERBOSE(0),
    .T_HOLD(0)
  )
  `endif
   cut1_i (
      .clk0   (clk_i),
      .csb0   (~cs[1]),
      .web0   (~we_i),
      .wmask0 (be_i),
      .addr0  ($unsigned(addr_i[AddrWidth-3-1:0])),
      .din0   ({1'b0, wdata_i}),
      .dout0  ({unused[1], rdata_o})//,
      //.spare_wen0 (1'b0)
  );

  sky130_sram_4kbyte_1rw_32x1024_8
  `ifndef SYNTHESIS
  #(
    .DELAY(0),
    .VERBOSE(0),
    .T_HOLD(0)
  )
  `endif
   cut2_i (
      .clk0   (clk_i),
      .csb0   (~cs[2]),
      .web0   (~we_i),
      .wmask0 (be_i),
      .addr0  ($unsigned(addr_i[AddrWidth-3-1:0])),
      .din0   ({1'b0, wdata_i}),
      .dout0  ({unused[2], rdata_o})//,
      //.spare_wen0 (1'b0)
  );


  sky130_sram_4kbyte_1rw_32x1024_8
  `ifndef SYNTHESIS
  #(
    .DELAY(0),
    .VERBOSE(0),
    .T_HOLD(0)
  )
  `endif
   cut3_i (
      .clk0   (clk_i),
      .csb0   (~cs[3]),
      .web0   (~we_i),
      .wmask0 (be_i),
      .addr0  ($unsigned(addr_i[AddrWidth-3-1:0])),
      .din0   ({1'b0, wdata_i}),
      .dout0  ({unused[3], rdata_o})//,
      //.spare_wen0 (1'b0)
  );

  sky130_sram_4kbyte_1rw_32x1024_8
  `ifndef SYNTHESIS
  #(
    .DELAY(0),
    .VERBOSE(0),
    .T_HOLD(0)
  )
  `endif
   cut4_i (
      .clk0   (clk_i),
      .csb0   (~cs[4]),
      .web0   (~we_i),
      .wmask0 (be_i),
      .addr0  ($unsigned(addr_i[AddrWidth-3-1:0])),
      .din0   ({1'b0, wdata_i}),
      .dout0  ({unused[4], rdata_o})//,
      //.spare_wen0 (1'b0)
  );

  sky130_sram_4kbyte_1rw_32x1024_8
  `ifndef SYNTHESIS
  #(
    .DELAY(0),
    .VERBOSE(0),
    .T_HOLD(0)
  )
  `endif
   cut5_i (
      .clk0   (clk_i),
      .csb0   (~cs[5]),
      .web0   (~we_i),
      .wmask0 (be_i),
      .addr0  ($unsigned(addr_i[AddrWidth-3-1:0])),
      .din0   ({1'b0, wdata_i}),
      .dout0  ({unused[5], rdata_o})//,
      //.spare_wen0 (1'b0)
  );

  sky130_sram_4kbyte_1rw_32x1024_8
  `ifndef SYNTHESIS
  #(
    .DELAY(0),
    .VERBOSE(0),
    .T_HOLD(0)
  )
  `endif
   cut6_i (
      .clk0   (clk_i),
      .csb0   (~cs[6]),
      .web0   (~we_i),
      .wmask0 (be_i),
      .addr0  ($unsigned(addr_i[AddrWidth-3-1:0])),
      .din0   ({1'b0, wdata_i}),
      .dout0  ({unused[6], rdata_o})//,
      //.spare_wen0 (1'b0)
  );

  sky130_sram_4kbyte_1rw_32x1024_8
  `ifndef SYNTHESIS
  #(
    .DELAY(0),
    .VERBOSE(0),
    .T_HOLD(0)
  )
  `endif
   cut7_i (
      .clk0   (clk_i),
      .csb0   (~cs[7]),
      .web0   (~we_i),
      .wmask0 (be_i),
      .addr0  ($unsigned(addr_i[AddrWidth-3-1:0])),
      .din0   ({1'b0, wdata_i}),
      .dout0  ({unused[7], rdata_o})//,
      //.spare_wen0 (1'b0)
  );

endmodule // sram_wrapper