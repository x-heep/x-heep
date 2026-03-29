/*
 *  Copyright (C) 2019  Claire Wolf <claire@symbioticeda.com>
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

module rvb_bextdep #(
	parameter integer XLEN = 64,
	parameter integer GREV = 1,
	parameter integer SHFL = 1,
	parameter integer FFS = 1
) (
	// control signals
	input             clock,          // positive edge clock
	input             reset,          // synchronous reset

	// data input
	input             din_valid,      // input is valid
	output            din_ready,      // core accepts input
	input  [XLEN-1:0] din_rs1,        // value of 1st argument
	input  [XLEN-1:0] din_rs2,        // value of 2nd argument
	input             din_insn3,      // value of instruction bit 3
	input             din_insn13,     // value of instruction bit 13
	input             din_insn14,     // value of instruction bit 14
	input             din_insn29,     // value of instruction bit 29
	input             din_insn30,     // value of instruction bit 30

	// data output
	output            dout_valid,     // output is valid
	input             dout_ready,     // accept output
	output [XLEN-1:0] dout_rd         // output value
);
	// 30 29 14 13  3   Function
	// --------------   --------
	//  0  1  1  0  W   GORC
	//  1  1  1  0  W   GREV
	//  0  0  0  0  W   SHFL
	//  0  0  1  0  W   UNSHFL
	//  1  0  1  1  W   BDEP
	//  0  0  1  1  W   BEXT

	wire enable = !dout_valid || dout_ready;
	assign din_ready = enable && !reset;

	//  2  1  0   Function
	// --------   --------
	//  0  1  1   GORC
	//  0  1  0   GREV
	//  1  1  1   SHFL
	//  1  1  0   UNSHFL
	//  0  0  1   BDEP
	//  0  0  0   BEXT
	wire [2:0] din_mode =
			(GREV && din_insn29) ? (din_insn30 ? 3'b010 : 3'b011) :
			(SHFL && !din_insn13) ? {2'b11, !din_insn14} : {2'b00, din_insn30};

	wire [XLEN-1:0] din_rs1_w = din_rs1 & (din_insn3 ? 64'h 0000_0000_ffff_ffff : 64'h ffff_ffff_ffff_ffff);
	wire [XLEN-1:0] din_rs2_w = din_rs2 & (din_insn3 ? (din_insn13 ? 64'h 0000_0000_ffff_ffff : 64'h 0000_0000_ffff_ffdf) : 64'h ffff_ffff_ffff_ffff);
	wire [XLEN-1:0] dout_rd_w;

	wire [5:0] shfl_mask = (XLEN == 32 || din_insn3) ? din_rs2_w[3:0] : din_rs2_w[4:0];
	wire [XLEN-1:0] din_mask = (SHFL && din_mode[2]) ? {din_rs2_w[XLEN-1:6], shfl_mask} : din_rs2_w;

	wire dout_insn3;
	generate if (FFS) begin
		reg [FFS-1:0] din_insn3_q;
		always @(posedge clock) if (enable) din_insn3_q <= {din_insn3_q, din_insn3};
		assign dout_insn3 = din_insn3_q[FFS-1];
	end else begin
		assign dout_insn3 = din_insn3;
	end endgenerate

	wire dout_valid_t;
	assign dout_valid = dout_valid_t && !reset;

	assign dout_rd = dout_insn3 ? {{32{dout_rd_w[31]}}, dout_rd_w[31:0]} : dout_rd_w;

	rvb_bextdep_xlen_pipeline #(
		.GREV(GREV),
		.SHFL(SHFL),
		.XLEN(XLEN),
		.FFS(FFS)
	) core (
		.clock       (clock         ),
		.reset       (reset         ),
		.enable      (enable        ),
		.din_valid   (din_valid     ),
		.din_mode    (din_mode      ),
		.din_value   (din_rs1_w     ),
		.din_mask    (din_mask      ),
		.dout_valid  (dout_valid_t  ),
		.dout_result (dout_rd_w     )
	);
endmodule

module rvb_bextdep_xlen_pipeline #(
	parameter integer GREV = 1,
	parameter integer SHFL = 1,
	parameter integer XLEN = 32,
	parameter integer FFS = 1
) (
	input                 clock,
	input                 reset,
	input                 enable,

	input                 din_valid,
	input      [     2:0] din_mode,
	input      [XLEN-1:0] din_value,
	input      [XLEN-1:0] din_mask,

	output reg            dout_valid,
	output reg [XLEN-1:0] dout_result
);
	wire [XLEN/2-1:0] decoder_s1, decoder_s2, decoder_s4;
	wire [XLEN/2-1:0] decoder_s8, decoder_s16, decoder_s32;

	rvb_bextdep_decoder #(
		.XLEN(XLEN),
		.FFSTAGE(FFS == 3)
	) decoder (
		.clock  (clock      ),
		.enable (enable     ),
		.mask   (din_mask   ),
		.s1     (decoder_s1 ),
		.s2     (decoder_s2 ),
		.s4     (decoder_s4 ),
		.s8     (decoder_s8 ),
		.s16    (decoder_s16),
		.s32    (decoder_s32)
	);

	reg valid_t;
	reg [2:0] din_mode_t;
	reg [XLEN-1:0] din_value_t, din_mask_t;

	reg valid_r;
	reg [2:0] din_mode_r;
	reg [XLEN-1:0] din_value_r, din_mask_r;
	reg [XLEN/2-1:0] decoder_s1_r, decoder_s2_r, decoder_s4_r;
	reg [XLEN/2-1:0] decoder_s8_r, decoder_s16_r, decoder_s32_r;

	generate
		if (FFS == 3) begin
			always @(posedge clock) begin
				if (enable) begin
					valid_t <= din_valid;
					din_mode_t <= din_mode;
					din_value_t <= din_value;
					din_mask_t <= din_mask;

					valid_r <= valid_t;
					din_mode_r <= din_mode_t;
					din_value_r <= din_value_t;
					din_mask_r <= din_mask_t;

					decoder_s1_r <= decoder_s1;
					decoder_s2_r <= decoder_s2;
					decoder_s4_r <= decoder_s4;
					decoder_s8_r <= decoder_s8;
					decoder_s16_r <= decoder_s16;
					decoder_s32_r <= decoder_s32;
				end

				if (reset) begin
					valid_t <= 0;
					valid_r <= 0;
				end
			end
		end else
		if (FFS == 2) begin
			always @(posedge clock) begin
				if (enable) begin
					valid_r <= din_valid;
					din_mode_r <= din_mode;
					din_value_r <= din_value;
					din_mask_r <= din_mask;

					decoder_s1_r <= decoder_s1;
					decoder_s2_r <= decoder_s2;
					decoder_s4_r <= decoder_s4;
					decoder_s8_r <= decoder_s8;
					decoder_s16_r <= decoder_s16;
					decoder_s32_r <= decoder_s32;
				end

				if (reset) begin
					valid_r <= 0;
				end
			end
		end else begin
			always @* begin
				valid_r = !reset && din_valid;

				din_mode_r = din_mode;
				din_value_r = din_value;
				din_mask_r = din_mask;

				decoder_s1_r = decoder_s1;
				decoder_s2_r = decoder_s2;
				decoder_s4_r = decoder_s4;
				decoder_s8_r = decoder_s8;
				decoder_s16_r = decoder_s16;
				decoder_s32_r = decoder_s32;
			end
		end
	endgenerate

	wire [XLEN-1:0] result_fwd;
	wire [XLEN-1:0] result_bwd;

	wire [XLEN/2-1:0] s1  = (SHFL && din_mode_r[2]) ? {XLEN/2{1'b0}} : (GREV && din_mode_r[1]) ? {XLEN/2{din_mask_r[0]}} : ~decoder_s1_r;
	wire [XLEN/2-1:0] s2  = (SHFL && din_mode_r[2]) ? {XLEN/2{1'b0}} : (GREV && din_mode_r[1]) ? {XLEN/2{din_mask_r[1]}} : ~decoder_s2_r;
	wire [XLEN/2-1:0] s4  = (SHFL && din_mode_r[2]) ? {XLEN/2{1'b0}} : (GREV && din_mode_r[1]) ? {XLEN/2{din_mask_r[2]}} : ~decoder_s4_r;
	wire [XLEN/2-1:0] s8  = (SHFL && din_mode_r[2]) ? {XLEN/2{1'b0}} : (GREV && din_mode_r[1]) ? {XLEN/2{din_mask_r[3]}} : ~decoder_s8_r;
	wire [XLEN/2-1:0] s16 = (SHFL && din_mode_r[2]) ? {XLEN/2{1'b0}} : (GREV && din_mode_r[1]) ? {XLEN/2{din_mask_r[4]}} : ~decoder_s16_r;
	wire [XLEN/2-1:0] s32 =                                  ((SHFL || GREV) && din_mode_r[1]) ? {XLEN/2{din_mask_r[5]}} : ~decoder_s32_r;

	rvb_bextdep_butterfly_fwd #(
		.XLEN(XLEN),
		.SHFL(SHFL),
		.GORC(GREV)
	) butterfly_fwd (
		.gorc    (din_mode_r == 3'b011),
		.shfl_en (SHFL && din_mode_r[2]),
		.shfl    (din_mask_r[4:0]),
		.din     (din_value_r),
		.s1      (s1 ),
		.s2      (s2 ),
		.s4      (s4 ),
		.s8      (s8 ),
		.s16     (s16),
		.s32     (s32),
		.dout    (result_fwd)
	);

	rvb_bextdep_butterfly_bwd #(
		.XLEN(XLEN),
		.SHFL(SHFL),
		.GORC(0)
	) butterfly_bwd (
		.gorc    (1'b0),
		.shfl_en (SHFL && din_mode_r[2]),
		.shfl    (din_mask_r[4:0]),
		.din     (din_value_r & (din_mask_r | {XLEN{(SHFL || GREV) && din_mode_r[1]}})),
		.s1      (s1 ),
		.s2      (s2 ),
		.s4      (s4 ),
		.s8      (s8 ),
		.s16     (s16),
		.s32     (s32),
		.dout    (result_bwd)
	);

	generate if (FFS) begin
		always @(posedge clock) begin
			if (enable) begin
				dout_valid <= valid_r;
				dout_result <= din_mode_r[0] ? (((SHFL || GREV) && din_mode_r[1]) ? result_fwd : (result_fwd & din_mask_r)) : result_bwd;
			end
			if (reset) begin
				dout_valid <= 0;
			end
		end
	end else begin
		always @* begin
			dout_valid = din_valid;
			dout_result = din_mode_r[0] ? (((SHFL || GREV) && din_mode_r[1]) ? result_fwd : (result_fwd & din_mask_r)) : result_bwd;
		end
	end endgenerate
endmodule

// ========================================================================

module rvb_bextdep_lrotcz #(
	parameter integer N = 1,
	parameter integer M = 1
) (
	input [7:0] din,
	output [M-1:0] dout
);
	wire [2*M-1:0] mask = {M{1'b1}};
	assign dout = (mask << din[N-1:0]) >> M;
endmodule

module rvb_bextdep_decoder #(
	parameter integer XLEN = 32,
	parameter integer FFSTAGE = 1
) (
	input clock, enable,
	input [XLEN-1:0] mask,
	output [XLEN/2-1:0] s1, s2, s4, s8, s16, s32,
	output [7:0] sum
);
	wire [8*XLEN-1:0] ppsdata;

	assign sum = ppsdata[8*(XLEN-1) +: 8];

	generate
		if (XLEN == 4 && !FFSTAGE) begin:pps4
			rvb_bextdep_pps4 pps_core (
				.din  (mask),
				.dout (ppsdata)
			);
		end
		if (XLEN == 8 && !FFSTAGE) begin:pps8
			rvb_bextdep_pps8 pps_core (
				.din  (mask),
				.dout (ppsdata)
			);
		end
		if (XLEN == 16 && !FFSTAGE) begin:pps16
			rvb_bextdep_pps16 pps_core (
				.din  (mask),
				.dout (ppsdata)
			);
		end
		if (XLEN == 32 && !FFSTAGE) begin:pps32
			rvb_bextdep_pps32 pps_core (
				.din  (mask),
				.dout (ppsdata)
			);
		end
		if (XLEN == 64 && !FFSTAGE) begin:pps64
			rvb_bextdep_pps64 pps_core (
				.din  (mask),
				.dout (ppsdata)
			);
		end
		if (XLEN == 32 && FFSTAGE) begin:pps32f
			rvb_bextdep_pps32f pps_core (
				.clock  (clock),
				.enable (enable),
				.din    (mask),
				.dout   (ppsdata)
			);
		end
		if (XLEN == 64 && FFSTAGE) begin:pps64f
			rvb_bextdep_pps64f pps_core (
				.clock  (clock),
				.enable (enable),
				.din    (mask),
				.dout   (ppsdata)
			);
		end
	endgenerate

	genvar i;
	generate
		for (i = 0; i < XLEN/2; i = i+1) begin:stage1
			rvb_bextdep_lrotcz #(.N(1), .M(1)) lrotc_zero (
				.din(ppsdata[8*(2*i + 1 - 1) +: 8]),
				.dout(s1[i])
			);
		end

		for (i = 0; i < XLEN/4; i = i+1) begin:stage2
			rvb_bextdep_lrotcz #(.N(2), .M(2)) lrotc_zero (
				.din(ppsdata[8*(4*i + 2 - 1) +: 8]),
				.dout(s2[2*i +: 2])
			);
		end

		for (i = 0; i < XLEN/8; i = i+1) begin:stage4
			rvb_bextdep_lrotcz #(.N(3), .M(4)) lrotc_zero (
				.din(ppsdata[8*(8*i + 4 - 1) +: 8]),
				.dout(s4[4*i +: 4])
			);
		end

		for (i = 0; i < XLEN/16; i = i+1) begin:stage8
			rvb_bextdep_lrotcz #(.N(4), .M(8)) lrotc_zero (
				.din(ppsdata[8*(16*i + 8 - 1) +: 8]),
				.dout(s8[8*i +: 8])
			);
		end

		for (i = 0; i < XLEN/32; i = i+1) begin:stage16
			rvb_bextdep_lrotcz #(.N(5), .M(16)) lrotc_zero (
				.din(ppsdata[8*(32*i + 16 - 1) +: 8]),
				.dout(s16[16*i +: 16])
			);
		end

		for (i = 0; i < XLEN/64; i = i+1) begin:stage32
			rvb_bextdep_lrotcz #(.N(6), .M(32)) lrotc_zero (
				.din(ppsdata[8*(64*i + 32 - 1) +: 8]),
				.dout(s32[32*i +: 32])
			);
		end
	endgenerate
endmodule

// ========================================================================
// -x- Everything below this line is auto-generated by bflymaker.py and ppsmaker.py

module rvb_bextdep_butterfly_fwd #(
  parameter integer XLEN = 32,
  parameter integer SHFL = 1,
  parameter integer GORC = 1
) (
  input gorc,
  input shfl_en,
  input [4:0] shfl,
  input [XLEN-1:0] din,
  input [XLEN/2-1:0] s1, s2, s4, s8, s16, s32,
  output [XLEN-1:0] dout
);
  wire orc = GORC && gorc;
  wire [4:0] sh = SHFL && shfl_en ? (XLEN == 64 ? shfl : shfl[3:0]) : 5'b0;
  wire [31:0] x1 = s1, x2 = s2, x4 = s4, x8 = s8, x16 = s16;
  wire [31:0] x32 = XLEN == 64 ? s32 : 32'b0;
  wire [63:0] start = din;
  wire [63:0] bfly32;
  assign bfly32[0] = x32[0] ? (start[32] | (orc & start[0])): start[0];
  assign bfly32[1] = x32[1] ? (start[33] | (orc & start[1])): start[1];
  assign bfly32[2] = x32[2] ? (start[34] | (orc & start[2])): start[2];
  assign bfly32[3] = x32[3] ? (start[35] | (orc & start[3])): start[3];
  assign bfly32[4] = x32[4] ? (start[36] | (orc & start[4])): start[4];
  assign bfly32[5] = x32[5] ? (start[37] | (orc & start[5])): start[5];
  assign bfly32[6] = x32[6] ? (start[38] | (orc & start[6])): start[6];
  assign bfly32[7] = x32[7] ? (start[39] | (orc & start[7])): start[7];
  assign bfly32[8] = x32[8] ? (start[40] | (orc & start[8])): start[8];
  assign bfly32[9] = x32[9] ? (start[41] | (orc & start[9])): start[9];
  assign bfly32[10] = x32[10] ? (start[42] | (orc & start[10])): start[10];
  assign bfly32[11] = x32[11] ? (start[43] | (orc & start[11])): start[11];
  assign bfly32[12] = x32[12] ? (start[44] | (orc & start[12])): start[12];
  assign bfly32[13] = x32[13] ? (start[45] | (orc & start[13])): start[13];
  assign bfly32[14] = x32[14] ? (start[46] | (orc & start[14])): start[14];
  assign bfly32[15] = x32[15] ? (start[47] | (orc & start[15])): start[15];
  assign bfly32[16] = x32[16] ? (start[48] | (orc & start[16])): start[16];
  assign bfly32[17] = x32[17] ? (start[49] | (orc & start[17])): start[17];
  assign bfly32[18] = x32[18] ? (start[50] | (orc & start[18])): start[18];
  assign bfly32[19] = x32[19] ? (start[51] | (orc & start[19])): start[19];
  assign bfly32[20] = x32[20] ? (start[52] | (orc & start[20])): start[20];
  assign bfly32[21] = x32[21] ? (start[53] | (orc & start[21])): start[21];
  assign bfly32[22] = x32[22] ? (start[54] | (orc & start[22])): start[22];
  assign bfly32[23] = x32[23] ? (start[55] | (orc & start[23])): start[23];
  assign bfly32[24] = x32[24] ? (start[56] | (orc & start[24])): start[24];
  assign bfly32[25] = x32[25] ? (start[57] | (orc & start[25])): start[25];
  assign bfly32[26] = x32[26] ? (start[58] | (orc & start[26])): start[26];
  assign bfly32[27] = x32[27] ? (start[59] | (orc & start[27])): start[27];
  assign bfly32[28] = x32[28] ? (start[60] | (orc & start[28])): start[28];
  assign bfly32[29] = x32[29] ? (start[61] | (orc & start[29])): start[29];
  assign bfly32[30] = x32[30] ? (start[62] | (orc & start[30])): start[30];
  assign bfly32[31] = x32[31] ? (start[63] | (orc & start[31])): start[31];
  assign bfly32[32] = x32[0] ? (start[0] | (orc & start[32])): start[32];
  assign bfly32[33] = x32[1] ? (start[1] | (orc & start[33])): start[33];
  assign bfly32[34] = x32[2] ? (start[2] | (orc & start[34])): start[34];
  assign bfly32[35] = x32[3] ? (start[3] | (orc & start[35])): start[35];
  assign bfly32[36] = x32[4] ? (start[4] | (orc & start[36])): start[36];
  assign bfly32[37] = x32[5] ? (start[5] | (orc & start[37])): start[37];
  assign bfly32[38] = x32[6] ? (start[6] | (orc & start[38])): start[38];
  assign bfly32[39] = x32[7] ? (start[7] | (orc & start[39])): start[39];
  assign bfly32[40] = x32[8] ? (start[8] | (orc & start[40])): start[40];
  assign bfly32[41] = x32[9] ? (start[9] | (orc & start[41])): start[41];
  assign bfly32[42] = x32[10] ? (start[10] | (orc & start[42])): start[42];
  assign bfly32[43] = x32[11] ? (start[11] | (orc & start[43])): start[43];
  assign bfly32[44] = x32[12] ? (start[12] | (orc & start[44])): start[44];
  assign bfly32[45] = x32[13] ? (start[13] | (orc & start[45])): start[45];
  assign bfly32[46] = x32[14] ? (start[14] | (orc & start[46])): start[46];
  assign bfly32[47] = x32[15] ? (start[15] | (orc & start[47])): start[47];
  assign bfly32[48] = x32[16] ? (start[16] | (orc & start[48])): start[48];
  assign bfly32[49] = x32[17] ? (start[17] | (orc & start[49])): start[49];
  assign bfly32[50] = x32[18] ? (start[18] | (orc & start[50])): start[50];
  assign bfly32[51] = x32[19] ? (start[19] | (orc & start[51])): start[51];
  assign bfly32[52] = x32[20] ? (start[20] | (orc & start[52])): start[52];
  assign bfly32[53] = x32[21] ? (start[21] | (orc & start[53])): start[53];
  assign bfly32[54] = x32[22] ? (start[22] | (orc & start[54])): start[54];
  assign bfly32[55] = x32[23] ? (start[23] | (orc & start[55])): start[55];
  assign bfly32[56] = x32[24] ? (start[24] | (orc & start[56])): start[56];
  assign bfly32[57] = x32[25] ? (start[25] | (orc & start[57])): start[57];
  assign bfly32[58] = x32[26] ? (start[26] | (orc & start[58])): start[58];
  assign bfly32[59] = x32[27] ? (start[27] | (orc & start[59])): start[59];
  assign bfly32[60] = x32[28] ? (start[28] | (orc & start[60])): start[60];
  assign bfly32[61] = x32[29] ? (start[29] | (orc & start[61])): start[61];
  assign bfly32[62] = x32[30] ? (start[30] | (orc & start[62])): start[62];
  assign bfly32[63] = x32[31] ? (start[31] | (orc & start[63])): start[63];
  wire [63:0] bfly16;
  assign bfly16[0] = x16[0] ? (bfly32[16] | (orc & bfly32[0])): bfly32[0];
  assign bfly16[1] = x16[1] ? (bfly32[17] | (orc & bfly32[1])): bfly32[1];
  assign bfly16[2] = x16[2] ? (bfly32[18] | (orc & bfly32[2])): bfly32[2];
  assign bfly16[3] = x16[3] ? (bfly32[19] | (orc & bfly32[3])): bfly32[3];
  assign bfly16[4] = x16[4] ? (bfly32[20] | (orc & bfly32[4])): bfly32[4];
  assign bfly16[5] = x16[5] ? (bfly32[21] | (orc & bfly32[5])): bfly32[5];
  assign bfly16[6] = x16[6] ? (bfly32[22] | (orc & bfly32[6])): bfly32[6];
  assign bfly16[7] = x16[7] ? (bfly32[23] | (orc & bfly32[7])): bfly32[7];
  assign bfly16[8] = x16[8] ? (bfly32[24] | (orc & bfly32[8])): bfly32[8];
  assign bfly16[9] = x16[9] ? (bfly32[25] | (orc & bfly32[9])): bfly32[9];
  assign bfly16[10] = x16[10] ? (bfly32[26] | (orc & bfly32[10])): bfly32[10];
  assign bfly16[11] = x16[11] ? (bfly32[27] | (orc & bfly32[11])): bfly32[11];
  assign bfly16[12] = x16[12] ? (bfly32[28] | (orc & bfly32[12])): bfly32[12];
  assign bfly16[13] = x16[13] ? (bfly32[29] | (orc & bfly32[13])): bfly32[13];
  assign bfly16[14] = x16[14] ? (bfly32[30] | (orc & bfly32[14])): bfly32[14];
  assign bfly16[15] = x16[15] ? (bfly32[31] | (orc & bfly32[15])): bfly32[15];
  assign bfly16[16] = sh[4] ? bfly32[32] : (x16[0] ? (bfly32[0] | (orc & bfly32[16])) : bfly32[16]);
  assign bfly16[17] = sh[4] ? bfly32[33] : (x16[1] ? (bfly32[1] | (orc & bfly32[17])) : bfly32[17]);
  assign bfly16[18] = sh[4] ? bfly32[34] : (x16[2] ? (bfly32[2] | (orc & bfly32[18])) : bfly32[18]);
  assign bfly16[19] = sh[4] ? bfly32[35] : (x16[3] ? (bfly32[3] | (orc & bfly32[19])) : bfly32[19]);
  assign bfly16[20] = sh[4] ? bfly32[36] : (x16[4] ? (bfly32[4] | (orc & bfly32[20])) : bfly32[20]);
  assign bfly16[21] = sh[4] ? bfly32[37] : (x16[5] ? (bfly32[5] | (orc & bfly32[21])) : bfly32[21]);
  assign bfly16[22] = sh[4] ? bfly32[38] : (x16[6] ? (bfly32[6] | (orc & bfly32[22])) : bfly32[22]);
  assign bfly16[23] = sh[4] ? bfly32[39] : (x16[7] ? (bfly32[7] | (orc & bfly32[23])) : bfly32[23]);
  assign bfly16[24] = sh[4] ? bfly32[40] : (x16[8] ? (bfly32[8] | (orc & bfly32[24])) : bfly32[24]);
  assign bfly16[25] = sh[4] ? bfly32[41] : (x16[9] ? (bfly32[9] | (orc & bfly32[25])) : bfly32[25]);
  assign bfly16[26] = sh[4] ? bfly32[42] : (x16[10] ? (bfly32[10] | (orc & bfly32[26])) : bfly32[26]);
  assign bfly16[27] = sh[4] ? bfly32[43] : (x16[11] ? (bfly32[11] | (orc & bfly32[27])) : bfly32[27]);
  assign bfly16[28] = sh[4] ? bfly32[44] : (x16[12] ? (bfly32[12] | (orc & bfly32[28])) : bfly32[28]);
  assign bfly16[29] = sh[4] ? bfly32[45] : (x16[13] ? (bfly32[13] | (orc & bfly32[29])) : bfly32[29]);
  assign bfly16[30] = sh[4] ? bfly32[46] : (x16[14] ? (bfly32[14] | (orc & bfly32[30])) : bfly32[30]);
  assign bfly16[31] = sh[4] ? bfly32[47] : (x16[15] ? (bfly32[15] | (orc & bfly32[31])) : bfly32[31]);
  assign bfly16[32] = sh[4] ? bfly32[16] : (x16[16] ? (bfly32[48] | (orc & bfly32[32])) : bfly32[32]);
  assign bfly16[33] = sh[4] ? bfly32[17] : (x16[17] ? (bfly32[49] | (orc & bfly32[33])) : bfly32[33]);
  assign bfly16[34] = sh[4] ? bfly32[18] : (x16[18] ? (bfly32[50] | (orc & bfly32[34])) : bfly32[34]);
  assign bfly16[35] = sh[4] ? bfly32[19] : (x16[19] ? (bfly32[51] | (orc & bfly32[35])) : bfly32[35]);
  assign bfly16[36] = sh[4] ? bfly32[20] : (x16[20] ? (bfly32[52] | (orc & bfly32[36])) : bfly32[36]);
  assign bfly16[37] = sh[4] ? bfly32[21] : (x16[21] ? (bfly32[53] | (orc & bfly32[37])) : bfly32[37]);
  assign bfly16[38] = sh[4] ? bfly32[22] : (x16[22] ? (bfly32[54] | (orc & bfly32[38])) : bfly32[38]);
  assign bfly16[39] = sh[4] ? bfly32[23] : (x16[23] ? (bfly32[55] | (orc & bfly32[39])) : bfly32[39]);
  assign bfly16[40] = sh[4] ? bfly32[24] : (x16[24] ? (bfly32[56] | (orc & bfly32[40])) : bfly32[40]);
  assign bfly16[41] = sh[4] ? bfly32[25] : (x16[25] ? (bfly32[57] | (orc & bfly32[41])) : bfly32[41]);
  assign bfly16[42] = sh[4] ? bfly32[26] : (x16[26] ? (bfly32[58] | (orc & bfly32[42])) : bfly32[42]);
  assign bfly16[43] = sh[4] ? bfly32[27] : (x16[27] ? (bfly32[59] | (orc & bfly32[43])) : bfly32[43]);
  assign bfly16[44] = sh[4] ? bfly32[28] : (x16[28] ? (bfly32[60] | (orc & bfly32[44])) : bfly32[44]);
  assign bfly16[45] = sh[4] ? bfly32[29] : (x16[29] ? (bfly32[61] | (orc & bfly32[45])) : bfly32[45]);
  assign bfly16[46] = sh[4] ? bfly32[30] : (x16[30] ? (bfly32[62] | (orc & bfly32[46])) : bfly32[46]);
  assign bfly16[47] = sh[4] ? bfly32[31] : (x16[31] ? (bfly32[63] | (orc & bfly32[47])) : bfly32[47]);
  assign bfly16[48] = x16[16] ? (bfly32[32] | (orc & bfly32[48])): bfly32[48];
  assign bfly16[49] = x16[17] ? (bfly32[33] | (orc & bfly32[49])): bfly32[49];
  assign bfly16[50] = x16[18] ? (bfly32[34] | (orc & bfly32[50])): bfly32[50];
  assign bfly16[51] = x16[19] ? (bfly32[35] | (orc & bfly32[51])): bfly32[51];
  assign bfly16[52] = x16[20] ? (bfly32[36] | (orc & bfly32[52])): bfly32[52];
  assign bfly16[53] = x16[21] ? (bfly32[37] | (orc & bfly32[53])): bfly32[53];
  assign bfly16[54] = x16[22] ? (bfly32[38] | (orc & bfly32[54])): bfly32[54];
  assign bfly16[55] = x16[23] ? (bfly32[39] | (orc & bfly32[55])): bfly32[55];
  assign bfly16[56] = x16[24] ? (bfly32[40] | (orc & bfly32[56])): bfly32[56];
  assign bfly16[57] = x16[25] ? (bfly32[41] | (orc & bfly32[57])): bfly32[57];
  assign bfly16[58] = x16[26] ? (bfly32[42] | (orc & bfly32[58])): bfly32[58];
  assign bfly16[59] = x16[27] ? (bfly32[43] | (orc & bfly32[59])): bfly32[59];
  assign bfly16[60] = x16[28] ? (bfly32[44] | (orc & bfly32[60])): bfly32[60];
  assign bfly16[61] = x16[29] ? (bfly32[45] | (orc & bfly32[61])): bfly32[61];
  assign bfly16[62] = x16[30] ? (bfly32[46] | (orc & bfly32[62])): bfly32[62];
  assign bfly16[63] = x16[31] ? (bfly32[47] | (orc & bfly32[63])): bfly32[63];
  wire [63:0] bfly8;
  assign bfly8[0] = x8[0] ? (bfly16[8] | (orc & bfly16[0])): bfly16[0];
  assign bfly8[1] = x8[1] ? (bfly16[9] | (orc & bfly16[1])): bfly16[1];
  assign bfly8[2] = x8[2] ? (bfly16[10] | (orc & bfly16[2])): bfly16[2];
  assign bfly8[3] = x8[3] ? (bfly16[11] | (orc & bfly16[3])): bfly16[3];
  assign bfly8[4] = x8[4] ? (bfly16[12] | (orc & bfly16[4])): bfly16[4];
  assign bfly8[5] = x8[5] ? (bfly16[13] | (orc & bfly16[5])): bfly16[5];
  assign bfly8[6] = x8[6] ? (bfly16[14] | (orc & bfly16[6])): bfly16[6];
  assign bfly8[7] = x8[7] ? (bfly16[15] | (orc & bfly16[7])): bfly16[7];
  assign bfly8[8] = sh[3] ? bfly16[16] : (x8[0] ? (bfly16[0] | (orc & bfly16[8])) : bfly16[8]);
  assign bfly8[9] = sh[3] ? bfly16[17] : (x8[1] ? (bfly16[1] | (orc & bfly16[9])) : bfly16[9]);
  assign bfly8[10] = sh[3] ? bfly16[18] : (x8[2] ? (bfly16[2] | (orc & bfly16[10])) : bfly16[10]);
  assign bfly8[11] = sh[3] ? bfly16[19] : (x8[3] ? (bfly16[3] | (orc & bfly16[11])) : bfly16[11]);
  assign bfly8[12] = sh[3] ? bfly16[20] : (x8[4] ? (bfly16[4] | (orc & bfly16[12])) : bfly16[12]);
  assign bfly8[13] = sh[3] ? bfly16[21] : (x8[5] ? (bfly16[5] | (orc & bfly16[13])) : bfly16[13]);
  assign bfly8[14] = sh[3] ? bfly16[22] : (x8[6] ? (bfly16[6] | (orc & bfly16[14])) : bfly16[14]);
  assign bfly8[15] = sh[3] ? bfly16[23] : (x8[7] ? (bfly16[7] | (orc & bfly16[15])) : bfly16[15]);
  assign bfly8[16] = sh[3] ? bfly16[8] : (x8[8] ? (bfly16[24] | (orc & bfly16[16])) : bfly16[16]);
  assign bfly8[17] = sh[3] ? bfly16[9] : (x8[9] ? (bfly16[25] | (orc & bfly16[17])) : bfly16[17]);
  assign bfly8[18] = sh[3] ? bfly16[10] : (x8[10] ? (bfly16[26] | (orc & bfly16[18])) : bfly16[18]);
  assign bfly8[19] = sh[3] ? bfly16[11] : (x8[11] ? (bfly16[27] | (orc & bfly16[19])) : bfly16[19]);
  assign bfly8[20] = sh[3] ? bfly16[12] : (x8[12] ? (bfly16[28] | (orc & bfly16[20])) : bfly16[20]);
  assign bfly8[21] = sh[3] ? bfly16[13] : (x8[13] ? (bfly16[29] | (orc & bfly16[21])) : bfly16[21]);
  assign bfly8[22] = sh[3] ? bfly16[14] : (x8[14] ? (bfly16[30] | (orc & bfly16[22])) : bfly16[22]);
  assign bfly8[23] = sh[3] ? bfly16[15] : (x8[15] ? (bfly16[31] | (orc & bfly16[23])) : bfly16[23]);
  assign bfly8[24] = x8[8] ? (bfly16[16] | (orc & bfly16[24])): bfly16[24];
  assign bfly8[25] = x8[9] ? (bfly16[17] | (orc & bfly16[25])): bfly16[25];
  assign bfly8[26] = x8[10] ? (bfly16[18] | (orc & bfly16[26])): bfly16[26];
  assign bfly8[27] = x8[11] ? (bfly16[19] | (orc & bfly16[27])): bfly16[27];
  assign bfly8[28] = x8[12] ? (bfly16[20] | (orc & bfly16[28])): bfly16[28];
  assign bfly8[29] = x8[13] ? (bfly16[21] | (orc & bfly16[29])): bfly16[29];
  assign bfly8[30] = x8[14] ? (bfly16[22] | (orc & bfly16[30])): bfly16[30];
  assign bfly8[31] = x8[15] ? (bfly16[23] | (orc & bfly16[31])): bfly16[31];
  assign bfly8[32] = x8[16] ? (bfly16[40] | (orc & bfly16[32])): bfly16[32];
  assign bfly8[33] = x8[17] ? (bfly16[41] | (orc & bfly16[33])): bfly16[33];
  assign bfly8[34] = x8[18] ? (bfly16[42] | (orc & bfly16[34])): bfly16[34];
  assign bfly8[35] = x8[19] ? (bfly16[43] | (orc & bfly16[35])): bfly16[35];
  assign bfly8[36] = x8[20] ? (bfly16[44] | (orc & bfly16[36])): bfly16[36];
  assign bfly8[37] = x8[21] ? (bfly16[45] | (orc & bfly16[37])): bfly16[37];
  assign bfly8[38] = x8[22] ? (bfly16[46] | (orc & bfly16[38])): bfly16[38];
  assign bfly8[39] = x8[23] ? (bfly16[47] | (orc & bfly16[39])): bfly16[39];
  assign bfly8[40] = sh[3] ? bfly16[48] : (x8[16] ? (bfly16[32] | (orc & bfly16[40])) : bfly16[40]);
  assign bfly8[41] = sh[3] ? bfly16[49] : (x8[17] ? (bfly16[33] | (orc & bfly16[41])) : bfly16[41]);
  assign bfly8[42] = sh[3] ? bfly16[50] : (x8[18] ? (bfly16[34] | (orc & bfly16[42])) : bfly16[42]);
  assign bfly8[43] = sh[3] ? bfly16[51] : (x8[19] ? (bfly16[35] | (orc & bfly16[43])) : bfly16[43]);
  assign bfly8[44] = sh[3] ? bfly16[52] : (x8[20] ? (bfly16[36] | (orc & bfly16[44])) : bfly16[44]);
  assign bfly8[45] = sh[3] ? bfly16[53] : (x8[21] ? (bfly16[37] | (orc & bfly16[45])) : bfly16[45]);
  assign bfly8[46] = sh[3] ? bfly16[54] : (x8[22] ? (bfly16[38] | (orc & bfly16[46])) : bfly16[46]);
  assign bfly8[47] = sh[3] ? bfly16[55] : (x8[23] ? (bfly16[39] | (orc & bfly16[47])) : bfly16[47]);
  assign bfly8[48] = sh[3] ? bfly16[40] : (x8[24] ? (bfly16[56] | (orc & bfly16[48])) : bfly16[48]);
  assign bfly8[49] = sh[3] ? bfly16[41] : (x8[25] ? (bfly16[57] | (orc & bfly16[49])) : bfly16[49]);
  assign bfly8[50] = sh[3] ? bfly16[42] : (x8[26] ? (bfly16[58] | (orc & bfly16[50])) : bfly16[50]);
  assign bfly8[51] = sh[3] ? bfly16[43] : (x8[27] ? (bfly16[59] | (orc & bfly16[51])) : bfly16[51]);
  assign bfly8[52] = sh[3] ? bfly16[44] : (x8[28] ? (bfly16[60] | (orc & bfly16[52])) : bfly16[52]);
  assign bfly8[53] = sh[3] ? bfly16[45] : (x8[29] ? (bfly16[61] | (orc & bfly16[53])) : bfly16[53]);
  assign bfly8[54] = sh[3] ? bfly16[46] : (x8[30] ? (bfly16[62] | (orc & bfly16[54])) : bfly16[54]);
  assign bfly8[55] = sh[3] ? bfly16[47] : (x8[31] ? (bfly16[63] | (orc & bfly16[55])) : bfly16[55]);
  assign bfly8[56] = x8[24] ? (bfly16[48] | (orc & bfly16[56])): bfly16[56];
  assign bfly8[57] = x8[25] ? (bfly16[49] | (orc & bfly16[57])): bfly16[57];
  assign bfly8[58] = x8[26] ? (bfly16[50] | (orc & bfly16[58])): bfly16[58];
  assign bfly8[59] = x8[27] ? (bfly16[51] | (orc & bfly16[59])): bfly16[59];
  assign bfly8[60] = x8[28] ? (bfly16[52] | (orc & bfly16[60])): bfly16[60];
  assign bfly8[61] = x8[29] ? (bfly16[53] | (orc & bfly16[61])): bfly16[61];
  assign bfly8[62] = x8[30] ? (bfly16[54] | (orc & bfly16[62])): bfly16[62];
  assign bfly8[63] = x8[31] ? (bfly16[55] | (orc & bfly16[63])): bfly16[63];
  wire [63:0] bfly4;
  assign bfly4[0] = x4[0] ? (bfly8[4] | (orc & bfly8[0])): bfly8[0];
  assign bfly4[1] = x4[1] ? (bfly8[5] | (orc & bfly8[1])): bfly8[1];
  assign bfly4[2] = x4[2] ? (bfly8[6] | (orc & bfly8[2])): bfly8[2];
  assign bfly4[3] = x4[3] ? (bfly8[7] | (orc & bfly8[3])): bfly8[3];
  assign bfly4[4] = sh[2] ? bfly8[8] : (x4[0] ? (bfly8[0] | (orc & bfly8[4])) : bfly8[4]);
  assign bfly4[5] = sh[2] ? bfly8[9] : (x4[1] ? (bfly8[1] | (orc & bfly8[5])) : bfly8[5]);
  assign bfly4[6] = sh[2] ? bfly8[10] : (x4[2] ? (bfly8[2] | (orc & bfly8[6])) : bfly8[6]);
  assign bfly4[7] = sh[2] ? bfly8[11] : (x4[3] ? (bfly8[3] | (orc & bfly8[7])) : bfly8[7]);
  assign bfly4[8] = sh[2] ? bfly8[4] : (x4[4] ? (bfly8[12] | (orc & bfly8[8])) : bfly8[8]);
  assign bfly4[9] = sh[2] ? bfly8[5] : (x4[5] ? (bfly8[13] | (orc & bfly8[9])) : bfly8[9]);
  assign bfly4[10] = sh[2] ? bfly8[6] : (x4[6] ? (bfly8[14] | (orc & bfly8[10])) : bfly8[10]);
  assign bfly4[11] = sh[2] ? bfly8[7] : (x4[7] ? (bfly8[15] | (orc & bfly8[11])) : bfly8[11]);
  assign bfly4[12] = x4[4] ? (bfly8[8] | (orc & bfly8[12])): bfly8[12];
  assign bfly4[13] = x4[5] ? (bfly8[9] | (orc & bfly8[13])): bfly8[13];
  assign bfly4[14] = x4[6] ? (bfly8[10] | (orc & bfly8[14])): bfly8[14];
  assign bfly4[15] = x4[7] ? (bfly8[11] | (orc & bfly8[15])): bfly8[15];
  assign bfly4[16] = x4[8] ? (bfly8[20] | (orc & bfly8[16])): bfly8[16];
  assign bfly4[17] = x4[9] ? (bfly8[21] | (orc & bfly8[17])): bfly8[17];
  assign bfly4[18] = x4[10] ? (bfly8[22] | (orc & bfly8[18])): bfly8[18];
  assign bfly4[19] = x4[11] ? (bfly8[23] | (orc & bfly8[19])): bfly8[19];
  assign bfly4[20] = sh[2] ? bfly8[24] : (x4[8] ? (bfly8[16] | (orc & bfly8[20])) : bfly8[20]);
  assign bfly4[21] = sh[2] ? bfly8[25] : (x4[9] ? (bfly8[17] | (orc & bfly8[21])) : bfly8[21]);
  assign bfly4[22] = sh[2] ? bfly8[26] : (x4[10] ? (bfly8[18] | (orc & bfly8[22])) : bfly8[22]);
  assign bfly4[23] = sh[2] ? bfly8[27] : (x4[11] ? (bfly8[19] | (orc & bfly8[23])) : bfly8[23]);
  assign bfly4[24] = sh[2] ? bfly8[20] : (x4[12] ? (bfly8[28] | (orc & bfly8[24])) : bfly8[24]);
  assign bfly4[25] = sh[2] ? bfly8[21] : (x4[13] ? (bfly8[29] | (orc & bfly8[25])) : bfly8[25]);
  assign bfly4[26] = sh[2] ? bfly8[22] : (x4[14] ? (bfly8[30] | (orc & bfly8[26])) : bfly8[26]);
  assign bfly4[27] = sh[2] ? bfly8[23] : (x4[15] ? (bfly8[31] | (orc & bfly8[27])) : bfly8[27]);
  assign bfly4[28] = x4[12] ? (bfly8[24] | (orc & bfly8[28])): bfly8[28];
  assign bfly4[29] = x4[13] ? (bfly8[25] | (orc & bfly8[29])): bfly8[29];
  assign bfly4[30] = x4[14] ? (bfly8[26] | (orc & bfly8[30])): bfly8[30];
  assign bfly4[31] = x4[15] ? (bfly8[27] | (orc & bfly8[31])): bfly8[31];
  assign bfly4[32] = x4[16] ? (bfly8[36] | (orc & bfly8[32])): bfly8[32];
  assign bfly4[33] = x4[17] ? (bfly8[37] | (orc & bfly8[33])): bfly8[33];
  assign bfly4[34] = x4[18] ? (bfly8[38] | (orc & bfly8[34])): bfly8[34];
  assign bfly4[35] = x4[19] ? (bfly8[39] | (orc & bfly8[35])): bfly8[35];
  assign bfly4[36] = sh[2] ? bfly8[40] : (x4[16] ? (bfly8[32] | (orc & bfly8[36])) : bfly8[36]);
  assign bfly4[37] = sh[2] ? bfly8[41] : (x4[17] ? (bfly8[33] | (orc & bfly8[37])) : bfly8[37]);
  assign bfly4[38] = sh[2] ? bfly8[42] : (x4[18] ? (bfly8[34] | (orc & bfly8[38])) : bfly8[38]);
  assign bfly4[39] = sh[2] ? bfly8[43] : (x4[19] ? (bfly8[35] | (orc & bfly8[39])) : bfly8[39]);
  assign bfly4[40] = sh[2] ? bfly8[36] : (x4[20] ? (bfly8[44] | (orc & bfly8[40])) : bfly8[40]);
  assign bfly4[41] = sh[2] ? bfly8[37] : (x4[21] ? (bfly8[45] | (orc & bfly8[41])) : bfly8[41]);
  assign bfly4[42] = sh[2] ? bfly8[38] : (x4[22] ? (bfly8[46] | (orc & bfly8[42])) : bfly8[42]);
  assign bfly4[43] = sh[2] ? bfly8[39] : (x4[23] ? (bfly8[47] | (orc & bfly8[43])) : bfly8[43]);
  assign bfly4[44] = x4[20] ? (bfly8[40] | (orc & bfly8[44])): bfly8[44];
  assign bfly4[45] = x4[21] ? (bfly8[41] | (orc & bfly8[45])): bfly8[45];
  assign bfly4[46] = x4[22] ? (bfly8[42] | (orc & bfly8[46])): bfly8[46];
  assign bfly4[47] = x4[23] ? (bfly8[43] | (orc & bfly8[47])): bfly8[47];
  assign bfly4[48] = x4[24] ? (bfly8[52] | (orc & bfly8[48])): bfly8[48];
  assign bfly4[49] = x4[25] ? (bfly8[53] | (orc & bfly8[49])): bfly8[49];
  assign bfly4[50] = x4[26] ? (bfly8[54] | (orc & bfly8[50])): bfly8[50];
  assign bfly4[51] = x4[27] ? (bfly8[55] | (orc & bfly8[51])): bfly8[51];
  assign bfly4[52] = sh[2] ? bfly8[56] : (x4[24] ? (bfly8[48] | (orc & bfly8[52])) : bfly8[52]);
  assign bfly4[53] = sh[2] ? bfly8[57] : (x4[25] ? (bfly8[49] | (orc & bfly8[53])) : bfly8[53]);
  assign bfly4[54] = sh[2] ? bfly8[58] : (x4[26] ? (bfly8[50] | (orc & bfly8[54])) : bfly8[54]);
  assign bfly4[55] = sh[2] ? bfly8[59] : (x4[27] ? (bfly8[51] | (orc & bfly8[55])) : bfly8[55]);
  assign bfly4[56] = sh[2] ? bfly8[52] : (x4[28] ? (bfly8[60] | (orc & bfly8[56])) : bfly8[56]);
  assign bfly4[57] = sh[2] ? bfly8[53] : (x4[29] ? (bfly8[61] | (orc & bfly8[57])) : bfly8[57]);
  assign bfly4[58] = sh[2] ? bfly8[54] : (x4[30] ? (bfly8[62] | (orc & bfly8[58])) : bfly8[58]);
  assign bfly4[59] = sh[2] ? bfly8[55] : (x4[31] ? (bfly8[63] | (orc & bfly8[59])) : bfly8[59]);
  assign bfly4[60] = x4[28] ? (bfly8[56] | (orc & bfly8[60])): bfly8[60];
  assign bfly4[61] = x4[29] ? (bfly8[57] | (orc & bfly8[61])): bfly8[61];
  assign bfly4[62] = x4[30] ? (bfly8[58] | (orc & bfly8[62])): bfly8[62];
  assign bfly4[63] = x4[31] ? (bfly8[59] | (orc & bfly8[63])): bfly8[63];
  wire [63:0] bfly2;
  assign bfly2[0] = x2[0] ? (bfly4[2] | (orc & bfly4[0])): bfly4[0];
  assign bfly2[1] = x2[1] ? (bfly4[3] | (orc & bfly4[1])): bfly4[1];
  assign bfly2[2] = sh[1] ? bfly4[4] : (x2[0] ? (bfly4[0] | (orc & bfly4[2])) : bfly4[2]);
  assign bfly2[3] = sh[1] ? bfly4[5] : (x2[1] ? (bfly4[1] | (orc & bfly4[3])) : bfly4[3]);
  assign bfly2[4] = sh[1] ? bfly4[2] : (x2[2] ? (bfly4[6] | (orc & bfly4[4])) : bfly4[4]);
  assign bfly2[5] = sh[1] ? bfly4[3] : (x2[3] ? (bfly4[7] | (orc & bfly4[5])) : bfly4[5]);
  assign bfly2[6] = x2[2] ? (bfly4[4] | (orc & bfly4[6])): bfly4[6];
  assign bfly2[7] = x2[3] ? (bfly4[5] | (orc & bfly4[7])): bfly4[7];
  assign bfly2[8] = x2[4] ? (bfly4[10] | (orc & bfly4[8])): bfly4[8];
  assign bfly2[9] = x2[5] ? (bfly4[11] | (orc & bfly4[9])): bfly4[9];
  assign bfly2[10] = sh[1] ? bfly4[12] : (x2[4] ? (bfly4[8] | (orc & bfly4[10])) : bfly4[10]);
  assign bfly2[11] = sh[1] ? bfly4[13] : (x2[5] ? (bfly4[9] | (orc & bfly4[11])) : bfly4[11]);
  assign bfly2[12] = sh[1] ? bfly4[10] : (x2[6] ? (bfly4[14] | (orc & bfly4[12])) : bfly4[12]);
  assign bfly2[13] = sh[1] ? bfly4[11] : (x2[7] ? (bfly4[15] | (orc & bfly4[13])) : bfly4[13]);
  assign bfly2[14] = x2[6] ? (bfly4[12] | (orc & bfly4[14])): bfly4[14];
  assign bfly2[15] = x2[7] ? (bfly4[13] | (orc & bfly4[15])): bfly4[15];
  assign bfly2[16] = x2[8] ? (bfly4[18] | (orc & bfly4[16])): bfly4[16];
  assign bfly2[17] = x2[9] ? (bfly4[19] | (orc & bfly4[17])): bfly4[17];
  assign bfly2[18] = sh[1] ? bfly4[20] : (x2[8] ? (bfly4[16] | (orc & bfly4[18])) : bfly4[18]);
  assign bfly2[19] = sh[1] ? bfly4[21] : (x2[9] ? (bfly4[17] | (orc & bfly4[19])) : bfly4[19]);
  assign bfly2[20] = sh[1] ? bfly4[18] : (x2[10] ? (bfly4[22] | (orc & bfly4[20])) : bfly4[20]);
  assign bfly2[21] = sh[1] ? bfly4[19] : (x2[11] ? (bfly4[23] | (orc & bfly4[21])) : bfly4[21]);
  assign bfly2[22] = x2[10] ? (bfly4[20] | (orc & bfly4[22])): bfly4[22];
  assign bfly2[23] = x2[11] ? (bfly4[21] | (orc & bfly4[23])): bfly4[23];
  assign bfly2[24] = x2[12] ? (bfly4[26] | (orc & bfly4[24])): bfly4[24];
  assign bfly2[25] = x2[13] ? (bfly4[27] | (orc & bfly4[25])): bfly4[25];
  assign bfly2[26] = sh[1] ? bfly4[28] : (x2[12] ? (bfly4[24] | (orc & bfly4[26])) : bfly4[26]);
  assign bfly2[27] = sh[1] ? bfly4[29] : (x2[13] ? (bfly4[25] | (orc & bfly4[27])) : bfly4[27]);
  assign bfly2[28] = sh[1] ? bfly4[26] : (x2[14] ? (bfly4[30] | (orc & bfly4[28])) : bfly4[28]);
  assign bfly2[29] = sh[1] ? bfly4[27] : (x2[15] ? (bfly4[31] | (orc & bfly4[29])) : bfly4[29]);
  assign bfly2[30] = x2[14] ? (bfly4[28] | (orc & bfly4[30])): bfly4[30];
  assign bfly2[31] = x2[15] ? (bfly4[29] | (orc & bfly4[31])): bfly4[31];
  assign bfly2[32] = x2[16] ? (bfly4[34] | (orc & bfly4[32])): bfly4[32];
  assign bfly2[33] = x2[17] ? (bfly4[35] | (orc & bfly4[33])): bfly4[33];
  assign bfly2[34] = sh[1] ? bfly4[36] : (x2[16] ? (bfly4[32] | (orc & bfly4[34])) : bfly4[34]);
  assign bfly2[35] = sh[1] ? bfly4[37] : (x2[17] ? (bfly4[33] | (orc & bfly4[35])) : bfly4[35]);
  assign bfly2[36] = sh[1] ? bfly4[34] : (x2[18] ? (bfly4[38] | (orc & bfly4[36])) : bfly4[36]);
  assign bfly2[37] = sh[1] ? bfly4[35] : (x2[19] ? (bfly4[39] | (orc & bfly4[37])) : bfly4[37]);
  assign bfly2[38] = x2[18] ? (bfly4[36] | (orc & bfly4[38])): bfly4[38];
  assign bfly2[39] = x2[19] ? (bfly4[37] | (orc & bfly4[39])): bfly4[39];
  assign bfly2[40] = x2[20] ? (bfly4[42] | (orc & bfly4[40])): bfly4[40];
  assign bfly2[41] = x2[21] ? (bfly4[43] | (orc & bfly4[41])): bfly4[41];
  assign bfly2[42] = sh[1] ? bfly4[44] : (x2[20] ? (bfly4[40] | (orc & bfly4[42])) : bfly4[42]);
  assign bfly2[43] = sh[1] ? bfly4[45] : (x2[21] ? (bfly4[41] | (orc & bfly4[43])) : bfly4[43]);
  assign bfly2[44] = sh[1] ? bfly4[42] : (x2[22] ? (bfly4[46] | (orc & bfly4[44])) : bfly4[44]);
  assign bfly2[45] = sh[1] ? bfly4[43] : (x2[23] ? (bfly4[47] | (orc & bfly4[45])) : bfly4[45]);
  assign bfly2[46] = x2[22] ? (bfly4[44] | (orc & bfly4[46])): bfly4[46];
  assign bfly2[47] = x2[23] ? (bfly4[45] | (orc & bfly4[47])): bfly4[47];
  assign bfly2[48] = x2[24] ? (bfly4[50] | (orc & bfly4[48])): bfly4[48];
  assign bfly2[49] = x2[25] ? (bfly4[51] | (orc & bfly4[49])): bfly4[49];
  assign bfly2[50] = sh[1] ? bfly4[52] : (x2[24] ? (bfly4[48] | (orc & bfly4[50])) : bfly4[50]);
  assign bfly2[51] = sh[1] ? bfly4[53] : (x2[25] ? (bfly4[49] | (orc & bfly4[51])) : bfly4[51]);
  assign bfly2[52] = sh[1] ? bfly4[50] : (x2[26] ? (bfly4[54] | (orc & bfly4[52])) : bfly4[52]);
  assign bfly2[53] = sh[1] ? bfly4[51] : (x2[27] ? (bfly4[55] | (orc & bfly4[53])) : bfly4[53]);
  assign bfly2[54] = x2[26] ? (bfly4[52] | (orc & bfly4[54])): bfly4[54];
  assign bfly2[55] = x2[27] ? (bfly4[53] | (orc & bfly4[55])): bfly4[55];
  assign bfly2[56] = x2[28] ? (bfly4[58] | (orc & bfly4[56])): bfly4[56];
  assign bfly2[57] = x2[29] ? (bfly4[59] | (orc & bfly4[57])): bfly4[57];
  assign bfly2[58] = sh[1] ? bfly4[60] : (x2[28] ? (bfly4[56] | (orc & bfly4[58])) : bfly4[58]);
  assign bfly2[59] = sh[1] ? bfly4[61] : (x2[29] ? (bfly4[57] | (orc & bfly4[59])) : bfly4[59]);
  assign bfly2[60] = sh[1] ? bfly4[58] : (x2[30] ? (bfly4[62] | (orc & bfly4[60])) : bfly4[60]);
  assign bfly2[61] = sh[1] ? bfly4[59] : (x2[31] ? (bfly4[63] | (orc & bfly4[61])) : bfly4[61]);
  assign bfly2[62] = x2[30] ? (bfly4[60] | (orc & bfly4[62])): bfly4[62];
  assign bfly2[63] = x2[31] ? (bfly4[61] | (orc & bfly4[63])): bfly4[63];
  wire [63:0] bfly1;
  assign bfly1[0] = x1[0] ? (bfly2[1] | (orc & bfly2[0])): bfly2[0];
  assign bfly1[1] = sh[0] ? bfly2[2] : (x1[0] ? (bfly2[0] | (orc & bfly2[1])) : bfly2[1]);
  assign bfly1[2] = sh[0] ? bfly2[1] : (x1[1] ? (bfly2[3] | (orc & bfly2[2])) : bfly2[2]);
  assign bfly1[3] = x1[1] ? (bfly2[2] | (orc & bfly2[3])): bfly2[3];
  assign bfly1[4] = x1[2] ? (bfly2[5] | (orc & bfly2[4])): bfly2[4];
  assign bfly1[5] = sh[0] ? bfly2[6] : (x1[2] ? (bfly2[4] | (orc & bfly2[5])) : bfly2[5]);
  assign bfly1[6] = sh[0] ? bfly2[5] : (x1[3] ? (bfly2[7] | (orc & bfly2[6])) : bfly2[6]);
  assign bfly1[7] = x1[3] ? (bfly2[6] | (orc & bfly2[7])): bfly2[7];
  assign bfly1[8] = x1[4] ? (bfly2[9] | (orc & bfly2[8])): bfly2[8];
  assign bfly1[9] = sh[0] ? bfly2[10] : (x1[4] ? (bfly2[8] | (orc & bfly2[9])) : bfly2[9]);
  assign bfly1[10] = sh[0] ? bfly2[9] : (x1[5] ? (bfly2[11] | (orc & bfly2[10])) : bfly2[10]);
  assign bfly1[11] = x1[5] ? (bfly2[10] | (orc & bfly2[11])): bfly2[11];
  assign bfly1[12] = x1[6] ? (bfly2[13] | (orc & bfly2[12])): bfly2[12];
  assign bfly1[13] = sh[0] ? bfly2[14] : (x1[6] ? (bfly2[12] | (orc & bfly2[13])) : bfly2[13]);
  assign bfly1[14] = sh[0] ? bfly2[13] : (x1[7] ? (bfly2[15] | (orc & bfly2[14])) : bfly2[14]);
  assign bfly1[15] = x1[7] ? (bfly2[14] | (orc & bfly2[15])): bfly2[15];
  assign bfly1[16] = x1[8] ? (bfly2[17] | (orc & bfly2[16])): bfly2[16];
  assign bfly1[17] = sh[0] ? bfly2[18] : (x1[8] ? (bfly2[16] | (orc & bfly2[17])) : bfly2[17]);
  assign bfly1[18] = sh[0] ? bfly2[17] : (x1[9] ? (bfly2[19] | (orc & bfly2[18])) : bfly2[18]);
  assign bfly1[19] = x1[9] ? (bfly2[18] | (orc & bfly2[19])): bfly2[19];
  assign bfly1[20] = x1[10] ? (bfly2[21] | (orc & bfly2[20])): bfly2[20];
  assign bfly1[21] = sh[0] ? bfly2[22] : (x1[10] ? (bfly2[20] | (orc & bfly2[21])) : bfly2[21]);
  assign bfly1[22] = sh[0] ? bfly2[21] : (x1[11] ? (bfly2[23] | (orc & bfly2[22])) : bfly2[22]);
  assign bfly1[23] = x1[11] ? (bfly2[22] | (orc & bfly2[23])): bfly2[23];
  assign bfly1[24] = x1[12] ? (bfly2[25] | (orc & bfly2[24])): bfly2[24];
  assign bfly1[25] = sh[0] ? bfly2[26] : (x1[12] ? (bfly2[24] | (orc & bfly2[25])) : bfly2[25]);
  assign bfly1[26] = sh[0] ? bfly2[25] : (x1[13] ? (bfly2[27] | (orc & bfly2[26])) : bfly2[26]);
  assign bfly1[27] = x1[13] ? (bfly2[26] | (orc & bfly2[27])): bfly2[27];
  assign bfly1[28] = x1[14] ? (bfly2[29] | (orc & bfly2[28])): bfly2[28];
  assign bfly1[29] = sh[0] ? bfly2[30] : (x1[14] ? (bfly2[28] | (orc & bfly2[29])) : bfly2[29]);
  assign bfly1[30] = sh[0] ? bfly2[29] : (x1[15] ? (bfly2[31] | (orc & bfly2[30])) : bfly2[30]);
  assign bfly1[31] = x1[15] ? (bfly2[30] | (orc & bfly2[31])): bfly2[31];
  assign bfly1[32] = x1[16] ? (bfly2[33] | (orc & bfly2[32])): bfly2[32];
  assign bfly1[33] = sh[0] ? bfly2[34] : (x1[16] ? (bfly2[32] | (orc & bfly2[33])) : bfly2[33]);
  assign bfly1[34] = sh[0] ? bfly2[33] : (x1[17] ? (bfly2[35] | (orc & bfly2[34])) : bfly2[34]);
  assign bfly1[35] = x1[17] ? (bfly2[34] | (orc & bfly2[35])): bfly2[35];
  assign bfly1[36] = x1[18] ? (bfly2[37] | (orc & bfly2[36])): bfly2[36];
  assign bfly1[37] = sh[0] ? bfly2[38] : (x1[18] ? (bfly2[36] | (orc & bfly2[37])) : bfly2[37]);
  assign bfly1[38] = sh[0] ? bfly2[37] : (x1[19] ? (bfly2[39] | (orc & bfly2[38])) : bfly2[38]);
  assign bfly1[39] = x1[19] ? (bfly2[38] | (orc & bfly2[39])): bfly2[39];
  assign bfly1[40] = x1[20] ? (bfly2[41] | (orc & bfly2[40])): bfly2[40];
  assign bfly1[41] = sh[0] ? bfly2[42] : (x1[20] ? (bfly2[40] | (orc & bfly2[41])) : bfly2[41]);
  assign bfly1[42] = sh[0] ? bfly2[41] : (x1[21] ? (bfly2[43] | (orc & bfly2[42])) : bfly2[42]);
  assign bfly1[43] = x1[21] ? (bfly2[42] | (orc & bfly2[43])): bfly2[43];
  assign bfly1[44] = x1[22] ? (bfly2[45] | (orc & bfly2[44])): bfly2[44];
  assign bfly1[45] = sh[0] ? bfly2[46] : (x1[22] ? (bfly2[44] | (orc & bfly2[45])) : bfly2[45]);
  assign bfly1[46] = sh[0] ? bfly2[45] : (x1[23] ? (bfly2[47] | (orc & bfly2[46])) : bfly2[46]);
  assign bfly1[47] = x1[23] ? (bfly2[46] | (orc & bfly2[47])): bfly2[47];
  assign bfly1[48] = x1[24] ? (bfly2[49] | (orc & bfly2[48])): bfly2[48];
  assign bfly1[49] = sh[0] ? bfly2[50] : (x1[24] ? (bfly2[48] | (orc & bfly2[49])) : bfly2[49]);
  assign bfly1[50] = sh[0] ? bfly2[49] : (x1[25] ? (bfly2[51] | (orc & bfly2[50])) : bfly2[50]);
  assign bfly1[51] = x1[25] ? (bfly2[50] | (orc & bfly2[51])): bfly2[51];
  assign bfly1[52] = x1[26] ? (bfly2[53] | (orc & bfly2[52])): bfly2[52];
  assign bfly1[53] = sh[0] ? bfly2[54] : (x1[26] ? (bfly2[52] | (orc & bfly2[53])) : bfly2[53]);
  assign bfly1[54] = sh[0] ? bfly2[53] : (x1[27] ? (bfly2[55] | (orc & bfly2[54])) : bfly2[54]);
  assign bfly1[55] = x1[27] ? (bfly2[54] | (orc & bfly2[55])): bfly2[55];
  assign bfly1[56] = x1[28] ? (bfly2[57] | (orc & bfly2[56])): bfly2[56];
  assign bfly1[57] = sh[0] ? bfly2[58] : (x1[28] ? (bfly2[56] | (orc & bfly2[57])) : bfly2[57]);
  assign bfly1[58] = sh[0] ? bfly2[57] : (x1[29] ? (bfly2[59] | (orc & bfly2[58])) : bfly2[58]);
  assign bfly1[59] = x1[29] ? (bfly2[58] | (orc & bfly2[59])): bfly2[59];
  assign bfly1[60] = x1[30] ? (bfly2[61] | (orc & bfly2[60])): bfly2[60];
  assign bfly1[61] = sh[0] ? bfly2[62] : (x1[30] ? (bfly2[60] | (orc & bfly2[61])) : bfly2[61]);
  assign bfly1[62] = sh[0] ? bfly2[61] : (x1[31] ? (bfly2[63] | (orc & bfly2[62])) : bfly2[62]);
  assign bfly1[63] = x1[31] ? (bfly2[62] | (orc & bfly2[63])): bfly2[63];
  assign dout = bfly1;
endmodule
module rvb_bextdep_butterfly_bwd #(
  parameter integer XLEN = 32,
  parameter integer SHFL = 1,
  parameter integer GORC = 1
) (
  input gorc,
  input shfl_en,
  input [4:0] shfl,
  input [XLEN-1:0] din,
  input [XLEN/2-1:0] s1, s2, s4, s8, s16, s32,
  output [XLEN-1:0] dout
);
  wire orc = GORC && gorc;
  wire [4:0] sh = SHFL && shfl_en ? (XLEN == 64 ? shfl : shfl[3:0]) : 5'b0;
  wire [31:0] x1 = s1, x2 = s2, x4 = s4, x8 = s8, x16 = s16;
  wire [31:0] x32 = XLEN == 64 ? s32 : 32'b0;
  wire [63:0] start = din;
  wire [63:0] bfly1;
  assign bfly1[0] = x1[0] ? (start[1] | (orc & start[0])): start[0];
  assign bfly1[1] = sh[0] ? start[2] : (x1[0] ? (start[0] | (orc & start[1])) : start[1]);
  assign bfly1[2] = sh[0] ? start[1] : (x1[1] ? (start[3] | (orc & start[2])) : start[2]);
  assign bfly1[3] = x1[1] ? (start[2] | (orc & start[3])): start[3];
  assign bfly1[4] = x1[2] ? (start[5] | (orc & start[4])): start[4];
  assign bfly1[5] = sh[0] ? start[6] : (x1[2] ? (start[4] | (orc & start[5])) : start[5]);
  assign bfly1[6] = sh[0] ? start[5] : (x1[3] ? (start[7] | (orc & start[6])) : start[6]);
  assign bfly1[7] = x1[3] ? (start[6] | (orc & start[7])): start[7];
  assign bfly1[8] = x1[4] ? (start[9] | (orc & start[8])): start[8];
  assign bfly1[9] = sh[0] ? start[10] : (x1[4] ? (start[8] | (orc & start[9])) : start[9]);
  assign bfly1[10] = sh[0] ? start[9] : (x1[5] ? (start[11] | (orc & start[10])) : start[10]);
  assign bfly1[11] = x1[5] ? (start[10] | (orc & start[11])): start[11];
  assign bfly1[12] = x1[6] ? (start[13] | (orc & start[12])): start[12];
  assign bfly1[13] = sh[0] ? start[14] : (x1[6] ? (start[12] | (orc & start[13])) : start[13]);
  assign bfly1[14] = sh[0] ? start[13] : (x1[7] ? (start[15] | (orc & start[14])) : start[14]);
  assign bfly1[15] = x1[7] ? (start[14] | (orc & start[15])): start[15];
  assign bfly1[16] = x1[8] ? (start[17] | (orc & start[16])): start[16];
  assign bfly1[17] = sh[0] ? start[18] : (x1[8] ? (start[16] | (orc & start[17])) : start[17]);
  assign bfly1[18] = sh[0] ? start[17] : (x1[9] ? (start[19] | (orc & start[18])) : start[18]);
  assign bfly1[19] = x1[9] ? (start[18] | (orc & start[19])): start[19];
  assign bfly1[20] = x1[10] ? (start[21] | (orc & start[20])): start[20];
  assign bfly1[21] = sh[0] ? start[22] : (x1[10] ? (start[20] | (orc & start[21])) : start[21]);
  assign bfly1[22] = sh[0] ? start[21] : (x1[11] ? (start[23] | (orc & start[22])) : start[22]);
  assign bfly1[23] = x1[11] ? (start[22] | (orc & start[23])): start[23];
  assign bfly1[24] = x1[12] ? (start[25] | (orc & start[24])): start[24];
  assign bfly1[25] = sh[0] ? start[26] : (x1[12] ? (start[24] | (orc & start[25])) : start[25]);
  assign bfly1[26] = sh[0] ? start[25] : (x1[13] ? (start[27] | (orc & start[26])) : start[26]);
  assign bfly1[27] = x1[13] ? (start[26] | (orc & start[27])): start[27];
  assign bfly1[28] = x1[14] ? (start[29] | (orc & start[28])): start[28];
  assign bfly1[29] = sh[0] ? start[30] : (x1[14] ? (start[28] | (orc & start[29])) : start[29]);
  assign bfly1[30] = sh[0] ? start[29] : (x1[15] ? (start[31] | (orc & start[30])) : start[30]);
  assign bfly1[31] = x1[15] ? (start[30] | (orc & start[31])): start[31];
  assign bfly1[32] = x1[16] ? (start[33] | (orc & start[32])): start[32];
  assign bfly1[33] = sh[0] ? start[34] : (x1[16] ? (start[32] | (orc & start[33])) : start[33]);
  assign bfly1[34] = sh[0] ? start[33] : (x1[17] ? (start[35] | (orc & start[34])) : start[34]);
  assign bfly1[35] = x1[17] ? (start[34] | (orc & start[35])): start[35];
  assign bfly1[36] = x1[18] ? (start[37] | (orc & start[36])): start[36];
  assign bfly1[37] = sh[0] ? start[38] : (x1[18] ? (start[36] | (orc & start[37])) : start[37]);
  assign bfly1[38] = sh[0] ? start[37] : (x1[19] ? (start[39] | (orc & start[38])) : start[38]);
  assign bfly1[39] = x1[19] ? (start[38] | (orc & start[39])): start[39];
  assign bfly1[40] = x1[20] ? (start[41] | (orc & start[40])): start[40];
  assign bfly1[41] = sh[0] ? start[42] : (x1[20] ? (start[40] | (orc & start[41])) : start[41]);
  assign bfly1[42] = sh[0] ? start[41] : (x1[21] ? (start[43] | (orc & start[42])) : start[42]);
  assign bfly1[43] = x1[21] ? (start[42] | (orc & start[43])): start[43];
  assign bfly1[44] = x1[22] ? (start[45] | (orc & start[44])): start[44];
  assign bfly1[45] = sh[0] ? start[46] : (x1[22] ? (start[44] | (orc & start[45])) : start[45]);
  assign bfly1[46] = sh[0] ? start[45] : (x1[23] ? (start[47] | (orc & start[46])) : start[46]);
  assign bfly1[47] = x1[23] ? (start[46] | (orc & start[47])): start[47];
  assign bfly1[48] = x1[24] ? (start[49] | (orc & start[48])): start[48];
  assign bfly1[49] = sh[0] ? start[50] : (x1[24] ? (start[48] | (orc & start[49])) : start[49]);
  assign bfly1[50] = sh[0] ? start[49] : (x1[25] ? (start[51] | (orc & start[50])) : start[50]);
  assign bfly1[51] = x1[25] ? (start[50] | (orc & start[51])): start[51];
  assign bfly1[52] = x1[26] ? (start[53] | (orc & start[52])): start[52];
  assign bfly1[53] = sh[0] ? start[54] : (x1[26] ? (start[52] | (orc & start[53])) : start[53]);
  assign bfly1[54] = sh[0] ? start[53] : (x1[27] ? (start[55] | (orc & start[54])) : start[54]);
  assign bfly1[55] = x1[27] ? (start[54] | (orc & start[55])): start[55];
  assign bfly1[56] = x1[28] ? (start[57] | (orc & start[56])): start[56];
  assign bfly1[57] = sh[0] ? start[58] : (x1[28] ? (start[56] | (orc & start[57])) : start[57]);
  assign bfly1[58] = sh[0] ? start[57] : (x1[29] ? (start[59] | (orc & start[58])) : start[58]);
  assign bfly1[59] = x1[29] ? (start[58] | (orc & start[59])): start[59];
  assign bfly1[60] = x1[30] ? (start[61] | (orc & start[60])): start[60];
  assign bfly1[61] = sh[0] ? start[62] : (x1[30] ? (start[60] | (orc & start[61])) : start[61]);
  assign bfly1[62] = sh[0] ? start[61] : (x1[31] ? (start[63] | (orc & start[62])) : start[62]);
  assign bfly1[63] = x1[31] ? (start[62] | (orc & start[63])): start[63];
  wire [63:0] bfly2;
  assign bfly2[0] = x2[0] ? (bfly1[2] | (orc & bfly1[0])): bfly1[0];
  assign bfly2[1] = x2[1] ? (bfly1[3] | (orc & bfly1[1])): bfly1[1];
  assign bfly2[2] = sh[1] ? bfly1[4] : (x2[0] ? (bfly1[0] | (orc & bfly1[2])) : bfly1[2]);
  assign bfly2[3] = sh[1] ? bfly1[5] : (x2[1] ? (bfly1[1] | (orc & bfly1[3])) : bfly1[3]);
  assign bfly2[4] = sh[1] ? bfly1[2] : (x2[2] ? (bfly1[6] | (orc & bfly1[4])) : bfly1[4]);
  assign bfly2[5] = sh[1] ? bfly1[3] : (x2[3] ? (bfly1[7] | (orc & bfly1[5])) : bfly1[5]);
  assign bfly2[6] = x2[2] ? (bfly1[4] | (orc & bfly1[6])): bfly1[6];
  assign bfly2[7] = x2[3] ? (bfly1[5] | (orc & bfly1[7])): bfly1[7];
  assign bfly2[8] = x2[4] ? (bfly1[10] | (orc & bfly1[8])): bfly1[8];
  assign bfly2[9] = x2[5] ? (bfly1[11] | (orc & bfly1[9])): bfly1[9];
  assign bfly2[10] = sh[1] ? bfly1[12] : (x2[4] ? (bfly1[8] | (orc & bfly1[10])) : bfly1[10]);
  assign bfly2[11] = sh[1] ? bfly1[13] : (x2[5] ? (bfly1[9] | (orc & bfly1[11])) : bfly1[11]);
  assign bfly2[12] = sh[1] ? bfly1[10] : (x2[6] ? (bfly1[14] | (orc & bfly1[12])) : bfly1[12]);
  assign bfly2[13] = sh[1] ? bfly1[11] : (x2[7] ? (bfly1[15] | (orc & bfly1[13])) : bfly1[13]);
  assign bfly2[14] = x2[6] ? (bfly1[12] | (orc & bfly1[14])): bfly1[14];
  assign bfly2[15] = x2[7] ? (bfly1[13] | (orc & bfly1[15])): bfly1[15];
  assign bfly2[16] = x2[8] ? (bfly1[18] | (orc & bfly1[16])): bfly1[16];
  assign bfly2[17] = x2[9] ? (bfly1[19] | (orc & bfly1[17])): bfly1[17];
  assign bfly2[18] = sh[1] ? bfly1[20] : (x2[8] ? (bfly1[16] | (orc & bfly1[18])) : bfly1[18]);
  assign bfly2[19] = sh[1] ? bfly1[21] : (x2[9] ? (bfly1[17] | (orc & bfly1[19])) : bfly1[19]);
  assign bfly2[20] = sh[1] ? bfly1[18] : (x2[10] ? (bfly1[22] | (orc & bfly1[20])) : bfly1[20]);
  assign bfly2[21] = sh[1] ? bfly1[19] : (x2[11] ? (bfly1[23] | (orc & bfly1[21])) : bfly1[21]);
  assign bfly2[22] = x2[10] ? (bfly1[20] | (orc & bfly1[22])): bfly1[22];
  assign bfly2[23] = x2[11] ? (bfly1[21] | (orc & bfly1[23])): bfly1[23];
  assign bfly2[24] = x2[12] ? (bfly1[26] | (orc & bfly1[24])): bfly1[24];
  assign bfly2[25] = x2[13] ? (bfly1[27] | (orc & bfly1[25])): bfly1[25];
  assign bfly2[26] = sh[1] ? bfly1[28] : (x2[12] ? (bfly1[24] | (orc & bfly1[26])) : bfly1[26]);
  assign bfly2[27] = sh[1] ? bfly1[29] : (x2[13] ? (bfly1[25] | (orc & bfly1[27])) : bfly1[27]);
  assign bfly2[28] = sh[1] ? bfly1[26] : (x2[14] ? (bfly1[30] | (orc & bfly1[28])) : bfly1[28]);
  assign bfly2[29] = sh[1] ? bfly1[27] : (x2[15] ? (bfly1[31] | (orc & bfly1[29])) : bfly1[29]);
  assign bfly2[30] = x2[14] ? (bfly1[28] | (orc & bfly1[30])): bfly1[30];
  assign bfly2[31] = x2[15] ? (bfly1[29] | (orc & bfly1[31])): bfly1[31];
  assign bfly2[32] = x2[16] ? (bfly1[34] | (orc & bfly1[32])): bfly1[32];
  assign bfly2[33] = x2[17] ? (bfly1[35] | (orc & bfly1[33])): bfly1[33];
  assign bfly2[34] = sh[1] ? bfly1[36] : (x2[16] ? (bfly1[32] | (orc & bfly1[34])) : bfly1[34]);
  assign bfly2[35] = sh[1] ? bfly1[37] : (x2[17] ? (bfly1[33] | (orc & bfly1[35])) : bfly1[35]);
  assign bfly2[36] = sh[1] ? bfly1[34] : (x2[18] ? (bfly1[38] | (orc & bfly1[36])) : bfly1[36]);
  assign bfly2[37] = sh[1] ? bfly1[35] : (x2[19] ? (bfly1[39] | (orc & bfly1[37])) : bfly1[37]);
  assign bfly2[38] = x2[18] ? (bfly1[36] | (orc & bfly1[38])): bfly1[38];
  assign bfly2[39] = x2[19] ? (bfly1[37] | (orc & bfly1[39])): bfly1[39];
  assign bfly2[40] = x2[20] ? (bfly1[42] | (orc & bfly1[40])): bfly1[40];
  assign bfly2[41] = x2[21] ? (bfly1[43] | (orc & bfly1[41])): bfly1[41];
  assign bfly2[42] = sh[1] ? bfly1[44] : (x2[20] ? (bfly1[40] | (orc & bfly1[42])) : bfly1[42]);
  assign bfly2[43] = sh[1] ? bfly1[45] : (x2[21] ? (bfly1[41] | (orc & bfly1[43])) : bfly1[43]);
  assign bfly2[44] = sh[1] ? bfly1[42] : (x2[22] ? (bfly1[46] | (orc & bfly1[44])) : bfly1[44]);
  assign bfly2[45] = sh[1] ? bfly1[43] : (x2[23] ? (bfly1[47] | (orc & bfly1[45])) : bfly1[45]);
  assign bfly2[46] = x2[22] ? (bfly1[44] | (orc & bfly1[46])): bfly1[46];
  assign bfly2[47] = x2[23] ? (bfly1[45] | (orc & bfly1[47])): bfly1[47];
  assign bfly2[48] = x2[24] ? (bfly1[50] | (orc & bfly1[48])): bfly1[48];
  assign bfly2[49] = x2[25] ? (bfly1[51] | (orc & bfly1[49])): bfly1[49];
  assign bfly2[50] = sh[1] ? bfly1[52] : (x2[24] ? (bfly1[48] | (orc & bfly1[50])) : bfly1[50]);
  assign bfly2[51] = sh[1] ? bfly1[53] : (x2[25] ? (bfly1[49] | (orc & bfly1[51])) : bfly1[51]);
  assign bfly2[52] = sh[1] ? bfly1[50] : (x2[26] ? (bfly1[54] | (orc & bfly1[52])) : bfly1[52]);
  assign bfly2[53] = sh[1] ? bfly1[51] : (x2[27] ? (bfly1[55] | (orc & bfly1[53])) : bfly1[53]);
  assign bfly2[54] = x2[26] ? (bfly1[52] | (orc & bfly1[54])): bfly1[54];
  assign bfly2[55] = x2[27] ? (bfly1[53] | (orc & bfly1[55])): bfly1[55];
  assign bfly2[56] = x2[28] ? (bfly1[58] | (orc & bfly1[56])): bfly1[56];
  assign bfly2[57] = x2[29] ? (bfly1[59] | (orc & bfly1[57])): bfly1[57];
  assign bfly2[58] = sh[1] ? bfly1[60] : (x2[28] ? (bfly1[56] | (orc & bfly1[58])) : bfly1[58]);
  assign bfly2[59] = sh[1] ? bfly1[61] : (x2[29] ? (bfly1[57] | (orc & bfly1[59])) : bfly1[59]);
  assign bfly2[60] = sh[1] ? bfly1[58] : (x2[30] ? (bfly1[62] | (orc & bfly1[60])) : bfly1[60]);
  assign bfly2[61] = sh[1] ? bfly1[59] : (x2[31] ? (bfly1[63] | (orc & bfly1[61])) : bfly1[61]);
  assign bfly2[62] = x2[30] ? (bfly1[60] | (orc & bfly1[62])): bfly1[62];
  assign bfly2[63] = x2[31] ? (bfly1[61] | (orc & bfly1[63])): bfly1[63];
  wire [63:0] bfly4;
  assign bfly4[0] = x4[0] ? (bfly2[4] | (orc & bfly2[0])): bfly2[0];
  assign bfly4[1] = x4[1] ? (bfly2[5] | (orc & bfly2[1])): bfly2[1];
  assign bfly4[2] = x4[2] ? (bfly2[6] | (orc & bfly2[2])): bfly2[2];
  assign bfly4[3] = x4[3] ? (bfly2[7] | (orc & bfly2[3])): bfly2[3];
  assign bfly4[4] = sh[2] ? bfly2[8] : (x4[0] ? (bfly2[0] | (orc & bfly2[4])) : bfly2[4]);
  assign bfly4[5] = sh[2] ? bfly2[9] : (x4[1] ? (bfly2[1] | (orc & bfly2[5])) : bfly2[5]);
  assign bfly4[6] = sh[2] ? bfly2[10] : (x4[2] ? (bfly2[2] | (orc & bfly2[6])) : bfly2[6]);
  assign bfly4[7] = sh[2] ? bfly2[11] : (x4[3] ? (bfly2[3] | (orc & bfly2[7])) : bfly2[7]);
  assign bfly4[8] = sh[2] ? bfly2[4] : (x4[4] ? (bfly2[12] | (orc & bfly2[8])) : bfly2[8]);
  assign bfly4[9] = sh[2] ? bfly2[5] : (x4[5] ? (bfly2[13] | (orc & bfly2[9])) : bfly2[9]);
  assign bfly4[10] = sh[2] ? bfly2[6] : (x4[6] ? (bfly2[14] | (orc & bfly2[10])) : bfly2[10]);
  assign bfly4[11] = sh[2] ? bfly2[7] : (x4[7] ? (bfly2[15] | (orc & bfly2[11])) : bfly2[11]);
  assign bfly4[12] = x4[4] ? (bfly2[8] | (orc & bfly2[12])): bfly2[12];
  assign bfly4[13] = x4[5] ? (bfly2[9] | (orc & bfly2[13])): bfly2[13];
  assign bfly4[14] = x4[6] ? (bfly2[10] | (orc & bfly2[14])): bfly2[14];
  assign bfly4[15] = x4[7] ? (bfly2[11] | (orc & bfly2[15])): bfly2[15];
  assign bfly4[16] = x4[8] ? (bfly2[20] | (orc & bfly2[16])): bfly2[16];
  assign bfly4[17] = x4[9] ? (bfly2[21] | (orc & bfly2[17])): bfly2[17];
  assign bfly4[18] = x4[10] ? (bfly2[22] | (orc & bfly2[18])): bfly2[18];
  assign bfly4[19] = x4[11] ? (bfly2[23] | (orc & bfly2[19])): bfly2[19];
  assign bfly4[20] = sh[2] ? bfly2[24] : (x4[8] ? (bfly2[16] | (orc & bfly2[20])) : bfly2[20]);
  assign bfly4[21] = sh[2] ? bfly2[25] : (x4[9] ? (bfly2[17] | (orc & bfly2[21])) : bfly2[21]);
  assign bfly4[22] = sh[2] ? bfly2[26] : (x4[10] ? (bfly2[18] | (orc & bfly2[22])) : bfly2[22]);
  assign bfly4[23] = sh[2] ? bfly2[27] : (x4[11] ? (bfly2[19] | (orc & bfly2[23])) : bfly2[23]);
  assign bfly4[24] = sh[2] ? bfly2[20] : (x4[12] ? (bfly2[28] | (orc & bfly2[24])) : bfly2[24]);
  assign bfly4[25] = sh[2] ? bfly2[21] : (x4[13] ? (bfly2[29] | (orc & bfly2[25])) : bfly2[25]);
  assign bfly4[26] = sh[2] ? bfly2[22] : (x4[14] ? (bfly2[30] | (orc & bfly2[26])) : bfly2[26]);
  assign bfly4[27] = sh[2] ? bfly2[23] : (x4[15] ? (bfly2[31] | (orc & bfly2[27])) : bfly2[27]);
  assign bfly4[28] = x4[12] ? (bfly2[24] | (orc & bfly2[28])): bfly2[28];
  assign bfly4[29] = x4[13] ? (bfly2[25] | (orc & bfly2[29])): bfly2[29];
  assign bfly4[30] = x4[14] ? (bfly2[26] | (orc & bfly2[30])): bfly2[30];
  assign bfly4[31] = x4[15] ? (bfly2[27] | (orc & bfly2[31])): bfly2[31];
  assign bfly4[32] = x4[16] ? (bfly2[36] | (orc & bfly2[32])): bfly2[32];
  assign bfly4[33] = x4[17] ? (bfly2[37] | (orc & bfly2[33])): bfly2[33];
  assign bfly4[34] = x4[18] ? (bfly2[38] | (orc & bfly2[34])): bfly2[34];
  assign bfly4[35] = x4[19] ? (bfly2[39] | (orc & bfly2[35])): bfly2[35];
  assign bfly4[36] = sh[2] ? bfly2[40] : (x4[16] ? (bfly2[32] | (orc & bfly2[36])) : bfly2[36]);
  assign bfly4[37] = sh[2] ? bfly2[41] : (x4[17] ? (bfly2[33] | (orc & bfly2[37])) : bfly2[37]);
  assign bfly4[38] = sh[2] ? bfly2[42] : (x4[18] ? (bfly2[34] | (orc & bfly2[38])) : bfly2[38]);
  assign bfly4[39] = sh[2] ? bfly2[43] : (x4[19] ? (bfly2[35] | (orc & bfly2[39])) : bfly2[39]);
  assign bfly4[40] = sh[2] ? bfly2[36] : (x4[20] ? (bfly2[44] | (orc & bfly2[40])) : bfly2[40]);
  assign bfly4[41] = sh[2] ? bfly2[37] : (x4[21] ? (bfly2[45] | (orc & bfly2[41])) : bfly2[41]);
  assign bfly4[42] = sh[2] ? bfly2[38] : (x4[22] ? (bfly2[46] | (orc & bfly2[42])) : bfly2[42]);
  assign bfly4[43] = sh[2] ? bfly2[39] : (x4[23] ? (bfly2[47] | (orc & bfly2[43])) : bfly2[43]);
  assign bfly4[44] = x4[20] ? (bfly2[40] | (orc & bfly2[44])): bfly2[44];
  assign bfly4[45] = x4[21] ? (bfly2[41] | (orc & bfly2[45])): bfly2[45];
  assign bfly4[46] = x4[22] ? (bfly2[42] | (orc & bfly2[46])): bfly2[46];
  assign bfly4[47] = x4[23] ? (bfly2[43] | (orc & bfly2[47])): bfly2[47];
  assign bfly4[48] = x4[24] ? (bfly2[52] | (orc & bfly2[48])): bfly2[48];
  assign bfly4[49] = x4[25] ? (bfly2[53] | (orc & bfly2[49])): bfly2[49];
  assign bfly4[50] = x4[26] ? (bfly2[54] | (orc & bfly2[50])): bfly2[50];
  assign bfly4[51] = x4[27] ? (bfly2[55] | (orc & bfly2[51])): bfly2[51];
  assign bfly4[52] = sh[2] ? bfly2[56] : (x4[24] ? (bfly2[48] | (orc & bfly2[52])) : bfly2[52]);
  assign bfly4[53] = sh[2] ? bfly2[57] : (x4[25] ? (bfly2[49] | (orc & bfly2[53])) : bfly2[53]);
  assign bfly4[54] = sh[2] ? bfly2[58] : (x4[26] ? (bfly2[50] | (orc & bfly2[54])) : bfly2[54]);
  assign bfly4[55] = sh[2] ? bfly2[59] : (x4[27] ? (bfly2[51] | (orc & bfly2[55])) : bfly2[55]);
  assign bfly4[56] = sh[2] ? bfly2[52] : (x4[28] ? (bfly2[60] | (orc & bfly2[56])) : bfly2[56]);
  assign bfly4[57] = sh[2] ? bfly2[53] : (x4[29] ? (bfly2[61] | (orc & bfly2[57])) : bfly2[57]);
  assign bfly4[58] = sh[2] ? bfly2[54] : (x4[30] ? (bfly2[62] | (orc & bfly2[58])) : bfly2[58]);
  assign bfly4[59] = sh[2] ? bfly2[55] : (x4[31] ? (bfly2[63] | (orc & bfly2[59])) : bfly2[59]);
  assign bfly4[60] = x4[28] ? (bfly2[56] | (orc & bfly2[60])): bfly2[60];
  assign bfly4[61] = x4[29] ? (bfly2[57] | (orc & bfly2[61])): bfly2[61];
  assign bfly4[62] = x4[30] ? (bfly2[58] | (orc & bfly2[62])): bfly2[62];
  assign bfly4[63] = x4[31] ? (bfly2[59] | (orc & bfly2[63])): bfly2[63];
  wire [63:0] bfly8;
  assign bfly8[0] = x8[0] ? (bfly4[8] | (orc & bfly4[0])): bfly4[0];
  assign bfly8[1] = x8[1] ? (bfly4[9] | (orc & bfly4[1])): bfly4[1];
  assign bfly8[2] = x8[2] ? (bfly4[10] | (orc & bfly4[2])): bfly4[2];
  assign bfly8[3] = x8[3] ? (bfly4[11] | (orc & bfly4[3])): bfly4[3];
  assign bfly8[4] = x8[4] ? (bfly4[12] | (orc & bfly4[4])): bfly4[4];
  assign bfly8[5] = x8[5] ? (bfly4[13] | (orc & bfly4[5])): bfly4[5];
  assign bfly8[6] = x8[6] ? (bfly4[14] | (orc & bfly4[6])): bfly4[6];
  assign bfly8[7] = x8[7] ? (bfly4[15] | (orc & bfly4[7])): bfly4[7];
  assign bfly8[8] = sh[3] ? bfly4[16] : (x8[0] ? (bfly4[0] | (orc & bfly4[8])) : bfly4[8]);
  assign bfly8[9] = sh[3] ? bfly4[17] : (x8[1] ? (bfly4[1] | (orc & bfly4[9])) : bfly4[9]);
  assign bfly8[10] = sh[3] ? bfly4[18] : (x8[2] ? (bfly4[2] | (orc & bfly4[10])) : bfly4[10]);
  assign bfly8[11] = sh[3] ? bfly4[19] : (x8[3] ? (bfly4[3] | (orc & bfly4[11])) : bfly4[11]);
  assign bfly8[12] = sh[3] ? bfly4[20] : (x8[4] ? (bfly4[4] | (orc & bfly4[12])) : bfly4[12]);
  assign bfly8[13] = sh[3] ? bfly4[21] : (x8[5] ? (bfly4[5] | (orc & bfly4[13])) : bfly4[13]);
  assign bfly8[14] = sh[3] ? bfly4[22] : (x8[6] ? (bfly4[6] | (orc & bfly4[14])) : bfly4[14]);
  assign bfly8[15] = sh[3] ? bfly4[23] : (x8[7] ? (bfly4[7] | (orc & bfly4[15])) : bfly4[15]);
  assign bfly8[16] = sh[3] ? bfly4[8] : (x8[8] ? (bfly4[24] | (orc & bfly4[16])) : bfly4[16]);
  assign bfly8[17] = sh[3] ? bfly4[9] : (x8[9] ? (bfly4[25] | (orc & bfly4[17])) : bfly4[17]);
  assign bfly8[18] = sh[3] ? bfly4[10] : (x8[10] ? (bfly4[26] | (orc & bfly4[18])) : bfly4[18]);
  assign bfly8[19] = sh[3] ? bfly4[11] : (x8[11] ? (bfly4[27] | (orc & bfly4[19])) : bfly4[19]);
  assign bfly8[20] = sh[3] ? bfly4[12] : (x8[12] ? (bfly4[28] | (orc & bfly4[20])) : bfly4[20]);
  assign bfly8[21] = sh[3] ? bfly4[13] : (x8[13] ? (bfly4[29] | (orc & bfly4[21])) : bfly4[21]);
  assign bfly8[22] = sh[3] ? bfly4[14] : (x8[14] ? (bfly4[30] | (orc & bfly4[22])) : bfly4[22]);
  assign bfly8[23] = sh[3] ? bfly4[15] : (x8[15] ? (bfly4[31] | (orc & bfly4[23])) : bfly4[23]);
  assign bfly8[24] = x8[8] ? (bfly4[16] | (orc & bfly4[24])): bfly4[24];
  assign bfly8[25] = x8[9] ? (bfly4[17] | (orc & bfly4[25])): bfly4[25];
  assign bfly8[26] = x8[10] ? (bfly4[18] | (orc & bfly4[26])): bfly4[26];
  assign bfly8[27] = x8[11] ? (bfly4[19] | (orc & bfly4[27])): bfly4[27];
  assign bfly8[28] = x8[12] ? (bfly4[20] | (orc & bfly4[28])): bfly4[28];
  assign bfly8[29] = x8[13] ? (bfly4[21] | (orc & bfly4[29])): bfly4[29];
  assign bfly8[30] = x8[14] ? (bfly4[22] | (orc & bfly4[30])): bfly4[30];
  assign bfly8[31] = x8[15] ? (bfly4[23] | (orc & bfly4[31])): bfly4[31];
  assign bfly8[32] = x8[16] ? (bfly4[40] | (orc & bfly4[32])): bfly4[32];
  assign bfly8[33] = x8[17] ? (bfly4[41] | (orc & bfly4[33])): bfly4[33];
  assign bfly8[34] = x8[18] ? (bfly4[42] | (orc & bfly4[34])): bfly4[34];
  assign bfly8[35] = x8[19] ? (bfly4[43] | (orc & bfly4[35])): bfly4[35];
  assign bfly8[36] = x8[20] ? (bfly4[44] | (orc & bfly4[36])): bfly4[36];
  assign bfly8[37] = x8[21] ? (bfly4[45] | (orc & bfly4[37])): bfly4[37];
  assign bfly8[38] = x8[22] ? (bfly4[46] | (orc & bfly4[38])): bfly4[38];
  assign bfly8[39] = x8[23] ? (bfly4[47] | (orc & bfly4[39])): bfly4[39];
  assign bfly8[40] = sh[3] ? bfly4[48] : (x8[16] ? (bfly4[32] | (orc & bfly4[40])) : bfly4[40]);
  assign bfly8[41] = sh[3] ? bfly4[49] : (x8[17] ? (bfly4[33] | (orc & bfly4[41])) : bfly4[41]);
  assign bfly8[42] = sh[3] ? bfly4[50] : (x8[18] ? (bfly4[34] | (orc & bfly4[42])) : bfly4[42]);
  assign bfly8[43] = sh[3] ? bfly4[51] : (x8[19] ? (bfly4[35] | (orc & bfly4[43])) : bfly4[43]);
  assign bfly8[44] = sh[3] ? bfly4[52] : (x8[20] ? (bfly4[36] | (orc & bfly4[44])) : bfly4[44]);
  assign bfly8[45] = sh[3] ? bfly4[53] : (x8[21] ? (bfly4[37] | (orc & bfly4[45])) : bfly4[45]);
  assign bfly8[46] = sh[3] ? bfly4[54] : (x8[22] ? (bfly4[38] | (orc & bfly4[46])) : bfly4[46]);
  assign bfly8[47] = sh[3] ? bfly4[55] : (x8[23] ? (bfly4[39] | (orc & bfly4[47])) : bfly4[47]);
  assign bfly8[48] = sh[3] ? bfly4[40] : (x8[24] ? (bfly4[56] | (orc & bfly4[48])) : bfly4[48]);
  assign bfly8[49] = sh[3] ? bfly4[41] : (x8[25] ? (bfly4[57] | (orc & bfly4[49])) : bfly4[49]);
  assign bfly8[50] = sh[3] ? bfly4[42] : (x8[26] ? (bfly4[58] | (orc & bfly4[50])) : bfly4[50]);
  assign bfly8[51] = sh[3] ? bfly4[43] : (x8[27] ? (bfly4[59] | (orc & bfly4[51])) : bfly4[51]);
  assign bfly8[52] = sh[3] ? bfly4[44] : (x8[28] ? (bfly4[60] | (orc & bfly4[52])) : bfly4[52]);
  assign bfly8[53] = sh[3] ? bfly4[45] : (x8[29] ? (bfly4[61] | (orc & bfly4[53])) : bfly4[53]);
  assign bfly8[54] = sh[3] ? bfly4[46] : (x8[30] ? (bfly4[62] | (orc & bfly4[54])) : bfly4[54]);
  assign bfly8[55] = sh[3] ? bfly4[47] : (x8[31] ? (bfly4[63] | (orc & bfly4[55])) : bfly4[55]);
  assign bfly8[56] = x8[24] ? (bfly4[48] | (orc & bfly4[56])): bfly4[56];
  assign bfly8[57] = x8[25] ? (bfly4[49] | (orc & bfly4[57])): bfly4[57];
  assign bfly8[58] = x8[26] ? (bfly4[50] | (orc & bfly4[58])): bfly4[58];
  assign bfly8[59] = x8[27] ? (bfly4[51] | (orc & bfly4[59])): bfly4[59];
  assign bfly8[60] = x8[28] ? (bfly4[52] | (orc & bfly4[60])): bfly4[60];
  assign bfly8[61] = x8[29] ? (bfly4[53] | (orc & bfly4[61])): bfly4[61];
  assign bfly8[62] = x8[30] ? (bfly4[54] | (orc & bfly4[62])): bfly4[62];
  assign bfly8[63] = x8[31] ? (bfly4[55] | (orc & bfly4[63])): bfly4[63];
  wire [63:0] bfly16;
  assign bfly16[0] = x16[0] ? (bfly8[16] | (orc & bfly8[0])): bfly8[0];
  assign bfly16[1] = x16[1] ? (bfly8[17] | (orc & bfly8[1])): bfly8[1];
  assign bfly16[2] = x16[2] ? (bfly8[18] | (orc & bfly8[2])): bfly8[2];
  assign bfly16[3] = x16[3] ? (bfly8[19] | (orc & bfly8[3])): bfly8[3];
  assign bfly16[4] = x16[4] ? (bfly8[20] | (orc & bfly8[4])): bfly8[4];
  assign bfly16[5] = x16[5] ? (bfly8[21] | (orc & bfly8[5])): bfly8[5];
  assign bfly16[6] = x16[6] ? (bfly8[22] | (orc & bfly8[6])): bfly8[6];
  assign bfly16[7] = x16[7] ? (bfly8[23] | (orc & bfly8[7])): bfly8[7];
  assign bfly16[8] = x16[8] ? (bfly8[24] | (orc & bfly8[8])): bfly8[8];
  assign bfly16[9] = x16[9] ? (bfly8[25] | (orc & bfly8[9])): bfly8[9];
  assign bfly16[10] = x16[10] ? (bfly8[26] | (orc & bfly8[10])): bfly8[10];
  assign bfly16[11] = x16[11] ? (bfly8[27] | (orc & bfly8[11])): bfly8[11];
  assign bfly16[12] = x16[12] ? (bfly8[28] | (orc & bfly8[12])): bfly8[12];
  assign bfly16[13] = x16[13] ? (bfly8[29] | (orc & bfly8[13])): bfly8[13];
  assign bfly16[14] = x16[14] ? (bfly8[30] | (orc & bfly8[14])): bfly8[14];
  assign bfly16[15] = x16[15] ? (bfly8[31] | (orc & bfly8[15])): bfly8[15];
  assign bfly16[16] = sh[4] ? bfly8[32] : (x16[0] ? (bfly8[0] | (orc & bfly8[16])) : bfly8[16]);
  assign bfly16[17] = sh[4] ? bfly8[33] : (x16[1] ? (bfly8[1] | (orc & bfly8[17])) : bfly8[17]);
  assign bfly16[18] = sh[4] ? bfly8[34] : (x16[2] ? (bfly8[2] | (orc & bfly8[18])) : bfly8[18]);
  assign bfly16[19] = sh[4] ? bfly8[35] : (x16[3] ? (bfly8[3] | (orc & bfly8[19])) : bfly8[19]);
  assign bfly16[20] = sh[4] ? bfly8[36] : (x16[4] ? (bfly8[4] | (orc & bfly8[20])) : bfly8[20]);
  assign bfly16[21] = sh[4] ? bfly8[37] : (x16[5] ? (bfly8[5] | (orc & bfly8[21])) : bfly8[21]);
  assign bfly16[22] = sh[4] ? bfly8[38] : (x16[6] ? (bfly8[6] | (orc & bfly8[22])) : bfly8[22]);
  assign bfly16[23] = sh[4] ? bfly8[39] : (x16[7] ? (bfly8[7] | (orc & bfly8[23])) : bfly8[23]);
  assign bfly16[24] = sh[4] ? bfly8[40] : (x16[8] ? (bfly8[8] | (orc & bfly8[24])) : bfly8[24]);
  assign bfly16[25] = sh[4] ? bfly8[41] : (x16[9] ? (bfly8[9] | (orc & bfly8[25])) : bfly8[25]);
  assign bfly16[26] = sh[4] ? bfly8[42] : (x16[10] ? (bfly8[10] | (orc & bfly8[26])) : bfly8[26]);
  assign bfly16[27] = sh[4] ? bfly8[43] : (x16[11] ? (bfly8[11] | (orc & bfly8[27])) : bfly8[27]);
  assign bfly16[28] = sh[4] ? bfly8[44] : (x16[12] ? (bfly8[12] | (orc & bfly8[28])) : bfly8[28]);
  assign bfly16[29] = sh[4] ? bfly8[45] : (x16[13] ? (bfly8[13] | (orc & bfly8[29])) : bfly8[29]);
  assign bfly16[30] = sh[4] ? bfly8[46] : (x16[14] ? (bfly8[14] | (orc & bfly8[30])) : bfly8[30]);
  assign bfly16[31] = sh[4] ? bfly8[47] : (x16[15] ? (bfly8[15] | (orc & bfly8[31])) : bfly8[31]);
  assign bfly16[32] = sh[4] ? bfly8[16] : (x16[16] ? (bfly8[48] | (orc & bfly8[32])) : bfly8[32]);
  assign bfly16[33] = sh[4] ? bfly8[17] : (x16[17] ? (bfly8[49] | (orc & bfly8[33])) : bfly8[33]);
  assign bfly16[34] = sh[4] ? bfly8[18] : (x16[18] ? (bfly8[50] | (orc & bfly8[34])) : bfly8[34]);
  assign bfly16[35] = sh[4] ? bfly8[19] : (x16[19] ? (bfly8[51] | (orc & bfly8[35])) : bfly8[35]);
  assign bfly16[36] = sh[4] ? bfly8[20] : (x16[20] ? (bfly8[52] | (orc & bfly8[36])) : bfly8[36]);
  assign bfly16[37] = sh[4] ? bfly8[21] : (x16[21] ? (bfly8[53] | (orc & bfly8[37])) : bfly8[37]);
  assign bfly16[38] = sh[4] ? bfly8[22] : (x16[22] ? (bfly8[54] | (orc & bfly8[38])) : bfly8[38]);
  assign bfly16[39] = sh[4] ? bfly8[23] : (x16[23] ? (bfly8[55] | (orc & bfly8[39])) : bfly8[39]);
  assign bfly16[40] = sh[4] ? bfly8[24] : (x16[24] ? (bfly8[56] | (orc & bfly8[40])) : bfly8[40]);
  assign bfly16[41] = sh[4] ? bfly8[25] : (x16[25] ? (bfly8[57] | (orc & bfly8[41])) : bfly8[41]);
  assign bfly16[42] = sh[4] ? bfly8[26] : (x16[26] ? (bfly8[58] | (orc & bfly8[42])) : bfly8[42]);
  assign bfly16[43] = sh[4] ? bfly8[27] : (x16[27] ? (bfly8[59] | (orc & bfly8[43])) : bfly8[43]);
  assign bfly16[44] = sh[4] ? bfly8[28] : (x16[28] ? (bfly8[60] | (orc & bfly8[44])) : bfly8[44]);
  assign bfly16[45] = sh[4] ? bfly8[29] : (x16[29] ? (bfly8[61] | (orc & bfly8[45])) : bfly8[45]);
  assign bfly16[46] = sh[4] ? bfly8[30] : (x16[30] ? (bfly8[62] | (orc & bfly8[46])) : bfly8[46]);
  assign bfly16[47] = sh[4] ? bfly8[31] : (x16[31] ? (bfly8[63] | (orc & bfly8[47])) : bfly8[47]);
  assign bfly16[48] = x16[16] ? (bfly8[32] | (orc & bfly8[48])): bfly8[48];
  assign bfly16[49] = x16[17] ? (bfly8[33] | (orc & bfly8[49])): bfly8[49];
  assign bfly16[50] = x16[18] ? (bfly8[34] | (orc & bfly8[50])): bfly8[50];
  assign bfly16[51] = x16[19] ? (bfly8[35] | (orc & bfly8[51])): bfly8[51];
  assign bfly16[52] = x16[20] ? (bfly8[36] | (orc & bfly8[52])): bfly8[52];
  assign bfly16[53] = x16[21] ? (bfly8[37] | (orc & bfly8[53])): bfly8[53];
  assign bfly16[54] = x16[22] ? (bfly8[38] | (orc & bfly8[54])): bfly8[54];
  assign bfly16[55] = x16[23] ? (bfly8[39] | (orc & bfly8[55])): bfly8[55];
  assign bfly16[56] = x16[24] ? (bfly8[40] | (orc & bfly8[56])): bfly8[56];
  assign bfly16[57] = x16[25] ? (bfly8[41] | (orc & bfly8[57])): bfly8[57];
  assign bfly16[58] = x16[26] ? (bfly8[42] | (orc & bfly8[58])): bfly8[58];
  assign bfly16[59] = x16[27] ? (bfly8[43] | (orc & bfly8[59])): bfly8[59];
  assign bfly16[60] = x16[28] ? (bfly8[44] | (orc & bfly8[60])): bfly8[60];
  assign bfly16[61] = x16[29] ? (bfly8[45] | (orc & bfly8[61])): bfly8[61];
  assign bfly16[62] = x16[30] ? (bfly8[46] | (orc & bfly8[62])): bfly8[62];
  assign bfly16[63] = x16[31] ? (bfly8[47] | (orc & bfly8[63])): bfly8[63];
  wire [63:0] bfly32;
  assign bfly32[0] = x32[0] ? (bfly16[32] | (orc & bfly16[0])): bfly16[0];
  assign bfly32[1] = x32[1] ? (bfly16[33] | (orc & bfly16[1])): bfly16[1];
  assign bfly32[2] = x32[2] ? (bfly16[34] | (orc & bfly16[2])): bfly16[2];
  assign bfly32[3] = x32[3] ? (bfly16[35] | (orc & bfly16[3])): bfly16[3];
  assign bfly32[4] = x32[4] ? (bfly16[36] | (orc & bfly16[4])): bfly16[4];
  assign bfly32[5] = x32[5] ? (bfly16[37] | (orc & bfly16[5])): bfly16[5];
  assign bfly32[6] = x32[6] ? (bfly16[38] | (orc & bfly16[6])): bfly16[6];
  assign bfly32[7] = x32[7] ? (bfly16[39] | (orc & bfly16[7])): bfly16[7];
  assign bfly32[8] = x32[8] ? (bfly16[40] | (orc & bfly16[8])): bfly16[8];
  assign bfly32[9] = x32[9] ? (bfly16[41] | (orc & bfly16[9])): bfly16[9];
  assign bfly32[10] = x32[10] ? (bfly16[42] | (orc & bfly16[10])): bfly16[10];
  assign bfly32[11] = x32[11] ? (bfly16[43] | (orc & bfly16[11])): bfly16[11];
  assign bfly32[12] = x32[12] ? (bfly16[44] | (orc & bfly16[12])): bfly16[12];
  assign bfly32[13] = x32[13] ? (bfly16[45] | (orc & bfly16[13])): bfly16[13];
  assign bfly32[14] = x32[14] ? (bfly16[46] | (orc & bfly16[14])): bfly16[14];
  assign bfly32[15] = x32[15] ? (bfly16[47] | (orc & bfly16[15])): bfly16[15];
  assign bfly32[16] = x32[16] ? (bfly16[48] | (orc & bfly16[16])): bfly16[16];
  assign bfly32[17] = x32[17] ? (bfly16[49] | (orc & bfly16[17])): bfly16[17];
  assign bfly32[18] = x32[18] ? (bfly16[50] | (orc & bfly16[18])): bfly16[18];
  assign bfly32[19] = x32[19] ? (bfly16[51] | (orc & bfly16[19])): bfly16[19];
  assign bfly32[20] = x32[20] ? (bfly16[52] | (orc & bfly16[20])): bfly16[20];
  assign bfly32[21] = x32[21] ? (bfly16[53] | (orc & bfly16[21])): bfly16[21];
  assign bfly32[22] = x32[22] ? (bfly16[54] | (orc & bfly16[22])): bfly16[22];
  assign bfly32[23] = x32[23] ? (bfly16[55] | (orc & bfly16[23])): bfly16[23];
  assign bfly32[24] = x32[24] ? (bfly16[56] | (orc & bfly16[24])): bfly16[24];
  assign bfly32[25] = x32[25] ? (bfly16[57] | (orc & bfly16[25])): bfly16[25];
  assign bfly32[26] = x32[26] ? (bfly16[58] | (orc & bfly16[26])): bfly16[26];
  assign bfly32[27] = x32[27] ? (bfly16[59] | (orc & bfly16[27])): bfly16[27];
  assign bfly32[28] = x32[28] ? (bfly16[60] | (orc & bfly16[28])): bfly16[28];
  assign bfly32[29] = x32[29] ? (bfly16[61] | (orc & bfly16[29])): bfly16[29];
  assign bfly32[30] = x32[30] ? (bfly16[62] | (orc & bfly16[30])): bfly16[30];
  assign bfly32[31] = x32[31] ? (bfly16[63] | (orc & bfly16[31])): bfly16[31];
  assign bfly32[32] = x32[0] ? (bfly16[0] | (orc & bfly16[32])): bfly16[32];
  assign bfly32[33] = x32[1] ? (bfly16[1] | (orc & bfly16[33])): bfly16[33];
  assign bfly32[34] = x32[2] ? (bfly16[2] | (orc & bfly16[34])): bfly16[34];
  assign bfly32[35] = x32[3] ? (bfly16[3] | (orc & bfly16[35])): bfly16[35];
  assign bfly32[36] = x32[4] ? (bfly16[4] | (orc & bfly16[36])): bfly16[36];
  assign bfly32[37] = x32[5] ? (bfly16[5] | (orc & bfly16[37])): bfly16[37];
  assign bfly32[38] = x32[6] ? (bfly16[6] | (orc & bfly16[38])): bfly16[38];
  assign bfly32[39] = x32[7] ? (bfly16[7] | (orc & bfly16[39])): bfly16[39];
  assign bfly32[40] = x32[8] ? (bfly16[8] | (orc & bfly16[40])): bfly16[40];
  assign bfly32[41] = x32[9] ? (bfly16[9] | (orc & bfly16[41])): bfly16[41];
  assign bfly32[42] = x32[10] ? (bfly16[10] | (orc & bfly16[42])): bfly16[42];
  assign bfly32[43] = x32[11] ? (bfly16[11] | (orc & bfly16[43])): bfly16[43];
  assign bfly32[44] = x32[12] ? (bfly16[12] | (orc & bfly16[44])): bfly16[44];
  assign bfly32[45] = x32[13] ? (bfly16[13] | (orc & bfly16[45])): bfly16[45];
  assign bfly32[46] = x32[14] ? (bfly16[14] | (orc & bfly16[46])): bfly16[46];
  assign bfly32[47] = x32[15] ? (bfly16[15] | (orc & bfly16[47])): bfly16[47];
  assign bfly32[48] = x32[16] ? (bfly16[16] | (orc & bfly16[48])): bfly16[48];
  assign bfly32[49] = x32[17] ? (bfly16[17] | (orc & bfly16[49])): bfly16[49];
  assign bfly32[50] = x32[18] ? (bfly16[18] | (orc & bfly16[50])): bfly16[50];
  assign bfly32[51] = x32[19] ? (bfly16[19] | (orc & bfly16[51])): bfly16[51];
  assign bfly32[52] = x32[20] ? (bfly16[20] | (orc & bfly16[52])): bfly16[52];
  assign bfly32[53] = x32[21] ? (bfly16[21] | (orc & bfly16[53])): bfly16[53];
  assign bfly32[54] = x32[22] ? (bfly16[22] | (orc & bfly16[54])): bfly16[54];
  assign bfly32[55] = x32[23] ? (bfly16[23] | (orc & bfly16[55])): bfly16[55];
  assign bfly32[56] = x32[24] ? (bfly16[24] | (orc & bfly16[56])): bfly16[56];
  assign bfly32[57] = x32[25] ? (bfly16[25] | (orc & bfly16[57])): bfly16[57];
  assign bfly32[58] = x32[26] ? (bfly16[26] | (orc & bfly16[58])): bfly16[58];
  assign bfly32[59] = x32[27] ? (bfly16[27] | (orc & bfly16[59])): bfly16[59];
  assign bfly32[60] = x32[28] ? (bfly16[28] | (orc & bfly16[60])): bfly16[60];
  assign bfly32[61] = x32[29] ? (bfly16[29] | (orc & bfly16[61])): bfly16[61];
  assign bfly32[62] = x32[30] ? (bfly16[30] | (orc & bfly16[62])): bfly16[62];
  assign bfly32[63] = x32[31] ? (bfly16[31] | (orc & bfly16[63])): bfly16[63];
  assign dout = bfly32;
endmodule
module rvb_bextdep_pps4 (
  input [3:0] din,
  output [31:0] dout
);
  function [15:0] carry_save_add;
    input [15:0] a, b;
    reg [7:0] x, y;
    begin
      x = a[15:8] ^ a[7:0] ^ b[7:0];
      y = ((a[15:8] & a[7:0]) | (a[15:8] & b[7:0]) | (a[7:0] & b[7:0])) << 1;
      carry_save_add[7:0] = x ^ y ^ b[15:8];
      carry_save_add[15:8] = ((x & y) | (x & b[15:8]) | (y & b[15:8])) << 1;
    end
  endfunction
  function [7:0] carry_save_get;
    input [15:0] a;
    begin
      carry_save_get = a[7:0] + a[15:8];
    end
  endfunction
  // inputs
  wire [15:0] e0s0 = {15'b0, din[0 +: 1]};
  wire [15:0] e1s0 = {15'b0, din[1 +: 1]};
  wire [15:0] e2s0 = {15'b0, din[2 +: 1]};
  wire [15:0] e3s0 = {15'b0, din[3 +: 1]};
  // forward pass
  wire [15:0] e1s1 = carry_save_add(e1s0, e0s0);
  wire [15:0] e3s1 = carry_save_add(e3s0, e2s0);
  wire [15:0] e3s2 = carry_save_add(e3s1, e1s1);
  // backward pass
  wire [15:0] e2s3 = carry_save_add(e2s0, e1s1);
  // outputs
  assign dout[0 +: 8] = carry_save_get(e0s0);
  assign dout[8 +: 8] = carry_save_get(e1s1);
  assign dout[16 +: 8] = carry_save_get(e2s3);
  assign dout[24 +: 8] = carry_save_get(e3s2);
endmodule
module rvb_bextdep_pps8 (
  input [7:0] din,
  output [63:0] dout
);
  function [15:0] carry_save_add;
    input [15:0] a, b;
    reg [7:0] x, y;
    begin
      x = a[15:8] ^ a[7:0] ^ b[7:0];
      y = ((a[15:8] & a[7:0]) | (a[15:8] & b[7:0]) | (a[7:0] & b[7:0])) << 1;
      carry_save_add[7:0] = x ^ y ^ b[15:8];
      carry_save_add[15:8] = ((x & y) | (x & b[15:8]) | (y & b[15:8])) << 1;
    end
  endfunction
  function [7:0] carry_save_get;
    input [15:0] a;
    begin
      carry_save_get = a[7:0] + a[15:8];
    end
  endfunction
  // inputs
  wire [15:0] e0s0 = {15'b0, din[0 +: 1]};
  wire [15:0] e1s0 = {15'b0, din[1 +: 1]};
  wire [15:0] e2s0 = {15'b0, din[2 +: 1]};
  wire [15:0] e3s0 = {15'b0, din[3 +: 1]};
  wire [15:0] e4s0 = {15'b0, din[4 +: 1]};
  wire [15:0] e5s0 = {15'b0, din[5 +: 1]};
  wire [15:0] e6s0 = {15'b0, din[6 +: 1]};
  wire [15:0] e7s0 = {15'b0, din[7 +: 1]};
  // forward pass
  wire [15:0] e1s1 = carry_save_add(e1s0, e0s0);
  wire [15:0] e3s1 = carry_save_add(e3s0, e2s0);
  wire [15:0] e5s1 = carry_save_add(e5s0, e4s0);
  wire [15:0] e7s1 = carry_save_add(e7s0, e6s0);
  wire [15:0] e3s2 = carry_save_add(e3s1, e1s1);
  wire [15:0] e7s2 = carry_save_add(e7s1, e5s1);
  wire [15:0] e7s3 = carry_save_add(e7s2, e3s2);
  // backward pass
  wire [15:0] e5s4 = carry_save_add(e5s1, e3s2);
  wire [15:0] e2s5 = carry_save_add(e2s0, e1s1);
  wire [15:0] e4s5 = carry_save_add(e4s0, e3s2);
  wire [15:0] e6s5 = carry_save_add(e6s0, e5s4);
  // outputs
  assign dout[0 +: 8] = carry_save_get(e0s0);
  assign dout[8 +: 8] = carry_save_get(e1s1);
  assign dout[16 +: 8] = carry_save_get(e2s5);
  assign dout[24 +: 8] = carry_save_get(e3s2);
  assign dout[32 +: 8] = carry_save_get(e4s5);
  assign dout[40 +: 8] = carry_save_get(e5s4);
  assign dout[48 +: 8] = carry_save_get(e6s5);
  assign dout[56 +: 8] = carry_save_get(e7s3);
endmodule
module rvb_bextdep_pps16 (
  input [15:0] din,
  output [127:0] dout
);
  function [15:0] carry_save_add;
    input [15:0] a, b;
    reg [7:0] x, y;
    begin
      x = a[15:8] ^ a[7:0] ^ b[7:0];
      y = ((a[15:8] & a[7:0]) | (a[15:8] & b[7:0]) | (a[7:0] & b[7:0])) << 1;
      carry_save_add[7:0] = x ^ y ^ b[15:8];
      carry_save_add[15:8] = ((x & y) | (x & b[15:8]) | (y & b[15:8])) << 1;
    end
  endfunction
  function [7:0] carry_save_get;
    input [15:0] a;
    begin
      carry_save_get = a[7:0] + a[15:8];
    end
  endfunction
  // inputs
  wire [15:0] e0s0 = {15'b0, din[0 +: 1]};
  wire [15:0] e1s0 = {15'b0, din[1 +: 1]};
  wire [15:0] e2s0 = {15'b0, din[2 +: 1]};
  wire [15:0] e3s0 = {15'b0, din[3 +: 1]};
  wire [15:0] e4s0 = {15'b0, din[4 +: 1]};
  wire [15:0] e5s0 = {15'b0, din[5 +: 1]};
  wire [15:0] e6s0 = {15'b0, din[6 +: 1]};
  wire [15:0] e7s0 = {15'b0, din[7 +: 1]};
  wire [15:0] e8s0 = {15'b0, din[8 +: 1]};
  wire [15:0] e9s0 = {15'b0, din[9 +: 1]};
  wire [15:0] e10s0 = {15'b0, din[10 +: 1]};
  wire [15:0] e11s0 = {15'b0, din[11 +: 1]};
  wire [15:0] e12s0 = {15'b0, din[12 +: 1]};
  wire [15:0] e13s0 = {15'b0, din[13 +: 1]};
  wire [15:0] e14s0 = {15'b0, din[14 +: 1]};
  wire [15:0] e15s0 = {15'b0, din[15 +: 1]};
  // forward pass
  wire [15:0] e1s1 = carry_save_add(e1s0, e0s0);
  wire [15:0] e3s1 = carry_save_add(e3s0, e2s0);
  wire [15:0] e5s1 = carry_save_add(e5s0, e4s0);
  wire [15:0] e7s1 = carry_save_add(e7s0, e6s0);
  wire [15:0] e9s1 = carry_save_add(e9s0, e8s0);
  wire [15:0] e11s1 = carry_save_add(e11s0, e10s0);
  wire [15:0] e13s1 = carry_save_add(e13s0, e12s0);
  wire [15:0] e15s1 = carry_save_add(e15s0, e14s0);
  wire [15:0] e3s2 = carry_save_add(e3s1, e1s1);
  wire [15:0] e7s2 = carry_save_add(e7s1, e5s1);
  wire [15:0] e11s2 = carry_save_add(e11s1, e9s1);
  wire [15:0] e15s2 = carry_save_add(e15s1, e13s1);
  wire [15:0] e7s3 = carry_save_add(e7s2, e3s2);
  wire [15:0] e15s3 = carry_save_add(e15s2, e11s2);
  wire [15:0] e15s4 = carry_save_add(e15s3, e7s3);
  // backward pass
  wire [15:0] e11s5 = carry_save_add(e11s2, e7s3);
  wire [15:0] e5s6 = carry_save_add(e5s1, e3s2);
  wire [15:0] e9s6 = carry_save_add(e9s1, e7s3);
  wire [15:0] e13s6 = carry_save_add(e13s1, e11s5);
  wire [15:0] e2s7 = carry_save_add(e2s0, e1s1);
  wire [15:0] e4s7 = carry_save_add(e4s0, e3s2);
  wire [15:0] e6s7 = carry_save_add(e6s0, e5s6);
  wire [15:0] e8s7 = carry_save_add(e8s0, e7s3);
  wire [15:0] e10s7 = carry_save_add(e10s0, e9s6);
  wire [15:0] e12s7 = carry_save_add(e12s0, e11s5);
  wire [15:0] e14s7 = carry_save_add(e14s0, e13s6);
  // outputs
  assign dout[0 +: 8] = carry_save_get(e0s0);
  assign dout[8 +: 8] = carry_save_get(e1s1);
  assign dout[16 +: 8] = carry_save_get(e2s7);
  assign dout[24 +: 8] = carry_save_get(e3s2);
  assign dout[32 +: 8] = carry_save_get(e4s7);
  assign dout[40 +: 8] = carry_save_get(e5s6);
  assign dout[48 +: 8] = carry_save_get(e6s7);
  assign dout[56 +: 8] = carry_save_get(e7s3);
  assign dout[64 +: 8] = carry_save_get(e8s7);
  assign dout[72 +: 8] = carry_save_get(e9s6);
  assign dout[80 +: 8] = carry_save_get(e10s7);
  assign dout[88 +: 8] = carry_save_get(e11s5);
  assign dout[96 +: 8] = carry_save_get(e12s7);
  assign dout[104 +: 8] = carry_save_get(e13s6);
  assign dout[112 +: 8] = carry_save_get(e14s7);
  assign dout[120 +: 8] = carry_save_get(e15s4);
endmodule
module rvb_bextdep_pps32 (
  input [31:0] din,
  output [255:0] dout
);
  function [15:0] carry_save_add;
    input [15:0] a, b;
    reg [7:0] x, y;
    begin
      x = a[15:8] ^ a[7:0] ^ b[7:0];
      y = ((a[15:8] & a[7:0]) | (a[15:8] & b[7:0]) | (a[7:0] & b[7:0])) << 1;
      carry_save_add[7:0] = x ^ y ^ b[15:8];
      carry_save_add[15:8] = ((x & y) | (x & b[15:8]) | (y & b[15:8])) << 1;
    end
  endfunction
  function [7:0] carry_save_get;
    input [15:0] a;
    begin
      carry_save_get = a[7:0] + a[15:8];
    end
  endfunction
  // inputs
  wire [15:0] e0s0 = {15'b0, din[0 +: 1]};
  wire [15:0] e1s0 = {15'b0, din[1 +: 1]};
  wire [15:0] e2s0 = {15'b0, din[2 +: 1]};
  wire [15:0] e3s0 = {15'b0, din[3 +: 1]};
  wire [15:0] e4s0 = {15'b0, din[4 +: 1]};
  wire [15:0] e5s0 = {15'b0, din[5 +: 1]};
  wire [15:0] e6s0 = {15'b0, din[6 +: 1]};
  wire [15:0] e7s0 = {15'b0, din[7 +: 1]};
  wire [15:0] e8s0 = {15'b0, din[8 +: 1]};
  wire [15:0] e9s0 = {15'b0, din[9 +: 1]};
  wire [15:0] e10s0 = {15'b0, din[10 +: 1]};
  wire [15:0] e11s0 = {15'b0, din[11 +: 1]};
  wire [15:0] e12s0 = {15'b0, din[12 +: 1]};
  wire [15:0] e13s0 = {15'b0, din[13 +: 1]};
  wire [15:0] e14s0 = {15'b0, din[14 +: 1]};
  wire [15:0] e15s0 = {15'b0, din[15 +: 1]};
  wire [15:0] e16s0 = {15'b0, din[16 +: 1]};
  wire [15:0] e17s0 = {15'b0, din[17 +: 1]};
  wire [15:0] e18s0 = {15'b0, din[18 +: 1]};
  wire [15:0] e19s0 = {15'b0, din[19 +: 1]};
  wire [15:0] e20s0 = {15'b0, din[20 +: 1]};
  wire [15:0] e21s0 = {15'b0, din[21 +: 1]};
  wire [15:0] e22s0 = {15'b0, din[22 +: 1]};
  wire [15:0] e23s0 = {15'b0, din[23 +: 1]};
  wire [15:0] e24s0 = {15'b0, din[24 +: 1]};
  wire [15:0] e25s0 = {15'b0, din[25 +: 1]};
  wire [15:0] e26s0 = {15'b0, din[26 +: 1]};
  wire [15:0] e27s0 = {15'b0, din[27 +: 1]};
  wire [15:0] e28s0 = {15'b0, din[28 +: 1]};
  wire [15:0] e29s0 = {15'b0, din[29 +: 1]};
  wire [15:0] e30s0 = {15'b0, din[30 +: 1]};
  wire [15:0] e31s0 = {15'b0, din[31 +: 1]};
  // forward pass
  wire [15:0] e1s1 = carry_save_add(e1s0, e0s0);
  wire [15:0] e3s1 = carry_save_add(e3s0, e2s0);
  wire [15:0] e5s1 = carry_save_add(e5s0, e4s0);
  wire [15:0] e7s1 = carry_save_add(e7s0, e6s0);
  wire [15:0] e9s1 = carry_save_add(e9s0, e8s0);
  wire [15:0] e11s1 = carry_save_add(e11s0, e10s0);
  wire [15:0] e13s1 = carry_save_add(e13s0, e12s0);
  wire [15:0] e15s1 = carry_save_add(e15s0, e14s0);
  wire [15:0] e17s1 = carry_save_add(e17s0, e16s0);
  wire [15:0] e19s1 = carry_save_add(e19s0, e18s0);
  wire [15:0] e21s1 = carry_save_add(e21s0, e20s0);
  wire [15:0] e23s1 = carry_save_add(e23s0, e22s0);
  wire [15:0] e25s1 = carry_save_add(e25s0, e24s0);
  wire [15:0] e27s1 = carry_save_add(e27s0, e26s0);
  wire [15:0] e29s1 = carry_save_add(e29s0, e28s0);
  wire [15:0] e31s1 = carry_save_add(e31s0, e30s0);
  wire [15:0] e3s2 = carry_save_add(e3s1, e1s1);
  wire [15:0] e7s2 = carry_save_add(e7s1, e5s1);
  wire [15:0] e11s2 = carry_save_add(e11s1, e9s1);
  wire [15:0] e15s2 = carry_save_add(e15s1, e13s1);
  wire [15:0] e19s2 = carry_save_add(e19s1, e17s1);
  wire [15:0] e23s2 = carry_save_add(e23s1, e21s1);
  wire [15:0] e27s2 = carry_save_add(e27s1, e25s1);
  wire [15:0] e31s2 = carry_save_add(e31s1, e29s1);
  wire [15:0] e7s3 = carry_save_add(e7s2, e3s2);
  wire [15:0] e15s3 = carry_save_add(e15s2, e11s2);
  wire [15:0] e23s3 = carry_save_add(e23s2, e19s2);
  wire [15:0] e31s3 = carry_save_add(e31s2, e27s2);
  wire [15:0] e15s4 = carry_save_add(e15s3, e7s3);
  wire [15:0] e31s4 = carry_save_add(e31s3, e23s3);
  wire [15:0] e31s5 = carry_save_add(e31s4, e15s4);
  // backward pass
  wire [15:0] e23s6 = carry_save_add(e23s3, e15s4);
  wire [15:0] e11s7 = carry_save_add(e11s2, e7s3);
  wire [15:0] e19s7 = carry_save_add(e19s2, e15s4);
  wire [15:0] e27s7 = carry_save_add(e27s2, e23s6);
  wire [15:0] e5s8 = carry_save_add(e5s1, e3s2);
  wire [15:0] e9s8 = carry_save_add(e9s1, e7s3);
  wire [15:0] e13s8 = carry_save_add(e13s1, e11s7);
  wire [15:0] e17s8 = carry_save_add(e17s1, e15s4);
  wire [15:0] e21s8 = carry_save_add(e21s1, e19s7);
  wire [15:0] e25s8 = carry_save_add(e25s1, e23s6);
  wire [15:0] e29s8 = carry_save_add(e29s1, e27s7);
  wire [15:0] e2s9 = carry_save_add(e2s0, e1s1);
  wire [15:0] e4s9 = carry_save_add(e4s0, e3s2);
  wire [15:0] e6s9 = carry_save_add(e6s0, e5s8);
  wire [15:0] e8s9 = carry_save_add(e8s0, e7s3);
  wire [15:0] e10s9 = carry_save_add(e10s0, e9s8);
  wire [15:0] e12s9 = carry_save_add(e12s0, e11s7);
  wire [15:0] e14s9 = carry_save_add(e14s0, e13s8);
  wire [15:0] e16s9 = carry_save_add(e16s0, e15s4);
  wire [15:0] e18s9 = carry_save_add(e18s0, e17s8);
  wire [15:0] e20s9 = carry_save_add(e20s0, e19s7);
  wire [15:0] e22s9 = carry_save_add(e22s0, e21s8);
  wire [15:0] e24s9 = carry_save_add(e24s0, e23s6);
  wire [15:0] e26s9 = carry_save_add(e26s0, e25s8);
  wire [15:0] e28s9 = carry_save_add(e28s0, e27s7);
  wire [15:0] e30s9 = carry_save_add(e30s0, e29s8);
  // outputs
  assign dout[0 +: 8] = carry_save_get(e0s0);
  assign dout[8 +: 8] = carry_save_get(e1s1);
  assign dout[16 +: 8] = carry_save_get(e2s9);
  assign dout[24 +: 8] = carry_save_get(e3s2);
  assign dout[32 +: 8] = carry_save_get(e4s9);
  assign dout[40 +: 8] = carry_save_get(e5s8);
  assign dout[48 +: 8] = carry_save_get(e6s9);
  assign dout[56 +: 8] = carry_save_get(e7s3);
  assign dout[64 +: 8] = carry_save_get(e8s9);
  assign dout[72 +: 8] = carry_save_get(e9s8);
  assign dout[80 +: 8] = carry_save_get(e10s9);
  assign dout[88 +: 8] = carry_save_get(e11s7);
  assign dout[96 +: 8] = carry_save_get(e12s9);
  assign dout[104 +: 8] = carry_save_get(e13s8);
  assign dout[112 +: 8] = carry_save_get(e14s9);
  assign dout[120 +: 8] = carry_save_get(e15s4);
  assign dout[128 +: 8] = carry_save_get(e16s9);
  assign dout[136 +: 8] = carry_save_get(e17s8);
  assign dout[144 +: 8] = carry_save_get(e18s9);
  assign dout[152 +: 8] = carry_save_get(e19s7);
  assign dout[160 +: 8] = carry_save_get(e20s9);
  assign dout[168 +: 8] = carry_save_get(e21s8);
  assign dout[176 +: 8] = carry_save_get(e22s9);
  assign dout[184 +: 8] = carry_save_get(e23s6);
  assign dout[192 +: 8] = carry_save_get(e24s9);
  assign dout[200 +: 8] = carry_save_get(e25s8);
  assign dout[208 +: 8] = carry_save_get(e26s9);
  assign dout[216 +: 8] = carry_save_get(e27s7);
  assign dout[224 +: 8] = carry_save_get(e28s9);
  assign dout[232 +: 8] = carry_save_get(e29s8);
  assign dout[240 +: 8] = carry_save_get(e30s9);
  assign dout[248 +: 8] = carry_save_get(e31s5);
endmodule
module rvb_bextdep_pps64 (
  input [63:0] din,
  output [511:0] dout
);
  function [15:0] carry_save_add;
    input [15:0] a, b;
    reg [7:0] x, y;
    begin
      x = a[15:8] ^ a[7:0] ^ b[7:0];
      y = ((a[15:8] & a[7:0]) | (a[15:8] & b[7:0]) | (a[7:0] & b[7:0])) << 1;
      carry_save_add[7:0] = x ^ y ^ b[15:8];
      carry_save_add[15:8] = ((x & y) | (x & b[15:8]) | (y & b[15:8])) << 1;
    end
  endfunction
  function [7:0] carry_save_get;
    input [15:0] a;
    begin
      carry_save_get = a[7:0] + a[15:8];
    end
  endfunction
  // inputs
  wire [15:0] e0s0 = {15'b0, din[0 +: 1]};
  wire [15:0] e1s0 = {15'b0, din[1 +: 1]};
  wire [15:0] e2s0 = {15'b0, din[2 +: 1]};
  wire [15:0] e3s0 = {15'b0, din[3 +: 1]};
  wire [15:0] e4s0 = {15'b0, din[4 +: 1]};
  wire [15:0] e5s0 = {15'b0, din[5 +: 1]};
  wire [15:0] e6s0 = {15'b0, din[6 +: 1]};
  wire [15:0] e7s0 = {15'b0, din[7 +: 1]};
  wire [15:0] e8s0 = {15'b0, din[8 +: 1]};
  wire [15:0] e9s0 = {15'b0, din[9 +: 1]};
  wire [15:0] e10s0 = {15'b0, din[10 +: 1]};
  wire [15:0] e11s0 = {15'b0, din[11 +: 1]};
  wire [15:0] e12s0 = {15'b0, din[12 +: 1]};
  wire [15:0] e13s0 = {15'b0, din[13 +: 1]};
  wire [15:0] e14s0 = {15'b0, din[14 +: 1]};
  wire [15:0] e15s0 = {15'b0, din[15 +: 1]};
  wire [15:0] e16s0 = {15'b0, din[16 +: 1]};
  wire [15:0] e17s0 = {15'b0, din[17 +: 1]};
  wire [15:0] e18s0 = {15'b0, din[18 +: 1]};
  wire [15:0] e19s0 = {15'b0, din[19 +: 1]};
  wire [15:0] e20s0 = {15'b0, din[20 +: 1]};
  wire [15:0] e21s0 = {15'b0, din[21 +: 1]};
  wire [15:0] e22s0 = {15'b0, din[22 +: 1]};
  wire [15:0] e23s0 = {15'b0, din[23 +: 1]};
  wire [15:0] e24s0 = {15'b0, din[24 +: 1]};
  wire [15:0] e25s0 = {15'b0, din[25 +: 1]};
  wire [15:0] e26s0 = {15'b0, din[26 +: 1]};
  wire [15:0] e27s0 = {15'b0, din[27 +: 1]};
  wire [15:0] e28s0 = {15'b0, din[28 +: 1]};
  wire [15:0] e29s0 = {15'b0, din[29 +: 1]};
  wire [15:0] e30s0 = {15'b0, din[30 +: 1]};
  wire [15:0] e31s0 = {15'b0, din[31 +: 1]};
  wire [15:0] e32s0 = {15'b0, din[32 +: 1]};
  wire [15:0] e33s0 = {15'b0, din[33 +: 1]};
  wire [15:0] e34s0 = {15'b0, din[34 +: 1]};
  wire [15:0] e35s0 = {15'b0, din[35 +: 1]};
  wire [15:0] e36s0 = {15'b0, din[36 +: 1]};
  wire [15:0] e37s0 = {15'b0, din[37 +: 1]};
  wire [15:0] e38s0 = {15'b0, din[38 +: 1]};
  wire [15:0] e39s0 = {15'b0, din[39 +: 1]};
  wire [15:0] e40s0 = {15'b0, din[40 +: 1]};
  wire [15:0] e41s0 = {15'b0, din[41 +: 1]};
  wire [15:0] e42s0 = {15'b0, din[42 +: 1]};
  wire [15:0] e43s0 = {15'b0, din[43 +: 1]};
  wire [15:0] e44s0 = {15'b0, din[44 +: 1]};
  wire [15:0] e45s0 = {15'b0, din[45 +: 1]};
  wire [15:0] e46s0 = {15'b0, din[46 +: 1]};
  wire [15:0] e47s0 = {15'b0, din[47 +: 1]};
  wire [15:0] e48s0 = {15'b0, din[48 +: 1]};
  wire [15:0] e49s0 = {15'b0, din[49 +: 1]};
  wire [15:0] e50s0 = {15'b0, din[50 +: 1]};
  wire [15:0] e51s0 = {15'b0, din[51 +: 1]};
  wire [15:0] e52s0 = {15'b0, din[52 +: 1]};
  wire [15:0] e53s0 = {15'b0, din[53 +: 1]};
  wire [15:0] e54s0 = {15'b0, din[54 +: 1]};
  wire [15:0] e55s0 = {15'b0, din[55 +: 1]};
  wire [15:0] e56s0 = {15'b0, din[56 +: 1]};
  wire [15:0] e57s0 = {15'b0, din[57 +: 1]};
  wire [15:0] e58s0 = {15'b0, din[58 +: 1]};
  wire [15:0] e59s0 = {15'b0, din[59 +: 1]};
  wire [15:0] e60s0 = {15'b0, din[60 +: 1]};
  wire [15:0] e61s0 = {15'b0, din[61 +: 1]};
  wire [15:0] e62s0 = {15'b0, din[62 +: 1]};
  wire [15:0] e63s0 = {15'b0, din[63 +: 1]};
  // forward pass
  wire [15:0] e1s1 = carry_save_add(e1s0, e0s0);
  wire [15:0] e3s1 = carry_save_add(e3s0, e2s0);
  wire [15:0] e5s1 = carry_save_add(e5s0, e4s0);
  wire [15:0] e7s1 = carry_save_add(e7s0, e6s0);
  wire [15:0] e9s1 = carry_save_add(e9s0, e8s0);
  wire [15:0] e11s1 = carry_save_add(e11s0, e10s0);
  wire [15:0] e13s1 = carry_save_add(e13s0, e12s0);
  wire [15:0] e15s1 = carry_save_add(e15s0, e14s0);
  wire [15:0] e17s1 = carry_save_add(e17s0, e16s0);
  wire [15:0] e19s1 = carry_save_add(e19s0, e18s0);
  wire [15:0] e21s1 = carry_save_add(e21s0, e20s0);
  wire [15:0] e23s1 = carry_save_add(e23s0, e22s0);
  wire [15:0] e25s1 = carry_save_add(e25s0, e24s0);
  wire [15:0] e27s1 = carry_save_add(e27s0, e26s0);
  wire [15:0] e29s1 = carry_save_add(e29s0, e28s0);
  wire [15:0] e31s1 = carry_save_add(e31s0, e30s0);
  wire [15:0] e33s1 = carry_save_add(e33s0, e32s0);
  wire [15:0] e35s1 = carry_save_add(e35s0, e34s0);
  wire [15:0] e37s1 = carry_save_add(e37s0, e36s0);
  wire [15:0] e39s1 = carry_save_add(e39s0, e38s0);
  wire [15:0] e41s1 = carry_save_add(e41s0, e40s0);
  wire [15:0] e43s1 = carry_save_add(e43s0, e42s0);
  wire [15:0] e45s1 = carry_save_add(e45s0, e44s0);
  wire [15:0] e47s1 = carry_save_add(e47s0, e46s0);
  wire [15:0] e49s1 = carry_save_add(e49s0, e48s0);
  wire [15:0] e51s1 = carry_save_add(e51s0, e50s0);
  wire [15:0] e53s1 = carry_save_add(e53s0, e52s0);
  wire [15:0] e55s1 = carry_save_add(e55s0, e54s0);
  wire [15:0] e57s1 = carry_save_add(e57s0, e56s0);
  wire [15:0] e59s1 = carry_save_add(e59s0, e58s0);
  wire [15:0] e61s1 = carry_save_add(e61s0, e60s0);
  wire [15:0] e63s1 = carry_save_add(e63s0, e62s0);
  wire [15:0] e3s2 = carry_save_add(e3s1, e1s1);
  wire [15:0] e7s2 = carry_save_add(e7s1, e5s1);
  wire [15:0] e11s2 = carry_save_add(e11s1, e9s1);
  wire [15:0] e15s2 = carry_save_add(e15s1, e13s1);
  wire [15:0] e19s2 = carry_save_add(e19s1, e17s1);
  wire [15:0] e23s2 = carry_save_add(e23s1, e21s1);
  wire [15:0] e27s2 = carry_save_add(e27s1, e25s1);
  wire [15:0] e31s2 = carry_save_add(e31s1, e29s1);
  wire [15:0] e35s2 = carry_save_add(e35s1, e33s1);
  wire [15:0] e39s2 = carry_save_add(e39s1, e37s1);
  wire [15:0] e43s2 = carry_save_add(e43s1, e41s1);
  wire [15:0] e47s2 = carry_save_add(e47s1, e45s1);
  wire [15:0] e51s2 = carry_save_add(e51s1, e49s1);
  wire [15:0] e55s2 = carry_save_add(e55s1, e53s1);
  wire [15:0] e59s2 = carry_save_add(e59s1, e57s1);
  wire [15:0] e63s2 = carry_save_add(e63s1, e61s1);
  wire [15:0] e7s3 = carry_save_add(e7s2, e3s2);
  wire [15:0] e15s3 = carry_save_add(e15s2, e11s2);
  wire [15:0] e23s3 = carry_save_add(e23s2, e19s2);
  wire [15:0] e31s3 = carry_save_add(e31s2, e27s2);
  wire [15:0] e39s3 = carry_save_add(e39s2, e35s2);
  wire [15:0] e47s3 = carry_save_add(e47s2, e43s2);
  wire [15:0] e55s3 = carry_save_add(e55s2, e51s2);
  wire [15:0] e63s3 = carry_save_add(e63s2, e59s2);
  wire [15:0] e15s4 = carry_save_add(e15s3, e7s3);
  wire [15:0] e31s4 = carry_save_add(e31s3, e23s3);
  wire [15:0] e47s4 = carry_save_add(e47s3, e39s3);
  wire [15:0] e63s4 = carry_save_add(e63s3, e55s3);
  wire [15:0] e31s5 = carry_save_add(e31s4, e15s4);
  wire [15:0] e63s5 = carry_save_add(e63s4, e47s4);
  wire [15:0] e63s6 = carry_save_add(e63s5, e31s5);
  // backward pass
  wire [15:0] e47s7 = carry_save_add(e47s4, e31s5);
  wire [15:0] e23s8 = carry_save_add(e23s3, e15s4);
  wire [15:0] e39s8 = carry_save_add(e39s3, e31s5);
  wire [15:0] e55s8 = carry_save_add(e55s3, e47s7);
  wire [15:0] e11s9 = carry_save_add(e11s2, e7s3);
  wire [15:0] e19s9 = carry_save_add(e19s2, e15s4);
  wire [15:0] e27s9 = carry_save_add(e27s2, e23s8);
  wire [15:0] e35s9 = carry_save_add(e35s2, e31s5);
  wire [15:0] e43s9 = carry_save_add(e43s2, e39s8);
  wire [15:0] e51s9 = carry_save_add(e51s2, e47s7);
  wire [15:0] e59s9 = carry_save_add(e59s2, e55s8);
  wire [15:0] e5s10 = carry_save_add(e5s1, e3s2);
  wire [15:0] e9s10 = carry_save_add(e9s1, e7s3);
  wire [15:0] e13s10 = carry_save_add(e13s1, e11s9);
  wire [15:0] e17s10 = carry_save_add(e17s1, e15s4);
  wire [15:0] e21s10 = carry_save_add(e21s1, e19s9);
  wire [15:0] e25s10 = carry_save_add(e25s1, e23s8);
  wire [15:0] e29s10 = carry_save_add(e29s1, e27s9);
  wire [15:0] e33s10 = carry_save_add(e33s1, e31s5);
  wire [15:0] e37s10 = carry_save_add(e37s1, e35s9);
  wire [15:0] e41s10 = carry_save_add(e41s1, e39s8);
  wire [15:0] e45s10 = carry_save_add(e45s1, e43s9);
  wire [15:0] e49s10 = carry_save_add(e49s1, e47s7);
  wire [15:0] e53s10 = carry_save_add(e53s1, e51s9);
  wire [15:0] e57s10 = carry_save_add(e57s1, e55s8);
  wire [15:0] e61s10 = carry_save_add(e61s1, e59s9);
  wire [15:0] e2s11 = carry_save_add(e2s0, e1s1);
  wire [15:0] e4s11 = carry_save_add(e4s0, e3s2);
  wire [15:0] e6s11 = carry_save_add(e6s0, e5s10);
  wire [15:0] e8s11 = carry_save_add(e8s0, e7s3);
  wire [15:0] e10s11 = carry_save_add(e10s0, e9s10);
  wire [15:0] e12s11 = carry_save_add(e12s0, e11s9);
  wire [15:0] e14s11 = carry_save_add(e14s0, e13s10);
  wire [15:0] e16s11 = carry_save_add(e16s0, e15s4);
  wire [15:0] e18s11 = carry_save_add(e18s0, e17s10);
  wire [15:0] e20s11 = carry_save_add(e20s0, e19s9);
  wire [15:0] e22s11 = carry_save_add(e22s0, e21s10);
  wire [15:0] e24s11 = carry_save_add(e24s0, e23s8);
  wire [15:0] e26s11 = carry_save_add(e26s0, e25s10);
  wire [15:0] e28s11 = carry_save_add(e28s0, e27s9);
  wire [15:0] e30s11 = carry_save_add(e30s0, e29s10);
  wire [15:0] e32s11 = carry_save_add(e32s0, e31s5);
  wire [15:0] e34s11 = carry_save_add(e34s0, e33s10);
  wire [15:0] e36s11 = carry_save_add(e36s0, e35s9);
  wire [15:0] e38s11 = carry_save_add(e38s0, e37s10);
  wire [15:0] e40s11 = carry_save_add(e40s0, e39s8);
  wire [15:0] e42s11 = carry_save_add(e42s0, e41s10);
  wire [15:0] e44s11 = carry_save_add(e44s0, e43s9);
  wire [15:0] e46s11 = carry_save_add(e46s0, e45s10);
  wire [15:0] e48s11 = carry_save_add(e48s0, e47s7);
  wire [15:0] e50s11 = carry_save_add(e50s0, e49s10);
  wire [15:0] e52s11 = carry_save_add(e52s0, e51s9);
  wire [15:0] e54s11 = carry_save_add(e54s0, e53s10);
  wire [15:0] e56s11 = carry_save_add(e56s0, e55s8);
  wire [15:0] e58s11 = carry_save_add(e58s0, e57s10);
  wire [15:0] e60s11 = carry_save_add(e60s0, e59s9);
  wire [15:0] e62s11 = carry_save_add(e62s0, e61s10);
  // outputs
  assign dout[0 +: 8] = carry_save_get(e0s0);
  assign dout[8 +: 8] = carry_save_get(e1s1);
  assign dout[16 +: 8] = carry_save_get(e2s11);
  assign dout[24 +: 8] = carry_save_get(e3s2);
  assign dout[32 +: 8] = carry_save_get(e4s11);
  assign dout[40 +: 8] = carry_save_get(e5s10);
  assign dout[48 +: 8] = carry_save_get(e6s11);
  assign dout[56 +: 8] = carry_save_get(e7s3);
  assign dout[64 +: 8] = carry_save_get(e8s11);
  assign dout[72 +: 8] = carry_save_get(e9s10);
  assign dout[80 +: 8] = carry_save_get(e10s11);
  assign dout[88 +: 8] = carry_save_get(e11s9);
  assign dout[96 +: 8] = carry_save_get(e12s11);
  assign dout[104 +: 8] = carry_save_get(e13s10);
  assign dout[112 +: 8] = carry_save_get(e14s11);
  assign dout[120 +: 8] = carry_save_get(e15s4);
  assign dout[128 +: 8] = carry_save_get(e16s11);
  assign dout[136 +: 8] = carry_save_get(e17s10);
  assign dout[144 +: 8] = carry_save_get(e18s11);
  assign dout[152 +: 8] = carry_save_get(e19s9);
  assign dout[160 +: 8] = carry_save_get(e20s11);
  assign dout[168 +: 8] = carry_save_get(e21s10);
  assign dout[176 +: 8] = carry_save_get(e22s11);
  assign dout[184 +: 8] = carry_save_get(e23s8);
  assign dout[192 +: 8] = carry_save_get(e24s11);
  assign dout[200 +: 8] = carry_save_get(e25s10);
  assign dout[208 +: 8] = carry_save_get(e26s11);
  assign dout[216 +: 8] = carry_save_get(e27s9);
  assign dout[224 +: 8] = carry_save_get(e28s11);
  assign dout[232 +: 8] = carry_save_get(e29s10);
  assign dout[240 +: 8] = carry_save_get(e30s11);
  assign dout[248 +: 8] = carry_save_get(e31s5);
  assign dout[256 +: 8] = carry_save_get(e32s11);
  assign dout[264 +: 8] = carry_save_get(e33s10);
  assign dout[272 +: 8] = carry_save_get(e34s11);
  assign dout[280 +: 8] = carry_save_get(e35s9);
  assign dout[288 +: 8] = carry_save_get(e36s11);
  assign dout[296 +: 8] = carry_save_get(e37s10);
  assign dout[304 +: 8] = carry_save_get(e38s11);
  assign dout[312 +: 8] = carry_save_get(e39s8);
  assign dout[320 +: 8] = carry_save_get(e40s11);
  assign dout[328 +: 8] = carry_save_get(e41s10);
  assign dout[336 +: 8] = carry_save_get(e42s11);
  assign dout[344 +: 8] = carry_save_get(e43s9);
  assign dout[352 +: 8] = carry_save_get(e44s11);
  assign dout[360 +: 8] = carry_save_get(e45s10);
  assign dout[368 +: 8] = carry_save_get(e46s11);
  assign dout[376 +: 8] = carry_save_get(e47s7);
  assign dout[384 +: 8] = carry_save_get(e48s11);
  assign dout[392 +: 8] = carry_save_get(e49s10);
  assign dout[400 +: 8] = carry_save_get(e50s11);
  assign dout[408 +: 8] = carry_save_get(e51s9);
  assign dout[416 +: 8] = carry_save_get(e52s11);
  assign dout[424 +: 8] = carry_save_get(e53s10);
  assign dout[432 +: 8] = carry_save_get(e54s11);
  assign dout[440 +: 8] = carry_save_get(e55s8);
  assign dout[448 +: 8] = carry_save_get(e56s11);
  assign dout[456 +: 8] = carry_save_get(e57s10);
  assign dout[464 +: 8] = carry_save_get(e58s11);
  assign dout[472 +: 8] = carry_save_get(e59s9);
  assign dout[480 +: 8] = carry_save_get(e60s11);
  assign dout[488 +: 8] = carry_save_get(e61s10);
  assign dout[496 +: 8] = carry_save_get(e62s11);
  assign dout[504 +: 8] = carry_save_get(e63s6);
endmodule
module rvb_bextdep_pps32f (
  input clock,
  input enable,
  input [31:0] din,
  output [255:0] dout
);
  function [15:0] carry_save_add;
    input [15:0] a, b;
    reg [7:0] x, y;
    begin
      x = a[15:8] ^ a[7:0] ^ b[7:0];
      y = ((a[15:8] & a[7:0]) | (a[15:8] & b[7:0]) | (a[7:0] & b[7:0])) << 1;
      carry_save_add[7:0] = x ^ y ^ b[15:8];
      carry_save_add[15:8] = ((x & y) | (x & b[15:8]) | (y & b[15:8])) << 1;
    end
  endfunction
  function [7:0] carry_save_get;
    input [15:0] a;
    begin
      carry_save_get = a[7:0] + a[15:8];
    end
  endfunction
  // inputs
  wire [15:0] e0s0 = {15'b0, din[0 +: 1]};
  wire [15:0] e1s0 = {15'b0, din[1 +: 1]};
  wire [15:0] e2s0 = {15'b0, din[2 +: 1]};
  wire [15:0] e3s0 = {15'b0, din[3 +: 1]};
  wire [15:0] e4s0 = {15'b0, din[4 +: 1]};
  wire [15:0] e5s0 = {15'b0, din[5 +: 1]};
  wire [15:0] e6s0 = {15'b0, din[6 +: 1]};
  wire [15:0] e7s0 = {15'b0, din[7 +: 1]};
  wire [15:0] e8s0 = {15'b0, din[8 +: 1]};
  wire [15:0] e9s0 = {15'b0, din[9 +: 1]};
  wire [15:0] e10s0 = {15'b0, din[10 +: 1]};
  wire [15:0] e11s0 = {15'b0, din[11 +: 1]};
  wire [15:0] e12s0 = {15'b0, din[12 +: 1]};
  wire [15:0] e13s0 = {15'b0, din[13 +: 1]};
  wire [15:0] e14s0 = {15'b0, din[14 +: 1]};
  wire [15:0] e15s0 = {15'b0, din[15 +: 1]};
  wire [15:0] e16s0 = {15'b0, din[16 +: 1]};
  wire [15:0] e17s0 = {15'b0, din[17 +: 1]};
  wire [15:0] e18s0 = {15'b0, din[18 +: 1]};
  wire [15:0] e19s0 = {15'b0, din[19 +: 1]};
  wire [15:0] e20s0 = {15'b0, din[20 +: 1]};
  wire [15:0] e21s0 = {15'b0, din[21 +: 1]};
  wire [15:0] e22s0 = {15'b0, din[22 +: 1]};
  wire [15:0] e23s0 = {15'b0, din[23 +: 1]};
  wire [15:0] e24s0 = {15'b0, din[24 +: 1]};
  wire [15:0] e25s0 = {15'b0, din[25 +: 1]};
  wire [15:0] e26s0 = {15'b0, din[26 +: 1]};
  wire [15:0] e27s0 = {15'b0, din[27 +: 1]};
  wire [15:0] e28s0 = {15'b0, din[28 +: 1]};
  wire [15:0] e29s0 = {15'b0, din[29 +: 1]};
  wire [15:0] e30s0 = {15'b0, din[30 +: 1]};
  wire [15:0] e31s0 = {15'b0, din[31 +: 1]};
  // forward pass
  wire [15:0] e1s1 = carry_save_add(e1s0, e0s0);
  wire [15:0] e3s1 = carry_save_add(e3s0, e2s0);
  wire [15:0] e5s1 = carry_save_add(e5s0, e4s0);
  wire [15:0] e7s1 = carry_save_add(e7s0, e6s0);
  wire [15:0] e9s1 = carry_save_add(e9s0, e8s0);
  wire [15:0] e11s1 = carry_save_add(e11s0, e10s0);
  wire [15:0] e13s1 = carry_save_add(e13s0, e12s0);
  wire [15:0] e15s1 = carry_save_add(e15s0, e14s0);
  wire [15:0] e17s1 = carry_save_add(e17s0, e16s0);
  wire [15:0] e19s1 = carry_save_add(e19s0, e18s0);
  wire [15:0] e21s1 = carry_save_add(e21s0, e20s0);
  wire [15:0] e23s1 = carry_save_add(e23s0, e22s0);
  wire [15:0] e25s1 = carry_save_add(e25s0, e24s0);
  wire [15:0] e27s1 = carry_save_add(e27s0, e26s0);
  wire [15:0] e29s1 = carry_save_add(e29s0, e28s0);
  wire [15:0] e31s1 = carry_save_add(e31s0, e30s0);
  wire [15:0] e3s2 = carry_save_add(e3s1, e1s1);
  wire [15:0] e7s2 = carry_save_add(e7s1, e5s1);
  wire [15:0] e11s2 = carry_save_add(e11s1, e9s1);
  wire [15:0] e15s2 = carry_save_add(e15s1, e13s1);
  wire [15:0] e19s2 = carry_save_add(e19s1, e17s1);
  wire [15:0] e23s2 = carry_save_add(e23s1, e21s1);
  wire [15:0] e27s2 = carry_save_add(e27s1, e25s1);
  wire [15:0] e31s2 = carry_save_add(e31s1, e29s1);
  wire [15:0] e7s3 = carry_save_add(e7s2, e3s2);
  wire [15:0] e15s3 = carry_save_add(e15s2, e11s2);
  wire [15:0] e23s3 = carry_save_add(e23s2, e19s2);
  wire [15:0] e31s3 = carry_save_add(e31s2, e27s2);
  wire [15:0] e15s4 = carry_save_add(e15s3, e7s3);
  wire [15:0] e31s4 = carry_save_add(e31s3, e23s3);
  wire [15:0] e31s5 = carry_save_add(e31s4, e15s4);
  // backward pass
  reg [15:0] r23;
  always @(posedge clock) if (enable) r23 <= e23s3;
  reg [15:0] r15;
  always @(posedge clock) if (enable) r15 <= e15s4;
  wire [15:0] e23s6 = carry_save_add(r23, r15);
  reg [15:0] r11;
  always @(posedge clock) if (enable) r11 <= e11s2;
  reg [15:0] r7;
  always @(posedge clock) if (enable) r7 <= e7s3;
  wire [15:0] e11s7 = carry_save_add(r11, r7);
  reg [15:0] r19;
  always @(posedge clock) if (enable) r19 <= e19s2;
  wire [15:0] e19s7 = carry_save_add(r19, r15);
  reg [15:0] r27;
  always @(posedge clock) if (enable) r27 <= e27s2;
  wire [15:0] e27s7 = carry_save_add(r27, e23s6);
  reg [15:0] r5;
  always @(posedge clock) if (enable) r5 <= e5s1;
  reg [15:0] r3;
  always @(posedge clock) if (enable) r3 <= e3s2;
  wire [15:0] e5s8 = carry_save_add(r5, r3);
  reg [15:0] r9;
  always @(posedge clock) if (enable) r9 <= e9s1;
  wire [15:0] e9s8 = carry_save_add(r9, r7);
  reg [15:0] r13;
  always @(posedge clock) if (enable) r13 <= e13s1;
  wire [15:0] e13s8 = carry_save_add(r13, e11s7);
  reg [15:0] r17;
  always @(posedge clock) if (enable) r17 <= e17s1;
  wire [15:0] e17s8 = carry_save_add(r17, r15);
  reg [15:0] r21;
  always @(posedge clock) if (enable) r21 <= e21s1;
  wire [15:0] e21s8 = carry_save_add(r21, e19s7);
  reg [15:0] r25;
  always @(posedge clock) if (enable) r25 <= e25s1;
  wire [15:0] e25s8 = carry_save_add(r25, e23s6);
  reg [15:0] r29;
  always @(posedge clock) if (enable) r29 <= e29s1;
  wire [15:0] e29s8 = carry_save_add(r29, e27s7);
  reg [15:0] r2;
  always @(posedge clock) if (enable) r2 <= e2s0;
  reg [15:0] r1;
  always @(posedge clock) if (enable) r1 <= e1s1;
  wire [15:0] e2s9 = carry_save_add(r2, r1);
  reg [15:0] r4;
  always @(posedge clock) if (enable) r4 <= e4s0;
  wire [15:0] e4s9 = carry_save_add(r4, r3);
  reg [15:0] r6;
  always @(posedge clock) if (enable) r6 <= e6s0;
  wire [15:0] e6s9 = carry_save_add(r6, e5s8);
  reg [15:0] r8;
  always @(posedge clock) if (enable) r8 <= e8s0;
  wire [15:0] e8s9 = carry_save_add(r8, r7);
  reg [15:0] r10;
  always @(posedge clock) if (enable) r10 <= e10s0;
  wire [15:0] e10s9 = carry_save_add(r10, e9s8);
  reg [15:0] r12;
  always @(posedge clock) if (enable) r12 <= e12s0;
  wire [15:0] e12s9 = carry_save_add(r12, e11s7);
  reg [15:0] r14;
  always @(posedge clock) if (enable) r14 <= e14s0;
  wire [15:0] e14s9 = carry_save_add(r14, e13s8);
  reg [15:0] r16;
  always @(posedge clock) if (enable) r16 <= e16s0;
  wire [15:0] e16s9 = carry_save_add(r16, r15);
  reg [15:0] r18;
  always @(posedge clock) if (enable) r18 <= e18s0;
  wire [15:0] e18s9 = carry_save_add(r18, e17s8);
  reg [15:0] r20;
  always @(posedge clock) if (enable) r20 <= e20s0;
  wire [15:0] e20s9 = carry_save_add(r20, e19s7);
  reg [15:0] r22;
  always @(posedge clock) if (enable) r22 <= e22s0;
  wire [15:0] e22s9 = carry_save_add(r22, e21s8);
  reg [15:0] r24;
  always @(posedge clock) if (enable) r24 <= e24s0;
  wire [15:0] e24s9 = carry_save_add(r24, e23s6);
  reg [15:0] r26;
  always @(posedge clock) if (enable) r26 <= e26s0;
  wire [15:0] e26s9 = carry_save_add(r26, e25s8);
  reg [15:0] r28;
  always @(posedge clock) if (enable) r28 <= e28s0;
  wire [15:0] e28s9 = carry_save_add(r28, e27s7);
  reg [15:0] r30;
  always @(posedge clock) if (enable) r30 <= e30s0;
  wire [15:0] e30s9 = carry_save_add(r30, e29s8);
  // outputs
  reg [15:0] r0;
  always @(posedge clock) if (enable) r0 <= e0s0;
  assign dout[0 +: 8] = carry_save_get(r0);
  assign dout[8 +: 8] = carry_save_get(r1);
  assign dout[16 +: 8] = carry_save_get(e2s9);
  assign dout[24 +: 8] = carry_save_get(r3);
  assign dout[32 +: 8] = carry_save_get(e4s9);
  assign dout[40 +: 8] = carry_save_get(e5s8);
  assign dout[48 +: 8] = carry_save_get(e6s9);
  assign dout[56 +: 8] = carry_save_get(r7);
  assign dout[64 +: 8] = carry_save_get(e8s9);
  assign dout[72 +: 8] = carry_save_get(e9s8);
  assign dout[80 +: 8] = carry_save_get(e10s9);
  assign dout[88 +: 8] = carry_save_get(e11s7);
  assign dout[96 +: 8] = carry_save_get(e12s9);
  assign dout[104 +: 8] = carry_save_get(e13s8);
  assign dout[112 +: 8] = carry_save_get(e14s9);
  assign dout[120 +: 8] = carry_save_get(r15);
  assign dout[128 +: 8] = carry_save_get(e16s9);
  assign dout[136 +: 8] = carry_save_get(e17s8);
  assign dout[144 +: 8] = carry_save_get(e18s9);
  assign dout[152 +: 8] = carry_save_get(e19s7);
  assign dout[160 +: 8] = carry_save_get(e20s9);
  assign dout[168 +: 8] = carry_save_get(e21s8);
  assign dout[176 +: 8] = carry_save_get(e22s9);
  assign dout[184 +: 8] = carry_save_get(e23s6);
  assign dout[192 +: 8] = carry_save_get(e24s9);
  assign dout[200 +: 8] = carry_save_get(e25s8);
  assign dout[208 +: 8] = carry_save_get(e26s9);
  assign dout[216 +: 8] = carry_save_get(e27s7);
  assign dout[224 +: 8] = carry_save_get(e28s9);
  assign dout[232 +: 8] = carry_save_get(e29s8);
  assign dout[240 +: 8] = carry_save_get(e30s9);
  reg [15:0] r31;
  always @(posedge clock) if (enable) r31 <= e31s5;
  assign dout[248 +: 8] = carry_save_get(r31);
endmodule
module rvb_bextdep_pps64f (
  input clock,
  input enable,
  input [63:0] din,
  output [511:0] dout
);
  function [15:0] carry_save_add;
    input [15:0] a, b;
    reg [7:0] x, y;
    begin
      x = a[15:8] ^ a[7:0] ^ b[7:0];
      y = ((a[15:8] & a[7:0]) | (a[15:8] & b[7:0]) | (a[7:0] & b[7:0])) << 1;
      carry_save_add[7:0] = x ^ y ^ b[15:8];
      carry_save_add[15:8] = ((x & y) | (x & b[15:8]) | (y & b[15:8])) << 1;
    end
  endfunction
  function [7:0] carry_save_get;
    input [15:0] a;
    begin
      carry_save_get = a[7:0] + a[15:8];
    end
  endfunction
  // inputs
  wire [15:0] e0s0 = {15'b0, din[0 +: 1]};
  wire [15:0] e1s0 = {15'b0, din[1 +: 1]};
  wire [15:0] e2s0 = {15'b0, din[2 +: 1]};
  wire [15:0] e3s0 = {15'b0, din[3 +: 1]};
  wire [15:0] e4s0 = {15'b0, din[4 +: 1]};
  wire [15:0] e5s0 = {15'b0, din[5 +: 1]};
  wire [15:0] e6s0 = {15'b0, din[6 +: 1]};
  wire [15:0] e7s0 = {15'b0, din[7 +: 1]};
  wire [15:0] e8s0 = {15'b0, din[8 +: 1]};
  wire [15:0] e9s0 = {15'b0, din[9 +: 1]};
  wire [15:0] e10s0 = {15'b0, din[10 +: 1]};
  wire [15:0] e11s0 = {15'b0, din[11 +: 1]};
  wire [15:0] e12s0 = {15'b0, din[12 +: 1]};
  wire [15:0] e13s0 = {15'b0, din[13 +: 1]};
  wire [15:0] e14s0 = {15'b0, din[14 +: 1]};
  wire [15:0] e15s0 = {15'b0, din[15 +: 1]};
  wire [15:0] e16s0 = {15'b0, din[16 +: 1]};
  wire [15:0] e17s0 = {15'b0, din[17 +: 1]};
  wire [15:0] e18s0 = {15'b0, din[18 +: 1]};
  wire [15:0] e19s0 = {15'b0, din[19 +: 1]};
  wire [15:0] e20s0 = {15'b0, din[20 +: 1]};
  wire [15:0] e21s0 = {15'b0, din[21 +: 1]};
  wire [15:0] e22s0 = {15'b0, din[22 +: 1]};
  wire [15:0] e23s0 = {15'b0, din[23 +: 1]};
  wire [15:0] e24s0 = {15'b0, din[24 +: 1]};
  wire [15:0] e25s0 = {15'b0, din[25 +: 1]};
  wire [15:0] e26s0 = {15'b0, din[26 +: 1]};
  wire [15:0] e27s0 = {15'b0, din[27 +: 1]};
  wire [15:0] e28s0 = {15'b0, din[28 +: 1]};
  wire [15:0] e29s0 = {15'b0, din[29 +: 1]};
  wire [15:0] e30s0 = {15'b0, din[30 +: 1]};
  wire [15:0] e31s0 = {15'b0, din[31 +: 1]};
  wire [15:0] e32s0 = {15'b0, din[32 +: 1]};
  wire [15:0] e33s0 = {15'b0, din[33 +: 1]};
  wire [15:0] e34s0 = {15'b0, din[34 +: 1]};
  wire [15:0] e35s0 = {15'b0, din[35 +: 1]};
  wire [15:0] e36s0 = {15'b0, din[36 +: 1]};
  wire [15:0] e37s0 = {15'b0, din[37 +: 1]};
  wire [15:0] e38s0 = {15'b0, din[38 +: 1]};
  wire [15:0] e39s0 = {15'b0, din[39 +: 1]};
  wire [15:0] e40s0 = {15'b0, din[40 +: 1]};
  wire [15:0] e41s0 = {15'b0, din[41 +: 1]};
  wire [15:0] e42s0 = {15'b0, din[42 +: 1]};
  wire [15:0] e43s0 = {15'b0, din[43 +: 1]};
  wire [15:0] e44s0 = {15'b0, din[44 +: 1]};
  wire [15:0] e45s0 = {15'b0, din[45 +: 1]};
  wire [15:0] e46s0 = {15'b0, din[46 +: 1]};
  wire [15:0] e47s0 = {15'b0, din[47 +: 1]};
  wire [15:0] e48s0 = {15'b0, din[48 +: 1]};
  wire [15:0] e49s0 = {15'b0, din[49 +: 1]};
  wire [15:0] e50s0 = {15'b0, din[50 +: 1]};
  wire [15:0] e51s0 = {15'b0, din[51 +: 1]};
  wire [15:0] e52s0 = {15'b0, din[52 +: 1]};
  wire [15:0] e53s0 = {15'b0, din[53 +: 1]};
  wire [15:0] e54s0 = {15'b0, din[54 +: 1]};
  wire [15:0] e55s0 = {15'b0, din[55 +: 1]};
  wire [15:0] e56s0 = {15'b0, din[56 +: 1]};
  wire [15:0] e57s0 = {15'b0, din[57 +: 1]};
  wire [15:0] e58s0 = {15'b0, din[58 +: 1]};
  wire [15:0] e59s0 = {15'b0, din[59 +: 1]};
  wire [15:0] e60s0 = {15'b0, din[60 +: 1]};
  wire [15:0] e61s0 = {15'b0, din[61 +: 1]};
  wire [15:0] e62s0 = {15'b0, din[62 +: 1]};
  wire [15:0] e63s0 = {15'b0, din[63 +: 1]};
  // forward pass
  wire [15:0] e1s1 = carry_save_add(e1s0, e0s0);
  wire [15:0] e3s1 = carry_save_add(e3s0, e2s0);
  wire [15:0] e5s1 = carry_save_add(e5s0, e4s0);
  wire [15:0] e7s1 = carry_save_add(e7s0, e6s0);
  wire [15:0] e9s1 = carry_save_add(e9s0, e8s0);
  wire [15:0] e11s1 = carry_save_add(e11s0, e10s0);
  wire [15:0] e13s1 = carry_save_add(e13s0, e12s0);
  wire [15:0] e15s1 = carry_save_add(e15s0, e14s0);
  wire [15:0] e17s1 = carry_save_add(e17s0, e16s0);
  wire [15:0] e19s1 = carry_save_add(e19s0, e18s0);
  wire [15:0] e21s1 = carry_save_add(e21s0, e20s0);
  wire [15:0] e23s1 = carry_save_add(e23s0, e22s0);
  wire [15:0] e25s1 = carry_save_add(e25s0, e24s0);
  wire [15:0] e27s1 = carry_save_add(e27s0, e26s0);
  wire [15:0] e29s1 = carry_save_add(e29s0, e28s0);
  wire [15:0] e31s1 = carry_save_add(e31s0, e30s0);
  wire [15:0] e33s1 = carry_save_add(e33s0, e32s0);
  wire [15:0] e35s1 = carry_save_add(e35s0, e34s0);
  wire [15:0] e37s1 = carry_save_add(e37s0, e36s0);
  wire [15:0] e39s1 = carry_save_add(e39s0, e38s0);
  wire [15:0] e41s1 = carry_save_add(e41s0, e40s0);
  wire [15:0] e43s1 = carry_save_add(e43s0, e42s0);
  wire [15:0] e45s1 = carry_save_add(e45s0, e44s0);
  wire [15:0] e47s1 = carry_save_add(e47s0, e46s0);
  wire [15:0] e49s1 = carry_save_add(e49s0, e48s0);
  wire [15:0] e51s1 = carry_save_add(e51s0, e50s0);
  wire [15:0] e53s1 = carry_save_add(e53s0, e52s0);
  wire [15:0] e55s1 = carry_save_add(e55s0, e54s0);
  wire [15:0] e57s1 = carry_save_add(e57s0, e56s0);
  wire [15:0] e59s1 = carry_save_add(e59s0, e58s0);
  wire [15:0] e61s1 = carry_save_add(e61s0, e60s0);
  wire [15:0] e63s1 = carry_save_add(e63s0, e62s0);
  wire [15:0] e3s2 = carry_save_add(e3s1, e1s1);
  wire [15:0] e7s2 = carry_save_add(e7s1, e5s1);
  wire [15:0] e11s2 = carry_save_add(e11s1, e9s1);
  wire [15:0] e15s2 = carry_save_add(e15s1, e13s1);
  wire [15:0] e19s2 = carry_save_add(e19s1, e17s1);
  wire [15:0] e23s2 = carry_save_add(e23s1, e21s1);
  wire [15:0] e27s2 = carry_save_add(e27s1, e25s1);
  wire [15:0] e31s2 = carry_save_add(e31s1, e29s1);
  wire [15:0] e35s2 = carry_save_add(e35s1, e33s1);
  wire [15:0] e39s2 = carry_save_add(e39s1, e37s1);
  wire [15:0] e43s2 = carry_save_add(e43s1, e41s1);
  wire [15:0] e47s2 = carry_save_add(e47s1, e45s1);
  wire [15:0] e51s2 = carry_save_add(e51s1, e49s1);
  wire [15:0] e55s2 = carry_save_add(e55s1, e53s1);
  wire [15:0] e59s2 = carry_save_add(e59s1, e57s1);
  wire [15:0] e63s2 = carry_save_add(e63s1, e61s1);
  wire [15:0] e7s3 = carry_save_add(e7s2, e3s2);
  wire [15:0] e15s3 = carry_save_add(e15s2, e11s2);
  wire [15:0] e23s3 = carry_save_add(e23s2, e19s2);
  wire [15:0] e31s3 = carry_save_add(e31s2, e27s2);
  wire [15:0] e39s3 = carry_save_add(e39s2, e35s2);
  wire [15:0] e47s3 = carry_save_add(e47s2, e43s2);
  wire [15:0] e55s3 = carry_save_add(e55s2, e51s2);
  wire [15:0] e63s3 = carry_save_add(e63s2, e59s2);
  wire [15:0] e15s4 = carry_save_add(e15s3, e7s3);
  wire [15:0] e31s4 = carry_save_add(e31s3, e23s3);
  wire [15:0] e47s4 = carry_save_add(e47s3, e39s3);
  wire [15:0] e63s4 = carry_save_add(e63s3, e55s3);
  wire [15:0] e31s5 = carry_save_add(e31s4, e15s4);
  wire [15:0] e63s5 = carry_save_add(e63s4, e47s4);
  wire [15:0] e63s6 = carry_save_add(e63s5, e31s5);
  // backward pass
  reg [15:0] r47;
  always @(posedge clock) if (enable) r47 <= e47s4;
  reg [15:0] r31;
  always @(posedge clock) if (enable) r31 <= e31s5;
  wire [15:0] e47s7 = carry_save_add(r47, r31);
  reg [15:0] r23;
  always @(posedge clock) if (enable) r23 <= e23s3;
  reg [15:0] r15;
  always @(posedge clock) if (enable) r15 <= e15s4;
  wire [15:0] e23s8 = carry_save_add(r23, r15);
  reg [15:0] r39;
  always @(posedge clock) if (enable) r39 <= e39s3;
  wire [15:0] e39s8 = carry_save_add(r39, r31);
  reg [15:0] r55;
  always @(posedge clock) if (enable) r55 <= e55s3;
  wire [15:0] e55s8 = carry_save_add(r55, e47s7);
  reg [15:0] r11;
  always @(posedge clock) if (enable) r11 <= e11s2;
  reg [15:0] r7;
  always @(posedge clock) if (enable) r7 <= e7s3;
  wire [15:0] e11s9 = carry_save_add(r11, r7);
  reg [15:0] r19;
  always @(posedge clock) if (enable) r19 <= e19s2;
  wire [15:0] e19s9 = carry_save_add(r19, r15);
  reg [15:0] r27;
  always @(posedge clock) if (enable) r27 <= e27s2;
  wire [15:0] e27s9 = carry_save_add(r27, e23s8);
  reg [15:0] r35;
  always @(posedge clock) if (enable) r35 <= e35s2;
  wire [15:0] e35s9 = carry_save_add(r35, r31);
  reg [15:0] r43;
  always @(posedge clock) if (enable) r43 <= e43s2;
  wire [15:0] e43s9 = carry_save_add(r43, e39s8);
  reg [15:0] r51;
  always @(posedge clock) if (enable) r51 <= e51s2;
  wire [15:0] e51s9 = carry_save_add(r51, e47s7);
  reg [15:0] r59;
  always @(posedge clock) if (enable) r59 <= e59s2;
  wire [15:0] e59s9 = carry_save_add(r59, e55s8);
  reg [15:0] r5;
  always @(posedge clock) if (enable) r5 <= e5s1;
  reg [15:0] r3;
  always @(posedge clock) if (enable) r3 <= e3s2;
  wire [15:0] e5s10 = carry_save_add(r5, r3);
  reg [15:0] r9;
  always @(posedge clock) if (enable) r9 <= e9s1;
  wire [15:0] e9s10 = carry_save_add(r9, r7);
  reg [15:0] r13;
  always @(posedge clock) if (enable) r13 <= e13s1;
  wire [15:0] e13s10 = carry_save_add(r13, e11s9);
  reg [15:0] r17;
  always @(posedge clock) if (enable) r17 <= e17s1;
  wire [15:0] e17s10 = carry_save_add(r17, r15);
  reg [15:0] r21;
  always @(posedge clock) if (enable) r21 <= e21s1;
  wire [15:0] e21s10 = carry_save_add(r21, e19s9);
  reg [15:0] r25;
  always @(posedge clock) if (enable) r25 <= e25s1;
  wire [15:0] e25s10 = carry_save_add(r25, e23s8);
  reg [15:0] r29;
  always @(posedge clock) if (enable) r29 <= e29s1;
  wire [15:0] e29s10 = carry_save_add(r29, e27s9);
  reg [15:0] r33;
  always @(posedge clock) if (enable) r33 <= e33s1;
  wire [15:0] e33s10 = carry_save_add(r33, r31);
  reg [15:0] r37;
  always @(posedge clock) if (enable) r37 <= e37s1;
  wire [15:0] e37s10 = carry_save_add(r37, e35s9);
  reg [15:0] r41;
  always @(posedge clock) if (enable) r41 <= e41s1;
  wire [15:0] e41s10 = carry_save_add(r41, e39s8);
  reg [15:0] r45;
  always @(posedge clock) if (enable) r45 <= e45s1;
  wire [15:0] e45s10 = carry_save_add(r45, e43s9);
  reg [15:0] r49;
  always @(posedge clock) if (enable) r49 <= e49s1;
  wire [15:0] e49s10 = carry_save_add(r49, e47s7);
  reg [15:0] r53;
  always @(posedge clock) if (enable) r53 <= e53s1;
  wire [15:0] e53s10 = carry_save_add(r53, e51s9);
  reg [15:0] r57;
  always @(posedge clock) if (enable) r57 <= e57s1;
  wire [15:0] e57s10 = carry_save_add(r57, e55s8);
  reg [15:0] r61;
  always @(posedge clock) if (enable) r61 <= e61s1;
  wire [15:0] e61s10 = carry_save_add(r61, e59s9);
  reg [15:0] r2;
  always @(posedge clock) if (enable) r2 <= e2s0;
  reg [15:0] r1;
  always @(posedge clock) if (enable) r1 <= e1s1;
  wire [15:0] e2s11 = carry_save_add(r2, r1);
  reg [15:0] r4;
  always @(posedge clock) if (enable) r4 <= e4s0;
  wire [15:0] e4s11 = carry_save_add(r4, r3);
  reg [15:0] r6;
  always @(posedge clock) if (enable) r6 <= e6s0;
  wire [15:0] e6s11 = carry_save_add(r6, e5s10);
  reg [15:0] r8;
  always @(posedge clock) if (enable) r8 <= e8s0;
  wire [15:0] e8s11 = carry_save_add(r8, r7);
  reg [15:0] r10;
  always @(posedge clock) if (enable) r10 <= e10s0;
  wire [15:0] e10s11 = carry_save_add(r10, e9s10);
  reg [15:0] r12;
  always @(posedge clock) if (enable) r12 <= e12s0;
  wire [15:0] e12s11 = carry_save_add(r12, e11s9);
  reg [15:0] r14;
  always @(posedge clock) if (enable) r14 <= e14s0;
  wire [15:0] e14s11 = carry_save_add(r14, e13s10);
  reg [15:0] r16;
  always @(posedge clock) if (enable) r16 <= e16s0;
  wire [15:0] e16s11 = carry_save_add(r16, r15);
  reg [15:0] r18;
  always @(posedge clock) if (enable) r18 <= e18s0;
  wire [15:0] e18s11 = carry_save_add(r18, e17s10);
  reg [15:0] r20;
  always @(posedge clock) if (enable) r20 <= e20s0;
  wire [15:0] e20s11 = carry_save_add(r20, e19s9);
  reg [15:0] r22;
  always @(posedge clock) if (enable) r22 <= e22s0;
  wire [15:0] e22s11 = carry_save_add(r22, e21s10);
  reg [15:0] r24;
  always @(posedge clock) if (enable) r24 <= e24s0;
  wire [15:0] e24s11 = carry_save_add(r24, e23s8);
  reg [15:0] r26;
  always @(posedge clock) if (enable) r26 <= e26s0;
  wire [15:0] e26s11 = carry_save_add(r26, e25s10);
  reg [15:0] r28;
  always @(posedge clock) if (enable) r28 <= e28s0;
  wire [15:0] e28s11 = carry_save_add(r28, e27s9);
  reg [15:0] r30;
  always @(posedge clock) if (enable) r30 <= e30s0;
  wire [15:0] e30s11 = carry_save_add(r30, e29s10);
  reg [15:0] r32;
  always @(posedge clock) if (enable) r32 <= e32s0;
  wire [15:0] e32s11 = carry_save_add(r32, r31);
  reg [15:0] r34;
  always @(posedge clock) if (enable) r34 <= e34s0;
  wire [15:0] e34s11 = carry_save_add(r34, e33s10);
  reg [15:0] r36;
  always @(posedge clock) if (enable) r36 <= e36s0;
  wire [15:0] e36s11 = carry_save_add(r36, e35s9);
  reg [15:0] r38;
  always @(posedge clock) if (enable) r38 <= e38s0;
  wire [15:0] e38s11 = carry_save_add(r38, e37s10);
  reg [15:0] r40;
  always @(posedge clock) if (enable) r40 <= e40s0;
  wire [15:0] e40s11 = carry_save_add(r40, e39s8);
  reg [15:0] r42;
  always @(posedge clock) if (enable) r42 <= e42s0;
  wire [15:0] e42s11 = carry_save_add(r42, e41s10);
  reg [15:0] r44;
  always @(posedge clock) if (enable) r44 <= e44s0;
  wire [15:0] e44s11 = carry_save_add(r44, e43s9);
  reg [15:0] r46;
  always @(posedge clock) if (enable) r46 <= e46s0;
  wire [15:0] e46s11 = carry_save_add(r46, e45s10);
  reg [15:0] r48;
  always @(posedge clock) if (enable) r48 <= e48s0;
  wire [15:0] e48s11 = carry_save_add(r48, e47s7);
  reg [15:0] r50;
  always @(posedge clock) if (enable) r50 <= e50s0;
  wire [15:0] e50s11 = carry_save_add(r50, e49s10);
  reg [15:0] r52;
  always @(posedge clock) if (enable) r52 <= e52s0;
  wire [15:0] e52s11 = carry_save_add(r52, e51s9);
  reg [15:0] r54;
  always @(posedge clock) if (enable) r54 <= e54s0;
  wire [15:0] e54s11 = carry_save_add(r54, e53s10);
  reg [15:0] r56;
  always @(posedge clock) if (enable) r56 <= e56s0;
  wire [15:0] e56s11 = carry_save_add(r56, e55s8);
  reg [15:0] r58;
  always @(posedge clock) if (enable) r58 <= e58s0;
  wire [15:0] e58s11 = carry_save_add(r58, e57s10);
  reg [15:0] r60;
  always @(posedge clock) if (enable) r60 <= e60s0;
  wire [15:0] e60s11 = carry_save_add(r60, e59s9);
  reg [15:0] r62;
  always @(posedge clock) if (enable) r62 <= e62s0;
  wire [15:0] e62s11 = carry_save_add(r62, e61s10);
  // outputs
  reg [15:0] r0;
  always @(posedge clock) if (enable) r0 <= e0s0;
  assign dout[0 +: 8] = carry_save_get(r0);
  assign dout[8 +: 8] = carry_save_get(r1);
  assign dout[16 +: 8] = carry_save_get(e2s11);
  assign dout[24 +: 8] = carry_save_get(r3);
  assign dout[32 +: 8] = carry_save_get(e4s11);
  assign dout[40 +: 8] = carry_save_get(e5s10);
  assign dout[48 +: 8] = carry_save_get(e6s11);
  assign dout[56 +: 8] = carry_save_get(r7);
  assign dout[64 +: 8] = carry_save_get(e8s11);
  assign dout[72 +: 8] = carry_save_get(e9s10);
  assign dout[80 +: 8] = carry_save_get(e10s11);
  assign dout[88 +: 8] = carry_save_get(e11s9);
  assign dout[96 +: 8] = carry_save_get(e12s11);
  assign dout[104 +: 8] = carry_save_get(e13s10);
  assign dout[112 +: 8] = carry_save_get(e14s11);
  assign dout[120 +: 8] = carry_save_get(r15);
  assign dout[128 +: 8] = carry_save_get(e16s11);
  assign dout[136 +: 8] = carry_save_get(e17s10);
  assign dout[144 +: 8] = carry_save_get(e18s11);
  assign dout[152 +: 8] = carry_save_get(e19s9);
  assign dout[160 +: 8] = carry_save_get(e20s11);
  assign dout[168 +: 8] = carry_save_get(e21s10);
  assign dout[176 +: 8] = carry_save_get(e22s11);
  assign dout[184 +: 8] = carry_save_get(e23s8);
  assign dout[192 +: 8] = carry_save_get(e24s11);
  assign dout[200 +: 8] = carry_save_get(e25s10);
  assign dout[208 +: 8] = carry_save_get(e26s11);
  assign dout[216 +: 8] = carry_save_get(e27s9);
  assign dout[224 +: 8] = carry_save_get(e28s11);
  assign dout[232 +: 8] = carry_save_get(e29s10);
  assign dout[240 +: 8] = carry_save_get(e30s11);
  assign dout[248 +: 8] = carry_save_get(r31);
  assign dout[256 +: 8] = carry_save_get(e32s11);
  assign dout[264 +: 8] = carry_save_get(e33s10);
  assign dout[272 +: 8] = carry_save_get(e34s11);
  assign dout[280 +: 8] = carry_save_get(e35s9);
  assign dout[288 +: 8] = carry_save_get(e36s11);
  assign dout[296 +: 8] = carry_save_get(e37s10);
  assign dout[304 +: 8] = carry_save_get(e38s11);
  assign dout[312 +: 8] = carry_save_get(e39s8);
  assign dout[320 +: 8] = carry_save_get(e40s11);
  assign dout[328 +: 8] = carry_save_get(e41s10);
  assign dout[336 +: 8] = carry_save_get(e42s11);
  assign dout[344 +: 8] = carry_save_get(e43s9);
  assign dout[352 +: 8] = carry_save_get(e44s11);
  assign dout[360 +: 8] = carry_save_get(e45s10);
  assign dout[368 +: 8] = carry_save_get(e46s11);
  assign dout[376 +: 8] = carry_save_get(e47s7);
  assign dout[384 +: 8] = carry_save_get(e48s11);
  assign dout[392 +: 8] = carry_save_get(e49s10);
  assign dout[400 +: 8] = carry_save_get(e50s11);
  assign dout[408 +: 8] = carry_save_get(e51s9);
  assign dout[416 +: 8] = carry_save_get(e52s11);
  assign dout[424 +: 8] = carry_save_get(e53s10);
  assign dout[432 +: 8] = carry_save_get(e54s11);
  assign dout[440 +: 8] = carry_save_get(e55s8);
  assign dout[448 +: 8] = carry_save_get(e56s11);
  assign dout[456 +: 8] = carry_save_get(e57s10);
  assign dout[464 +: 8] = carry_save_get(e58s11);
  assign dout[472 +: 8] = carry_save_get(e59s9);
  assign dout[480 +: 8] = carry_save_get(e60s11);
  assign dout[488 +: 8] = carry_save_get(e61s10);
  assign dout[496 +: 8] = carry_save_get(e62s11);
  reg [15:0] r63;
  always @(posedge clock) if (enable) r63 <= e63s6;
  assign dout[504 +: 8] = carry_save_get(r63);
endmodule
