// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

// For single-cycle SRAMs, supports RMW for byte enable
module relobi_sram_shim #(
  /// The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t ObiCfg    = obi_pkg::ObiDefaultConfig,
  /// The request struct for all ports.
  parameter type               relobi_req_t = logic,
  /// The response struct for all ports.
  parameter type               relobi_rsp_t = logic,
  parameter type               a_optional_t = logic,
  parameter type               r_optional_t = logic,
  parameter bit                EnableScrubber = 1'b0,
  parameter int unsigned       ScrubberMemWords = 256,
  parameter bit                ScrubberCorrectRead = 1'b1,
  parameter int unsigned       AddrWidth = EnableScrubber ? $clog2(ScrubberMemWords) : ObiCfg.AddrWidth
) (
  input  logic                          clk_i,
  input  logic                          rst_ni,

  input  relobi_req_t                   obi_req_i,
  output relobi_rsp_t                   obi_rsp_o,

  output logic                          req_o,
  output logic                          we_o,
  output logic [AddrWidth-1:0] addr_o,
  output logic [ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] wdata_o,

  input  logic                          gnt_i, // Should generally be 1'b1
  input  logic [ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] rdata_i,

  input  logic                          scrub_trigger_i, // Set to 1'b0 to disable
  output logic                          scrub_bit_corrected_o,
  output logic                          scrub_uncorrectable_o,
  output logic [1:0]                    fault_o
);

  if (ObiCfg.OptionalCfg.UseAtop) $error("Please use an ATOP resolver before sram shim.");
  if (ObiCfg.UseRReady) $error("Please use an RReady Fifo before sram shim.");
  if (ObiCfg.Integrity) $error("Integrity not yet supported, WIP");
  if (ObiCfg.OptionalCfg.UseProt) $warning("Prot not checked!");
  if (ObiCfg.OptionalCfg.UseMemtype) $warning("Memtype not checked!");

  logic [7:0] voter_errs;
  logic [11:0][1:0] hsiao_errs;
  logic [1:0][11:0] hsiao_errs_transpose;

  for (genvar i = 0; i < 2; i++) begin : gen_hsiao_errs_transpose
    for (genvar j = 0; j < 12; j++) begin : gen_hsiao_errs_transpose_inner
      assign hsiao_errs_transpose[i][j] = hsiao_errs[j][i];
    end
  end

  assign fault_o[0] = |voter_errs | |hsiao_errs_transpose[0];
  assign fault_o[1] = |hsiao_errs_transpose[1];


  logic [2:0] rvalid_d, rvalid_q;
  logic [2:0][ObiCfg.IdWidth-1:0] id_d, id_q, rid_voted;
  logic [relobi_pkg::relobi_r_other_ecc_width(ObiCfg)-1:0] other_ecc_d, other_ecc_q;

  logic      [ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] use_buffered;
  logic [2:0][ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] use_buffered_tmr;
  logic [2:0] req_o_tmr, req_o_scrubbed_tmr;
  logic [2:0] we, we_scrubbed;
  logic [2:0][ObiCfg.DataWidth/8-1:0] be;
  // logic [2:0][ObiCfg.IdWidth-1:0] aid;
  logic [2:0][relobi_pkg::relobi_r_other_ecc_width(ObiCfg)-1:0] other_ecc;
  logic [2:0][ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] rmw_wdata_tmr;
  logic [ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] wdata_buffer, rmw_wdata, scrub_wdata, scrub_rdata;
  logic [ObiCfg.AddrWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.AddrWidth)-1:0] addr_buffer;
  logic [2:0] r_gnt;
  logic [2:0] scrub_gnt;
  logic [2:0][ObiCfg.AddrWidth-1:0] addr_decoded;
  logic [2:0][AddrWidth-1:0] addr_decoded_trimmed;
  logic [2:0][AddrWidth-1:0] addr_scrubbed;

  TMR_voter_fail i_req_valid_vote (
    .a_i        (req_o_scrubbed_tmr[0]),
    .b_i        (req_o_scrubbed_tmr[1]),
    .c_i        (req_o_scrubbed_tmr[2]),
    .majority_o (req_o),
    .fault_detected_o(voter_errs[0])
  );

  bitwise_TMR_voter_fail #(
    .DataWidth( ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth) )
  ) i_use_buffered_vote (
    .a_i        (use_buffered_tmr[0]),
    .b_i        (use_buffered_tmr[1]),
    .c_i        (use_buffered_tmr[2]),
    .majority_o (use_buffered),
    .fault_detected_o(voter_errs[1])
  );

  for (genvar i = 0; i < ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth); i++) begin : gen_scrub_wdata
    assign scrub_wdata[i] = use_buffered[i] ? rmw_wdata[i] : obi_req_i.a.wdata[i];
  end

  always_comb begin
    obi_rsp_o         = '0;
    obi_rsp_o.gnt     = r_gnt;
    obi_rsp_o.rvalid  = rvalid_q;
    obi_rsp_o.r.rdata = scrub_rdata;
    obi_rsp_o.r.rid   = id_q;
    obi_rsp_o.r.err   = 1'b0;
    obi_rsp_o.r.other_ecc = other_ecc_q;
  end

  assign rvalid_d = obi_req_i.req & obi_rsp_o.gnt;

  if (EnableScrubber) begin : gen_scrubber
    ecc_scrubber #(
      .BankSize       (ScrubberMemWords),
      .UseExternalECC (1'b0),
      .DataWidth      (ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)),
      .ProtWidth      (hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)),
      .CorrectRead    (ScrubberCorrectRead),
      .TmrHs          (1'b1)
    ) i_scrubber (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),

      .scrub_trigger_i  (scrub_trigger_i),
      .bit_corrected_o  (scrub_bit_corrected_o),
      .uncorrectable_o  (scrub_uncorrectable_o),

      // Input signals from others accessing memory bank
      .intc_req_i   (req_o_tmr),
      .intc_gnt_o   (scrub_gnt),
      .intc_we_i    (we),
      .intc_add_i   (addr_decoded_trimmed),
      .intc_wdata_i (scrub_wdata),
      .intc_rdata_o (scrub_rdata),

      // Output directly to bank
      .bank_req_o   (req_o_scrubbed_tmr),
      .bank_gnt_i   ({3{gnt_i}}),
      .bank_we_o    (we_scrubbed),
      .bank_add_o   (addr_scrubbed),
      .bank_wdata_o (wdata_o),
      .bank_rdata_i (rdata_i),

      // If using external ECC
      .ecc_out_o (),
      .ecc_in_i  ('0),
      .ecc_err_i ('0),

      .fault_o (voter_errs[7])
    );
  end else begin : gen_no_scrubber
    assign req_o_scrubbed_tmr = req_o_tmr;
    assign scrub_gnt = {3{gnt_i}};
    assign we_scrubbed = we;
    assign addr_scrubbed = addr_decoded;
    assign wdata_o = scrub_wdata;
    assign scrub_bit_corrected_o = 1'b0;
    assign scrub_uncorrectable_o  = 1'b0;
    assign voter_errs[7] = 1'b0;
  end

  for (genvar i = 0; i < 3; i++) begin : gen_tmr_part
    relobi_sram_shim_tmr_part #(
      .ObiCfg(ObiCfg),
      .relobi_req_t(relobi_req_t),
      .relobi_rsp_t(relobi_rsp_t),
      .a_optional_t(a_optional_t),
      .r_optional_t(r_optional_t)
    ) i_tmr_part (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .req_i(obi_req_i.req[i]),
      .gnt_i(scrub_gnt[i]),
      .gnt_o(r_gnt[i]),
      .a_we_i(obi_req_i.a.we),
      .a_be_i(obi_req_i.a.be),
      // .a_aid_i(obi_req_i.a.aid),
      .rid_tmr_i (id_q),
      .a_optional_i(obi_req_i.a.a_optional),
      .a_other_ecc_i(obi_req_i.a.other_ecc),
      .wdata_rmw(wdata_buffer),
      .ldata_rmw(scrub_rdata),
      .wdata_modified(rmw_wdata_tmr[i]),
      .use_buffered(use_buffered_tmr[i]),
      .req_o(req_o_tmr[i]),
      .a_we_o(we[i]),
      .rid_o(rid_voted[i]),
      // .a_aid_o(aid[i]),
      .other_ecc_d(other_ecc[i]),
      .a_addr_i(obi_req_i.a.addr),
      .addr_buffer(addr_buffer),
      .addr_o(addr_decoded[i]),
      .hsiao_errs(hsiao_errs[4*i+:4]),
      .voter_err(voter_errs[3])
    );
    assign addr_decoded_trimmed[i] = addr_decoded[i][AddrWidth-1+$clog2(ObiCfg.AddrWidth/8):$clog2(ObiCfg.AddrWidth/8)];
  end

  TMR_voter_fail i_we_vote (
    .a_i        (we_scrubbed[0]),
    .b_i        (we_scrubbed[1]),
    .c_i        (we_scrubbed[2]),
    .majority_o (we_o),
    .fault_detected_o(voter_errs[2])
  );
  bitwise_TMR_voter_fail #(
    .DataWidth(AddrWidth)
  ) i_addr_vote (
    .a_i        (addr_scrubbed[0]),
    .b_i        (addr_scrubbed[1]),
    .c_i        (addr_scrubbed[2]),
    .majority_o (addr_o),
    .fault_detected_o(voter_errs[3])
  );
  // bitwise_TMR_voter_fail #(
  //   .DataWidth( ObiCfg.IdWidth )
  // ) i_aid_vote (
  //   .a_i        (aid[0]),
  //   .b_i        (aid[1]),
  //   .c_i        (aid[2]),
  //   .majority_o (id_d),
  //   .fault_detected_o(voter_errs[3])
  // );
  assign id_d = obi_req_i.a.aid;
  bitwise_TMR_voter_fail #(
    .DataWidth( relobi_pkg::relobi_r_other_ecc_width(ObiCfg) )
  ) i_other_ecc_vote (
    .a_i        (other_ecc[0]),
    .b_i        (other_ecc[1]),
    .c_i        (other_ecc[2]),
    .majority_o (other_ecc_d),
    .fault_detected_o(voter_errs[5])
  );
  bitwise_TMR_voter_fail #(
    .DataWidth( ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth) )
  ) i_wdata_vote (
    .a_i        (rmw_wdata_tmr[0]),
    .b_i        (rmw_wdata_tmr[1]),
    .c_i        (rmw_wdata_tmr[2]),
    .majority_o (rmw_wdata),
    .fault_detected_o(voter_errs[6])
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      rvalid_q <= 1'b0;
      id_q     <= '0;
      other_ecc_q <= '0;
    end else begin
      rvalid_q <= rvalid_d;
      id_q     <= id_d;
      other_ecc_q <= other_ecc_d;
    end
  end

    always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      wdata_buffer <= '0;
      addr_buffer <= '0;
    end else if (req_o && gnt_i) begin
      wdata_buffer <= obi_req_i.a.wdata;
      addr_buffer <= obi_req_i.a.addr;
    end
  end


endmodule

module relobi_sram_shim_tmr_part #(
  parameter obi_pkg::obi_cfg_t ObiCfg    = obi_pkg::ObiDefaultConfig,
  parameter type               relobi_req_t = logic,
  parameter type               relobi_rsp_t = logic,
  parameter type a_optional_t = logic,
  parameter type r_optional_t = logic
) (
  input logic clk_i,
  input logic rst_ni,
  input logic req_i,
  input logic gnt_i,
  output logic gnt_o,
  input logic a_we_i,
  input logic [ObiCfg.DataWidth/8-1:0] a_be_i,
  // input logic [ObiCfg.IdWidth-1:0] a_aid_i,
  input logic [2:0][ObiCfg.IdWidth-1:0] rid_tmr_i,
  input a_optional_t a_optional_i,
  input logic [relobi_pkg::relobi_a_other_ecc_width(ObiCfg)-1:0] a_other_ecc_i,
  input logic [ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] wdata_rmw,
  input logic [ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] ldata_rmw,
  output logic [ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] wdata_modified,
  output logic [ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] use_buffered,
  output logic req_o,
  output logic a_we_o,
  output logic [ObiCfg.IdWidth-1:0] rid_o,
  // output logic [ObiCfg.IdWidth-1:0] a_aid_o,
  output logic [relobi_pkg::relobi_r_other_ecc_width(ObiCfg)-1:0] other_ecc_d,
  input logic  [2:0][ObiCfg.AddrWidth-1:0] a_addr_i,
  input logic  [2:0][ObiCfg.AddrWidth-1:0] addr_buffer,
  output logic [ObiCfg.AddrWidth-1:0] addr_o,
  output logic [3:0][1:0] hsiao_errs,
  output logic voter_err
);

  typedef enum logic { NORMAL, READ_MODIFY_WRITE } store_state_e;
  store_state_e store_state_d, store_state_q;

  logic [ObiCfg.DataWidth/8-1:0] a_be_int, be_buffer;

  logic [ObiCfg.DataWidth-1:0] wdata_rmw_dec, ldata_rmw_dec;
  logic [ObiCfg.DataWidth-1:0] be_selector;
  logic a_we_int;

  relobi_a_other_decoder #(
    .Cfg          (ObiCfg),
    .a_optional_t (a_optional_t)
  ) i_a_other_decoder (
    .we_i (a_we_i),
    .be_i (a_be_i),
    // .aid_i (a_aid_i),
    .a_optional_i (a_optional_i),
    .other_ecc_i (a_other_ecc_i),
    .we_o (a_we_int),
    .be_o (a_be_int),
    // .aid_o (a_aid_o),
    .a_optional_o (),
    .fault_o (hsiao_errs[0])
  );

  relobi_r_other_encoder #(
    .Cfg(ObiCfg),
    .r_optional_t(r_optional_t)
  ) i_r_other_enc (
    // .rid_i(a_aid_o),
    .err_i(1'b0),
    .r_optional_i('0),
    .other_ecc_o (other_ecc_d)
  );

  for (genvar i = 0; i < ObiCfg.DataWidth/8; i++) begin : gen_be_selector
    assign be_selector[i*8 +: 8] = {8{be_buffer[i]}};
  end

  hsiao_ecc_dec #(
    .DataWidth ( ObiCfg.DataWidth )
  ) i_wdata_dec (
    .in        ( wdata_rmw ),
    .out       ( wdata_rmw_dec ),
    .syndrome_o(),
    .err_o     (hsiao_errs[1])
  );
  hsiao_ecc_dec #(
    .DataWidth ( ObiCfg.DataWidth )
  ) i_rdata_dec (
    .in        ( ldata_rmw ),
    .out       ( ldata_rmw_dec ),
    .syndrome_o(),
    .err_o     (hsiao_errs[2])
  );
  hsiao_ecc_enc #(
    .DataWidth ( ObiCfg.DataWidth )
  ) i_wdata_enc (
    .in        ( be_selector & wdata_rmw_dec |
                  (~be_selector & ldata_rmw_dec) ),
    .out       ( wdata_modified )
  );

  // hsiao_ecc_dec #(
  //   .DataWidth ( ObiCfg.AddrWidth )
  // ) i_addr_dec (
  //   .in        ( use_buffered[0] ? addr_buffer : a_addr_i ),
  //   .out       ( addr_o     ),
  //   .syndrome_o(),
  //   .err_o     (hsiao_errs[3])
  // );


  bitwise_TMR_voter_fail #(
    .DataWidth( ObiCfg.IdWidth )
  ) i_rid_vote (
    .a_i        (rid_tmr_i[0]),
    .b_i        (rid_tmr_i[1]),
    .c_i        (rid_tmr_i[2]),
    .majority_o (rid_o),
    .fault_detected_o(voter_err)
  );

  always_comb begin
    req_o = req_i;
    gnt_o = gnt_i;
    store_state_d = NORMAL;
    use_buffered = {ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth){1'b0}};
    a_we_o = a_we_int;
    if (store_state_q == NORMAL) begin
      if (req_i & (a_be_int != {ObiCfg.DataWidth/8{1'b1}}) & a_we_int) begin
        store_state_d = READ_MODIFY_WRITE;
        a_we_o = 1'b0;
      end
    end else begin
      req_o = 1'b1;
      gnt_o = 1'b0;
      a_we_o = 1'b1;
      use_buffered = {ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth){1'b1}};
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      store_state_q <= NORMAL;
      be_buffer <= '0;
    end else if (req_o && gnt_i) begin
      store_state_q <= store_state_d; // Quick to reload and dependents always voted
      be_buffer <= a_be_i; // Quick to reload and always voted with wdata
    end
  end


endmodule
