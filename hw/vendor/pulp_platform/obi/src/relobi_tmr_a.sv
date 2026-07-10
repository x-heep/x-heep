// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_tmr_a #(
  parameter obi_pkg::obi_cfg_t ObiCfg       = obi_pkg::ObiDefaultConfig,
  parameter type               obi_a_chan_t = logic,
  parameter type               a_optional_t = logic
) (
  input  obi_a_chan_t [2:0] three_a_i,
  output obi_a_chan_t       voted_a_o,
  output logic              fault_o
);

  logic [14:0] faults;

  assign fault_o = |faults;

  bitwise_TMR_voter_fail #(
    .DataWidth(3*ObiCfg.AddrWidth)
  ) i_r_data (
    .a_i        (three_a_i[0].addr),
    .b_i        (three_a_i[1].addr),
    .c_i        (three_a_i[2].addr),
    .majority_o (voted_a_o.addr),
    .fault_detected_o (faults[0])
  );
  TMR_voter_fail i_r_we (
    .a_i        (three_a_i[0].we),
    .b_i        (three_a_i[1].we),
    .c_i        (three_a_i[2].we),
    .majority_o (voted_a_o.we),
    .fault_detected_o (faults[1])
  );
  bitwise_TMR_voter_fail #(
    .DataWidth(ObiCfg.DataWidth/8)
  ) i_r_data (
    .a_i        (three_a_i[0].be),
    .b_i        (three_a_i[1].be),
    .c_i        (three_a_i[2].be),
    .majority_o (voted_a_o.be),
    .fault_detected_o (faults[2])
  );
  bitwise_TMR_voter_fail #(
    .DataWidth(ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth))
  ) i_r_data (
    .a_i        (three_a_i[0].wdata),
    .b_i        (three_a_i[1].wdata),
    .c_i        (three_a_i[2].wdata),
    .majority_o (voted_a_o.wdata),
    .fault_detected_o (faults[3])
  );
  bitwise_TMR_voter_fail #(
    .DataWidth(3*ObiCfg.IdWidth)
  ) i_r_id (
    .a_i        (three_a_i[0].aid),
    .b_i        (three_a_i[1].aid),
    .c_i        (three_a_i[2].aid),
    .majority_o (voted_a_o.aid),
    .fault_detected_o (faults[4])
  );
  TMR_voter_fail i_r_err (
    .a_i        (three_r_i[0].err),
    .b_i        (three_r_i[1].err),
    .c_i        (three_r_i[2].err),
    .majority_o (voted_r_o.err),
    .fault_detected_o (faults[5])
  );

  if (ObiCfg.OptionalCfg.AUserWidth) begin : gen_auser
    bitwise_TMR_voter_fail #(
      .DataWidth(ObiCfg.OptionalCfg.RUserWidth)
    ) i_r_id (
      .a_i        (three_a_i[0].a_optional.auser),
      .b_i        (three_a_i[1].a_optional.auser),
      .c_i        (three_a_i[2].a_optional.auser),
      .majority_o (voted_a_o.a_optional.auser),
      .fault_detected_o (faults[6])
    );
  end else begin : gen_no_auser
    assign faults[6] = 1'b0;
  end
  if (ObiCfg.OptionalCfg.WUserWidth) begin : gen_wuser
    bitwise_TMR_voter_fail #(
      .DataWidth(ObiCfg.OptionalCfg.RUserWidth)
    ) i_r_id (
      .a_i        (three_a_i[0].a_optional.wuser),
      .b_i        (three_a_i[1].a_optional.wuser),
      .c_i        (three_a_i[2].a_optional.wuser),
      .majority_o (voted_a_o.a_optional.wuser),
      .fault_detected_o (faults[7])
    );
  end else begin : gen_no_wuser
    assign faults[7] = 1'b0;
  end
  if (ObiCfg.OptionalCfg.UseAtop) begin : gen_atop
    bitwise_TMR_voter #(
      .DataWidth(6)
    ) i_r_err (
      .a_i        (three_a_i[0].a_optional.atop),
      .b_i        (three_a_i[1].a_optional.atop),
      .c_i        (three_a_i[2].a_optional.atop),
      .majority_o (voted_a_o.a_optional.atop),
      .fault_detected_o (faults[8])
    );
  end else begin : gen_no_atop
    assign faults[8] = 1'b0;
  end
  if (ObiCfg.OptionalCfg.UseMemtype) begin : gen_memtype
    bitwise_TMR_voter_fail #(
      .DataWidth(2)
    ) i_r_err (
      .a_i        (three_a_i[0].a_optional.memtype),
      .b_i        (three_a_i[1].a_optional.memtype),
      .c_i        (three_a_i[2].a_optional.memtype),
      .majority_o (voted_a_o.a_optional.memtype),
      .fault_detected_o (faults[9])
    );
  end else begin : gen_no_memtype
    assign faults[9] = 1'b0;
  end
  if (ObiCfg.OptionalCfg.MidWidth) begin : gen_mid
    bitwise_TMR_voter_fail #(
      .DataWidth(ObiCfg.OptionalCfg.MidWidth)
    ) i_r_err (
      .a_i        (three_a_i[0].a_optional.mid),
      .b_i        (three_a_i[1].a_optional.mid),
      .c_i        (three_a_i[2].a_optional.mid),
      .majority_o (voted_a_o.a_optional.mid),
      .fault_detected_o (faults[10])
    );
  end else begin : gen_no_mid
    assign faults[10] = 1'b0;
  end
  if (ObiCfg.OptionalCfg.UseProt) begin : gen_prot
    bitwise_TMR_voter_fail #(
      .DataWidth(3)
    ) i_r_err (
      .a_i        (three_a_i[0].a_optional.prot),
      .b_i        (three_a_i[1].a_optional.prot),
      .c_i        (three_a_i[2].a_optional.prot),
      .majority_o (voted_a_o.a_optional.prot),
      .fault_detected_o (faults[11])
    );
  end else begin : gen_no_prot
    assign faults[11] = 1'b0;
  end
  if (ObiCfg.OptionalCfg.UseDbg) begin : gen_dbg
    TMR_voter_fail i_r_err (
      .a_i        (three_a_i[0].a_optional.dbg),
      .b_i        (three_a_i[1].a_optional.dbg),
      .c_i        (three_a_i[2].a_optional.dbg),
      .majority_o (voted_a_o.a_optional.dbg),
      .fault_detected_o (faults[12])
    );
  end else begin : gen_no_dbg
    assign faults[12] = 1'b0;
  end
  if (ObiCfg.OptionalCfg.AChkWidth) begin : gen_achk
    bitwise_TMR_voter_fail #(
      .DataWidth(ObiCfg.OptionalCfg.AChkWidth)
    ) i_r_id (
      .a_i        (three_a_i[0].a_optional.achk),
      .b_i        (three_a_i[1].a_optional.achk),
      .c_i        (three_a_i[2].a_optional.achk),
      .majority_o (voted_a_o.a_optional.achk),
      .fault_detected_o (faults[13])
    );
  end else begin : gen_no_achk
    assign faults[13] = 1'b0;
  end
  if (!ObiCfg.OptionalCfg.AUserWidth &&
      !ObiCfg.OptionalCfg.WUserWidth &&
      !ObiCfg.OptionalCfg.UseAtop    &&
      !ObiCfg.OptionalCfg.UseMemtype &&
      !ObiCfg.OptionalCfg.MidWidth   &&
      !ObiCfg.OptionalCfg.UseProt    &&
      !ObiCfg.OptionalCfg.UseDbg     &&
      !ObiCfg.OptionalCfg.AChkWidth    ) begin : gen_optional_tie
    assign voted_a_o.a_optional = '0;
  end
  bitwise_TMR_voter_fail #(
    .DataWidth(hsiao_ecc_pkg::min_ecc(1+ObiCfg.DataWidth/8+ObiCfg.IdWidth+$bits(a_optional_t)))
  ) i_r_id (
    .a_i        (three_a_i[0].other_ecc),
    .b_i        (three_a_i[1].other_ecc),
    .c_i        (three_a_i[2].other_ecc),
    .majority_o (voted_a_o.other_ecc),
    .fault_detected_o (faults[14])
  );

endmodule
