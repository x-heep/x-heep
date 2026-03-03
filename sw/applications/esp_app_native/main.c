/*
 * Copyright 2020 ETH Zurich
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Author: Robert Balas <balasr@iis.ee.ethz.ch>
 */

#include <stdlib.h>
#include <stdint.h>
#include "xheep_common.h"
#include "core_v_mini_mcu.h"

static const char __attribute__((aligned(4))) xheep_native_msg[] = "Hello from X-Heep Native tile!\n";

int main(int argc, char *argv[])
{
    // AXI: perform only 32-bit writes
    volatile uint32_t *esp_string = (volatile uint32_t *)(uintptr_t)(EXT_SLAVE_START_ADDRESS + XHEEP_SHARED_STR_ADDR);
    const uint32_t *axi_msg_words = (const uint32_t *)xheep_native_msg;
    unsigned num_words = (sizeof(xheep_native_msg) + 3) / 4;  // Round up to whole words
    
    for (unsigned i = 0; i < num_words - 1; i++) {
        esp_string[i] = axi_msg_words[i];
    }
    
    // Handle last word with padding
    uint32_t last_word = 0;  // Zero-padded
    unsigned remaining_bytes = sizeof(xheep_native_msg) - (num_words - 1) * 4;
    const char *last_bytes = &xheep_native_msg[(num_words - 1) * 4];
    for (unsigned i = 0; i < remaining_bytes; i++) {
        last_word |= ((uint32_t)last_bytes[i]) << (i * 8);
    }
    esp_string[num_words - 1] = last_word;
    
    return EXIT_SUCCESS;
}
