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

module rvb_full #(
	parameter integer XLEN = 64
) (
	// control signals
	input             clock,          // positive edge clock
	input             reset,          // synchronous reset

	// data input
	input             din_valid,      // input is valid
	output            din_ready,      // core accepts input
	output            din_decoded,    // core can decode insn
	input  [XLEN-1:0] din_rs1,        // value of 1st argument
	input  [XLEN-1:0] din_rs2,        // value of 2nd argument
	input  [XLEN-1:0] din_rs3,        // value of 3rd argument
	input      [31:0] din_insn,       // value of instruction word

	// data output
	output            dout_valid,     // output is valid
	input             dout_ready,     // accept output
	output [XLEN-1:0] dout_rd         // output value

`ifdef RVB_DEBUG
,	output [XLEN-1:0] debug_rs2,
	output            debug_insn_bextdep,
	output            debug_insn_bitcnt,
	output            debug_insn_bmatxor,
	output            debug_insn_clmul,
	output            debug_insn_crc,
	output            debug_insn_shifter,
	output            debug_insn_simple
`endif
);
	wire insn_bextdep;
	wire insn_bitcnt;
	wire insn_bmatxor;
	wire insn_clmul;
	wire insn_crc;
	wire insn_shifter;
	wire insn_simple;

	wire [XLEN-1:0] imm = $signed(din_insn[31:20]);
	wire [XLEN-1:0] rs2 = din_insn[5] ? din_rs2 : imm;

`ifdef RVB_DEBUG
	assign debug_rs2 = rs2;
	assign debug_insn_bextdep = insn_bextdep;
	assign debug_insn_bitcnt  = insn_bitcnt;
	assign debug_insn_bmatxor = insn_bmatxor;
	assign debug_insn_clmul   = insn_clmul;
	assign debug_insn_crc     = insn_crc;
	assign debug_insn_shifter = insn_shifter;
	assign debug_insn_simple  = insn_simple;
`endif

	rvb_full_decoder #(.XLEN(XLEN)) decoder (
		.insn        (din_insn    ),
		.insn_bextdep(insn_bextdep),
		.insn_bitcnt (insn_bitcnt ),
		.insn_bmatxor(insn_bmatxor),
		.insn_clmul  (insn_clmul  ),
		.insn_crc    (insn_crc    ),
		.insn_shifter(insn_shifter),
		.insn_simple (insn_simple )
	);

	wire stall;
	assign din_decoded = insn_bextdep || insn_bitcnt || insn_bmatxor || insn_clmul || insn_crc || insn_shifter || insn_simple;
	assign din_ready = !reset && !stall && din_decoded;


	// ---- Input Stage ----

	reg in_bextdep;
	reg in_bitcnt;
	reg in_bmatxor;
	reg in_clmul;
	reg in_crc;
	reg in_shifter;
	reg in_simple;

	wire in_bextdep_ready;
	wire in_bitcnt_ready;
	wire in_bmatxor_ready;
	wire in_clmul_ready;
	wire in_crc_ready;
	wire in_shifter_ready;
	wire in_simple_ready;

	reg [XLEN-1:0] in_rs1, in_rs2, in_rs3;
	reg [31:0] in_insn;

	always @(posedge clock) begin
		if (in_bextdep_ready) in_bextdep <= 0;
		if (in_bitcnt_ready ) in_bitcnt  <= 0;
		if (in_bmatxor_ready) in_bmatxor <= 0;
		if (in_clmul_ready  ) in_clmul   <= 0;
		if (in_crc_ready    ) in_crc     <= 0;
		if (in_shifter_ready) in_shifter <= 0;
		if (in_simple_ready ) in_simple  <= 0;

		if (din_ready && din_valid) begin
			in_bextdep <= insn_bextdep;
			in_bitcnt  <= insn_bitcnt;
			in_bmatxor <= insn_bmatxor;
			in_clmul   <= insn_clmul;
			in_crc     <= insn_crc;
			in_shifter <= insn_shifter;
			in_simple  <= insn_simple;
			in_rs1     <= din_rs1;
			in_rs2     <= rs2;
			in_rs3     <= din_rs3;
			in_insn    <= din_insn;
		end

		if (reset) begin
			in_bextdep <= 0;
			in_bitcnt  <= 0;
			in_bmatxor <= 0;
			in_clmul   <= 0;
			in_crc     <= 0;
			in_shifter <= 0;
			in_simple  <= 0;
		end
	end


	// ---- Process Stage ----

	wire [XLEN-1:0] out_bextdep;
	wire [XLEN-1:0] out_bitcnt;
	wire [XLEN-1:0] out_bmatxor;
	wire [XLEN-1:0] out_clmul;
	wire [XLEN-1:0] out_crc;
	wire [XLEN-1:0] out_shifter;
	wire [XLEN-1:0] out_simple;

	wire out_bextdep_valid;
	wire out_bitcnt_valid;
	wire out_bmatxor_valid;
	wire out_clmul_valid;
	wire out_crc_valid;
	wire out_shifter_valid;
	wire out_simple_valid;
	wire out_ready;

	rvb_bextdep #(
		.XLEN(XLEN),
		.GREV(1),
		.SHFL(1),
		.FFS(0)
	) rvb_bextdep (
		.clock      (clock      ),
		.reset      (reset      ),
		.din_valid  (in_bextdep ),
		.din_ready  (in_bextdep_ready),
		.din_rs1    (in_rs1     ),
		.din_rs2    (in_rs2     ),
		.din_insn3  (in_insn[3] ),
		.din_insn13 (in_insn[13]),
		.din_insn14 (in_insn[14]),
		.din_insn29 (in_insn[29]),
		.din_insn30 (in_insn[30]),
		.dout_valid (out_bextdep_valid),
		.dout_ready (out_ready  ),
		.dout_rd    (out_bextdep)
	);

	rvb_bitcnt #(
		.XLEN(XLEN),
		.BMAT(1)
	) rvb_bitcnt (
		.clock      (clock      ),
		.reset      (reset      ),
		.din_valid  (in_bitcnt  ),
		.din_ready  (in_bitcnt_ready),
		.din_rs1    (in_rs1     ),
		.din_insn3  (in_insn[3] ),
		.din_insn20 (in_insn[20]),
		.din_insn21 (in_insn[21]),
		.din_insn22 (in_insn[22]),
		.dout_valid (out_bitcnt_valid),
		.dout_ready (out_ready  ),
		.dout_rd    (out_bitcnt )
	);

	generate if (XLEN == 64) begin
		rvb_bmatxor #(
			.CYCLES(0)
		) rvb_bmatxor (
			.clock      (clock      ),
			.reset      (reset      ),
			.din_valid  (in_bmatxor ),
			.din_ready  (in_bmatxor_ready),
			.din_rs1    (in_rs1     ),
			.din_rs2    (in_rs2     ),
			.din_insn30 (in_insn[30]),
			.dout_valid (out_bmatxor_valid),
			.dout_ready (out_ready  ),
			.dout_rd    (out_bmatxor)
		);
	end else begin
		assign out_bmatxor = 0;
		assign out_bmatxor_valid = 0;
		assign in_bmatxor_ready = 1;
	end endgenerate

	rvb_clmul #(
		.XLEN(XLEN)
	) rvb_clmul (
		.clock      (clock      ),
		.reset      (reset      ),
		.din_valid  (in_clmul   ),
		.din_ready  (in_clmul_ready),
		.din_rs1    (in_rs1     ),
		.din_rs2    (in_rs2     ),
		.din_insn3  (in_insn[3] ),
		.din_insn12 (in_insn[12]),
		.din_insn13 (in_insn[13]),
		.dout_valid (out_clmul_valid),
		.dout_ready (out_ready  ),
		.dout_rd    (out_clmul  )
	);

	rvb_crc #(
		.XLEN(XLEN)
	) rvb_crc (
		.clock      (clock      ),
		.reset      (reset      ),
		.din_valid  (in_crc     ),
		.din_ready  (in_crc_ready),
		.din_rs1    (in_rs1     ),
		.din_insn20 (in_insn[20]),
		.din_insn21 (in_insn[21]),
		.din_insn23 (in_insn[23]),
		.dout_valid (out_crc_valid),
		.dout_ready (out_ready  ),
		.dout_rd    (out_crc    )
	);

	rvb_shifter #(
		.XLEN(XLEN),
		.SBOP(1),
		.BFP(1)
	) rvb_shifter (
		.clock      (clock      ),
		.reset      (reset      ),
		.din_valid  (in_shifter ),
		.din_ready  (in_shifter_ready),
		.din_rs1    (in_rs1     ),
		.din_rs2    (in_rs2     ),
		.din_rs3    (in_rs3     ),
		.din_insn3  (in_insn[3] ),
		.din_insn13 (in_insn[13]),
		.din_insn14 (in_insn[14]),
		.din_insn26 (in_insn[26]),
		.din_insn27 (in_insn[27]),
		.din_insn29 (in_insn[29]),
		.din_insn30 (in_insn[30]),
		.dout_valid (out_shifter_valid),
		.dout_ready (out_ready  ),
		.dout_rd    (out_shifter)
	);

	rvb_simple #(
		.XLEN(XLEN)
	) rvb_simple (
		.clock      (clock      ),
		.reset      (reset      ),
		.din_valid  (in_simple  ),
		.din_ready  (in_simple_ready),
		.din_rs1    (in_rs1     ),
		.din_rs2    (in_rs2     ),
		.din_rs3    (in_rs3     ),
		.din_insn3  (in_insn[3] ),
		.din_insn5  (in_insn[5] ),
		.din_insn12 (in_insn[12]),
		.din_insn13 (in_insn[13]),
		.din_insn14 (in_insn[14]),
		.din_insn25 (in_insn[25]),
		.din_insn26 (in_insn[26]),
		.din_insn27 (in_insn[27]),
		.din_insn30 (in_insn[30]),
		.dout_valid (out_simple_valid),
		.dout_ready (out_ready  ),
		.dout_rd    (out_simple )
	);


	// ---- Output Stage ----

	reg output_valid;
	reg [XLEN-1:0] output_value;

	assign out_ready = !dout_valid || dout_ready;

	always @(posedge clock) begin
		if (dout_valid && dout_ready) begin
			output_valid <= 0;
		end
		if (out_ready) begin
			(* parallel_case *)
			case (1'b1)
				out_bextdep_valid: begin output_valid <= 1; output_value <= out_bextdep; end
				out_bitcnt_valid:  begin output_valid <= 1; output_value <= out_bitcnt;  end
				out_bmatxor_valid: begin output_valid <= 1; output_value <= out_bmatxor; end
				out_clmul_valid:   begin output_valid <= 1; output_value <= out_clmul;   end
				out_crc_valid:     begin output_valid <= 1; output_value <= out_crc;     end
				out_shifter_valid: begin output_valid <= 1; output_value <= out_shifter; end
				out_simple_valid:  begin output_valid <= 1; output_value <= out_simple;  end
			endcase
		end
		if (reset) begin
			output_valid <= 0;
		end
	end

	assign dout_valid = !reset && output_valid;
	assign dout_rd = output_value;


	// ---- Arbiter ----

	reg busy, busy_reg;
	wire out_any_valid = out_bextdep_valid || out_bitcnt_valid || out_bmatxor_valid || out_clmul_valid || out_crc_valid || out_shifter_valid || out_simple_valid;
	assign stall = busy;

	always @* begin
		busy = busy_reg;
		if (in_bextdep) busy = 1;
		if (in_bitcnt ) busy = 1;
		if (in_bmatxor) busy = 1;
		if (in_clmul  ) busy = 1;
		if (in_crc    ) busy = 1;
		if (in_shifter) busy = 1;
		if (in_simple ) busy = 1;
		if (out_ready && out_any_valid) busy = 0;
		if (reset) busy = 0;
	end

	always @(posedge clock) begin
		busy_reg <= busy;
	end
endmodule

module rvb_full_decoder #(
	parameter integer XLEN = 64
) (
	input [31:0] insn,
	output reg insn_bextdep,
	output reg insn_bitcnt,
	output reg insn_bmatxor,
	output reg insn_clmul,
	output reg insn_crc,
	output reg insn_shifter,
	output reg insn_simple
);
	always @* begin
		insn_bextdep = 0;
		insn_bitcnt  = 0;
		insn_bmatxor = 0;
		insn_clmul   = 0;
		insn_crc     = 0;
		insn_shifter = 0;
		insn_simple  = 0;

		(* parallel_case *)
		casez ({insn, XLEN == 64})
			33'b 0100000_zzzzz_zzzzz_111_zzzzz_0110011_z: insn_simple = 1;  // ANDN
			33'b 0100000_zzzzz_zzzzz_110_zzzzz_0110011_z: insn_simple = 1;  // ORN
			33'b 0100000_zzzzz_zzzzz_100_zzzzz_0110011_z: insn_simple = 1;  // XNOR

			33'b 0010000_zzzzz_zzzzz_010_zzzzz_0110011_z: insn_simple = 1;  // SH1ADD
			33'b 0010000_zzzzz_zzzzz_100_zzzzz_0110011_z: insn_simple = 1;  // SH2ADD
			33'b 0010000_zzzzz_zzzzz_110_zzzzz_0110011_z: insn_simple = 1;  // SH3ADD

			33'b 0000000_zzzzz_zzzzz_001_zzzzz_0110011_z: insn_shifter = 1; // SLL
			33'b 0000000_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_shifter = 1; // SRL
			33'b 0100000_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_shifter = 1; // SRA
			33'b 0010000_zzzzz_zzzzz_001_zzzzz_0110011_z: insn_shifter = 1; // SLO
			33'b 0010000_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_shifter = 1; // SRO
			33'b 0110000_zzzzz_zzzzz_001_zzzzz_0110011_z: insn_shifter = 1; // ROL
			33'b 0110000_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_shifter = 1; // ROR

			33'b 0100100_zzzzz_zzzzz_001_zzzzz_0110011_z: insn_shifter = 1; // SBCLR
			33'b 0010100_zzzzz_zzzzz_001_zzzzz_0110011_z: insn_shifter = 1; // SBSET
			33'b 0110100_zzzzz_zzzzz_001_zzzzz_0110011_z: insn_shifter = 1; // SBINV
			33'b 0100100_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_shifter = 1; // SBEXT
			33'b 0010100_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_bextdep = 1; // GORC
			33'b 0110100_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_bextdep = 1; // GREV

			33'b 00000_00zzzzz_zzzzz_001_zzzzz_0010011_0: insn_shifter = 1; // SLLI (RV32)
			33'b 00000_00zzzzz_zzzzz_101_zzzzz_0010011_0: insn_shifter = 1; // SRLI (RV32)
			33'b 01000_00zzzzz_zzzzz_101_zzzzz_0010011_0: insn_shifter = 1; // SRAI (RV32)
			33'b 00100_00zzzzz_zzzzz_001_zzzzz_0010011_0: insn_shifter = 1; // SLOI (RV32)
			33'b 00100_00zzzzz_zzzzz_101_zzzzz_0010011_0: insn_shifter = 1; // SROI (RV32)
			33'b 01100_00zzzzz_zzzzz_101_zzzzz_0010011_0: insn_shifter = 1; // RORI (RV32)

			33'b 00000_0zzzzzz_zzzzz_001_zzzzz_0010011_1: insn_shifter = 1; // SLLI (RV64)
			33'b 00000_0zzzzzz_zzzzz_101_zzzzz_0010011_1: insn_shifter = 1; // SRLI (RV64)
			33'b 01000_0zzzzzz_zzzzz_101_zzzzz_0010011_1: insn_shifter = 1; // SRAI (RV64)
			33'b 00100_0zzzzzz_zzzzz_001_zzzzz_0010011_1: insn_shifter = 1; // SLOI (RV64)
			33'b 00100_0zzzzzz_zzzzz_101_zzzzz_0010011_1: insn_shifter = 1; // SROI (RV64)
			33'b 01100_0zzzzzz_zzzzz_101_zzzzz_0010011_1: insn_shifter = 1; // RORI (RV64)

			33'b 01001_00zzzzz_zzzzz_001_zzzzz_0010011_0: insn_shifter = 1; // SBCLRI (RV32)
			33'b 00101_00zzzzz_zzzzz_001_zzzzz_0010011_0: insn_shifter = 1; // SBSETI (RV32)
			33'b 01101_00zzzzz_zzzzz_001_zzzzz_0010011_0: insn_shifter = 1; // SBINVI (RV32)
			33'b 01001_00zzzzz_zzzzz_101_zzzzz_0010011_0: insn_shifter = 1; // SBEXTI (RV32)
			33'b 00101_00zzzzz_zzzzz_101_zzzzz_0010011_0: insn_bextdep = 1; // GORCI (RV32)
			33'b 01101_00zzzzz_zzzzz_101_zzzzz_0010011_0: insn_bextdep = 1; // GREVI (RV32)

			33'b 01001_0zzzzzz_zzzzz_001_zzzzz_0010011_1: insn_shifter = 1; // SBCLRI (RV64)
			33'b 00101_0zzzzzz_zzzzz_001_zzzzz_0010011_1: insn_shifter = 1; // SBSETI (RV64)
			33'b 01101_0zzzzzz_zzzzz_001_zzzzz_0010011_1: insn_shifter = 1; // SBINVI (RV64)
			33'b 01001_0zzzzzz_zzzzz_101_zzzzz_0010011_1: insn_shifter = 1; // SBEXTI (RV64)
			33'b 00101_0zzzzzz_zzzzz_101_zzzzz_0010011_1: insn_shifter = 1; // GORCI (RV64)
			33'b 01101_0zzzzzz_zzzzz_101_zzzzz_0010011_1: insn_shifter = 1; // GREVI (RV64)

			33'b zzzzz11_zzzzz_zzzzz_001_zzzzz_0110011_z: insn_simple  = 1; // CMIX
			33'b zzzzz11_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_simple  = 1; // CMOV
			33'b zzzzz10_zzzzz_zzzzz_001_zzzzz_0110011_z: insn_shifter = 1; // FSL
			33'b zzzzz10_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_shifter = 1; // FSR
			33'b zzzzz1_0zzzzz_zzzzz_101_zzzzz_0010011_0: insn_shifter = 1; // FSRI (RV32)
			33'b zzzzz1_zzzzzz_zzzzz_101_zzzzz_0010011_1: insn_shifter = 1; // FSRI (RV64)

			33'b 0110000_00000_zzzzz_001_zzzzz_0010011_z: insn_bitcnt  = 1; // CLZ
			33'b 0110000_00001_zzzzz_001_zzzzz_0010011_z: insn_bitcnt  = 1; // CTZ
			33'b 0110000_00010_zzzzz_001_zzzzz_0010011_z: insn_bitcnt  = 1; // PCNT
			33'b 0110000_00011_zzzzz_001_zzzzz_0010011_1: insn_bitcnt  = 1; // BMATFLIP
			33'b 0110000_00100_zzzzz_001_zzzzz_0010011_z: insn_bitcnt  = 1; // SEXT.B
			33'b 0110000_00101_zzzzz_001_zzzzz_0010011_z: insn_bitcnt  = 1; // SEXT.H

			33'b 0110000_10000_zzzzz_001_zzzzz_0010011_z: insn_crc     = 1; // CRC32.B
			33'b 0110000_10001_zzzzz_001_zzzzz_0010011_z: insn_crc     = 1; // CRC32.H
			33'b 0110000_10010_zzzzz_001_zzzzz_0010011_z: insn_crc     = 1; // CRC32.W
			33'b 0110000_10011_zzzzz_001_zzzzz_0010011_z: insn_crc     = 1; // CRC32.D
			33'b 0110000_11000_zzzzz_001_zzzzz_0010011_z: insn_crc     = 1; // CRC32C.B
			33'b 0110000_11001_zzzzz_001_zzzzz_0010011_z: insn_crc     = 1; // CRC32C.H
			33'b 0110000_11010_zzzzz_001_zzzzz_0010011_z: insn_crc     = 1; // CRC32C.W
			33'b 0110000_11011_zzzzz_001_zzzzz_0010011_z: insn_crc     = 1; // CRC32C.D

			33'b 0000101_zzzzz_zzzzz_001_zzzzz_0110011_z: insn_clmul   = 1; // CLMUL
			33'b 0000101_zzzzz_zzzzz_010_zzzzz_0110011_z: insn_clmul   = 1; // CLMULR
			33'b 0000101_zzzzz_zzzzz_011_zzzzz_0110011_z: insn_clmul   = 1; // CLMULH
			33'b 0000101_zzzzz_zzzzz_100_zzzzz_0110011_z: insn_simple  = 1; // MIN
			33'b 0000101_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_simple  = 1; // MAX
			33'b 0000101_zzzzz_zzzzz_110_zzzzz_0110011_z: insn_simple  = 1; // MINU
			33'b 0000101_zzzzz_zzzzz_111_zzzzz_0110011_z: insn_simple  = 1; // MAXU

			33'b 0000100_zzzzz_zzzzz_001_zzzzz_0110011_z: insn_bextdep = 1; // SHFL
			33'b 0000100_zzzzz_zzzzz_101_zzzzz_0110011_z: insn_bextdep = 1; // UNSHFL
			33'b 0100100_zzzzz_zzzzz_110_zzzzz_0110011_z: insn_bextdep = 1; // BDEP
			33'b 0000100_zzzzz_zzzzz_110_zzzzz_0110011_z: insn_bextdep = 1; // BEXT
			33'b 0000100_zzzzz_zzzzz_100_zzzzz_0110011_z: insn_simple  = 1; // PACK
			33'b 0100100_zzzzz_zzzzz_100_zzzzz_0110011_z: insn_simple  = 1; // PACKU
			33'b 0000100_zzzzz_zzzzz_111_zzzzz_0110011_z: insn_simple  = 1; // PACKH
			33'b 0000100_zzzzz_zzzzz_011_zzzzz_0110011_1: insn_bmatxor = 1; // BMATOR
			33'b 0100100_zzzzz_zzzzz_011_zzzzz_0110011_1: insn_bmatxor = 1; // BMATXOR
			33'b 0100100_zzzzz_zzzzz_111_zzzzz_0110011_z: insn_shifter = 1; // BFP

			33'b 000010_00zzzz_zzzzz_001_zzzzz_0010011_0: insn_bextdep = 1; // SHFLI (RV32)
			33'b 000010_00zzzz_zzzzz_101_zzzzz_0010011_0: insn_bextdep = 1; // UNSHFLI (RV32)

			33'b 000010_0zzzzz_zzzzz_001_zzzzz_0010011_1: insn_bextdep = 1; // SHFLI (RV64)
			33'b 000010_0zzzzz_zzzzz_101_zzzzz_0010011_1: insn_bextdep = 1; // UNSHFLI (RV64)

			33'b zzzzzzz_zzzzz_zzzzz_100_zzzzz_0011011_1: insn_simple  = 1; // ADDIWU
			33'b 000010_zzzzzz_zzzzz_001_zzzzz_0011011_1: insn_shifter = 1; // SLLIU.W

			33'b 0000101_zzzzz_zzzzz_000_zzzzz_0111011_1: insn_simple  = 1; // ADDWU
			33'b 0100101_zzzzz_zzzzz_000_zzzzz_0111011_1: insn_simple  = 1; // SUBWU
			33'b 0000100_zzzzz_zzzzz_000_zzzzz_0111011_1: insn_simple  = 1; // ADDUW
			33'b 0100100_zzzzz_zzzzz_000_zzzzz_0111011_1: insn_simple  = 1; // SUBUW

			33'b 0010000_zzzzz_zzzzz_010_zzzzz_0111011_1: insn_simple = 1;  // SH1ADDU.W
			33'b 0010000_zzzzz_zzzzz_100_zzzzz_0111011_1: insn_simple = 1;  // SH2ADDU.W
			33'b 0010000_zzzzz_zzzzz_110_zzzzz_0111011_1: insn_simple = 1;  // SH3ADDU.W

			33'b 0000000_zzzzz_zzzzz_001_zzzzz_0111011_1: insn_shifter = 1; // SLLW
			33'b 0000000_zzzzz_zzzzz_101_zzzzz_0111011_1: insn_shifter = 1; // SRLW
			33'b 0100000_zzzzz_zzzzz_101_zzzzz_0111011_1: insn_shifter = 1; // SRAW
			33'b 0010000_zzzzz_zzzzz_001_zzzzz_0111011_1: insn_shifter = 1; // SLOW
			33'b 0010000_zzzzz_zzzzz_101_zzzzz_0111011_1: insn_shifter = 1; // SROW
			33'b 0110000_zzzzz_zzzzz_001_zzzzz_0111011_1: insn_shifter = 1; // ROLW
			33'b 0110000_zzzzz_zzzzz_101_zzzzz_0111011_1: insn_shifter = 1; // RORW

			33'b 0100100_zzzzz_zzzzz_001_zzzzz_0111011_1: insn_shifter = 1; // SBCLRW
			33'b 0010100_zzzzz_zzzzz_001_zzzzz_0111011_1: insn_shifter = 1; // SBSETW
			33'b 0110100_zzzzz_zzzzz_001_zzzzz_0111011_1: insn_shifter = 1; // SBINVW
			33'b 0100100_zzzzz_zzzzz_101_zzzzz_0111011_1: insn_shifter = 1; // SBEXTW
			33'b 0010100_zzzzz_zzzzz_101_zzzzz_0111011_1: insn_bextdep = 1; // GORCW
			33'b 0110100_zzzzz_zzzzz_101_zzzzz_0111011_1: insn_bextdep = 1; // GREVW

			33'b 00000_00zzzzz_zzzzz_001_zzzzz_0011011_1: insn_shifter = 1; // SLLIW
			33'b 00000_00zzzzz_zzzzz_101_zzzzz_0011011_1: insn_shifter = 1; // SRLIW
			33'b 01000_00zzzzz_zzzzz_101_zzzzz_0011011_1: insn_shifter = 1; // SRAIW
			33'b 00100_00zzzzz_zzzzz_001_zzzzz_0011011_1: insn_shifter = 1; // SLOIW
			33'b 00100_00zzzzz_zzzzz_101_zzzzz_0011011_1: insn_shifter = 1; // SROIW
			33'b 01100_00zzzzz_zzzzz_101_zzzzz_0011011_1: insn_shifter = 1; // RORIW

			33'b 01001_00zzzzz_zzzzz_001_zzzzz_0011011_1: insn_shifter = 1; // SBCLRIW
			33'b 00101_00zzzzz_zzzzz_001_zzzzz_0011011_1: insn_shifter = 1; // SBSETIW
			33'b 01101_00zzzzz_zzzzz_001_zzzzz_0011011_1: insn_shifter = 1; // SBINVIW
			33'b 00101_00zzzzz_zzzzz_101_zzzzz_0011011_1: insn_bextdep = 1; // GORCIW
			33'b 01101_00zzzzz_zzzzz_101_zzzzz_0011011_1: insn_bextdep = 1; // GREVIW

			33'b zzzzz10_zzzzz_zzzzz_001_zzzzz_0111011_1: insn_shifter = 1; // FSLW
			33'b zzzzz10_zzzzz_zzzzz_101_zzzzz_0111011_1: insn_shifter = 1; // FSRW
			33'b zzzzz1_0zzzzz_zzzzz_101_zzzzz_0011011_1: insn_shifter = 1; // FSRIW

			33'b 0110000_00000_zzzzz_001_zzzzz_0011011_1: insn_bitcnt  = 1; // CLZW
			33'b 0110000_00001_zzzzz_001_zzzzz_0011011_1: insn_bitcnt  = 1; // CTZW
			33'b 0110000_00010_zzzzz_001_zzzzz_0011011_1: insn_bitcnt  = 1; // PCNTW

			33'b 0000101_zzzzz_zzzzz_001_zzzzz_0111011_1: insn_clmul   = 1; // CLMULW
			33'b 0000101_zzzzz_zzzzz_010_zzzzz_0111011_1: insn_clmul   = 1; // CLMULRW
			33'b 0000101_zzzzz_zzzzz_011_zzzzz_0111011_1: insn_clmul   = 1; // CLMULHW

			33'b 0000100_zzzzz_zzzzz_001_zzzzz_0111011_1: insn_bextdep = 1; // SHFLW
			33'b 0000100_zzzzz_zzzzz_101_zzzzz_0111011_1: insn_bextdep = 1; // UNSHFLW
			33'b 0100100_zzzzz_zzzzz_110_zzzzz_0111011_1: insn_bextdep = 1; // BDEPW
			33'b 0000100_zzzzz_zzzzz_110_zzzzz_0111011_1: insn_bextdep = 1; // BEXTW
			33'b 0000100_zzzzz_zzzzz_100_zzzzz_0111011_1: insn_simple  = 1; // PACKW
			33'b 0100100_zzzzz_zzzzz_100_zzzzz_0111011_1: insn_simple  = 1; // PACKUW
			33'b 0100100_zzzzz_zzzzz_111_zzzzz_0111011_1: insn_shifter = 1; // BFPW
		endcase
	end
endmodule
