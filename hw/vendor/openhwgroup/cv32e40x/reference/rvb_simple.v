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

module rvb_simple #(
	parameter integer XLEN = 64
) (
	// control signals
	input             clock,          // positive edge clock
	input             reset,          // synchronous reset

	// data input
	input             din_valid,      // input is valid
	output            din_ready,      // core accepts input
	input  [XLEN-1:0] din_rs1,        // value of 1st argument
	input  [XLEN-1:0] din_rs2,        // value of 2nd argument
	input  [XLEN-1:0] din_rs3,        // value of 3rd argument
	input             din_insn3,      // value of instruction bit 3
	input             din_insn5,      // value of instruction bit 5
	input             din_insn12,     // value of instruction bit 12
	input             din_insn13,     // value of instruction bit 13
	input             din_insn14,     // value of instruction bit 14
	input             din_insn25,     // value of instruction bit 25
	input             din_insn26,     // value of instruction bit 26
	input             din_insn27,     // value of instruction bit 27
	input             din_insn30,     // value of instruction bit 30

	// data output
	output            dout_valid,     // output is valid
	input             dout_ready,     // accept output
	output [XLEN-1:0] dout_rd         // output value
);
	// 30 27 26 25 14 13 12  5  3   Function
	// --------------------------   --------
	//  0  1  0  1  1  0  0  1  0   MIN
	//  0  1  0  1  1  0  1  1  0   MAX
	//  0  1  0  1  1  1  0  1  0   MINU
	//  0  1  0  1  1  1  1  1  0   MAXU
	// --------------------------   --------
	//  1  0  0  0  1  1  1  1  0   ANDN
	//  1  0  0  0  1  1  0  1  0   ORN
	//  1  0  0  0  1  0  0  1  0   XNOR
	// --------------------------   --------
	//  0  1  0  0  1  0  0  1  0   PACK
	//  0  1  0  0  1  0  0  1  1   PACKW
	//  0  1  0  0  1  1  1  1  0   PACKH
	//  1  1  0  0  1  0  0  1  0   PACKU
	//  1  1  0  0  1  0  0  1  1   PACKUW
	// --------------------------   --------
	//  -  -  0  1  0  0  1  1  0   CMIX
	//  -  -  0  1  1  0  1  1  0   CMOV
	// --------------------------   --------
	//  -  -  -  -  1  0  0  0  1   ADDIWU
	//  0  1  0  1  0  0  0  1  1   ADDWU
	//  1  1  0  1  0  0  0  1  1   SUBWU
	//  0  1  0  0  0  0  0  1  1   ADDUW
	//  1  1  0  0  0  0  0  1  1   SUBUW
	// --------------------------   --------
	//  0  0  0  0  0  1  0  1  0   SH1ADD
	//  0  0  0  0  1  0  0  1  0   SH2ADD
	//  0  0  0  0  1  1  0  1  0   SH3ADD
	// --------------------------   --------
	//  0  0  0  0  0  1  0  1  1   SH1ADDU.W
	//  0  0  0  0  1  0  0  1  1   SH2ADDU.W
	//  0  0  0  0  1  1  0  1  1   SH3ADDU.W
	// --------------------------   --------

	assign din_ready = dout_ready && !reset;
	assign dout_valid = din_valid && !reset;


	// ---- SH1ADD SH2ADD SH3ADD SH1ADDW.U SH2ADDW.U SH3ADDW.U ----

	wire shadd_active = !{din_insn30, din_insn27, din_insn26, din_insn25} && din_insn5;
	wire [1:0] shadd_shamt = {din_insn14, din_insn13};
	wire [XLEN-1:0] shadd_tmp = (din_insn3 ? din_rs1[31:0] : din_rs1) << shadd_shamt;
	wire [XLEN-1:0] shadd_out = shadd_active ? shadd_tmp + din_rs2 : 0;


	// ---- ADDIW ADDWU SUBWU ADDUW SUBUW ----

	wire wuw_active = (XLEN == 64) && (!din_insn5 || (din_insn3 && !din_insn14 && din_insn27));

	wire wuw_sub = din_insn30 && din_insn5;
	wire wuw_wu = !din_insn5 || din_insn25;

	wire [XLEN-1:0] wuw_arg = wuw_wu ? din_rs2 : din_rs2[31:0];
	wire [XLEN-1:0] wuw_sum = din_rs1 + (wuw_arg ^ {XLEN{wuw_sub}}) + wuw_sub;
	wire [XLEN-1:0] wuw_out = wuw_wu ? wuw_sum[31:0] : wuw_sum;

	wire [XLEN-1:0] wuw_dout = wuw_active ? wuw_out : 0;


	// ---- MIN MAX MINU MAXU ----

	wire minmax_active = !wuw_active && {din_insn30, din_insn27, din_insn26, din_insn25, din_insn14} == 5'b 01011;

	wire [XLEN:0] minmax_a = {din_insn13 ? 1'b0 : din_rs1[XLEN-1], din_rs1};
	wire [XLEN:0] minmax_b = {din_insn13 ? 1'b0 : din_rs2[XLEN-1], din_rs2};
	wire minmax_a_larger_b = $signed(minmax_a) > $signed(minmax_b);
	wire minmax_choose_b = minmax_a_larger_b ^ din_insn12;

	wire [XLEN-1:0] minmax_dout = minmax_active ? (minmax_choose_b ? din_rs2 : din_rs1) : 0;


	// ---- ANDN ORN XNOR ----

	wire logicn_active = !wuw_active && {din_insn30, din_insn27, din_insn26, din_insn25, din_insn14} == 5'b 10001;

	wire [XLEN-1:0] logicn_dout = !logicn_active ? 0 : din_insn12 ? din_rs1 & ~din_rs2 :
			din_insn13 ? din_rs1 | ~din_rs2 : din_rs1 ^ ~din_rs2;


	// ---- PACK PACKW PACKH PACKU PACKUW ----

	wire pack_active = !wuw_active && {din_insn27, din_insn26, din_insn25, din_insn14} == 4'b 1001;

	wire [31:0] pack_rs1 = din_insn30 ? ((din_insn3 || XLEN == 32) ? {16'bx, din_rs1[31:16]} : din_rs1 >> 32) : din_rs1;
	wire [31:0] pack_rs2 = din_insn30 ? ((din_insn3 || XLEN == 32) ? {16'bx, din_rs2[31:16]} : din_rs2 >> 32) : din_rs2;

	wire [31:0] pack_dout32 = {pack_rs2[15:0], pack_rs1[15:0]};
	wire [63:0] pack_dout64 = {pack_rs2[31:0], pack_rs1[31:0]};

	wire [XLEN-1:0] pack_dout = !pack_active ? 0 : din_insn13 ? {din_rs2[7:0], din_rs1[7:0]} :
			(din_insn3 || XLEN == 32) ? {{32{pack_dout32[31]}}, pack_dout32} : pack_dout64;


	// ---- CMIX CMOV ----

	wire cmixmov_active = !wuw_active && din_insn26;

	wire [XLEN-1:0] cmixmov_dout = !cmixmov_active ? 0 : din_insn14 ? (din_rs2 ? din_rs1 : din_rs3) : (din_rs1 & din_rs2) | (din_rs3 & ~din_rs2);


	// ---- Output Stage ----

	assign dout_rd = shadd_out | wuw_dout | minmax_dout | logicn_dout | pack_dout | cmixmov_dout;
endmodule
