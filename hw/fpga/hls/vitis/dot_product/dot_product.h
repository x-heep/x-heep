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
// pulse start, poll done and read the result.
void dot_product(const dp_data_t *a, const dp_data_t *b, uint32_t size, dp_result_t *result);

#endif  // DOT_PRODUCT_H
