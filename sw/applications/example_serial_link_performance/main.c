// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Description: Performance evaluation of Serial Link FIFO vs Direct Write modes.
//              Measures sender-side cycles for 1, 4, 8, 16, 32 words.

#include <stdio.h>
#include <stdlib.h>
#include "serial_link_single_channel_regs.h"
#include "serial_link_regs.h"
#include "serial_link.h"
#include "serial_link_xheep_wrapper_driver.h"
#include "core_v_mini_mcu.h"
#include "csr.h"
#include "pad_control.h"
#include "pad_control_regs.h"

// 1 = receiver board, 0 = sender board 
#define FPGA_RECEIVE 1

#define PRINTF_IN_FPGA  1

#if PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

#define DIRECT_WRITE_TARGET_ADDR    0x0000F800
#define MAX_WORDS                   32

const int32_t test_data[MAX_WORDS] = {
    0x11111111, 0x22222222, 0x33333333, 0x44444444,
    0x55555555, 0x66666666, 0x77777777, 0x88888888,
    0x99999999, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC,
    0xDDDDDDDD, 0xEEEEEEEE, 0xFFFFFFFF, 0x12345678,
    0x11111111, 0x22222222, 0x33333333, 0x44444444,
    0x55555555, 0x66666666, 0x77777777, 0x88888888,
    0x99999999, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC,
    0xDDDDDDDD, 0xEEEEEEEE, 0xFFFFFFFF, 0x12345678
};

// Word counts to test
const int test_sizes[] = {1, 4, 8, 16, 32};
#define NUM_SIZES 5

int main(int argc, char *argv[]) {

    pad_control_t pad_control;
    pad_control.base_addr = mmio_region_from_addr((uintptr_t)PAD_CONTROL_START_ADDRESS);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_1_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_2_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_3_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_6_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_7_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_8_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_9_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_10_REG_OFFSET), 1);

    sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);

#if FPGA_RECEIVE
    // =========================================================================
    // FPGA RECEIVER
    // =========================================================================
    int errors = 0;
    int32_t rcv_data;
    uint32_t cycles_start, cycles_end;
    uint32_t fifo_cycles[NUM_SIZES];
    uint32_t dw_cycles[NUM_SIZES];

    PRINTF("=== Serial Link Performance Evaluation (FPGA RECEIVE) ===\n");

    // Test 1: FIFO mode
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
    for (int s = 0; s < NUM_SIZES; s++) {
        int n = test_sizes[s];
        volatile int32_t *addr_p_fifo = SL_READ;
        
        // Warmup - consume dummy word sent by sender before test
        rcv_data = *addr_p_fifo;  // not measured

        CSR_READ(CSR_REG_MCYCLE, &cycles_start);
        for (int i = 0; i < n; i++) {
            rcv_data = *addr_p_fifo;
            if (rcv_data != test_data[i]) errors++;
        }
        CSR_READ(CSR_REG_MCYCLE, &cycles_end);
        fifo_cycles[s] = cycles_end - cycles_start;
    }

    // Test 2: Direct write mode
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
    for (int s = 0; s < NUM_SIZES; s++) {
        int n = test_sizes[s];
        
        // Clear all targets
        for (int i = 0; i < n; i++)
            *(volatile uint32_t *)(DIRECT_WRITE_TARGET_ADDR + i * 4) = 0;

        CSR_READ(CSR_REG_MCYCLE, &cycles_start);
        for (int i = 0; i < n; i++) {
            volatile uint32_t *target = (volatile uint32_t *)(DIRECT_WRITE_TARGET_ADDR + i * 4);
            while(*target == 0);
            if ((int32_t)*target != test_data[i]) errors++;
        }
        CSR_READ(CSR_REG_MCYCLE, &cycles_end);
        dw_cycles[s] = cycles_end - cycles_start;
    }

    // Print results
    PRINTF("\n=== Receiver Cycle Counts ===\n");
    PRINTF("Words | FIFO cycles | FIFO cyc/word | DW cycles | DW cyc/word\n");
    PRINTF("------|-------------|---------------|-----------|------------\n");
    for (int s = 0; s < NUM_SIZES; s++) {
        int n = test_sizes[s];
        PRINTF("%5d | %11u | %13u | %9u | %11u\n",
               n,
               fifo_cycles[s], fifo_cycles[s] / n,
               dw_cycles[s],   dw_cycles[s] / n);
    }

    if (errors == 0) {
        PRINTF("\nDONE - All tests passed\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("\nFAILED - %d errors\n", errors);
        return EXIT_FAILURE;
    }

#else
    // =========================================================================
    // FPGA SENDER
    // =========================================================================
    uint32_t cycles_start, cycles_end;
    uint32_t fifo_cycles[NUM_SIZES];
    uint32_t dw_cycles[NUM_SIZES];

    PRINTF("=== Serial Link Performance Evaluation (FPGA SEND) ===\n");

    // Test 1: FIFO mode 
    for (int s = 0; s < NUM_SIZES; s++) {
        int n = test_sizes[s];

        *SL_WRITE = 0xDEADBEEF; // dummy word, receiver will discard 

        CSR_READ(CSR_REG_MCYCLE, &cycles_start);
        for (int i = 0; i < n; i++) {
            *SL_WRITE = test_data[i];
        }
        CSR_READ(CSR_REG_MCYCLE, &cycles_end);
        fifo_cycles[s] = cycles_end - cycles_start;
    }

    // Test 2: Direct write mode
    for (int s = 0; s < NUM_SIZES; s++) {
        int n = test_sizes[s];

        CSR_READ(CSR_REG_MCYCLE, &cycles_start);
        for (int i = 0; i < n; i++) {
            sl_wrapper_direct_write(DIRECT_WRITE_TARGET_ADDR + i * 4,
                                    (uint32_t)test_data[i]);
        }
        CSR_READ(CSR_REG_MCYCLE, &cycles_end);
        dw_cycles[s] = cycles_end - cycles_start;
    }

    // Print results after all measurements
    PRINTF("Words | FIFO cycles | FIFO cyc/word | DW cycles | DW cyc/word\n");
    PRINTF("------|-------------|---------------|-----------|------------\n");
    for (int s = 0; s < NUM_SIZES; s++) {
        int n = test_sizes[s];
        PRINTF("%5d | %11u | %13u | %9u | %11u\n",
               n,
               fifo_cycles[s], fifo_cycles[s] / n,
               dw_cycles[s],   dw_cycles[s] / n);
    }

    PRINTF("\nDONE\n");
    return EXIT_SUCCESS;
#endif
}


// // Copyright 2026 EPFL
// // Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// // SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// // Description: Performance evaluation of Serial Link FIFO vs Direct Write modes.
// //              Measures sender-side cycles for 1, 4, 8 words.
// //              All printf moved outside cycle measurement windows.

// #include <stdio.h>
// #include <stdlib.h>
// #include "serial_link_single_channel_regs.h"
// #include "serial_link_regs.h"
// #include "serial_link.h"
// #include "serial_link_xheep_wrapper_driver.h"
// #include "core_v_mini_mcu.h"
// #include "csr.h"
// #include "pad_control.h"
// #include "pad_control_regs.h"

// #define FPGA_RECEIVE 1

// #define PRINTF_IN_FPGA  1
// #define PRINTF_IN_SIM   1
// #if TARGET_SIM && PRINTF_IN_SIM
//     #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
// #elif PRINTF_IN_FPGA && !TARGET_SIM
//     #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
// #else
//     #define PRINTF(...)
// #endif

// #define DIRECT_WRITE_TARGET_ADDR    0x0000F800
// #define MAX_WORDS                   32

// #define SYNC_ADDR                   0x00007F00
// #define READY                       0x00000001

// const int32_t test_data[MAX_WORDS] = {
//     0x11111111, 0x22222222, 0x33333333, 0x44444444,
//     0x55555555, 0x66666666, 0x77777777, 0x88888888,
//     0x99999999, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC,
//     0xDDDDDDDD, 0xEEEEEEEE, 0xFFFFFFFF, 0x12345678,
//     0x11111111, 0x22222222, 0x33333333, 0x44444444,
//     0x55555555, 0x66666666, 0x77777777, 0x88888888,
//     0x99999999, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC,
//     0xDDDDDDDD, 0xEEEEEEEE, 0xFFFFFFFF, 0x12345678
// };

// // Word counts to test
// const int test_sizes[] = {1, 4, 8, 16, 32};
// #define NUM_SIZES 5

// static uint32_t dma_buffer[MAX_WORDS] __attribute__((aligned(4))) = {0};

// int main(int argc, char *argv[]) {

//     pad_control_t pad_control;
//     pad_control.base_addr = mmio_region_from_addr((uintptr_t)PAD_CONTROL_START_ADDRESS);
//     pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_1_REG_OFFSET), 1);
//     pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_2_REG_OFFSET), 1);
//     pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_3_REG_OFFSET), 1);
//     pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_6_REG_OFFSET), 1);
//     pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_7_REG_OFFSET), 1);
//     pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_8_REG_OFFSET), 1);
//     pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_9_REG_OFFSET), 1);
//     pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_10_REG_OFFSET), 1);

//     sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);

// #if FPGA_RECEIVE
//     // =========================================================================
//     // FPGA RECEIVER
//     // =========================================================================
//     int errors = 0;
//     int32_t rcv_data;
//     uint32_t cycles_start, cycles_end;
//     uint32_t fifo_cycles[NUM_SIZES];
//     uint32_t dw_cycles[NUM_SIZES];

//     PRINTF("=== Serial Link Performance Evaluation (FPGA RECEIVE) ===\n");

//     sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
//     // Test 1: FIFO mode
//     for (int s = 0; s < NUM_SIZES; s++) {
//         int n = test_sizes[s];
//         volatile int32_t *addr_p_fifo = SL_READ;

//         // Warmup - consume dummy word sent by sender before test
//         rcv_data = *addr_p_fifo;  // not measured

//         CSR_READ(CSR_REG_MCYCLE, &cycles_start);
//         for (int i = 0; i < n; i++) {
//             rcv_data = *addr_p_fifo;
//             if (rcv_data != test_data[i]) errors++;
//         }
//         CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//         fifo_cycles[s] = cycles_end - cycles_start;
//     }

//     sl_wrapper_direct_write(SYNC_ADDR, READY);

//     // Test 2: Direct write mode
//     sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
//     for (int i = 0; i < MAX_WORDS; i++)
//             *(volatile uint32_t *)(DIRECT_WRITE_TARGET_ADDR + i * 4) = 0;
   
//     for (int s = 0; s < NUM_SIZES; s++) {
//         int n = test_sizes[s];

//         // Clear all targets
//         // for (int i = 0; i < n; i++)
//         //     *(volatile uint32_t *)(DIRECT_WRITE_TARGET_ADDR + i * 4) = 0;

//         CSR_READ(CSR_REG_MCYCLE, &cycles_start);
//         for (int i = 0; i < n; i++) {
//             volatile uint32_t *target = (volatile uint32_t *)(DIRECT_WRITE_TARGET_ADDR + i * 4);
//             while(*target == 0);
//             if ((int32_t)*target != test_data[i]) errors++;
//         }
//         CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//         dw_cycles[s] = cycles_end - cycles_start;
//     }

//     sl_wrapper_direct_write(SYNC_ADDR, READY);

//     // Test 3: DMA mode
//     sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
//     for (int s = 0; s < NUM_SIZES; s++) {
//         int n = test_sizes[s];
//         volatile int32_t *addr_p_fifo = SL_READ;
        
//         // Warmup - consume dummy word sent by sender before test
//         rcv_data = *addr_p_fifo;  // not measured

//         for (int i = 0; i < n; i++) dma_buffer[i] = 0;

//         sl_dma_read(dma_buffer, (uint32_t *)SL_READ, n);
    
//         for (int i = 0; i < n; i++) {
//             if (dma_buffer[i] != (uint32_t)test_data[i]) errors++;
//         }

//     }

//     // Print results
//     PRINTF("\n=== Receiver Cycle Counts ===\n");
//     PRINTF("Words | FIFO cycles | FIFO cyc/word | DW cycles | DW cyc/word\n");
//     PRINTF("------|-------------|---------------|-----------|------------\n");
//     for (int s = 0; s < NUM_SIZES; s++) {
//         int n = test_sizes[s];
//         PRINTF("%5d | %11u | %13u | %9u | %11u\n",
//                n,
//                fifo_cycles[s], fifo_cycles[s] / n,
//                dw_cycles[s],   dw_cycles[s] / n);
//     }

//     if (errors == 0) {
//         PRINTF("\nDONE - All tests passed\n");
//         return EXIT_SUCCESS;
//     } else {
//         PRINTF("\nFAILED - %d errors\n", errors);
//         return EXIT_FAILURE;
//     }

// #else
//     // =========================================================================
//     // FPGA SENDER
//     // =========================================================================
//     uint32_t cycles_start, cycles_end;
//     uint32_t fifo_cycles[NUM_SIZES];
//     uint32_t dw_cycles[NUM_SIZES];

//     sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
//     volatile uint32_t *ready = (volatile uint32_t *)SYNC_ADDR;

//     PRINTF("=== Serial Link Performance Evaluation (FPGA SEND) ===\n");

//     // Test 1: FIFO mode 
//     for (int s = 0; s < NUM_SIZES; s++) {
//         int n = test_sizes[s];

//         *SL_WRITE = 0xDEADBEEF; // dummy word, receiver will discard 

//         CSR_READ(CSR_REG_MCYCLE, &cycles_start);
//         for (int i = 0; i < n; i++) {
//             *SL_WRITE = test_data[i];
//         }
//         CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//         fifo_cycles[s] = cycles_end - cycles_start;
//     }

//     //for (int i = 0; i < 10000; i++);
    
//     while(*ready != READY);
//     *ready = 0; // clear for next sync

//     // Test 2: Direct write mode
//     for (int s = 0; s < NUM_SIZES; s++) {
//         int n = test_sizes[s];

//         CSR_READ(CSR_REG_MCYCLE, &cycles_start);
//         for (int i = 0; i < n; i++) {
//             sl_wrapper_direct_write(DIRECT_WRITE_TARGET_ADDR + i * 4,
//                                     (uint32_t)test_data[i]);
//         }
//         CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//         dw_cycles[s] = cycles_end - cycles_start;
//     }

//     //for (int i = 0; i < 10000; i++); 

//     while(*ready != READY);
//     *ready = 0; // clear for next sync

//     // Test 3: FIFO mode with dma  
//     for (int s = 0; s < NUM_SIZES; s++) {
//         int n = test_sizes[s];

//         *SL_WRITE = 0xDEADBEEF; // dummy word, receiver will discard 

//         sl_dma_send((uint32_t *)test_data, (uint32_t *)SL_WRITE, n);
//     }

//     // Print results after all measurements
//     PRINTF("Words | FIFO cycles | FIFO cyc/word | DW cycles | DW cyc/word\n");
//     PRINTF("------|-------------|---------------|-----------|------------\n");
//     for (int s = 0; s < NUM_SIZES; s++) {
//         int n = test_sizes[s];
//         PRINTF("%5d | %11u | %13u | %9u | %11u\n",
//                n,
//                fifo_cycles[s], fifo_cycles[s] / n,
//                dw_cycles[s],   dw_cycles[s] / n);
//     }

//     PRINTF("\nDONE\n");
//     return EXIT_SUCCESS;
// #endif
// }