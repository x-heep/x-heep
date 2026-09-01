// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// 7-series output stage for the HDMI transmitter: four 10:1 serialisers turning
// the TMDS words into serial lanes, plus a fixed word on the clock lane. Each
// lane leaves through an OBUFDS driving a TMDS_33 differential pair.
//
// At 640x480@60 the pixel clock is 25 MHz, so each lane runs at 250 Mbit/s. That
// is far below what an HR bank can do, and the OSERDESE2 primitives need CLK at
// five times CLKDIV with both coming from the same MMCM.
//
// One serialiser per pair, not two: a 10:1 DDR conversion needs a cascaded
// master/slave OSERDESE2, and the SHIFTOUT/SHIFTIN chain only runs between the
// two OLOGIC blocks of one differential pair (UG471). A 10:1 lane therefore
// occupies the OLOGIC of both pins and can only emit on the master's pin, which
// is exactly why the complementary side has to come from OBUFDS rather than from
// a second serialiser.
//
// This module is Xilinx-specific on purpose. It sits in the FPGA wrapper so the
// RTL inside the MCU stays portable and simulable.

module hdmi_tmds_out_xilinx (
    input logic pclk_i,    // pixel clock, drives CLKDIV
    input logic pclk5x_i,  // 5x pixel clock, drives CLK
    input logic rst_i,     // active high, synchronous to pclk_i

    input logic [9:0] tmds_ch0_i,  // blue + syncs
    input logic [9:0] tmds_ch1_i,  // green
    input logic [9:0] tmds_ch2_i,  // red

    output logic       hdmi_clk_p_o,
    output logic       hdmi_clk_n_o,
    output logic [2:0] hdmi_data_p_o,
    output logic [2:0] hdmi_data_n_o
);

  // Five ones then five zeros: a square wave at the pixel rate. Sending it
  // through the same kind of serialiser as the data keeps the clock lane aligned
  // with the data lanes by construction, rather than by constraint.
  localparam logic [9:0] ClkWord = 10'b0000011111;

  logic [9:0] lane_word[4];

  assign lane_word[0] = tmds_ch0_i;
  assign lane_word[1] = tmds_ch1_i;
  assign lane_word[2] = tmds_ch2_i;
  assign lane_word[3] = ClkWord;

  logic [3:0] serial;
  logic [3:0] pad_p, pad_n;

  for (genvar i = 0; i < 4; i++) begin : gen_lane
    hdmi_oserdes10 ser_i (
        .pclk_i,
        .pclk5x_i,
        .rst_i,
        .data_i  (lane_word[i]),
        .serial_o(serial[i])
    );

    // The IOB generates the complement, so the two halves of the pair are
    // matched by construction instead of by placement.
    OBUFDS obufds_i (
        .I (serial[i]),
        .O (pad_p[i]),
        .OB(pad_n[i])
    );
  end

  assign hdmi_data_p_o = pad_p[2:0];
  assign hdmi_data_n_o = pad_n[2:0];
  assign hdmi_clk_p_o  = pad_p[3];
  assign hdmi_clk_n_o  = pad_n[3];

endmodule  // hdmi_tmds_out_xilinx


// One 10:1 DDR serialiser, built from the usual OSERDESE2 master/slave pair
// (Xilinx XAPP585). D1 leaves first, and TMDS words go out LSB first, so bit 0
// maps to D1.
module hdmi_oserdes10 (
    input logic pclk_i,
    input logic pclk5x_i,
    input logic rst_i,

    input  logic [9:0] data_i,
    output logic       serial_o
);

  logic shift1, shift2;

  OSERDESE2 #(
      .DATA_RATE_OQ  ("DDR"),
      .DATA_RATE_TQ  ("SDR"),
      .DATA_WIDTH    (10),
      .SERDES_MODE   ("MASTER"),
      .TRISTATE_WIDTH(1),
      .TBYTE_CTL     ("FALSE"),
      .TBYTE_SRC     ("FALSE")
  ) oserdes_master_i (
      .OQ       (serial_o),
      .OFB      (),
      .TQ       (),
      .TFB      (),
      .SHIFTOUT1(),
      .SHIFTOUT2(),
      .TBYTEOUT (),
      .CLK      (pclk5x_i),
      .CLKDIV   (pclk_i),
      .D1       (data_i[0]),
      .D2       (data_i[1]),
      .D3       (data_i[2]),
      .D4       (data_i[3]),
      .D5       (data_i[4]),
      .D6       (data_i[5]),
      .D7       (data_i[6]),
      .D8       (data_i[7]),
      .OCE      (1'b1),
      .TCE      (1'b0),
      .TBYTEIN  (1'b0),
      .RST      (rst_i),
      .SHIFTIN1 (shift1),
      .SHIFTIN2 (shift2),
      .T1       (1'b0),
      .T2       (1'b0),
      .T3       (1'b0),
      .T4       (1'b0)
  );

  // The slave carries the two bits that do not fit in the master and passes them
  // up through the shift chain.
  OSERDESE2 #(
      .DATA_RATE_OQ  ("DDR"),
      .DATA_RATE_TQ  ("SDR"),
      .DATA_WIDTH    (10),
      .SERDES_MODE   ("SLAVE"),
      .TRISTATE_WIDTH(1),
      .TBYTE_CTL     ("FALSE"),
      .TBYTE_SRC     ("FALSE")
  ) oserdes_slave_i (
      .OQ       (),
      .OFB      (),
      .TQ       (),
      .TFB      (),
      .SHIFTOUT1(shift1),
      .SHIFTOUT2(shift2),
      .TBYTEOUT (),
      .CLK      (pclk5x_i),
      .CLKDIV   (pclk_i),
      .D1       (1'b0),
      .D2       (1'b0),
      .D3       (data_i[8]),
      .D4       (data_i[9]),
      .D5       (1'b0),
      .D6       (1'b0),
      .D7       (1'b0),
      .D8       (1'b0),
      .OCE      (1'b1),
      .TCE      (1'b0),
      .TBYTEIN  (1'b0),
      .RST      (rst_i),
      .SHIFTIN1 (1'b0),
      .SHIFTIN2 (1'b0),
      .T1       (1'b0),
      .T2       (1'b0),
      .T3       (1'b0),
      .T4       (1'b0)
  );

endmodule  // hdmi_oserdes10
