// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "dot_product.h"

// Self-fetching streaming dot-product engine -- Bambu HLS flavour.
//
// Same function and same loop as ../../vitis/dot_product/dot_product.cpp; only
// the interface pragmas differ, because Bambu's pragma dialect is not Vitis':
//
//   * The pragma is lower-case and case sensitive:
//       #pragma HLS interface port=<arg> mode=<type> [offset=direct] [bundle=<name>]
//   * Bambu has no 's_axilite' mode, so there is no AXI4-Lite CTRL bundle and
//     no ap_ctrl_hs block in the generated RTL. The core only exposes
//     clock/reset/start_port/done_port plus one port per C argument, and the
//     memory-mapped CTRL register file (which is what X-HEEP software talks to
//     and is identical to the Vitis one) is a regtool-generated register file
//     (data/dot_product_ctrl.hjson, rtl/dot_product_ctrl_regs.sv) instead.
//   * 'offset=direct' is the only m_axi offset mode Bambu supports: the
//     pointer arguments 'a'/'b' become plain input address ports of the core
//     (the register file drives them), instead of Vitis' 'offset=slave'
//     where the base address lives in a generated register.
//   * Two bundles (gmem_a/gmem_b) give two independent AXI4 master ports, just
//     like in the Vitis version, so both vectors are fetched in parallel.
//   * Bambu has no equivalent of max_read_burst_length/num_read_outstanding
//     (its AXI master issues single-beat transactions), of PIPELINE II=1 or of
//     LOOP_TRIPCOUNT; the scheduler pipelines/optimises the loop on its own.
//
// 'size' (a by-value scalar) becomes a plain input port and 'result' (a
// write-only pointer) becomes an output port with a valid strobe, which is
// Bambu's default interface for those argument kinds under
// --generate-interface=INFER.
#pragma HLS interface port = a mode = m_axi offset = direct bundle = gmem_a
#pragma HLS interface port = b mode = m_axi offset = direct bundle = gmem_b
void dot_product(const dp_data_t *a, const dp_data_t *b, uint32_t size, dp_result_t *result) {
  dp_result_t acc = 0;

dot_product_loop:
  for (uint32_t i = 0; i < size; i++) {
    acc += (dp_result_t)a[i] * (dp_result_t)b[i];
  }

  *result = acc;
}
