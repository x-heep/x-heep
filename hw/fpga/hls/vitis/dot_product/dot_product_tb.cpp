// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "dot_product.h"
#include <iostream>

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
  dot_product(a, b, N, &result);

  std::cout << "expected = " << expected << ", got = " << result << std::endl;

  if (result != expected) {
    std::cout << "TEST FAILED" << std::endl;
    return 1;
  }

  std::cout << "TEST PASSED" << std::endl;
  return 0;
}
