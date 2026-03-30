// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include "core_v_mini_mcu.h"
#include "x-heep.h"

#define TEST_DATA_SIZE      16

#define PRINTF_IN_SIM   0

#if TARGET_SIM && PRINTF_IN_SIM
        #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif


int32_t errors = 0;
// Simple accelerator Decoder (address for bytes)
//0 READ ADDRESS
#define SIMPLE_ACC_READ_OFFSET 0
//4 WRITE ADDRESS
#define SIMPLE_ACC_WRITE_OFFSET 1
//8 THRESHOLD
#define SIMPLE_ACC_THRESHOLD_OFFSET 2
//C READY
#define SIMPLE_ACC_READY_OFFSET 3
//10 SIZE
#define SIMPLE_ACC_SIZE_OFFSET 4
//14 START
#define SIMPLE_ACC_START_OFFSET 5



int main(int argc, char *argv[])
{

    static uint32_t source_data[TEST_DATA_SIZE] __attribute__ ((aligned (4)));
    static uint32_t copied_data[TEST_DATA_SIZE] __attribute__ ((aligned (4)));
    uint32_t threshold_value = 20;
    //defined in the testharness_pkg.sv
    volatile uint32_t *simple_acc = (uint32_t *)((uint8_t *)EXT_PERIPHERAL_START_ADDRESS + 0x3000);


    for(int i=0;i<TEST_DATA_SIZE;i++)
        source_data[i] = i & 0x1 ? i*3 : i*2;


    simple_acc[SIMPLE_ACC_READ_OFFSET] = (uintptr_t) &source_data[0];
    simple_acc[SIMPLE_ACC_WRITE_OFFSET] = (uintptr_t) &copied_data[0];
    simple_acc[SIMPLE_ACC_THRESHOLD_OFFSET] = threshold_value;
    simple_acc[SIMPLE_ACC_SIZE_OFFSET] = TEST_DATA_SIZE;

    //START
    simple_acc[SIMPLE_ACC_START_OFFSET] = 1;

    //UNTIL IT IS NOT READY.. WAIT SIMPLE ACCELERATOR
    while(simple_acc[SIMPLE_ACC_READY_OFFSET] != 1);

    errors = 0;
    for(int i=0;i<TEST_DATA_SIZE;i++) {
        uint32_t expected_data = source_data[i] > threshold_value ? source_data[i] : threshold_value;
        if(copied_data[i] != expected_data){
            errors++;
            PRINTF("copied_data[%d] is %d, expected %d\n\r",i,copied_data[i], expected_data);
        }
    }

    if (errors == 0) {
        PRINTF("Simple Accelerator Successful\n\r");
        return EXIT_SUCCESS;
    } else {
        PRINTF("Simple Accelerator failure: %d errors out of %d data checked\n\r", errors, TEST_DATA_SIZE );
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
