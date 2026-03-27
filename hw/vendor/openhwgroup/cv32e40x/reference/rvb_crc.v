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

module rvb_crc #(
	parameter integer XLEN = 64
) (
	// control signals
	input             clock,          // positive edge clock
	input             reset,          // synchronous reset
	
	// data input
	input             din_valid,      // input is valid
	output            din_ready,      // core accepts input
	input  [XLEN-1:0] din_rs1,        // value of 1st argument
	input             din_insn20,     // value of instruction bit 20
	input             din_insn21,     // value of instruction bit 21
	input             din_insn23,     // value of instruction bit 23
	
	// data output
	output            dout_valid,     // output is valid
	input             dout_ready,     // accept output
	output [XLEN-1:0] dout_rd         // output value
);
	reg cmode;
	reg [3:0] state;
	reg [XLEN-1:0] data, next;

	assign din_ready = &state || (dout_valid && dout_ready);
	assign dout_valid = !state;
	assign dout_rd = data;

	integer i;
	always @* begin
		next = data;
		for (i = 0; i < 8; i = i+1)
			next = (next >> 1) ^ (next[0] ? (cmode ? 32'h 82F63B78 : 32'h EDB88320) : 0);
	end

	always @(posedge clock) begin
		if (|state != &state) begin
			state <= state - 1;
			data <= next;
		end
		if (dout_valid && dout_ready) begin
			state <= 15;
		end
		if (din_valid && din_ready) begin
			cmode <= din_insn23;
			state <= 1 << {din_insn21, din_insn20};
			data <= din_rs1;
		end
		if (reset) begin
			state <= 15;
		end
	end
endmodule
