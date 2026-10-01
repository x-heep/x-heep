// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "dot_product.h"
#include <iostream>

// Shared by the Vitis HLS and Bambu HLS flows. Bambu's RTL co-simulation
// needs to be told how many bytes each pointer argument points to (it can
// only infer sizeof(*ptr) from the C type, i.e. one element here); the
// __BAMBU_SIM__ macro is only defined by Bambu, so Vitis never sees this.
#ifdef __BAMBU_SIM__
#include <mdpi/mdpi_user.h>
#endif

int main() {
  const int N = 16;
  dp_data_t a[N], b[N];
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

  dot_product(a, b, N, &result);

  std::cout << "expected = " << expected << ", got = " << result << std::endl;

  if (result != expected) {
    std::cout << "TEST FAILED" << std::endl;
    return 1;
  }

  std::cout << "TEST PASSED" << std::endl;
  return 0;
}
