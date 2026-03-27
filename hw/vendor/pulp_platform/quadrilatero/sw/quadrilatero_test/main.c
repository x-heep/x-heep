// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Danilo Cammarata

/* By default, printfs are deactivated. */
#define PRINTF_IN_FPGA  0
#define PRINTF_IN_SIM   1


// ************************************************************************************************************
// *****************************                                                  *****************************
// *****************************            DO NOT TOUCH LINES BELOW !            *****************************
// *****************************                                                  *****************************
// ************************************************************************************************************

/* Includes */
#include <stdio.h>
#include <stdlib.h>
#include "csr.h"
#include "x-heep.h"
#include "gpio.h"

/* Declare functions and global variables */
void __attribute__ ((noinline)) nop_function(int value);
void __attribute__ ((noinline)) configure_MREG();
void __attribute__ ((noinline)) waw_bug();
void __attribute__ ((noinline)) load_store_timing_bug();
void __attribute__ ((noinline)) pip_bug();
void __attribute__ ((noinline)) m0_RAW_bug();

int32_t __attribute__((section(".xheep_data_interleaved"))) test[] = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};

/* Select print mode */
#if TARGET_SIM && PRINTF_IN_SIM
        #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif TARGET_PYNQ_Z2 && PRINTF_IN_FPGA
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif


// -------------------------------------------------------------------------------------------------------------------------------------


int main()
{

    nop_function(200);
    configure_MREG();
    nop_function(200);
    waw_bug();
    nop_function(200);
    configure_MREG();
    waw_bug();
    nop_function(200);
    load_store_timing_bug();
    nop_function(200);
    pip_bug();
    nop_function(200);
    m0_RAW_bug();
    nop_function(200);

    PRINTF("Passed.\n\r");
    return 0;
}


// -------------------------------------------------------------------------------------------------------------------------------------

void __attribute__ ((noinline)) nop_function(int value){
    asm volatile("addi    t5,x0, 0              "         ); 
    asm volatile("nop_loop:                     "         );
    asm volatile("addi    t5,t5, 1              "         );
    asm volatile("blt     t5, %0, nop_loop" :: "r" (value));
}

void __attribute__ ((noinline)) configure_MREG(){
    asm volatile("mld.w m0, (%1), %0" ::"r"(4), "r"(test));
    asm volatile("mld.w m1, (%1), %0" ::"r"(4), "r"(test));
    asm volatile("mzero m2");
}
void __attribute__ ((noinline)) waw_bug(){
    asm volatile("mmasa.w m2,m1,m0");
    asm volatile("mmasa.w m2,m1,m0");
    asm volatile("mmasa.w m2,m1,m0");
    asm volatile("mmasa.w m2,m1,m0");
}
void __attribute__ ((noinline)) load_store_timing_bug(){   
    asm volatile("mzero m2");
    asm volatile("mzero m2");
    asm volatile("mzero m2");
    asm volatile("mzero m2");
    asm volatile("mzero m2");
    asm volatile("mzero m2");
    asm volatile("mst.w   m2, (%0) , %1        " :: "r" (test), "r"(4)                            );   // m5  -> (s5)
    asm volatile("mst.w   m2, (%0) , %1        " :: "r" (test), "r"(4)                            );   // m5  -> (s5)
    asm volatile("mst.w   m2, (%0) , %1        " :: "r" (test), "r"(4)                            );   // m5  -> (s5)
    asm volatile("mst.w   m2, (%0) , %1        " :: "r" (test), "r"(4)                            );   // m5  -> (s5)
    asm volatile("mst.w   m2, (%0) , %1        " :: "r" (test), "r"(4)                            );   // m5  -> (s5)

}

void __attribute__ ((noinline)) pip_bug(){
    asm volatile("mzero m1");
    asm volatile("mld.w m0, (%1), %0" ::"r"(4), "r"(test));
    asm volatile("mld.w m5, (%1), %0" ::"r"(4), "r"(test));
    asm volatile("mmasa.w m1, m0, m5");
    asm volatile("mld.w m6, (%1), %0" ::"r"(4), "r"(test));
    asm volatile("mmasa.w m2, m0, m6");
    asm volatile("mld.w m7, (%1), %0" ::"r"(4), "r"(test));
    asm volatile("mmasa.w m3, m0, m7");
    asm volatile("mld.w m5, (%1), %0" ::"r"(4), "r"(test));
    asm volatile("mmasa.w m4, m0, m5");
    asm volatile("mzero m1");
    asm volatile("mzero m2");
    asm volatile("mzero m3");
    asm volatile("mzero m4");
}

void __attribute__ ((noinline)) m0_RAW_bug() {
    asm volatile("mzero m1");
    asm volatile("mzero m2");
    for (int i = 0; i < 8; i++) {
        asm volatile("mmasa.w m0,m1,m2");
        asm volatile("mst.w m0, (%0), %1" :: "r" (test), "r"(16));
    }
}