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

module rvb_clmul #(
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
	input             din_insn3,      // value of instruction bit 3
	input             din_insn12,     // value of instruction bit 12
	input             din_insn13,     // value of instruction bit 13
	
	// data output
	output            dout_valid,     // output is valid
	input             dout_ready,     // accept output
	output [XLEN-1:0] dout_rd         // output value
);
	// 13 12  3   Function
	// --------   --------
	//  0  1  0   CLMUL
	//  1  0  0   CLMULR
	//  1  1  0   CLMULH
	// --------   --------
	//  0  1  1   CLMULW
	//  1  0  1   CLMULRW
	//  1  1  1   CLMULHW

	localparam SLEN = XLEN == 32 ? 3 : 4;

	reg busy;
	reg [SLEN-1:0] state;
	reg [XLEN-1:0] A, B, X;
	reg funct_w, funct_r, funct_h;

	wire [XLEN-1:0] next_X = (X << 8) ^
			(B[XLEN-1] ? A << 7 : 0) ^ (B[XLEN-2] ? A << 6 : 0) ^
			(B[XLEN-3] ? A << 5 : 0) ^ (B[XLEN-4] ? A << 4 : 0) ^
			(B[XLEN-5] ? A << 3 : 0) ^ (B[XLEN-6] ? A << 2 : 0) ^
			(B[XLEN-7] ? A << 1 : 0) ^ (B[XLEN-8] ? A << 0 : 0);

	function [XLEN-1:0] bitrev;
		input [XLEN-1:0] in;
		integer i;
		begin
			for (i = 0; i < XLEN; i = i+1)
				bitrev[i] = in[XLEN-1-i];
		end
	endfunction

	function [XLEN-1:0] bitrev32;
		input [XLEN-1:0] in;
		integer i;
		begin
			bitrev32 = 'bx;
			for (i = 0; i < 32; i = i+1)
				bitrev32[i] = in[31-i];
		end
	endfunction

	assign din_ready = (!busy || (dout_valid && dout_ready)) && !reset;
	assign dout_valid = !state && busy && !reset;

	reg [XLEN-1:0] dout_rd_reg;
	assign dout_rd = dout_rd_reg;
	
	always @* begin
		dout_rd_reg = X;
		if (funct_r) begin
			if (funct_w && XLEN != 32) begin
				dout_rd_reg = bitrev32(dout_rd_reg);
				dout_rd_reg[XLEN-32] = 0;
			end else begin
				dout_rd_reg = bitrev(dout_rd_reg);
			end
		end
		if (funct_h) begin
			dout_rd_reg = dout_rd_reg >> 1;
		end
		if (funct_w && XLEN != 32) begin
			dout_rd_reg[XLEN-1:XLEN-32] = {32{dout_rd_reg[31]}};
		end
	end

	always @(posedge clock) begin
		if (dout_valid && dout_ready) begin
			busy <= 0;
		end
		if (!state) begin
			if (din_valid && din_ready) begin
				funct_r <= din_insn13;
				funct_h <= din_insn13 && din_insn12;
				if (din_insn3 && XLEN != 32) begin
					funct_w <= 1;
					A <= din_insn13 ? bitrev32(din_rs1) : din_rs1;
					B <= din_insn13 ? bitrev(din_rs2) : {din_rs2, 32'bx};
				end else begin
					funct_w <= 0;
					A <= din_insn13 ? bitrev(din_rs1) : din_rs1;
					B <= din_insn13 ? bitrev(din_rs2) : din_rs2;
				end
				busy <= 1;
				state <= (din_insn3 || XLEN == 32) ? 4 : 8;
			end
		end else begin
			X <= next_X;
			B <= B << 8;
			state <= state - 1;
		end
		if (reset) begin
			busy <= 0;
			state <= 0;
		end
	end
endmodule
