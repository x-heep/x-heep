// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio

module quadrilatero_fixed_prio_arbiter #(
    parameter PORTS = 4
) (
    input  logic [PORTS-1:0] req_i,
    output logic [PORTS-1:0] grant_o
);

  always_comb begin
    grant_o = '0;

    for (int i = 0; i < PORTS; i++) begin
      if (req_i[i]) begin
        grant_o[i] = 1;
        break;
      end
    end
  end

endmodule
