// Copyright 2026 EPFL
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define TEST_WORDS 8192u
#define TEST_MASK  (TEST_WORDS - 1u)
#define TEST_SEED  0x1125a5a5u

static volatile uint32_t test_area[TEST_WORDS] __attribute__((aligned(8)));

static uint32_t pattern(uint32_t index)
{
    uint32_t value = index ^ TEST_SEED;
    value ^= value >> 16;
    value *= 0x7feb352du;
    value ^= value >> 15;
    return value;
}

int main(void)
{
    for (uint32_t i = 0; i < TEST_WORDS; ++i) {
        uint32_t index = (i * 4051u + 123u) & TEST_MASK;
        test_area[index] = pattern(index);
    }

    __asm__ volatile("fence rw, rw" ::: "memory");

    for (uint32_t i = 0; i < TEST_WORDS; ++i) {
        uint32_t index = (i * 2711u + 777u) & TEST_MASK;
        uint32_t expected = pattern(index);
        uint32_t observed = test_area[index];

        if (observed != expected) {
            printf("FAIL addr=0x%08lx expected=0x%08lx observed=0x%08lx\n",
                   (unsigned long)(uintptr_t)&test_area[index],
                   (unsigned long)expected, (unsigned long)observed);
            return EXIT_FAILURE;
        }
    }

    printf("PASS: %u random-access words\n", TEST_WORDS);
    return EXIT_SUCCESS;
}
