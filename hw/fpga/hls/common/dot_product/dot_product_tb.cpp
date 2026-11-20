// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "dot_product.h"
#include <iostream>

// Shared by the Vitis HLS, Bambu HLS and Dynamatic flows. Bambu's RTL
// co-simulation needs to be told how many bytes each pointer argument points
// to (it can only infer sizeof(*ptr) from the C type, i.e. one element here);
// the __BAMBU_SIM__ macro is only defined by Bambu, so Vitis never sees this.
#ifdef __BAMBU_SIM__
#include <mdpi/mdpi_user.h>
#endif

// Dynamatic's co-simulation (see ../../dynamatic/dot_product/dot_product.c,
// which includes this file and defines DOT_PRODUCT_DYNAMATIC) records the
// arguments of the CALL_KERNEL() call by name, so the variables passed to it
// must have the names and the types of the kernel's parameters: a and b are
// arrays of the kernel's fixed size, and the size is a variable called 'size'.
#ifdef DOT_PRODUCT_DYNAMATIC
#include "dynamatic/Integration.h"
#endif

int main() {
  const int N = 16;
#ifdef DOT_PRODUCT_DYNAMATIC
  static dp_data_t a[DOT_PRODUCT_DYNAMATIC_MAX_LEN], b[DOT_PRODUCT_DYNAMATIC_MAX_LEN];
#else
  dp_data_t a[N], b[N];
#endif
  dp_result_t expected = 0;

  for (int i = 0; i < N; i++) {
    a[i] = i + 1;
    b[i] = N - i;
    expected += (dp_result_t)a[i] * (dp_result_t)b[i];
  }

  dp_result_t result = 0;

#ifdef __BAMBU_SIM__
  // Argument indices follow dot_product()'s signature: a=0, b=1, result=3.
  m_param_alloc(0, sizeof(a));
  m_param_alloc(1, sizeof(b));
  m_param_alloc(3, sizeof(result));
#endif

#ifdef DOT_PRODUCT_DYNAMATIC
  // CALL_KERNEL() records the inputs and outputs that Dynamatic's
  // co-simulation replays on (and compares against) the generated RTL; it
  // does not hand back the return value, hence the second, plain call.
  uint32_t size = N;
  CALL_KERNEL(dot_product, a, b, size);
  result = dot_product(a, b, size);
#else
  dot_product(a, b, N, &result);
#endif

  std::cout << "expected = " << expected << ", got = " << result << std::endl;

  if (result != expected) {
    std::cout << "TEST FAILED" << std::endl;
    return 1;
  }

  std::cout << "TEST PASSED" << std::endl;
  return 0;
}
