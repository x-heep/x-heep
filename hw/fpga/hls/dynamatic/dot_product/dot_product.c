// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Dot-product engine -- Dynamatic flavour.
//
// Same computation and same loop as ../../vitis/dot_product/dot_product.cpp
// and ../../bambu/dot_product/dot_product.cpp; the differences come from what
// Dynamatic (a dynamically scheduled, dataflow HLS compiler) accepts and
// emits:
//
//   * The kernel is C, in a file named after it (Dynamatic takes the kernel
//     name from the file name), and has no pragmas: Dynamatic has no interface
//     directives. It schedules the loop dynamically (a circuit of handshake
//     channels) instead of with a static, II-based pipeline.
//   * No pointers: a/b are fixed-size arrays, each of which becomes a memory
//     port of the circuit (a BRAM-like interface with a fixed one-cycle read
//     latency), and the result is the return value, which becomes an output
//     channel. DOT_PRODUCT_DYNAMATIC selects this signature in the shared
//     dot_product.h. The base addresses of a/b live in the CTRL register file,
//     and the adapter (rtl/dot_product_hls_adapter.sv) fetches the vectors from
//     X-HEEP's memory into local RAMs before it starts the circuit.
//   * No AXI ports and no control register file: 'size' is an input channel,
//     plus start/end control channels; the adapter turns them into the same
//     CTRL register map as the other flows.
//
// 'size' must not exceed DOT_PRODUCT_DYNAMATIC_MAX_LEN (the size of the
// arrays, 1024); the adapter clamps it before handing it to the circuit.

#define DOT_PRODUCT_DYNAMATIC
#include "dot_product.h"

#include "dynamatic/Integration.h"

dp_result_t dot_product(const dp_data_t a[DOT_PRODUCT_DYNAMATIC_MAX_LEN],
                        const dp_data_t b[DOT_PRODUCT_DYNAMATIC_MAX_LEN], uint32_t size) {
  dp_result_t acc = 0;

  for (uint32_t i = 0; i < size; i++) {
    acc += (dp_result_t)a[i] * (dp_result_t)b[i];
  }

  return acc;
}

// Dynamatic wants the testbench's main() in the kernel's own file. It compiles
// this file as C for synthesis, where only the kernel matters, and as C++ (with
// its clang++) for the co-simulation, which is when the shared C++ testbench
// is needed.
#ifdef __cplusplus
#include "dot_product_tb.cpp"
#endif
