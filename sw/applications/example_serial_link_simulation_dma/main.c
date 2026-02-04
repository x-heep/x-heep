// Copyright 2025 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Description: Example application to test the Serial Link in simulation with DMA. 


#include <stdio.h>
#include <stdlib.h>
#include "serial_link_single_channel_regs.h"
#include "serial_link_regs.h"
#include "serial_link.h"


#define DMA_DATA_LARGE 8 
#define TEST_DATA_LARGE 16

// TODO: test on 8 and 16bits and unaligned addresses
static uint32_t to_be_sent_4B[TEST_DATA_LARGE] __attribute__((aligned(4))) = {0};
static uint32_t copied_data_4B[TEST_DATA_LARGE] __attribute__((aligned(4))) = {0};

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0


#if TARGET_SIM && PRINTF_IN_SIM
        #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif



int main(int argc, char *argv[]){
    
    sl_sim_init();
    
    for (int i = 0; i < TEST_DATA_LARGE; i++) {
        to_be_sent_4B[i] = i+525;
    }
    

    uint32_t chunks = TEST_DATA_LARGE / DMA_DATA_LARGE;
    uint32_t remainder = TEST_DATA_LARGE % DMA_DATA_LARGE;



    // DMA
    for (uint32_t i = 0; i < chunks; i++) {
        sl_dma_trans(
        to_be_sent_4B  + i * DMA_DATA_LARGE,   // src_d
        copied_data_4B + i * DMA_DATA_LARGE,   // dst_d
        SL_EXTERNAL_WRITE,                     // src (FIFO addr)
        SL_INTERNAL_READ,                      // dst (FIFO addr)
        DMA_DATA_LARGE);
    }
    if (remainder > 0) {
        sl_dma_trans(to_be_sent_4B + chunks * DMA_DATA_LARGE, copied_data_4B + chunks * DMA_DATA_LARGE,SL_EXTERNAL_WRITE,SL_INTERNAL_READ,remainder);
    }
    PRINTF("DMA DONE\n"); 

    // CPU
    for (uint32_t i = 0; i < chunks; i++) {
        sl_cpu_trans(
        to_be_sent_4B  + i * DMA_DATA_LARGE,
        copied_data_4B + i * DMA_DATA_LARGE,
        SL_EXTERNAL_WRITE,
        SL_INTERNAL_READ,
        DMA_DATA_LARGE);
    }
    if (remainder > 0) {        
        sl_cpu_trans(
        to_be_sent_4B  + chunks * DMA_DATA_LARGE,
        copied_data_4B + chunks * DMA_DATA_LARGE,
        SL_EXTERNAL_WRITE,
        SL_INTERNAL_READ,
        remainder);
    }

    PRINTF("CPU DONE\n"); 
    PRINTF("data saved:\n");
    for (int i = 0; i < TEST_DATA_LARGE; i++) {
        PRINTF("%x\n", copied_data_4B[i]);
    }

    PRINTF("DONE\n");  
    return EXIT_SUCCESS;
}





