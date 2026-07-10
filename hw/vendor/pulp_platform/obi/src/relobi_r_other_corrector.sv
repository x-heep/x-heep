// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_r_other_corrector #(
  /// Configuration of the bus
  parameter obi_pkg::obi_cfg_t Cfg           = obi_pkg::ObiDefaultConfig,

  parameter type               r_optional_t  = logic,
  parameter int unsigned       OtherEccWidth = relobi_pkg::relobi_r_other_ecc_width(Cfg)
) (
  // input  logic [Cfg.IdWidth  -1:0] rid_i,
  input  logic                     err_i,
  input  r_optional_t              r_optional_i,
  input  logic [OtherEccWidth-1:0] other_ecc_i,

  // output logic [Cfg.IdWidth  -1:0] rid_o,
  output logic                     err_o,
  output r_optional_t              r_optional_o,
  output logic [  OtherEccWidth-1:0] other_ecc_o,

  output logic [1:0]               fault_o
);


  hsiao_ecc_cor #(
    .DataWidth ( relobi_pkg::relobi_r_other_width(Cfg) )
  ) i_r_remaining_cor (
    .in ( {other_ecc_i,
          //  rid_i,
           err_i,
           r_optional_i} ),
    .out( {other_ecc_o,
          //  rid_o,
           err_o,
           r_optional_o} ),
    .syndrome_o(),
    .err_o     (fault_o)
  );

endmodule
