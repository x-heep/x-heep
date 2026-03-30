// Copyright (c) 2025 Eclipse Foundation
// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Instruction Fetch Stage
 *
 * Instruction fetch unit: Selection of the next PC, and buffering (sampling) of
 * the read instruction.
 */

`include "prim_assert.sv"

module cve2_if_stage import cve2_pkg::*; (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic [31:0]                  boot_addr_i,              // also used for mtvec
  input  logic                         req_i,                    // instruction request control

  // instruction cache interface
  output logic                        instr_req_o,
  output logic [31:0]                 instr_addr_o,
  input  logic                        instr_gnt_i,
  input  logic                        instr_rvalid_i,
  input  logic [31:0]                 instr_rdata_i,
  input  logic                        instr_err_i,

  // output of ID stage
  output logic                        instr_valid_id_o,         // instr in IF-ID is valid
  output logic                        instr_new_id_o,           // instr in IF-ID is new
  output logic [31:0]                 instr_rdata_id_o,         // instr for ID stage
  output logic [31:0]                 instr_rdata_alu_id_o,     // replicated instr for ID stage
                                                                // to reduce fan-out
  output logic [15:0]                 instr_rdata_c_id_o,       // compressed instr for ID stage
                                                                // (mtval), meaningful only if
                                                                // instr_is_compressed_id_o = 1'b1
  output logic                        instr_is_compressed_id_o, // compressed decoder thinks this
                                                                // is a compressed instr
  output logic                        instr_fetch_err_o,        // bus error on fetch
  output logic                        instr_fetch_err_plus2_o,  // bus error misaligned
  output logic                        illegal_c_insn_id_o,      // compressed decoder thinks this
                                                                // is an invalid instr
  output logic [31:0]                 pc_if_o,
  output logic [31:0]                 pc_id_o,
  input  logic                        pmp_err_if_i,
  input  logic                        pmp_err_if_plus2_i,

  // control signals
  input  logic                        instr_valid_clear_i,      // clear instr valid bit in IF-ID
  input  logic                        pc_set_i,                 // set the PC to a new value
  input  pc_sel_e                     pc_mux_i,                 // selector for PC multiplexer
  input  exc_pc_sel_e                 exc_pc_mux_i,             // selects ISR address
  input  exc_cause_e                  exc_cause,                // selects ISR address for
                                                                // vectorized interrupt lines
  // jump and branch target
  input  logic [31:0]                 branch_target_ex_i,       // branch/jump target address

  // CSRs
  input  logic [31:0]                 csr_mepc_i,               // PC to restore after handling
                                                                // the interrupt/exception
  input  logic [31:0]                 csr_depc_i,               // PC to restore after handling
                                                                // the debug request
  input  logic [31:0]                 csr_mtvec_i,              // base PC to jump to on exception
  output logic                        csr_mtvec_init_o,         // tell CS regfile to init mtvec

  // debug signals
  input logic [31:0]                  dm_halt_addr_i,           // default 32'h1A110800
  input logic [31:0]                  dm_exception_addr_i,      // default 32'h1A110808

  // pipeline stall
  input  logic                        id_in_ready_i,            // ID stage is ready for new instr

  // misc signals
  output logic                        if_busy_o                 // IF stage is busy fetching instr
);

  logic              instr_valid_id_d, instr_valid_id_q;
  logic              instr_new_id_d, instr_new_id_q;

  // prefetch buffer related signals
  logic              prefetch_busy;
  logic              branch_req;
  logic       [31:0] fetch_addr_n;
  logic              unused_fetch_addr_n0;

  logic              fetch_valid;
  logic              fetch_ready;
  logic       [31:0] fetch_rdata;
  logic       [31:0] fetch_addr;
  logic              fetch_err;
  logic              fetch_err_plus2;

  logic [31:0]       instr_decompressed;
  logic              illegal_c_insn;
  logic              instr_is_compressed;

  logic              if_instr_pmp_err;
  logic              if_instr_err;
  logic              if_instr_err_plus2;

  logic       [31:0] exc_pc;

  logic        [6:0] irq_id;
  logic              unused_irq_bit;

  logic              if_id_pipe_reg_we; // IF-ID pipeline reg write enable

  cve2_pkg::pc_sel_e pc_mux_internal;

  logic        [1:0] unused_boot_addr;
  logic        [7:0] unused_csr_mtvec;

  assign unused_boot_addr = boot_addr_i[1:0];
  assign unused_csr_mtvec = csr_mtvec_i[7:0];

  // extract interrupt ID from exception cause
  assign irq_id         = {exc_cause};
  assign unused_irq_bit = irq_id[6];   // MSB distinguishes interrupts from exceptions

  // exception PC selection mux
  always_comb begin : exc_pc_mux
    unique case (exc_pc_mux_i)
      EXC_PC_EXC:     exc_pc = { csr_mtvec_i[31:8], 8'h00              };
      EXC_PC_IRQ:     exc_pc = { csr_mtvec_i[31:8], irq_id[5:0], 2'b00 };
      EXC_PC_DBD:     exc_pc = dm_halt_addr_i;
      EXC_PC_DBG_EXC: exc_pc = dm_exception_addr_i;
      default:        exc_pc = { csr_mtvec_i[31:8], 8'h00              };
    endcase
  end

  assign pc_mux_internal =
    pc_mux_i;

  // fetch address selection mux
  always_comb begin : fetch_addr_mux
    unique case (pc_mux_internal)
      PC_BOOT: fetch_addr_n = { boot_addr_i[31:2], 2'b00 };
      PC_JUMP: fetch_addr_n = branch_target_ex_i;
      PC_EXC:  fetch_addr_n = exc_pc;                       // set PC to exception handler
      PC_ERET: fetch_addr_n = csr_mepc_i;                   // restore PC when returning from EXC
      PC_DRET: fetch_addr_n = csr_depc_i;
      default: fetch_addr_n = { boot_addr_i[31:2], 2'b00 };
    endcase
  end

  // tell CS register file to initialize mtvec on boot
  assign csr_mtvec_init_o = (pc_mux_i == PC_BOOT) & pc_set_i;

  // prefetch buffer, caches a fixed number of instructions
  cve2_prefetch_buffer #(
  ) prefetch_buffer_i (
      .clk_i               ( clk_i                      ),
      .rst_ni              ( rst_ni                     ),

      .req_i               ( req_i                      ),

      .branch_i            ( branch_req                 ),
      .addr_i              ( {fetch_addr_n[31:1], 1'b0} ),

      .ready_i             ( fetch_ready                ),
      .valid_o             ( fetch_valid                ),
      .rdata_o             ( fetch_rdata                ),
      .addr_o              ( fetch_addr                 ),
      .err_o               ( fetch_err                  ),
      .err_plus2_o         ( fetch_err_plus2            ),

      .instr_req_o         ( instr_req_o                ),
      .instr_addr_o        ( instr_addr_o               ),
      .instr_gnt_i         ( instr_gnt_i                ),
      .instr_rvalid_i      ( instr_rvalid_i             ),
      .instr_rdata_i       ( instr_rdata_i              ),
      .instr_err_i         ( instr_err_i                ),

      .busy_o              ( prefetch_busy              )
  );

  `ifndef SYNTHESIS
    // (As instroduced on the Ibex core project)
    // Needed by the RISC-V compliance checking simulation model for linking 
    // against C++ testbench code, that expects the simutil_get_scramble_key 
    // or simutil_get_scramble_nonce functions.
    // As a slightly ugly hack, let's define the DPI functions here (the 
    // real versions are defined in prim_util_get_scramble_params.svh)
    export "DPI-C" function simutil_get_scramble_key;
    export "DPI-C" function simutil_get_scramble_nonce;
    function automatic int simutil_get_scramble_key(output bit [127:0] val);
      return 0;
    endfunction
    function automatic int simutil_get_scramble_nonce(output bit [319:0] nonce);
      return 0;
    endfunction
  `endif

  assign unused_fetch_addr_n0 = fetch_addr_n[0];

  assign branch_req  = pc_set_i;

  assign pc_if_o     = fetch_addr;
  assign if_busy_o   = prefetch_busy;

  // PMP errors
  // An error can come from the instruction address, or the next instruction address for unaligned,
  // uncompressed instructions.
  assign if_instr_pmp_err = pmp_err_if_i |
                            (fetch_addr[2] & ~instr_is_compressed & pmp_err_if_plus2_i);

  // Combine bus errors and pmp errors
  assign if_instr_err = fetch_err | if_instr_pmp_err;

  // Capture the second half of the address for errors on the second part of an instruction
  assign if_instr_err_plus2 = ((fetch_addr[2] & ~instr_is_compressed & pmp_err_if_plus2_i) |
                               fetch_err_plus2) & ~pmp_err_if_i;

  // compressed instruction decoding, or more precisely compressed instruction
  // expander
  //
  // since it does not matter where we decompress instructions, we do it here
  // to ease timing closure
  cve2_compressed_decoder compressed_decoder_i (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .valid_i        (fetch_valid & ~fetch_err),
    .instr_i        (fetch_rdata),
    .instr_o        (instr_decompressed),
    .is_compressed_o(instr_is_compressed),
    .illegal_instr_o(illegal_c_insn)
  );

  // The ID stage becomes valid as soon as any instruction is registered in the ID stage flops.
  // Note that the current instruction is squashed by the incoming pc_set_i signal.
  // Valid is held until it is explicitly cleared (due to an instruction completing or an exception)
  assign instr_valid_id_d = (fetch_valid & id_in_ready_i & ~pc_set_i) |
                            (instr_valid_id_q & ~instr_valid_clear_i);
  assign instr_new_id_d   = fetch_valid & id_in_ready_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      instr_valid_id_q <= 1'b0;
      instr_new_id_q   <= 1'b0;
    end else begin
      instr_valid_id_q <= instr_valid_id_d;
      instr_new_id_q   <= instr_new_id_d;
    end
  end

  assign instr_valid_id_o = instr_valid_id_q;
  // Signal when a new instruction enters the ID stage (only used for RVFI signalling).
  assign instr_new_id_o   = instr_new_id_q;

  // IF-ID pipeline registers, frozen when the ID stage is stalled
  assign if_id_pipe_reg_we = instr_new_id_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      instr_rdata_id_o         <= '0;
      instr_rdata_alu_id_o     <= '0;
      instr_fetch_err_o        <= '0;
      instr_fetch_err_plus2_o  <= '0;
      instr_rdata_c_id_o       <= '0;
      instr_is_compressed_id_o <= '0;
      illegal_c_insn_id_o      <= '0;
      pc_id_o                  <= '0;
    end else if (if_id_pipe_reg_we) begin
      instr_rdata_id_o         <= instr_decompressed;
      // To reduce fan-out and help timing from the instr_rdata_id flops they are replicated.
      instr_rdata_alu_id_o     <= instr_decompressed;
      instr_fetch_err_o        <= if_instr_err;
      instr_fetch_err_plus2_o  <= if_instr_err_plus2;
      instr_rdata_c_id_o       <= fetch_rdata[15:0]; //if_instr_rdata[15:0];
      instr_is_compressed_id_o <= instr_is_compressed;
      illegal_c_insn_id_o      <= illegal_c_insn;
      pc_id_o                  <= pc_if_o;
    end
  end

  assign fetch_ready = id_in_ready_i;

  ////////////////
  // Assertions //
  ////////////////

  // Selectors must be known/valid.
  `ASSERT_KNOWN(CVE2ExcPcMuxKnown, exc_pc_mux_i)

  // Boot address must be aligned to 4 bytes.
  `ASSERT(CVE2BootAddrUnaligned, boot_addr_i[1:0] == 2'b00)

  // Address must not contain X when request is sent.
  `ASSERT(CVE2InstrAddrUnknown, instr_req_o |-> !$isunknown(instr_addr_o))

  // Address must be word aligned when request is sent.
  `ASSERT(CVE2InstrAddrUnaligned, instr_req_o |-> (instr_addr_o[1:0] == 2'b00))

endmodule
