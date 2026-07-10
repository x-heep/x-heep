// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_encoder #(
  /// Configuration of the bus
  parameter obi_pkg::obi_cfg_t Cfg = obi_pkg::ObiDefaultConfig,

  parameter type relobi_req_t      = logic,
  parameter type relobi_rsp_t      = logic,
  parameter type obi_req_t         = logic,
  parameter type obi_rsp_t         = logic,
  parameter type a_optional_t      = logic,
  parameter type r_optional_t      = logic
) (
  input  obi_req_t    req_i,
  output obi_rsp_t    rsp_o,

  output relobi_req_t rel_req_o,
  input  relobi_rsp_t rel_rsp_i,

  output logic [1:0]  fault_o
);

  logic [3:0] voter_errs;
  logic       voter_errs_red;
  logic [1:0][1:0] hsiao_errs;
  logic [3:0][1:0] hsiao_errs_gated;
  logic [1:0][1:0] hsiao_errs_transpose;
  logic [1:0]      hsiao_errs_transpose_red;

  assign voter_errs_red = |voter_errs;
  for (genvar i = 0; i < 2; i++) begin : gen_hsiao_errs_transpose
    assign hsiao_errs_transpose_red[i] = |hsiao_errs_transpose[i];
    for (genvar j = 0; j < 2; j++) begin : gen_hsiao_errs_transpose_inner
      assign hsiao_errs_transpose[i][j] = hsiao_errs_gated[j][i];
    end
  end

  assign fault_o[0] = voter_errs_red | hsiao_errs_transpose_red[0];
  assign fault_o[1] = hsiao_errs_transpose_red[1];

  assign rel_req_o.req = {3{req_i.req}};

  TMR_voter_fail i_req_gnt_vote (
    .a_i        (rel_rsp_i.gnt[0]),
    .b_i        (rel_rsp_i.gnt[1]),
    .c_i        (rel_rsp_i.gnt[2]),
    .majority_o (rsp_o.gnt),
    .fault_detected_o(voter_errs[0])
  );

  if (Cfg.UseRReady) begin : gen_rready_multiply
    assign rel_req_o.rready = {3{req_i.rready}};
  end

  TMR_voter_fail i_rsp_valid_vote (
    .a_i        (rel_rsp_i.rvalid[0]),
    .b_i        (rel_rsp_i.rvalid[1]),
    .c_i        (rel_rsp_i.rvalid[2]),
    .majority_o (rsp_o.rvalid),
    .fault_detected_o(voter_errs[1])
  );

  // hsiao_ecc_enc #(
  //   .DataWidth ( Cfg.AddrWidth )
  // ) i_addr_enc (
  //   .in ( req_i.a.addr ),
  //   .out( rel_req_o.a.addr )
  // );
  assign rel_req_o.a.addr[0] = req_i.a.addr;
  assign rel_req_o.a.addr[1] = req_i.a.addr;
  assign rel_req_o.a.addr[2] = req_i.a.addr;

  hsiao_ecc_enc #(
    .DataWidth ( Cfg.DataWidth )
  ) i_wdata_enc (
    .in ( req_i.a.wdata ),
    .out( rel_req_o.a.wdata )
  );

  relobi_a_other_encoder #(
    .Cfg          (Cfg),
    .a_optional_t (a_optional_t)
  ) i_a_remaining_enc (
    .we_i        (req_i.a.we),
    .be_i        (req_i.a.be),
    // .aid_i       (req_i.a.aid),
    .a_optional_i(req_i.a.a_optional),
    .other_ecc_o (rel_req_o.a.other_ecc)
  );
  assign rel_req_o.a.we = req_i.a.we;
  assign rel_req_o.a.be = req_i.a.be;
  assign rel_req_o.a.aid[0] = req_i.a.aid;
  assign rel_req_o.a.aid[1] = req_i.a.aid;
  assign rel_req_o.a.aid[2] = req_i.a.aid;
  assign rel_req_o.a.a_optional = req_i.a.a_optional;

  hsiao_ecc_dec #(
    .DataWidth ( Cfg.DataWidth )
  ) i_rdata_dec (
    .in        ( rel_rsp_i.r.rdata ),
    .out       ( rsp_o.r.rdata ),
    .syndrome_o(),
    .err_o     (hsiao_errs[0])
  );
  assign hsiao_errs_gated[0] = rel_rsp_i.rvalid[0] ? hsiao_errs[0] : '0;

  relobi_r_other_decoder #(
    .Cfg          (Cfg),
    .r_optional_t (r_optional_t)
  ) i_r_remaining_dec (
    // .rid_i       (rel_rsp_i.r.rid),
    .err_i       (rel_rsp_i.r.err),
    .r_optional_i(rel_rsp_i.r.r_optional),
    .other_ecc_i (rel_rsp_i.r.other_ecc),
    // .rid_o       (rsp_o.r.rid),
    .err_o       (rsp_o.r.err),
    .r_optional_o(rsp_o.r.r_optional),
    .fault_o    (hsiao_errs[1])
  );
  assign hsiao_errs_gated[1] = rel_rsp_i.rvalid[0] ? hsiao_errs[1] : '0;

  bitwise_TMR_voter_fail #(
    .DataWidth (Cfg.IdWidth)
  ) i_rid_vote (
    .a_i        (rel_rsp_i.r.rid[0]),
    .b_i        (rel_rsp_i.r.rid[1]),
    .c_i        (rel_rsp_i.r.rid[2]),
    .majority_o (rsp_o.r.rid),
    .fault_detected_o(voter_errs[2])
  );

endmodule
