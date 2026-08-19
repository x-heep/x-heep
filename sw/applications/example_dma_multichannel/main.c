/*
 *  Copyright EPFL contributors.
 *  Licensed under the Apache License, Version 2.0, see LICENSE for details.
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  Author: Tommaso Terzano <tommaso.terzano@epfl.ch>
 *                         <tommaso.terzano@gmail.com>
 *  
 *  Info: Example application of matrix manipulation by exploiting the multichannel feature of the DMA subsystem.
 *        This code is capable of testing the following features:
 *        - Verification of matrix operations carried out by the DMA subsystem
 *        - Performance comparison between the DMA multichannel and the CPU, obtained by performing similar matrix operations
 *          and monitoring the performance counter. 
 *          The performance of the DMA is compared against sequential CPU loops for each operation performed by a single channel.
 *          A typical case in which the DMA could be used to improve the performance is a series of matrix operations, 
 *          like extracting 3 matrices from a larger one.
 *          By exploiting the DMA, these three separate calls can be performed in parallel.
 */

#include <stdio.h>
#include <stdlib.h>
#include "dma.h"
#include "core_v_mini_mcu.h"
#include "x-heep.h"
#include "csr.h"
#include "rv_plic.h"
#include "test_data.h"
#include "w25q128jw.h"

/*   
 *  The following code is designed to test the DMA subsystem multichannel feature. In order to do so, several
 *  tests are available, which are run using some or all of the DMA channels available.
 * 
 *  DISCLAIMER:
 *  When using the default memory configuration (64kB), pay attention to the dimensions of the output matrices.
 *  When executing TEST_ID_3 on QuestaSim, make sure to enable the SPI FLASH.
 * 
 *  Enable one or more of the following tests by defining the correct TEST_ID_* macro:
 *  
 *  0: Extract a NxM matrix, perform optional padding and copy the result to two separate
 *     AxB matrices using N channels at the same time and using direct register writes. 
 *     Additionally, each DMA channel is set with a window of M size. For each window interrupt,
 *     the correct window flag is set.
 * 
 *  1: Extract a NxM matrix, perform optional padding and copy the result to two separate
 *     AxB matrices using N channels at the same time and using HALs. For each transaction interrupt, 
 *     the correct transaction flag is set.
 * 
 *  2: Each DMA channel performs, alternatively, one of the following operations:
 *      - Extract a NxM matrix, perform optional padding and copy the result
 *      - Extract a NxM matrix, perform optional padding, transpose it and copy the result
 * 
 *  3: Extract a NxM matrix, perform optional padding and copy the result to a location using one channel (with HALs), 
 *     while at the same time read a buffer from SPI and copy it to another location using another channel (with HALs).
 *     This test can only be performed on FPGA boards or using QuestaSim, by setting the correct macro (SIM_QUESTASIM).
 *     When executing on QuestaSim, make sure to compile in the correct way:
 *     - Include LINKER=flash_load in "make app ..."
 *     - Add boot_sel: 
 *       'make run PLUSARGS="c firmware=../../../sw/build/main.hex boot_sel=0" '
 *     
 */

#define TEST_ID_0
#define TEST_ID_1
#define TEST_ID_2
#define TEST_ID_3

/* Enable performance analysis */
#define EN_PERF 1

/* Enable verification */
#define EN_VERIF 1

/* Parameters */

/* Size of the extracted matrix (including strides on the input, excluding strides on the outputs) */
#define SIZE_EXTR_D1 10
#define SIZE_EXTR_D2 10

/* Set strides of the input ad output matrix */
#define STRIDE_IN_D1 1
#define STRIDE_IN_D2 1
#define STRIDE_OUT_D1 1
#define STRIDE_OUT_D2 1

/* Set the padding parameters */
#define TOP_PAD 0
#define BOTTOM_PAD 0
#define LEFT_PAD 0
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

/* 
 * Window size for the DMA. Since it has to be > 71 for the ISR to have the time to react,
 * the OUT_DIM_2D has to be big enough. DMA_WINDOW_SIZE is by default set to 80 for good measure.
 */

#define DMA_WINDOW_SIZE 80 

#if defined(TEST_ID_0) && ((OUT_DIM_2D < DMA_WINDOW_SIZE) || (DMA_WINDOW_SIZE < 72))
    #error "In order to correctly execute TEST_ID_0, the matrix output dimension has to be bigger than 72 and bigger than the window dimension.\nCheck these parameters and recompile.\n"
#endif

/* Defines for DMA channels */
#define DMA_CH0_IDX 0
#define DMA_CH1_IDX 1
#define DMA_CH2_IDX 2
#define DMA_CH3_IDX 3

/* Assigning a pointer to a define writes the pointed array in the flash */
#define TEST_DATA_FLASH_PTR test_data_flash

/* Mask for direct register operations example */
#define DMA_CSR_REG_MIE_MASK (( 1 << 30 ) |( 1 << 19 ) | (1 << 11 ))

/* Transposition example def */
#define TRANSPOSITION_EN 1

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
#elif TARGET_PYNQ_Z2 && PRINTF_IN_FPGA
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

/* QuestaSim macro to enable test 4, by default is disabled */
//#define SIM_QUESTASIM

/* Size of FLASH buffer */
#define TEST_DATA_FLASH_SIZE 32

/* Memory allocation for examples */
uint32_t copied_test_data_flash[TEST_DATA_FLASH_SIZE];
dma_input_data_type copied_data_2D_DMA[DMA_CH_NUM][OUT_DIM_2D];
dma_input_data_type copied_data_2D_CPU[DMA_CH_NUM][OUT_DIM_2D];

#if (TARGET_SIM == 0 || defined(TARGET_QUESTASIM))
/* Data for TEST_ID_3 to be stored in the FLASH */
uint32_t __attribute__((section(".xheep_data_flash_only"))) __attribute__ ((aligned (16))) test_data_flash[TEST_DATA_FLASH_SIZE] = {
    105 ,82 ,221 ,172 ,77 ,62,
    81 ,185 ,33 ,213 ,249 ,117,
    69 ,212 ,99 ,137 ,9 ,233,
    107 ,105 ,166 ,141 ,53 ,207,
    53 ,21 ,221 ,102 ,84 ,108,
    43 ,99 ,123 ,71 ,30 ,179
    };

/* Data for TEST_ID_3 to compare the copied data from the FLASH */
uint32_t test_data_flash_golden[TEST_DATA_FLASH_SIZE] = {
    105 ,82 ,221 ,172 ,77 ,62,
    81 ,185 ,33 ,213 ,249 ,117,
    69 ,212 ,99 ,137 ,9 ,233,
    107 ,105 ,166 ,141 ,53 ,207,
    53 ,21 ,221 ,102 ,84 ,108,
    43 ,99 ,123 ,71 ,30 ,179
    };
#endif

/* DMA source, destination and transaction */
dma_target_t tgt_src;
dma_target_t tgt_src_trsp;
dma_target_t tgt_dst[DMA_CH_NUM];
dma_trans_t trans[DMA_CH_NUM];

dma_config_flags_t res_valid, res_load, res_launch;

/* CPU computation variables */
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
uint32_t j_in_last;
uint16_t left_pad_cnt = 0;
uint16_t top_pad_cnt = 0;
uint8_t stride_1d_cnt = 0;
uint8_t stride_2d_cnt = 0;
uint8_t transaction_flag[DMA_CH_NUM];
uint8_t window_flag[DMA_CH_NUM];
char passed = 1;
char flag = 0;

/* Strong transaction ISR implementation */
void dma_intr_handler_trans_done(uint8_t channel)
{
    transaction_flag[channel] = 1;
    return;
}

/* Strong window ISR implementation */
void dma_intr_handler_window_done(uint8_t channel)
{
    window_flag[channel] = 1;
    return;
}

int main()
{

    #ifdef TEST_ID_0

    /* 
     * Testing copy and padding of a NxM matrix using direct register operations.
     * This strategy allows for maximum performance but doesn't perform any checks on the data integrity.
     * The data is copied using N channels to N different memory locations.
     */
    
    #if EN_PERF

    /* Reset the counter to evaluate the performance of the DMA */
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    CSR_WRITE(CSR_REG_MCYCLE, 0);
    #endif

    /* The DMA channels are initialized (i.e. Any current transaction is cleaned.) */
    dma_init(NULL);

    /* Enable global interrupts */
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);

    /* Enable fast interrupts */
    CSR_SET_BITS(CSR_REG_MIE, DMA_CSR_REG_MIE_MASK);

    
    for (int i=0; i<DMA_CH_NUM; i++)
    {
        /* Enable the DMA transaction interrupt logic for every channel */
        write_register(  
                    0x1,
                    DMA_INTERRUPT_EN_REG_OFFSET,
                    0xffff,
                    DMA_INTERRUPT_EN_TRANSACTION_DONE_BIT,
                    dma_peri(i)
                    );

        /* Enable the DMA transaction interrupt logic for every channel */
        write_register(  
                    0x1,
                    DMA_INTERRUPT_EN_REG_OFFSET,
                    0xffff,
                    DMA_INTERRUPT_EN_WINDOW_DONE_BIT,
                    dma_peri(i)
                    );
                    
        /* Pointer set up */
        dma_peri(i)->SRC_PTR = (uintptr_t) &test_data[0];
        dma_peri(i)->DST_PTR = (uintptr_t) &copied_data_2D_DMA[i];

        /* Dimensionality configuration */
        write_register( 0x1,
                        DMA_DIM_CONFIG_REG_OFFSET,
                        0x1,
                        DMA_DIM_CONFIG_DMA_DIM_BIT,
                        dma_peri(i) );

        /* Operation mode configuration */
        write_register( DMA_TRANS_MODE_SINGLE,
                        DMA_MODE_REG_OFFSET,
                        DMA_MODE_MODE_MASK,
                        DMA_MODE_MODE_OFFSET,
                        dma_peri(i) );

        /* Data type configuration */
        write_register(  DMA_DATA_TYPE,
                        DMA_DST_DATA_TYPE_REG_OFFSET,
                        DMA_DST_DATA_TYPE_DATA_TYPE_MASK,
                        DMA_DST_DATA_TYPE_DATA_TYPE_OFFSET,
                        dma_peri(i)  );
    
        write_register(  DMA_DATA_TYPE,
                        DMA_SRC_DATA_TYPE_REG_OFFSET,
                        DMA_SRC_DATA_TYPE_DATA_TYPE_MASK,
                        DMA_SRC_DATA_TYPE_DATA_TYPE_OFFSET,
                        dma_peri(i) );

        /* Set the source strides */
        write_register( SRC_INC_D1 * DMA_DATA_TYPE_2_SIZE(DMA_DATA_TYPE),
                        DMA_SRC_PTR_INC_D1_REG_OFFSET,
                        DMA_SRC_PTR_INC_D1_INC_MASK,
                        DMA_SRC_PTR_INC_D1_INC_OFFSET,
                        dma_peri(i) );
        
        write_register( SRC_INC_D2 * DMA_DATA_TYPE_2_SIZE(DMA_DATA_TYPE),
                        DMA_SRC_PTR_INC_D2_REG_OFFSET,
                        DMA_SRC_PTR_INC_D2_INC_MASK,
                        DMA_SRC_PTR_INC_D2_INC_OFFSET,
                        dma_peri(i) );
        
        write_register( DST_INC_D1 * DMA_DATA_TYPE_2_SIZE( DMA_DATA_TYPE),
                        DMA_DST_PTR_INC_D1_REG_OFFSET,
                        DMA_DST_PTR_INC_D1_INC_MASK,
                        DMA_DST_PTR_INC_D1_INC_OFFSET,
                        dma_peri(i) );
        
        write_register( DST_INC_D2 * DMA_DATA_TYPE_2_SIZE( DMA_DATA_TYPE),
                        DMA_DST_PTR_INC_D2_REG_OFFSET,
                        DMA_DST_PTR_INC_D2_INC_MASK,
                        DMA_DST_PTR_INC_D2_INC_OFFSET,
                        dma_peri(i) );
        
        /* Padding configuration */
        write_register( TOP_PAD,
                        DMA_PAD_TOP_REG_OFFSET,
                        DMA_PAD_TOP_PAD_MASK,
                        DMA_PAD_TOP_PAD_OFFSET,
                        dma_peri(i) );
        
        write_register( RIGHT_PAD,
                        DMA_PAD_RIGHT_REG_OFFSET,
                        DMA_PAD_RIGHT_PAD_MASK,
                        DMA_PAD_RIGHT_PAD_OFFSET,
                        dma_peri(i) );
        
        write_register( LEFT_PAD,
                        DMA_PAD_LEFT_REG_OFFSET,
                        DMA_PAD_LEFT_PAD_MASK,
                        DMA_PAD_LEFT_PAD_OFFSET,
                        dma_peri(i) );
        
        write_register( BOTTOM_PAD,
                        DMA_PAD_BOTTOM_REG_OFFSET,
                        DMA_PAD_BOTTOM_PAD_MASK,
                        DMA_PAD_BOTTOM_PAD_OFFSET,
                        dma_peri(i) );

        /* Set the window size */
        write_register( DMA_WINDOW_SIZE,
                        DMA_WINDOW_SIZE_REG_OFFSET,
                        DMA_WINDOW_SIZE_WINDOW_SIZE_MASK,
                        DMA_WINDOW_SIZE_WINDOW_SIZE_OFFSET,
                        dma_peri(i) );        
    }

    for (int i=0; i<DMA_CH_NUM; i++)
    {
        /* Set the sizes to start the transaction */
        write_register( SIZE_EXTR_D2,
                        DMA_SIZE_D2_REG_OFFSET,
                        DMA_SIZE_D2_SIZE_MASK,
                        DMA_SIZE_D2_SIZE_OFFSET,
                        dma_peri(i) );
        
        write_register( SIZE_EXTR_D1,
                        DMA_SIZE_D1_REG_OFFSET,
                        DMA_SIZE_D1_SIZE_MASK,
                        DMA_SIZE_D1_SIZE_OFFSET,
                        dma_peri(i) );
    }

    /* Wait for CH(N-1) to end */
    while(!dma_is_ready(DMA_CH_NUM-1)) {
        #if !EN_PERF
        /* Disable_interrupts */
        /* This does not prevent waking up the core as this is controlled by the MIP register */
        
        CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
        if ( dma_is_ready(0) == 0 ) {
            wait_for_interrupt();
            /* From here the core wakes up even if we did not jump to the ISR */
        }
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
        #endif
    }

    #if EN_PERF

    /* Read the cycles count after the DMA run */
    CSR_READ(CSR_REG_MCYCLE, &cycles_dma);

    /* Reset the performance counter to evaluate the CPU performance */
    CSR_SET_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    CSR_WRITE(CSR_REG_MCYCLE, 0);
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    #endif

    #if EN_VERIF

    /* Run the same computation on the CPU */
    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        i_in = 0;
        left_pad_cnt = 0;
        top_pad_cnt = 0;
        stride_2d_cnt = 0;

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
                    copied_data_2D_CPU[c][dst_ptr] = 0;
                }
                else
                {
                    copied_data_2D_CPU[c][dst_ptr] = test_data[src_ptr];
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
    }
    
    #endif

    #if EN_PERF

    /* Read the cycles count after the CPU run */
    CSR_READ(CSR_REG_MCYCLE, &cycles_cpu);

    PRINTF("DMA cycles: %d\n\r", cycles_dma);
    PRINTF("CPU cycles: %d \n\r", cycles_cpu);
    #endif

    #if EN_VERIF

    /* Verify that the DMA and the CPU outputs are the same */
    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        for (int i = 0; i < OUT_D2_PAD_STRIDE; i++) {
            for (int j = 0; j < OUT_D1_PAD_STRIDE; j++) {
                if ((copied_data_2D_CPU[c][i * OUT_D1_PAD_STRIDE + j] != copied_data_2D_DMA[c][i * OUT_D1_PAD_STRIDE + j])) 
                {
                    passed = 0;
                }
            }
        }
    }

    /* Verify that the window flags where correctly set */
    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        if (window_flag[c] == 0)
        {
            passed = 0;
        }
    }

    if (passed) {
        PRINTF("Success test 0\n\n\r");
    } 
    else 
    {
        PRINTF("Fail test 0\n\r");
        return EXIT_FAILURE;
    }

    #endif 

    #endif
    
    #ifdef TEST_ID_1

    /* Testing copy and padding of a NxM matrix to two different locations using 2 channels and HALs */
    
    /* Reset for third test */
    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        for (int i = 0; i < OUT_DIM_2D; i++) {
            copied_data_2D_DMA[c][i] = 0;
            copied_data_2D_CPU[c][i] = 0;
        }
    }

    #if EN_PERF

    /* Reset the counter to evaluate the performance of the DMA */
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    CSR_WRITE(CSR_REG_MCYCLE, 0);
    #endif

    dma_init(NULL);

    tgt_src.ptr            = (uint8_t *) test_data;
    tgt_src.inc_d1_du         = SRC_INC_D1;
    tgt_src.inc_d2_du      = SRC_INC_D2;
    tgt_src.trig           = DMA_TRIG_MEMORY;
    tgt_src.type           = DMA_DATA_TYPE;

    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        tgt_dst[c].ptr            = (uint8_t *) copied_data_2D_DMA[c];
        tgt_dst[c].inc_d1_du         = DST_INC_D1;
        tgt_dst[c].inc_d2_du      = DST_INC_D2;
        tgt_dst[c].trig           = DMA_TRIG_MEMORY;

        trans[c].src            = &tgt_src;
        trans[c].dst            = &tgt_dst[c];
        trans[c].size_d1_du     = SIZE_EXTR_D1;
        trans[c].size_d2_du     = SIZE_EXTR_D2;
        trans[c].mode           = DMA_TRANS_MODE_SINGLE;
        trans[c].dim            = DMA_DIM_CONF_2D;
        trans[c].pad_top_du     = TOP_PAD;
        trans[c].pad_bottom_du  = BOTTOM_PAD;
        trans[c].pad_left_du    = LEFT_PAD;
        trans[c].pad_right_du   = RIGHT_PAD;
        trans[c].win_du         = 0;
        trans[c].end            = DMA_TRANS_END_INTR;
        trans[c].channel        = c;
        
        #if EN_PERF

        dma_validate_transaction(&trans[c], DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
        dma_load_transaction(&trans[c]);
        dma_launch(&trans[c]);
        
        #else

        res_valid = dma_validate_transaction(&trans[c], DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
        PRINTF("tran: %u \t%s\n\r", res_valid, res_valid == DMA_CONFIG_OK ?  "Ok!" : "Error!");
        res_load = dma_load_transaction(&trans[c]);
        PRINTF("load: %u \t%s\n\r", res_load, res_load == DMA_CONFIG_OK ?  "Ok!" : "Error!");
        res_launch = dma_launch(&trans[c]);
        PRINTF("laun: %u \t%s\n\r", res_launch, res_launch == DMA_CONFIG_OK ?  "Ok!" : "Error!");
        #endif
    }

    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        #if EN_PERF
        dma_launch(&trans[c]);
        #else
        res_launch = dma_launch(&trans[c]);
        PRINTF("laun: %u \t%s\n\r", res_launch, res_launch == DMA_CONFIG_OK ?  "Ok!" : "Error!");
        #endif
    }

    /* Wait for CH1 to end */
    while(!dma_is_ready(DMA_CH_NUM-1)) {
        #if !EN_PERF
        /* Disable_interrupts */
        /* This does not prevent waking up the core as this is controlled by the MIP register */
        
        CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
        if ( dma_is_ready(0) == 0 ) {
            wait_for_interrupt();
            /* From here the core wakes up even if we did not jump to the ISR */
        }
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
        #endif
    }

    #if EN_PERF    

    /* Read the cycles count after the DMA run */
    CSR_READ(CSR_REG_MCYCLE, &cycles_dma);

    /* Reset the performance counter to evaluate the CPU performance */
    CSR_SET_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    CSR_WRITE(CSR_REG_MCYCLE, 0);
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    #endif

    #if EN_VERIF

    /* Run the same computation on the CPU */
    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        i_in = 0;
        left_pad_cnt = 0;
        top_pad_cnt = 0;
        stride_2d_cnt = 0;

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
                    copied_data_2D_CPU[c][dst_ptr] = 0;
                }
                else
                {
                    copied_data_2D_CPU[c][dst_ptr] = test_data[src_ptr];
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
    }
    #endif

    #if EN_PERF

    /* Read the cycles count after the CPU run */
    CSR_READ(CSR_REG_MCYCLE, &cycles_cpu);
    PRINTF("DMA cycles: %d\n\r", cycles_dma);
    PRINTF("CPU cycles: %d \n\r", cycles_cpu);

    #endif

    #if EN_VERIF

    /* Verify that the DMA and the CPU outputs are the same */
    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        for (int i = 0; i < OUT_D2_PAD_STRIDE; i++) {
            for (int j = 0; j < OUT_D1_PAD_STRIDE; j++) {
                if (copied_data_2D_DMA[c][i * OUT_D1_PAD_STRIDE + j] != copied_data_2D_CPU[c][i * OUT_D1_PAD_STRIDE + j]) 
                {
                    passed = 0;
                }
            }
        }
    }

    /* Verify that the transaction flags where correctly set */
    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        if (transaction_flag[c] == 0)
        {
            passed = 0;
        }
    }

    if (passed) {
        PRINTF("Success test 1\n\n\r");
    } 
    else 
    {
        PRINTF("Fail test 1\n\r");
        return EXIT_FAILURE;
    }
    #endif

    #endif
    
    #ifdef TEST_ID_2
    
    /* Transposing and standard matrix manipulation DMA test */

    /* Reset for third test */
    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        for (int i = 0; i < OUT_DIM_2D; i++) {
            copied_data_2D_DMA[c][i] = 0;
            copied_data_2D_CPU[c][i] = 0;
        }
    }
    
    #if EN_PERF

    /* Reset the counter to evaluate the performance of the DMA */
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    CSR_WRITE(CSR_REG_MCYCLE, 0);
    #endif

    tgt_src.ptr            = (uint8_t *) test_data;
    tgt_src.inc_d1_du         = SRC_INC_D1;
    tgt_src.inc_d2_du      = SRC_INC_D2;
    tgt_src.trig           = DMA_TRIG_MEMORY;
    tgt_src.type           = DMA_DATA_TYPE;

    tgt_src_trsp.ptr            = (uint8_t *) test_data;
    tgt_src_trsp.inc_d1_du         = SRC_INC_TRSP_D1;
    tgt_src_trsp.inc_d2_du      = SRC_INC_TRSP_D2;
    tgt_src_trsp.trig           = DMA_TRIG_MEMORY;
    tgt_src_trsp.type           = DMA_DATA_TYPE;

    dma_init(NULL);

    /* Reset flag to alternate DMA functions */
    flag = 0;

    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        tgt_dst[c].ptr            = (uint8_t *) copied_data_2D_DMA[c];
        tgt_dst[c].inc_d1_du         = DST_INC_D1;
        tgt_dst[c].inc_d2_du      = DST_INC_D2;
        tgt_dst[c].trig           = DMA_TRIG_MEMORY;

        if (flag == 0)
        {
            trans[c].src            = &tgt_src;
            trans[c].dst            = &tgt_dst[c];
            trans[c].size_d1_du     = SIZE_EXTR_D1;
            trans[c].size_d2_du     = SIZE_EXTR_D2;
            trans[c].mode           = DMA_TRANS_MODE_SINGLE;
            trans[c].dim            = DMA_DIM_CONF_2D;
            trans[c].pad_top_du     = TOP_PAD;
            trans[c].pad_bottom_du  = BOTTOM_PAD;
            trans[c].pad_left_du    = LEFT_PAD;
            trans[c].pad_right_du   = RIGHT_PAD;
            trans[c].win_du         = 0;
            trans[c].end            = DMA_TRANS_END_INTR;
            trans[c].channel        = c;
            flag = 1;
        } 
        else
        {
            trans[c].src            = &tgt_src_trsp;
            trans[c].dst            = &tgt_dst[c];
            trans[c].size_d1_du     = SIZE_EXTR_D1;
            trans[c].size_d2_du     = SIZE_EXTR_D2;
            trans[c].mode           = DMA_TRANS_MODE_SINGLE;
            trans[c].dim            = DMA_DIM_CONF_2D;
            trans[c].pad_top_du     = TOP_PAD;
            trans[c].pad_bottom_du  = BOTTOM_PAD;
            trans[c].pad_left_du    = LEFT_PAD;
            trans[c].pad_right_du   = RIGHT_PAD;
            trans[c].win_du         = 0;
            trans[c].end            = DMA_TRANS_END_INTR;
            trans[c].dim_inv        = TRANSPOSITION_EN;
            trans[c].channel        = c;
            flag = 0;
        }
        
        #if EN_PERF

        dma_validate_transaction(&trans[c], DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
        dma_load_transaction(&trans[c]);
        
        #else

        res_valid = dma_validate_transaction(&trans[c], DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
        PRINTF("tran: %u \t%s\n\r", res_valid, res_valid == DMA_CONFIG_OK ?  "Ok!" : "Error!");
        res_load = dma_load_transaction(&trans[c]);
        PRINTF("load: %u \t%s\n\r", res_load, res_load == DMA_CONFIG_OK ?  "Ok!" : "Error!");
        #endif
    }

    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        #if EN_PERF
        dma_launch(&trans[c]);
        #else
        res_launch = dma_launch(&trans[c]);
        PRINTF("laun: %u \t%s\n\r", res_launch, res_launch == DMA_CONFIG_OK ?  "Ok!" : "Error!");
        #endif
    }

    /* Wait for CH(DMA_CH_NUM-1) to end */
    while(!dma_is_ready(DMA_CH_NUM-1)) {
        #if !EN_PERF
        /* Disable_interrupts */
        /* This does not prevent waking up the core as this is controlled by the MIP register */
        
        CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
        if ( dma_is_ready(0) == 0 ) {
            wait_for_interrupt();
            /* From here the core wakes up even if we did not jump to the ISR */
        }
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
        #endif
    }
    

    #if EN_PERF    

    /* Read the cycles count after the DMA run */
    CSR_READ(CSR_REG_MCYCLE, &cycles_dma);

    /* Reset the performance counter to evaluate the CPU performance */
    CSR_SET_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    CSR_WRITE(CSR_REG_MCYCLE, 0);
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    #endif

    #if EN_VERIF

    /* Run the same computation on the CPU */
    flag = 0;
    for (int c=0; c<DMA_CH_NUM; c++)
    { 
        j_in_last = -1;
        stride_2d_cnt = 0;
        left_pad_cnt = 0;
        j_in = 0;
        i_in = 0;
        top_pad_cnt = 0;

        if (flag == 0)
        {
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
                        copied_data_2D_CPU[c][dst_ptr] = 0;
                    }
                    else
                    {
                        copied_data_2D_CPU[c][dst_ptr] = test_data[src_ptr];
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
            flag = 1;
        } 
        else
        {
            for (int i=0; i < OUT_D2_PAD_STRIDE; i++)
            {
                stride_1d_cnt = 0;
                j_in = 0;

                for (int j=0; j < OUT_D1_PAD_STRIDE; j++)
                {
                    dst_ptr = i * OUT_D1_PAD_STRIDE + j;
                    src_ptr = (j_in - left_pad_cnt) * STRIDE_IN_D2 * SIZE_IN_D1 + (i_in - top_pad_cnt ) * STRIDE_IN_D1;
                    if (i_in < TOP_PAD || i_in >= SIZE_EXTR_D2 + TOP_PAD || j_in < LEFT_PAD || j_in >= SIZE_EXTR_D1 + LEFT_PAD ||
                        stride_1d_cnt != 0 || stride_2d_cnt != 0)
                    {
                        copied_data_2D_CPU[c][dst_ptr] = 0;
                    }
                    else
                    {
                        copied_data_2D_CPU[c][dst_ptr] = test_data[src_ptr];
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
            flag = 0;
        }
    }
    
    #endif

    #if EN_PERF

    /* Read the cycles count after the CPU run */
    CSR_READ(CSR_REG_MCYCLE, &cycles_cpu);
    PRINTF("DMA cycles: %d\n\r", cycles_dma);
    PRINTF("CPU cycles: %d \n\r", cycles_cpu);

    #endif

    #if EN_VERIF

    /* Verify that the DMA and the CPU outputs are the same */
    for (int c=0; c<DMA_CH_NUM; c++)
    {
        for (int i = 0; i < OUT_D2_PAD_STRIDE; i++) {
            for (int j = 0; j < OUT_D1_PAD_STRIDE; j++) {
                if (copied_data_2D_DMA[c][i * OUT_D1_PAD_STRIDE + j] != copied_data_2D_CPU[c][i * OUT_D1_PAD_STRIDE + j])
                {
                    passed = 0;
                }
            }
        }
    }

    if (passed) {
        PRINTF("Success test 2\n\n\r");
    } 
    else 
    {
        PRINTF("Fail test 2\n\r");
        return EXIT_FAILURE;
    }
    #endif

    #endif

    #if defined(TEST_ID_3) && (TARGET_SIM == 0 || defined(TARGET_QUESTASIM)) && DMA_CH_NUM > 1

    /* Testing SPI2RAM & RAM2RAM operations on 2 channels */

    /* Reset for fourth test */
    passed = 1;
    i_in = 0;
    j_in = 0;
    left_pad_cnt = 0;
    top_pad_cnt = 0;
    stride_1d_cnt = 0;
    stride_2d_cnt = 0;
    for (int i = 0; i < OUT_DIM_2D; i++) {
        copied_data_2D_DMA[1][i] = 0;
        copied_data_2D_CPU[1][i] = 0;
    }

    #if EN_PERF

    /* Reset the counter to evaluate the performance of the DMA */
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    CSR_WRITE(CSR_REG_MCYCLE, 0);
    #endif

    dma_init(NULL);

    tgt_src.ptr            = (uint8_t *) test_data;
    tgt_src.inc_d1_du         = SRC_INC_D1;
    tgt_src.inc_d2_du      = SRC_INC_D2;
    tgt_src.trig           = DMA_TRIG_MEMORY;
    tgt_src.type           = DMA_DATA_TYPE;

    tgt_dst[1].ptr            = (uint8_t *) copied_data_2D_DMA[1];
    tgt_dst[1].inc_d1_du         = DST_INC_D1;
    tgt_dst[1].inc_d2_du      = DST_INC_D2;
    tgt_dst[1].trig           = DMA_TRIG_MEMORY;

    trans[1].src            = &tgt_src;
    trans[1].dst            = &tgt_dst[1];
    trans[1].size_d1_du     = SIZE_EXTR_D1;
    trans[1].size_d2_du     = SIZE_EXTR_D2;
    trans[1].mode           = DMA_TRANS_MODE_SINGLE;
    trans[1].dim            = DMA_DIM_CONF_2D;
    trans[1].pad_top_du     = TOP_PAD;
    trans[1].pad_bottom_du  = BOTTOM_PAD;
    trans[1].pad_left_du    = LEFT_PAD;
    trans[1].pad_right_du   = RIGHT_PAD;
    trans[1].win_du         = 0;
    trans[1].end            = DMA_TRANS_END_INTR;
    trans[1].channel        = DMA_CH1_IDX;
    trans[1].dim_inv        = 0;
    
    /* Initialize the SPI */
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);

    /* Pick the correct spi device based on simulation type */
    spi_host_t *spi;
    spi = spi_flash;

    /* Init SPI host and SPI<->Flash bridge parameters */
    if (w25q128jw_init(spi) != FLASH_OK)
    {
        PRINTF("Error initializing the flash SPI\n\r");
        return EXIT_FAILURE;
    }

    /* Start the reading process from the SPI, avoiding both sanity checks and waiting for the DMA to finish */
    w25q_error_codes_t status = w25q128jw_read_standard_dma(TEST_DATA_FLASH_PTR, copied_test_data_flash, TEST_DATA_FLASH_SIZE*4, 1, 1);
    if (status != FLASH_OK)
    {
        PRINTF("Error reading from flash\n\r");
        return EXIT_FAILURE;
    }
    
    #if EN_PERF

    dma_validate_transaction(&trans[1], DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    dma_load_transaction(&trans[1]);
    dma_launch(&trans[1]);
    
    #else

    res_valid = dma_validate_transaction(&trans_ch1, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    PRINTF("tran: %u \t%s\n\r", res_valid, res_valid == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    res_load = dma_load_transaction(&trans_ch1);
    PRINTF("load: %u \t%s\n\r", res_load, res_load == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    res_launch = dma_launch(&trans_ch1);
    PRINTF("laun: %u \t%s\n\r", res_launch, res_launch == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    #endif

    /* Wait for CH0 to end, since the SPI will be slower than the DMA */
    while(!dma_is_ready(0)) {
        #if !EN_PERF
        /* Disable_interrupts */
        /* This does not prevent waking up the core as this is controlled by the MIP register */
        
        CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
        if ( dma_is_ready(0) == 0 ) {
            wait_for_interrupt();
            /* From here the core wakes up even if we did not jump to the ISR */
        }
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
        #endif
    }

    #if EN_PERF    

    /* Read the cycles count after the DMA run */
    CSR_READ(CSR_REG_MCYCLE, &cycles_dma);

    /* Reset the performance counter to evaluate the CPU performance */
    CSR_SET_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    CSR_WRITE(CSR_REG_MCYCLE, 0);
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    #endif

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
                copied_data_2D_CPU[1][dst_ptr] = 0;
            }
            else
            {
                copied_data_2D_CPU[1][dst_ptr] = test_data[src_ptr];
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
    #endif

    #if EN_PERF

    /* Read the cycles count after the CPU run */
    CSR_READ(CSR_REG_MCYCLE, &cycles_cpu);
    PRINTF("DMA cycles: %d\n\r", cycles_dma);
    PRINTF("CPU cycles: %d \n\r", cycles_cpu);

    #endif

    #if EN_VERIF

    /* Verify that the DMA and the CPU outputs are the same */
    for (int i = 0; i < OUT_D2_PAD_STRIDE; i++) {
        for (int j = 0; j < OUT_D1_PAD_STRIDE; j++) {
            if ((copied_data_2D_DMA[1][i * OUT_D1_PAD_STRIDE + j] != copied_data_2D_CPU[1][i * OUT_D1_PAD_STRIDE + j])) 
            {
                passed = 0;
            }
        }
    }

    /* Verify that the SPI copy was successful */
    for (int i=0; i < TEST_DATA_FLASH_SIZE; i++)
    {
        if (copied_test_data_flash[i] != test_data_flash_golden[i])
        {
            passed = 0;
        }
    }

    if (passed) {
        PRINTF("Success test 3\n\r");
    } 
    else 
    {
        PRINTF("Fail test 3\n\r");
        return EXIT_FAILURE;
    }
    #endif

    #endif

    return EXIT_SUCCESS;
}