/*
 *  Copyright EPFL contributors.
 *  Licensed under the Apache License, Version 2.0, see LICENSE for details.
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  Author: Tommaso Terzano <tommaso.terzano@epfl.ch>
 *                         <tommaso.terzano@gmail.com>
 *  
 *  Info: Example application of a DMA interaction with a slow memory. The goal is to test the DMA's robustness with an OBI-compliant,
 *        realistic unit.
 */

#include <stdio.h>
#include <stdlib.h>
#include "dma.h"
#include "core_v_mini_mcu.h"
#include "x-heep.h"
#include "csr.h"
#include "rv_plic.h"
#include "test_data.h"
#include "timer_sdk.h"

/*  
 *  This code contains two different tests that can be run by defining the corresponding TEST_ID_* macro.
 *  - Write data to the slow memory with the DMA
 *  - Read data from the slow memory with the DMA
 */

#define TEST_ID_0
#define TEST_ID_1

/* Enable verification */
#define EN_VERIF 1

/* Parameters */

/* Size of the extracted matrix (including strides on the input, excluding strides on the outputs) */
#define SIZE_EXTR_D1 4
#define SIZE_EXTR_D2 3

/* Set strides of the input ad output matrix */
#define STRIDE_IN_D1 1
#define STRIDE_IN_D2 1
#define STRIDE_OUT_D1 1
#define STRIDE_OUT_D2 1

/* Set the padding parameters */
#define TOP_PAD 1
#define BOTTOM_PAD 0
#define LEFT_PAD 1
#define RIGHT_PAD 0

#if !DMA_ZERO_PADDING && (TOP_PAD || BOTTOM_PAD || LEFT_PAD || RIGHT_PAD)
#error("ERROR: DMA Zero Padding logic disabled, change the test parameters!")
#endif

/* Macros for dimensions computation */
#define OUT_D1_PAD ( SIZE_EXTR_D1 + LEFT_PAD + RIGHT_PAD )
#define OUT_D2_PAD ( SIZE_EXTR_D2  + TOP_PAD + BOTTOM_PAD )
#define OUT_D1_PAD_STRIDE ( (OUT_D1_PAD * STRIDE_OUT_D1) - (STRIDE_OUT_D1 - 1)  )
#define OUT_D2_PAD_STRIDE ( (OUT_D2_PAD * STRIDE_OUT_D2) - (STRIDE_OUT_D2 - 1)  )
#define OUT_DIM_1D ( OUT_D1_PAD_STRIDE  )
#define OUT_DIM_2D ( OUT_D1_PAD_STRIDE * OUT_D2_PAD_STRIDE )

/* Enables test format */
#define TEST_EN 1

/* Define the input datatype */
typedef uint32_t dma_input_data_type;

/* Pointer increments computation */
#define SRC_INC_D1 STRIDE_IN_D1
#define DST_INC_D1 STRIDE_OUT_D1
#define SRC_INC_D2 (STRIDE_IN_D2 * SIZE_IN_D1 - (SIZE_EXTR_D1 - 1 + (STRIDE_IN_D1 - 1) * (SIZE_EXTR_D1 - 1)))
#define DST_INC_D2 ((STRIDE_OUT_D2 - 1) * OUT_DIM_1D + 1)
#define SRC_INC_TRSP_D1 SRC_INC_D1
#define SRC_INC_TRSP_D2 (STRIDE_IN_D2 * SIZE_IN_D1)

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

dma_input_data_type copied_data_2D_DMA[OUT_DIM_2D];
dma_input_data_type copied_data_1D_DMA[OUT_DIM_1D];
dma_input_data_type copied_data_2D_CPU[OUT_DIM_2D];
dma_input_data_type copied_data_1D_CPU[OUT_DIM_2D];

dma_config_flags_t res_valid, res_load, res_launch;

dma *peri = dma_peri(0);

dma_target_t tgt_src;
dma_target_t tgt_dst;
dma_trans_t trans;

int* ext_slave_memory = (int*)EXT_SLAVE_START_ADDRESS;
int dma_value = 0;

uint32_t dst_ptr = 0, src_ptr = 0;
uint32_t cycles_dma, cycles_cpu;
uint32_t size_dst_trans_d1;
uint32_t dst_stride_d1;
uint32_t dst_stride_d2;
uint32_t size_src_trans_d1;
uint32_t src_stride_d1;
uint32_t src_stride_d2;
uint32_t i_in;
uint32_t j_in;
uint32_t i_in_last;
uint16_t left_pad_cnt = 0;
uint16_t top_pad_cnt = 0;
uint8_t stride_1d_cnt = 0;
uint8_t stride_2d_cnt = 0;
char passed = 1;

int main()
{    
    #ifdef TEST_ID_0

    /* This test writes data to the slow memory using the DMA */

    tgt_src.ptr = (uint8_t *) test_data;
    tgt_src.inc_d1_du = SRC_INC_D1;
    tgt_src.inc_d2_du = SRC_INC_D2;
    tgt_src.trig = DMA_TRIG_MEMORY;
    tgt_src.type = DMA_DATA_TYPE;
    
    tgt_dst.ptr = (uint8_t *)  EXT_SLAVE_START_ADDRESS;
    tgt_dst.inc_d1_du = DST_INC_D1;
    tgt_dst.inc_d2_du = DST_INC_D2;
    tgt_dst.trig = DMA_TRIG_MEMORY;
    tgt_dst.type = DMA_DATA_TYPE;

    trans.src = &tgt_src;
    trans.dst = &tgt_dst;
    trans.mode = DMA_TRANS_MODE_SINGLE;
    trans.dim = DMA_DIM_CONF_2D;
    trans.size_d1_du     = SIZE_EXTR_D1;
    trans.size_d2_du     = SIZE_EXTR_D2;
    trans.win_du         = 0,
    trans.end            = DMA_TRANS_END_INTR;
    
    #if (DMA_ZERO_PADDING)
    trans.pad_top_du     = TOP_PAD,
    trans.pad_bottom_du  = BOTTOM_PAD,
    trans.pad_left_du    = LEFT_PAD,
    trans.pad_right_du   = RIGHT_PAD,
    #endif

    dma_init(NULL);
    
    timer_start();
    
    #if TEST_EN

    res_valid = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    res_load = dma_load_transaction(&trans);
    res_launch = dma_launch(&trans);
    
    #else

    res_valid = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    PRINTF("tran: %u \t%s\n\r", res_valid, res_valid == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    res_load = dma_load_transaction(&trans);
    PRINTF("load: %u \t%s\n\r", res_load, res_load == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    res_launch = dma_launch(&trans);
    PRINTF("laun: %u \t%s\n\r", res_launch, res_launch == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    #endif

    while( ! dma_is_ready(0)) {
        /* Disable_interrupts */
        /* This does not prevent waking up the core as this is controlled by the MIP register */
        
        CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
        if ( dma_is_ready(0) == 0 ) {
            wait_for_interrupt();
            /* From here the core wakes up even if we did not jump to the ISR */
        }
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    }

    #if EN_VERIF

    /* Run the same computation on the CPU */
    for (int i=0; i < OUT_D2_PAD_STRIDE; i++)
    {
        stride_1d_cnt = 0;
        j_in = 0;

        for (int j=0; j < OUT_D1_PAD_STRIDE; j++)
        {
            dst_ptr = i * OUT_D1_PAD_STRIDE + j;
            src_ptr = (i_in - top_pad_cnt ) * STRIDE_IN_D2 * SIZE_IN_D1 + (j_in - left_pad_cnt) * STRIDE_IN_D1;
            if (i_in < TOP_PAD || i_in >= SIZE_EXTR_D2 + TOP_PAD || j_in < LEFT_PAD || j_in >= SIZE_EXTR_D1 + LEFT_PAD ||
                stride_1d_cnt != 0 || stride_2d_cnt != 0)
            {
                copied_data_2D_CPU[dst_ptr] = 0;
            }
            else
            {
                copied_data_2D_CPU[dst_ptr] = test_data[src_ptr];
            }

            if (j_in < LEFT_PAD && i_in >= TOP_PAD && stride_1d_cnt == 0 && stride_2d_cnt == 0)
            {
                left_pad_cnt++;
            }

            if (stride_1d_cnt == STRIDE_OUT_D1 - 1)
            {
                stride_1d_cnt = 0;
                j_in++;
            }
            else
            {
                stride_1d_cnt++;
            }

        }

        if (i_in < TOP_PAD && stride_2d_cnt == 0)
        {
            top_pad_cnt++;
        }
        
        if (stride_2d_cnt == STRIDE_OUT_D2 - 1)
        {
            stride_2d_cnt = 0;
            i_in++;
        }
        else
        {
            stride_2d_cnt++;
        }

        left_pad_cnt = 0;
    }
    
    /* Verify that the DMA and the CPU outputs are the same,
       i.e. verify that the DMA has correctly written the data
       to the slow memory, including padding & strides.
    */
    for (int i = 0; i < OUT_D2_PAD_STRIDE; i++) {
        for (int j = 0; j < OUT_D1_PAD_STRIDE; j++) {
            dma_value = ext_slave_memory[i * OUT_D1_PAD_STRIDE + j];
            
            if (dma_value != copied_data_2D_CPU[i * OUT_D1_PAD_STRIDE + j]) {
                passed = 0;
            }
        }
    }

    if (passed) {
        #if TEST_EN == 0
        PRINTF("TEST 0 PASSED!\n\r\n\r");
        #else
        PRINTF("0a:%d:0\n\r", cycles_cpu);   
        PRINTF("0b:%d:0\n\r", cycles_dma);               
        #endif
    } 
    else 
    {
        #if TEST_EN == 0
        PRINTF("TEST 0 FAILED\n\r");
        #else
        PRINTF("0a:%d:1\n\r", cycles_cpu); 
        PRINTF("0b:%d:1\n\r", cycles_dma); 
        #endif
        return EXIT_FAILURE;
    }
    #endif

    #endif
    
    /* Reset for second test */
    passed = 1;
    i_in = 0;
    j_in = 0;
    left_pad_cnt = 0;
    top_pad_cnt = 0;
    stride_1d_cnt = 0;
    stride_2d_cnt = 0;

    for (int i = 0; i < OUT_DIM_2D; i++) {
        copied_data_2D_DMA[i] = 0;
        copied_data_2D_CPU[i] = 0;
    }

    #ifdef TEST_ID_1

    /* This test reads data from the slow memory using the DMA */
    
    /* Initialize the slow memory */
    for (int i=0; i < OUT_D2_PAD_STRIDE; i++)
    {
        stride_1d_cnt = 0;
        j_in = 0;

        for (int j=0; j < OUT_D1_PAD_STRIDE; j++)
        {
            dst_ptr = i * OUT_D1_PAD_STRIDE + j;
            src_ptr = (i_in - top_pad_cnt ) * STRIDE_IN_D2 * SIZE_IN_D1 + (j_in - left_pad_cnt) * STRIDE_IN_D1;
            if (i_in < TOP_PAD || i_in >= SIZE_EXTR_D2 + TOP_PAD || j_in < LEFT_PAD || j_in >= SIZE_EXTR_D1 + LEFT_PAD ||
                stride_1d_cnt != 0 || stride_2d_cnt != 0)
            {
                ext_slave_memory[dst_ptr] = 0;
            }
            else
            {
                ext_slave_memory[dst_ptr] = test_data[src_ptr];
            }

            if (j_in < LEFT_PAD && i_in >= TOP_PAD && stride_1d_cnt == 0 && stride_2d_cnt == 0)
            {
                left_pad_cnt++;
            }

            if (stride_1d_cnt == STRIDE_OUT_D1 - 1)
            {
                stride_1d_cnt = 0;
                j_in++;
            }
            else
            {
                stride_1d_cnt++;
            }

        }

        if (i_in < TOP_PAD && stride_2d_cnt == 0)
        {
            top_pad_cnt++;
        }
        
        if (stride_2d_cnt == STRIDE_OUT_D2 - 1)
        {
            stride_2d_cnt = 0;
            i_in++;
        }
        else
        {
            stride_2d_cnt++;
        }

        left_pad_cnt = 0;
    }

    /* Retrieve data from the slow memory using the DMA */
    tgt_src.ptr = (uint8_t *) EXT_SLAVE_START_ADDRESS;
    tgt_src.inc_d1_du = SRC_INC_D1;
    tgt_src.inc_d2_du = SRC_INC_D2;
    tgt_src.trig = DMA_TRIG_MEMORY;
    tgt_src.type = DMA_DATA_TYPE;
    
    tgt_dst.ptr = (uint8_t *)  copied_data_2D_DMA;
    tgt_dst.inc_d1_du = DST_INC_D1;
    tgt_dst.inc_d2_du = DST_INC_D2;
    tgt_dst.trig = DMA_TRIG_MEMORY;
    tgt_dst.type = DMA_DATA_TYPE;

    trans.src = &tgt_src;
    trans.dst = &tgt_dst;
    trans.mode = DMA_TRANS_MODE_SINGLE;
    trans.dim = DMA_DIM_CONF_2D;
    trans.size_d1_du     = SIZE_EXTR_D1;
    trans.size_d2_du     = SIZE_EXTR_D2;
    trans.win_du         = 0,
    trans.end            = DMA_TRANS_END_INTR;
    
    #if (DMA_ZERO_PADDING)
    trans.pad_top_du     = TOP_PAD,
    trans.pad_bottom_du  = BOTTOM_PAD,
    trans.pad_left_du    = LEFT_PAD,
    trans.pad_right_du   = RIGHT_PAD,
    #endif

    dma_init(NULL);
    
    timer_start();
    
    #if TEST_EN

    res_valid = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    res_load = dma_load_transaction(&trans);
    res_launch = dma_launch(&trans);
    
    #else

    res_valid = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    PRINTF("tran: %u \t%s\n\r", res_valid, res_valid == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    res_load = dma_load_transaction(&trans);
    PRINTF("load: %u \t%s\n\r", res_load, res_load == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    res_launch = dma_launch(&trans);
    PRINTF("laun: %u \t%s\n\r", res_launch, res_launch == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    #endif

    while( ! dma_is_ready(0)) {
        /* Disable_interrupts */
        /* This does not prevent waking up the core as this is controlled by the MIP register */
        
        CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
        if ( dma_is_ready(0) == 0 ) {
            wait_for_interrupt();
            /* From here the core wakes up even if we did not jump to the ISR */
        }
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    }

    #if EN_VERIF
    
    /* Verify that the DMA and the CPU outputs are the same */
    for (int i = 0; i < OUT_D2_PAD_STRIDE; i++) {
        for (int j = 0; j < OUT_D1_PAD_STRIDE; j++) {
            if (copied_data_2D_DMA[i * OUT_D1_PAD_STRIDE + j] != copied_data_2D_CPU[i * OUT_D1_PAD_STRIDE + j]) {
              passed = 0;
            }
        }
        PRINTF("\n\r");
    }
    PRINTF("\n\r");

    if (passed) {
        #if TEST_EN == 0
        PRINTF("TEST 0 PASSED!\n\r\n\r");
        #else
        PRINTF("0a:%d:0\n\r", cycles_cpu);   
        PRINTF("0b:%d:0\n\r", cycles_dma);               
        #endif
    } 
    else 
    {
        #if TEST_EN == 0
        PRINTF("TEST 0 FAILED\n\r");
        #else
        PRINTF("0a:%d:1\n\r", cycles_cpu); 
        PRINTF("0b:%d:1\n\r", cycles_dma); 
        #endif
        return EXIT_FAILURE;
    }
    #endif

    #endif

    #if TEST_EN
    PRINTF("&\n\r");
    #endif

    return EXIT_SUCCESS;
}