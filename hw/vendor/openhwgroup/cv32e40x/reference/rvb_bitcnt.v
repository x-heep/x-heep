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

module rvb_bitcnt #(
	parameter integer XLEN = 64,
	parameter integer BMAT = 0
) (
	// control signals
	input             clock,          // positive edge clock
	input             reset,          // synchronous reset

	// data input
	input             din_valid,      // input is valid
	output            din_ready,      // core accepts input
	input  [XLEN-1:0] din_rs1,        // value of argument
	input             din_insn3,      // value of instruction bit 3
	input             din_insn20,     // value of instruction bit 20
	input             din_insn21,     // value of instruction bit 21
	input             din_insn22,     // value of instruction bit 22

	// data output
	output            dout_valid,     // output is valid
	input             dout_ready,     // accept output
	output [XLEN-1:0] dout_rd         // output value
);
	// 22 21 20  3   Function
	// -----------   --------
	//  0  0  0  W   CLZ
	//  0  0  1  W   CTZ
	//  0  1  0  W   PCNT
	//  0  1  1  0   BMATFLIP
	//  1  0  0  0   SEXT.B
	//  1  0  1  0   SEXT.H

	assign din_ready = dout_ready && !reset;
	assign dout_valid = din_valid && !reset;

	wire wmode = (XLEN == 32) || din_insn3;
	wire revmode = !din_insn20;
	wire czmode = !din_insn21;
	wire bmatmode = (XLEN == 64) && BMAT && din_insn20 && din_insn21;

	wire sextbit = din_insn20 ? din_rs1[15] : din_rs1[7];
	wire [XLEN-1:0] sextval = {{XLEN-16{sextbit}}, din_insn20 ? din_rs1[15:8] : {8{din_rs1[7]}}, din_rs1[7:0]};

	integer i;
	reg [XLEN-1:0] data;
	reg [XLEN-1:0] transp;
	reg [7:0] cnt;

	always @* begin
		for (i = 0; i < XLEN; i = i+1)
			data[i] = (i < 32 && wmode) ? din_rs1[(64-i-1) % 32] : din_rs1[(64-i-1) % XLEN];
		if (!revmode)
			data = din_rs1;
		if (czmode)
			data = (data-1) & ~data;
		if (wmode)
			data = data & 32'h FFFFFFFF;

		cnt = 0;
		for (i = 0; i < XLEN; i = i+1)
			cnt = cnt + data[i];

		for (i = 0; i < XLEN; i=i+1)
			transp[i] = din_rs1[{i[2:0], i[5:3]} % XLEN];
	end 

	assign dout_rd = din_insn22 ? sextval : bmatmode ? transp : cnt;
endmodule
