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

// simulation only -> Testharness last slave address on the external bus (size of the Slow memory in testharness pkg))
#if TARGET_SIM 
    #define EXT_SLAVE_LENGTH 0x400
    #define SL_EXTERNAL_WRITE  (int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH)
    #define SL_EXTERNAL_CTRL_REG_ADDR  (int32_t *)(EXT_PERIPHERAL_START_ADDRESS + 0x06000 + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
#endif

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif



int main(int argc, char *argv[]){
    
    sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);
    sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR, (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);
    
    for (int i = 0; i < TEST_DATA_LARGE; i++) {
        to_be_sent_4B[i] = i+525;
    }
    

    uint32_t chunks = TEST_DATA_LARGE / DMA_DATA_LARGE;
    uint32_t remainder = TEST_DATA_LARGE % DMA_DATA_LARGE;



    // DMA
    for (uint32_t i = 0; i < chunks; i++) {
        sl_dma_send(
                        to_be_sent_4B  + i * DMA_DATA_LARGE,   
                        SL_EXTERNAL_WRITE,                     
                        DMA_DATA_LARGE);
        sl_dma_read( 
                        copied_data_4B + i * DMA_DATA_LARGE,                       
                        SL_READ,                      
                        DMA_DATA_LARGE);
    }
    if (remainder > 0) {
        sl_dma_send(
                        to_be_sent_4B + chunks * DMA_DATA_LARGE, 
                        SL_EXTERNAL_WRITE,
                        remainder);
        sl_dma_read(
                        copied_data_4B + chunks * DMA_DATA_LARGE,
                        SL_READ,
                        remainder);
    }
    PRINTF("DMA DONE\n"); 

    // CPU
    for (uint32_t i = 0; i < chunks; i++) {
        sl_cpu_send(
                        to_be_sent_4B  + i * DMA_DATA_LARGE,   
                        SL_EXTERNAL_WRITE,                     
                        DMA_DATA_LARGE);
        sl_cpu_read( 
                        copied_data_4B + i * DMA_DATA_LARGE,                       
                        SL_READ,                      
                        DMA_DATA_LARGE);
    }
    if (remainder > 0) {        
        sl_cpu_send(
                        to_be_sent_4B + chunks * DMA_DATA_LARGE, 
                        SL_EXTERNAL_WRITE,
                        remainder);
        sl_cpu_read(
                        copied_data_4B + chunks * DMA_DATA_LARGE,
                        SL_READ,
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





