// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_a_other_encoder #(
  /// Configuration of the bus
  parameter obi_pkg::obi_cfg_t Cfg           = obi_pkg::ObiDefaultConfig,

  parameter type               a_optional_t  = logic,
  parameter int unsigned       OtherEccWidth = relobi_pkg::relobi_a_other_ecc_width(Cfg)
) (
  input  logic                       we_i,
  input  logic [Cfg.DataWidth/8-1:0] be_i,
  // input  logic [Cfg.IdWidth    -1:0] aid_i,
  input  a_optional_t                a_optional_i,

  output logic [  OtherEccWidth-1:0] other_ecc_o
);

  logic [relobi_pkg::relobi_a_other_width(Cfg)-1:0] unused;

  hsiao_ecc_enc #(
    .DataWidth (relobi_pkg::relobi_a_other_width(Cfg))
  ) i_a_remaining_enc (
    .in        ( {we_i,
                  be_i,
                  // aid_i,
                  a_optional_i} ),
    .out       ( {other_ecc_o, unused} )
  );

endmodule
