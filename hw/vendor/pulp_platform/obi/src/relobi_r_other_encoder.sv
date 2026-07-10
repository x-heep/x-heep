// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_r_other_encoder #(
  /// Configuration of the bus
  parameter obi_pkg::obi_cfg_t Cfg           = obi_pkg::ObiDefaultConfig,

  parameter type               r_optional_t  = logic,
  parameter int unsigned       OtherEccWidth = relobi_pkg::relobi_r_other_ecc_width(Cfg)
) (
  // input  logic [Cfg.IdWidth    -1:0] rid_i,
  input  logic                       err_i,
  input  r_optional_t                r_optional_i,

  output logic [  OtherEccWidth-1:0] other_ecc_o
);

  logic [relobi_pkg::relobi_r_other_width(Cfg)-1:0] unused;

  hsiao_ecc_enc #(
    .DataWidth (relobi_pkg::relobi_r_other_width(Cfg))
  ) i_a_remaining_enc (
    .in        ( {//rid_i,
                  err_i,
                  r_optional_i} ),
    .out       ( {other_ecc_o, unused} )
  );

endmodule
