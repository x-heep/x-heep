/*
*  Copyright 2022 EPFL Christoph Müller <christoph.mueller@epfl.ch>
*  Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
*  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
*/

package picorv32_pkg;

  typedef struct packed {
    logic        valid;
    logic [3:0]  wstrb;
    logic [31:0] addr;
    logic [31:0] wdata;
  } picorv32_req_t;

  typedef struct packed {
    logic        ready;
    logic [31:0] rdata;
  } picorv32_resp_t;

endpackage
