// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_tmr_r #(
  parameter obi_pkg::obi_cfg_t ObiCfg       = obi_pkg::ObiDefaultConfig,
  parameter type               obi_r_chan_t = logic,
  parameter type               r_optional_t = logic
) (
  input  obi_r_chan_t [2:0] three_r_i,
  output obi_r_chan_t       voted_r_o,

  output logic              fault_o
);

  logic [6:0] faults;
  assign fault_o = |faults;

  bitwise_TMR_voter_fail #(
    .DataWidth(ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth))
  ) i_r_data (
    .a_i        (three_r_i[0].rdata),
    .b_i        (three_r_i[1].rdata),
    .c_i        (three_r_i[2].rdata),
    .majority_o (voted_r_o.rdata),
    .fault_detected_o (faults[0])
  );
  bitwise_TMR_voter_fail #(
    .DataWidth(3*ObiCfg.IdWidth)
  ) i_r_id (
    .a_i        (three_r_i[0].rid),
    .b_i        (three_r_i[1].rid),
    .c_i        (three_r_i[2].rid),
    .majority_o (voted_r_o.rid),
    .fault_detected_o (faults[1])
  );
  TMR_voter_fail i_r_err (
    .a_i        (three_r_i[0].err),
    .b_i        (three_r_i[1].err),
    .c_i        (three_r_i[2].err),
    .majority_o (voted_r_o.err),
    .fault_detected_o (faults[2])
  );

  if (ObiCfg.OptionalCfg.RUserWidth) begin : gen_ruser
    bitwise_TMR_voter_fail #(
      .DataWidth(ObiCfg.OptionalCfg.RUserWidth)
    ) i_r_user (
      .a_i        (three_r_i[0].r_optional.ruser),
      .b_i        (three_r_i[1].r_optional.ruser),
      .c_i        (three_r_i[2].r_optional.ruser),
      .majority_o (voted_r_o.r_optional.ruser),
      .fault_detected_o (faults[3])
    );
  end else begin : gen_no_ruser
    assign faults[3] = '0;
  end
  if (ObiCfg.OptionalCfg.RChkWidth) begin : gen_rchk
    bitwise_TMR_voter_fail #(
      .DataWidth(ObiCfg.OptionalCfg.RChkWidth)
    ) i_r_rchk (
      .a_i        (three_r_i[0].r_optional.rchk),
      .b_i        (three_r_i[1].r_optional.rchk),
      .c_i        (three_r_i[2].r_optional.rchk),
      .majority_o (voted_r_o.r_optional.rchk),
      .fault_detected_o (faults[4])
    );
  end else begin : gen_no_rchk
    assign faults[4] = '0;
  end
  if (ObiCfg.OptionalCfg.UseAtop) begin : gen_exokay
    TMR_voter_fail i_r_err (
      .a_i        (three_r_i[0].r_optional.exokay),
      .b_i        (three_r_i[1].r_optional.exokay),
      .c_i        (three_r_i[2].r_optional.exokay),
      .majority_o (voted_r_o.r_optional.exokay),
      .fault_detected_o (faults[5])
    );
  end else begin : gen_no_exokay
    assign faults[5] = '0;
  end
  if (!ObiCfg.OptionalCfg.RUserWidth &&
      !ObiCfg.OptionalCfg.RChkWidth &&
      !ObiCfg.OptionalCfg.UseAtop ) begin : gen_optional_tie
    assign voted_r_o.r_optional = '0;
  end

  bitwise_TMR_voter_fail #(
    .DataWidth(hsiao_ecc_pkg::min_ecc(ObiCfg.IdWidth+1+$bits(r_optional_t)))
  ) i_r_other_ecc (
    .a_i        (three_r_i[0].other_ecc),
    .b_i        (three_r_i[1].other_ecc),
    .c_i        (three_r_i[2].other_ecc),
    .majority_o (voted_r_o.other_ecc),
    .fault_detected_o (faults[6])
  );


endmodule
