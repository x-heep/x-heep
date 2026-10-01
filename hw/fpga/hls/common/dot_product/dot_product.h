// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef DOT_PRODUCT_H
#define DOT_PRODUCT_H

#include <stdint.h>

// Maximum vector length the engine can handle in one call (loop bound
// needed by HLS since the actual length is only known at run time via
// the 'size' register).
#define DOT_PRODUCT_MAX_LEN 4096

typedef int32_t dp_data_t;    // element type of the input vectors
typedef int64_t dp_result_t;  // accumulator / result type

// a, b   : base addresses of the two vectors in memory (AXI4 master read
//          ports, one each -- the engine fetches its own operands).
// size   : number of elements to read from each vector.
// result : dot product, written back once the core is done.
//
// a/b/size/result all also sit on the AXI4-Lite 'CTRL' bundle, together
// with the standard ap_ctrl_hs start/done/idle/ready control register, so
// a single AXI4-Lite slave port lets software set up the addresses/length,
// pulse start, poll done and read the result. (Vitis HLS generates that
// register file itself; Bambu HLS cannot, so the Bambu flow provides an
// equivalent one by hand -- see ../../bambu/dot_product. The register map
// seen by X-HEEP software is the same in both flows.)
//
// The function has C linkage on purpose: this header is shared by the Vitis
// HLS and the Bambu HLS flows, and Bambu names the generated RTL module after
// the (mangled) symbol, so C++ linkage would give it an unusable name like
// '_Z11dot_productPKiS0_jPx' instead of 'dot_product'.
#ifdef __cplusplus
extern "C" {
#endif

void dot_product(const dp_data_t *a, const dp_data_t *b, uint32_t size, dp_result_t *result);

#ifdef __cplusplus
}
#endif

#endif  // DOT_PRODUCT_H
