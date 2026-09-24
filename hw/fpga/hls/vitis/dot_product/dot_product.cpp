// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "dot_product.h"

// Self-fetching streaming dot-product engine.
//
// Two independent AXI4 master read ports (bundles 'gmem_a'/'gmem_b') let
// the core pull both vectors out of memory on its own once started --
// no data ever has to pass through the control interface.
//
// Everything else (the two base addresses, 'size', 'result', and the
// standard ap_ctrl_hs start/done/idle/ready bits) is bundled onto a
// single AXI4-Lite slave port ('CTRL'), which is what software polls/
// pokes to configure and kick off the core.
void dot_product(const dp_data_t *a, const dp_data_t *b, uint32_t size, dp_result_t *result) {
#pragma HLS INTERFACE m_axi port = a offset = slave bundle = gmem_a max_read_burst_length = 256 num_read_outstanding = 2
#pragma HLS INTERFACE m_axi port = b offset = slave bundle = gmem_b max_read_burst_length = 256 num_read_outstanding = 2

#pragma HLS INTERFACE s_axilite port = a bundle = CTRL
#pragma HLS INTERFACE s_axilite port = b bundle = CTRL
#pragma HLS INTERFACE s_axilite port = size bundle = CTRL
#pragma HLS INTERFACE s_axilite port = result bundle = CTRL
#pragma HLS INTERFACE s_axilite port = return bundle = CTRL

  dp_result_t acc = 0;

dot_product_loop:
  for (uint32_t i = 0; i < size; i++) {
#pragma HLS PIPELINE II = 1
#pragma HLS LOOP_TRIPCOUNT min = 1 max = 4096

    acc += (dp_result_t)a[i] * (dp_result_t)b[i];
  }

  *result = acc;
}
