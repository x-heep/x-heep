// Copyright 2025 EPFL and Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: xheep_fifo_pkg.sv
// Author: Alessio Naclerio
// Date: 17/02/2025
// Description: Package for FIFOs in the DMA subsystem

package xheep_fifo_pkg;

  typedef struct packed {
    logic pop;
    logic push;
    logic flush;
    logic [31:0] data;
  } xheep_fifo_req_t;

  typedef struct packed {
    logic empty;
    logic full;
    logic alm_full;
    logic [31:0] data;
  } xheep_fifo_rsp_t;

endpackage
