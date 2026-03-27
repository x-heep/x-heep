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

module rvb_zbb32 (
	// control signals
	input             clock,          // positive edge clock
	input             reset,          // synchronous reset

	// data input
	input             din_valid,      // input is valid
	output            din_ready,      // core accepts input
	output            din_decoded,    // core can decode insn
	input      [31:0] din_rs1,        // value of 1st argument
	input      [31:0] din_rs2,        // value of 2nd argument
	input      [31:0] din_insn,       // value of instruction word

	// data output
	output            dout_valid,     // output is valid
	input             dout_ready,     // accept output
	output     [31:0] dout_rd         // output value
);
	wire insn_bitcnt;
	wire insn_minmax;
	wire insn_shift;
	wire insn_opneg;
	wire insn_pack;

	integer i;
	reg [31:0] dout_bitcnt = 0;
	reg [31:0] dout_minmax = 0;
	reg [31:0] dout_shift = 0;
	reg [31:0] dout_opneg = 0;
	reg [31:0] dout_pack = 0;

	assign dout_valid = din_valid && !reset;
	assign din_ready = dout_ready && !reset;

	assign din_decoded = |{insn_bitcnt, insn_minmax, insn_shift, insn_opneg, insn_pack};

	assign dout_rd = insn_bitcnt ? dout_bitcnt : insn_minmax ? dout_minmax :
			insn_shift ? dout_shift : insn_opneg ? dout_opneg : dout_pack;

	rvb_zbb32_decoder decoder (
		.insn       (din_insn   ),
		.insn_bitcnt(insn_bitcnt),
		.insn_minmax(insn_minmax),
		.insn_shift (insn_shift ),
		.insn_opneg (insn_opneg ),
		.insn_pack  (insn_pack  )
	);

	// ------------------------------------------------------------

	reg [31:0] din_rev;

	always @* begin
		din_rev = din_rs1;
		din_rev = ((din_rev & 32'h 55555555) <<  1) | ((din_rev & 32'h AAAAAAAA) >>  1);
		din_rev = ((din_rev & 32'h 33333333) <<  2) | ((din_rev & 32'h CCCCCCCC) >>  2);
		din_rev = ((din_rev & 32'h 0F0F0F0F) <<  4) | ((din_rev & 32'h F0F0F0F0) >>  4);
		din_rev = ((din_rev & 32'h 00FF00FF) <<  8) | ((din_rev & 32'h FF00FF00) >>  8);
		din_rev = ((din_rev & 32'h 0000FFFF) << 16) | ((din_rev & 32'h FFFF0000) >> 16);
	end

	// ------------------------------------------------------------

	wire bitcnt_ctz = din_insn[20];
	wire bitcnt_pcnt = din_insn[21];

	wire [31:0] bitcnt_data = bitcnt_ctz ? din_rs1 : din_rev;
	wire [31:0] bitcnt_bits = bitcnt_pcnt ? bitcnt_data : (bitcnt_data-1) & ~bitcnt_data;

	always @* begin
		dout_bitcnt = 0;
		for (i = 0; i < 32; i=i+1)
			dout_bitcnt[5:0] = dout_bitcnt[5:0] + bitcnt_bits[i];
	end

	// ------------------------------------------------------------

	wire rs1_msb = !din_insn[13] && din_rs1[31];
	wire rs2_msb = !din_insn[13] && din_rs2[31];
	wire minmax_lt = $signed({rs1_msb, din_rs1}) < $signed({rs2_msb, din_rs2});

	always @* begin
		dout_minmax = (din_insn[12] ^ minmax_lt) ? din_rs1 : din_rs2;
	end

	// ------------------------------------------------------------

	wire [4:0] shamt = din_insn[5] ? din_rs2 : din_insn[24:20];

	wire shift_left  = !din_insn[14] && !din_insn[27];
	wire shift_ones  = din_insn[30:29] == 2'b 01;
	wire shift_arith = din_insn[30:29] == 2'b 10;
	wire shift_rot   = din_insn[30:29] == 2'b 11;
	wire shift_none  = din_insn[27];

	wire shift_op_rev   = din_insn[27] && shamt[3:2] == 2'b 11;
	wire shift_op_rev8  = din_insn[27] && shamt[3:2] == 2'b 10;
	wire shift_op_orc_b = din_insn[27] && shamt[3:2] == 2'b 01;

	always @* begin
		dout_shift = din_rs1;

		if (shift_op_rev || shift_left) begin
			dout_shift = din_rev;
		end

		if (!shift_none) begin
			dout_shift = {shift_rot ? dout_shift : {32{shift_ones || (shift_arith && din_rs1[31])}}, dout_shift} >> shamt;
		end

		if (shift_op_orc_b || shift_left) begin
			dout_shift = (shift_op_orc_b ? dout_shift : 32'h 0) | ((dout_shift & 32'h 55555555) <<  1) | ((dout_shift & 32'h AAAAAAAA) >>  1);
			dout_shift = (shift_op_orc_b ? dout_shift : 32'h 0) | ((dout_shift & 32'h 33333333) <<  2) | ((dout_shift & 32'h CCCCCCCC) >>  2);
			dout_shift = (shift_op_orc_b ? dout_shift : 32'h 0) | ((dout_shift & 32'h 0F0F0F0F) <<  4) | ((dout_shift & 32'h F0F0F0F0) >>  4);
		end

		if (shift_op_rev8 || shift_left) begin
			dout_shift = ((dout_shift & 32'h 00FF00FF) <<  8) | ((dout_shift & 32'h FF00FF00) >>  8);
			dout_shift = ((dout_shift & 32'h 0000FFFF) << 16) | ((dout_shift & 32'h FFFF0000) >> 16);
		end
	end

	// ------------------------------------------------------------

	always @* begin
		dout_opneg = din_rs1 ^ ~din_rs2;
		if (din_insn[13]) dout_opneg = din_rs1 | ~din_rs2;
		if (din_insn[12]) dout_opneg = din_rs1 & ~din_rs2;
	end

	// ------------------------------------------------------------

	always @* begin
		dout_pack = {din_rs2[15:0], din_rs1[15:0]};
	end
endmodule

module rvb_zbb32_decoder (
	input [31:0] insn,
	output reg insn_bitcnt,
	output reg insn_minmax,
	output reg insn_shift,
	output reg insn_opneg,
	output reg insn_pack
);
	always @* begin
		insn_bitcnt = 0;
		insn_minmax = 0;
		insn_shift  = 0;
		insn_opneg  = 0;
		insn_pack   = 0;

		(* parallel_case *)
		casez (insn)
			32'b 0100000_zzzzz_zzzzz_111_zzzzz_0110011: insn_opneg = 1;  // ANDN
			32'b 0100000_zzzzz_zzzzz_110_zzzzz_0110011: insn_opneg = 1;  // ORN
			32'b 0100000_zzzzz_zzzzz_100_zzzzz_0110011: insn_opneg = 1;  // XNOR

			32'b 0000000_zzzzz_zzzzz_001_zzzzz_0110011: insn_shift = 1; // SLL
			32'b 0000000_zzzzz_zzzzz_101_zzzzz_0110011: insn_shift = 1; // SRL
			32'b 0100000_zzzzz_zzzzz_101_zzzzz_0110011: insn_shift = 1; // SRA
			32'b 0010000_zzzzz_zzzzz_001_zzzzz_0110011: insn_shift = 1; // SLO
			32'b 0010000_zzzzz_zzzzz_101_zzzzz_0110011: insn_shift = 1; // SRO
			32'b 0110000_zzzzz_zzzzz_001_zzzzz_0110011: insn_shift = 1; // ROL
			32'b 0110000_zzzzz_zzzzz_101_zzzzz_0110011: insn_shift = 1; // ROR

			32'b 00000_00zzzzz_zzzzz_001_zzzzz_0010011: insn_shift = 1; // SLLI
			32'b 00000_00zzzzz_zzzzz_101_zzzzz_0010011: insn_shift = 1; // SRLI
			32'b 01000_00zzzzz_zzzzz_101_zzzzz_0010011: insn_shift = 1; // SRAI
			32'b 00100_00zzzzz_zzzzz_001_zzzzz_0010011: insn_shift = 1; // SLOI
			32'b 00100_00zzzzz_zzzzz_101_zzzzz_0010011: insn_shift = 1; // SROI
			32'b 01100_00zzzzz_zzzzz_101_zzzzz_0010011: insn_shift = 1; // RORI

			32'b 01101_0011111_zzzzz_101_zzzzz_0010011: insn_shift = 1; // REV
			32'b 01101_0011000_zzzzz_101_zzzzz_0010011: insn_shift = 1; // REV8
			32'b 00101_0000111_zzzzz_101_zzzzz_0010011: insn_shift = 1; // ORC.B

			32'b 0110000_00000_zzzzz_001_zzzzz_0010011: insn_bitcnt  = 1; // CLZ
			32'b 0110000_00001_zzzzz_001_zzzzz_0010011: insn_bitcnt  = 1; // CTZ
			32'b 0110000_00010_zzzzz_001_zzzzz_0010011: insn_bitcnt  = 1; // PCNT

			32'b 0000101_zzzzz_zzzzz_100_zzzzz_0110011: insn_minmax  = 1; // MIN
			32'b 0000101_zzzzz_zzzzz_101_zzzzz_0110011: insn_minmax  = 1; // MAX
			32'b 0000101_zzzzz_zzzzz_110_zzzzz_0110011: insn_minmax  = 1; // MINU
			32'b 0000101_zzzzz_zzzzz_111_zzzzz_0110011: insn_minmax  = 1; // MAXU

			32'b 0000100_zzzzz_zzzzz_100_zzzzz_0110011: insn_pack  = 1; // PACK
		endcase
	end
endmodule
