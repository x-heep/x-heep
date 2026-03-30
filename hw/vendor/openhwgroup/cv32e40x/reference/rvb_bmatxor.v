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

module rvb_bmatxor #(
	parameter integer CYCLES = 0
) (
	// control signals
	input         clock,          // positive edge clock
	input         reset,          // synchronous reset
	
	// data input
	input         din_valid,      // input is valid
	output        din_ready,      // core accepts input
	input  [63:0] din_rs1,        // value of 1st argument
	input  [63:0] din_rs2,        // value of 2nd argument
	input         din_insn30,     // value of instruction bit 30
	
	// data output
	output        dout_valid,     // output is valid
	input         dout_ready,     // accept output
	output [63:0] dout_rd         // output value
);
	// 30   Function
	// --   --------
	//  0   BMATOR
	//  1   BMATXOR

	generate
		if (CYCLES == 0) begin
			rvb_bmatxor_0 core  (
				.clock      (clock     ),
				.reset      (reset     ),
				.din_valid  (din_valid ),
				.din_ready  (din_ready ),
				.din_rs1    (din_rs1   ),
				.din_rs2    (din_rs2   ),
				.din_xor    (din_insn30),
				.dout_valid (dout_valid),
				.dout_ready (dout_ready),
				.dout_rd    (dout_rd   )
			);
		end
		if (CYCLES == 8) begin
			rvb_bmatxor_8 core  (
				.clock      (clock     ),
				.reset      (reset     ),
				.din_valid  (din_valid ),
				.din_ready  (din_ready ),
				.din_rs1    (din_rs1   ),
				.din_rs2    (din_rs2   ),
				.din_xor    (din_insn30),
				.dout_valid (dout_valid),
				.dout_ready (dout_ready),
				.dout_rd    (dout_rd   )
			);
		end
	endgenerate
endmodule

module rvb_bmatxor_0 (
	// control signals
	input         clock,          // positive edge clock
	input         reset,          // synchronous reset
	
	// data input
	input         din_valid,      // input is valid
	output        din_ready,      // core accepts input
	input  [63:0] din_rs1,        // value of 1st argument
	input  [63:0] din_rs2,        // value of 2nd argument
	input         din_xor,        // select XOR function
	
	// data output
	output        dout_valid,     // output is valid
	input         dout_ready,     // accept output
	output [63:0] dout_rd         // output value
);
	assign dout_valid = din_valid && !reset;
	assign din_ready = dout_ready && !reset;

	wire [63:0] A, B;

	assign A = din_rs1;
	rvb_bmatxor_transpose transp (din_rs2, B);

	genvar i;
	generate
		for (i = 0; i < 64; i=i+1) begin:loop
			rvb_bmatxor_reduce slice (
				.A(A[8*(i/8) +: 8]),
				.B(B[8*(i%8) +: 8]),
				.XOR(din_xor),
				.Y(dout_rd[i])
			);
		end
	endgenerate
endmodule

module rvb_bmatxor_8 (
	// control signals
	input         clock,          // positive edge clock
	input         reset,          // synchronous reset
	
	// data input
	input         din_valid,      // input is valid
	output        din_ready,      // core accepts input
	input  [63:0] din_rs1,        // value of 1st argument
	input  [63:0] din_rs2,        // value of 2nd argument
	input         din_xor,        // select XOR function
	
	// data output
	output        dout_valid,     // output is valid
	input         dout_ready,     // accept output
	output [63:0] dout_rd         // output value
);
	reg XOR;
	reg [63:0] A, B;
	wire [7:0] P;

	wire [63:0] AI, BI;
	assign AI = din_rs1;
	rvb_bmatxor_transpose transp (din_rs2, BI);

	reg [3:0] state;
	assign din_ready = ((state == 0) || (state == 9 && dout_valid && dout_ready)) && !reset;
	assign dout_valid = (state == 9) && !reset;
	assign dout_rd = A;

	always @(posedge clock) begin
		if (state == 0) begin
			A <= AI;
			B <= BI;
			XOR <= din_xor;
			state <= din_valid && din_ready;
		end else if (state != 9) begin
			A <= {P, A[63:8]};
			state <= state + 1;
		end else if (dout_valid && dout_ready) begin
			A <= AI;
			B <= BI;
			XOR <= din_xor;
			state <= din_valid && din_ready;
		end
		if (reset) begin
			state <= 0;
		end
	end

	genvar i;
	generate
		for (i = 0; i < 8; i=i+1) begin:loop
			rvb_bmatxor_reduce slice (
				.A(A[7:0]),
				.B(B[8*(i%8) +: 8]),
				.XOR(XOR),
				.Y(P[i])
			);
		end
	endgenerate
endmodule

module rvb_bmatxor_transpose (
	input  [63:0] A,
	output [63:0] Y
);
	genvar i;
	generate for (i = 0; i < 64; i=i+1) begin:loop
		assign Y[i] = A[{i[2:0], i[5:3]}];
	end endgenerate
endmodule

module rvb_bmatxor_reduce (
	input [7:0] A, B,
	input XOR,
	output Y
);
	wire [7:0] AB = A & B;
	assign Y = XOR ? ^AB : |AB;
endmodule
