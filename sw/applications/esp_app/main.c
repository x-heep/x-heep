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

#include <stdio.h>
#include <stdlib.h>
#include "xheep_common.h"

int main(int argc, char *argv[])
{
    /* write something to stdout */
    printf("hello X-Heep!\n");
    static const char msg[] = "Hello from X-heep";
    volatile char *dst = (volatile char *)(uintptr_t)XHEEP_SHARED_STR_ADDR;
    for (unsigned i = 0; ; ++i) { 
        dst[i] = msg[i]; 
        if (msg[i] == '\0') break; 
    }

    return EXIT_SUCCESS;
}
