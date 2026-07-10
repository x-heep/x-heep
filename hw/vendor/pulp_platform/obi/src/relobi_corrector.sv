// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_corrector #(
  /// Configuration of the bus
  parameter obi_pkg::obi_cfg_t Cfg = obi_pkg::ObiDefaultConfig,

  parameter type relobi_req_t      = logic,
  parameter type relobi_rsp_t      = logic,
  parameter type a_optional_t      = logic,
  parameter type r_optional_t      = logic
) (
  input  relobi_req_t req_i,
  output relobi_rsp_t rsp_o,

  output relobi_req_t req_o,
  input  relobi_rsp_t rsp_i,

  output logic [1:0]  fault_o
);

  logic [11:0]     voter_errs;
  logic            voter_errs_red;
  logic [4:0][1:0] hsiao_errs;
  logic [1:0][4:0] hsiao_errs_transpose;
  logic [1:0]      hsiao_errs_transpose_red;

  for (genvar i = 0; i < 2; i++) begin : gen_hsiao_errs_transpose
    assign hsiao_errs_transpose_red[i] = |hsiao_errs_transpose[i];
    for (genvar j = 0; j < 5; j++) begin : gen_hsiao_errs_transpose_inner
      assign hsiao_errs_transpose[i][j] = hsiao_errs[j][i];
    end
  end

  assign voter_errs_red = |voter_errs;
  assign fault_o[0] = voter_errs_red | hsiao_errs_transpose_red[0];
  assign fault_o[1] = hsiao_errs_transpose_red[1];

  for (genvar i = 0; i < 3; i++) begin : gen_tmr_part
    TMR_voter_fail i_req_req_vote (
      .a_i        (req_i.req[0]),
      .b_i        (req_i.req[1]),
      .c_i        (req_i.req[2]),
      .majority_o (req_o.req[i]),
      .fault_detected_o(voter_errs[i])
    );
    TMR_voter_fail i_rsp_gnt_vote (
      .a_i        (rsp_i.gnt[0]),
      .b_i        (rsp_i.gnt[1]),
      .c_i        (rsp_i.gnt[2]),
      .majority_o (rsp_o.gnt[i]),
      .fault_detected_o(voter_errs[3+i])
    );
    TMR_voter_fail i_rsp_rvalid_vote (
      .a_i        (rsp_i.rvalid[0]),
      .b_i        (rsp_i.rvalid[1]),
      .c_i        (rsp_i.rvalid[2]),
      .majority_o (rsp_o.rvalid[i]),
      .fault_detected_o(voter_errs[6+i])
    );
    if (Cfg.UseRReady) begin : gen_rready_vote
      TMR_voter_fail i_req_rready_vote (
        .a_i        (req_i.rready[0]),
        .b_i        (req_i.rready[1]),
        .c_i        (req_i.rready[2]),
        .majority_o (req_o.rready[i]),
        .fault_detected_o(voter_errs[9+i])
      );
    end else begin : gen_no_rready_vote
      assign voter_errs[9+i] = 1'b0;
    end
  end

  hsiao_ecc_cor #(
    .DataWidth ( Cfg.AddrWidth )
  ) i_addr_enc (
    .in ( req_i.a.addr ),
    .out( req_o.a.addr ),
    .syndrome_o(),
    .err_o     (hsiao_errs[0])
  );

  hsiao_ecc_cor #(
    .DataWidth ( Cfg.DataWidth )
  ) i_wdata_enc (
    .in ( req_i.a.wdata ),
    .out( req_o.a.wdata ),
    .syndrome_o(),
    .err_o     (hsiao_errs[1])
  );

  relobi_a_other_corrector #(
    .Cfg          (Cfg),
    .a_optional_t (a_optional_t)
  ) i_a_remaining_enc (
    .we_i        (req_i.a.we),
    .be_i        (req_i.a.be),
    .aid_i       (req_i.a.aid),
    .a_optional_i(req_i.a.a_optional),
    .other_ecc_i (req_i.a.other_ecc),
    .we_o        (req_o.a.we),
    .be_o        (req_o.a.be),
    .aid_o       (req_o.a.aid),
    .a_optional_o(req_o.a.a_optional),
    .other_ecc_o (req_o.a.other_ecc),
    .fault_o     (hsiao_errs[2])
  );

  hsiao_ecc_cor #(
    .DataWidth ( Cfg.DataWidth )
  ) i_rdata_dec (
    .in        ( rsp_i.r.rdata ),
    .out       ( rsp_o.r.rdata ),
    .syndrome_o(),
    .err_o     (hsiao_errs[3])
  );

  relobi_r_other_corrector #(
    .Cfg          (Cfg),
    .r_optional_t (r_optional_t)
  ) i_r_remaining_dec (
    .rid_i       (rsp_i.r.rid),
    .err_i       (rsp_i.r.err),
    .r_optional_i(rsp_i.r.r_optional),
    .other_ecc_i (rsp_i.r.other_ecc),
    .rid_o       (rsp_o.r.rid),
    .err_o       (rsp_o.r.err),
    .r_optional_o(rsp_o.r.r_optional),
    .other_ecc_o (rsp_o.r.other_ecc),
    .fault_o    (hsiao_errs[4])
  );

endmodule
