// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

/// An encoder for reliable OBI
module relobi_decoder import hsiao_ecc_pkg::*; #(
  /// Configuration of the bus
  parameter obi_pkg::obi_cfg_t Cfg = obi_pkg::ObiDefaultConfig,

  parameter type relobi_req_t      = logic,
  parameter type relobi_rsp_t      = logic,
  parameter type obi_req_t         = logic,
  parameter type obi_rsp_t         = logic,
  parameter type a_optional_t      = logic,
  parameter type r_optional_t      = logic
) (
  input  relobi_req_t rel_req_i,
  output relobi_rsp_t rel_rsp_o,

  output obi_req_t    req_o,
  input  obi_rsp_t    rsp_i,

  output logic [1:0]  fault_o
);

  logic [3:0] voter_errs;
  logic [1:0][1:0] hsiao_errs;
  logic [1:0][1:0] hsiao_errs_gated;
  logic [1:0][1:0] hsiao_errs_transpose;

  for (genvar i = 0; i < 2; i++) begin : gen_hsiao_errs_transpose
    for (genvar j = 0; j < 2; j++) begin : gen_hsiao_errs_transpose_inner
      assign hsiao_errs_transpose[i][j] = hsiao_errs_gated[j][i];
    end
  end

  assign fault_o[0] = |voter_errs | |hsiao_errs_transpose[0];
  assign fault_o[1] = |hsiao_errs_transpose[1];

  TMR_voter_fail i_req_valid_vote (
    .a_i        (rel_req_i.req[0]),
    .b_i        (rel_req_i.req[1]),
    .c_i        (rel_req_i.req[2]),
    .majority_o (req_o.req),
    .fault_detected_o(voter_errs[0])
  );

  assign rel_rsp_o.gnt = {3{rsp_i.gnt}};

  if (Cfg.UseRReady) begin : gen_rready_vote
    TMR_voter_fail i_rsp_ready_vote (
      .a_i        (rel_req_i.rready[0]),
      .b_i        (rel_req_i.rready[1]),
      .c_i        (rel_req_i.rready[2]),
      .majority_o (req_o.rready),
      .fault_detected_o(voter_errs[1])
    );
  end else begin : gen_no_rready
    assign voter_errs[1] = '0;
  end

  assign rel_rsp_o.rvalid = {3{rsp_i.rvalid}};

  // hsiao_ecc_dec #(
  //   .DataWidth ( Cfg.AddrWidth )
  // ) i_addr_dec (
  //   .in        ( rel_req_i.a.addr ),
  //   .out       ( req_o.a.addr     ),
  //   .syndrome_o(),
  //   .err_o     (hsiao_errs[0])
  // );
  // assign hsiao_errs_gated[0] = rel_req_i.req[0] ? hsiao_errs[0] : '0;
  bitwise_TMR_voter_fail i_addr_vote (
    .a_i        (rel_req_i.a.addr[0]),
    .b_i        (rel_req_i.a.addr[1]),
    .c_i        (rel_req_i.a.addr[2]),
    .majority_o (req_o.a.addr),
    .fault_detected_o(voter_errs[2])
  );

  hsiao_ecc_dec #(
    .DataWidth ( Cfg.DataWidth )
  ) i_wdata_dec (
    .in        ( rel_req_i.a.wdata ),
    .out       ( req_o.a.wdata     ),
    .syndrome_o(),
    .err_o     (hsiao_errs[0])
  );
  assign hsiao_errs_gated[0] = rel_req_i.req[0] ? hsiao_errs[0] : '0;

  bitwise_TMR_voter_fail #(
    .DataWidth (Cfg.IdWidth)
  ) i_aid_vote (
    .a_i        (rel_req_i.a.aid[0]),
    .b_i        (rel_req_i.a.aid[1]),
    .c_i        (rel_req_i.a.aid[2]),
    .majority_o (req_o.a.aid),
    .fault_detected_o(voter_errs[3])
  );

  relobi_a_other_decoder #(
    .Cfg          (Cfg),
    .a_optional_t (a_optional_t)
  ) i_a_remaining_dec (
    .we_i        (rel_req_i.a.we),
    .be_i        (rel_req_i.a.be),
    // .aid_i       (rel_req_i.a.aid),
    .a_optional_i(rel_req_i.a.a_optional),
    .other_ecc_i (rel_req_i.a.other_ecc),
    .we_o        (req_o.a.we),
    .be_o        (req_o.a.be),
    // .aid_o       (req_o.a.aid),
    .a_optional_o(req_o.a.a_optional),
    .fault_o     (hsiao_errs[1])
  );
  assign hsiao_errs_gated[1] = rel_req_i.req[0] ? hsiao_errs[1] : '0;

  hsiao_ecc_enc #(
    .DataWidth ( Cfg.DataWidth )
  ) i_rdata_enc (
    .in ( rsp_i.r.rdata ),
    .out( rel_rsp_o.r.rdata )
  );

  relobi_r_other_encoder #(
    .Cfg          (Cfg),
    .r_optional_t (r_optional_t)
  ) i_r_remaining_enc (
    // .rid_i       (rsp_i.r.rid),
    .err_i       (rsp_i.r.err),
    .r_optional_i(rsp_i.r.r_optional),
    .other_ecc_o (rel_rsp_o.r.other_ecc)
  );
  assign rel_rsp_o.r.rid[0]       = rsp_i.r.rid;
  assign rel_rsp_o.r.rid[1]       = rsp_i.r.rid;
  assign rel_rsp_o.r.rid[2]       = rsp_i.r.rid;
  assign rel_rsp_o.r.err       = rsp_i.r.err;
  assign rel_rsp_o.r.r_optional = rsp_i.r.r_optional;

endmodule
