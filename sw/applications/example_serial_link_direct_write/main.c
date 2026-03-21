// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Description: Performance evaluation of Serial Link FIFO vs Direct Write modes.
//              Measures sender-side cycles for 1, 4, 8 words.
//              All printf moved outside cycle measurement windows.

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

#define FPGA_RECEIVE 1

#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   1
#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

#define DIRECT_WRITE_TARGET_ADDR    0x00007F00
#define MAX_WORDS                   32

#if TARGET_SIM
    #define EXT_SLAVE_LENGTH            0x400
    #define SL_EXTERNAL_WRITE           (volatile int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH)
    #define SL_EXTERNAL_CTRL_REG_ADDR   (int32_t *)(EXT_PERIPHERAL_START_ADDRESS + 0x06000 + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
    #define SL_EXTERNAL_DIRECT_WRITE    (int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH + DIRECT_WRITE_TARGET_ADDR)
#endif

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

#if TARGET_SIM
    sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR,
            (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);

    int errors = 0;
    int32_t rcv_data;
    uint32_t cycles_start, cycles_end;
    uint32_t fifo_cycles[NUM_SIZES];
    uint32_t dw_cycles[NUM_SIZES];

    PRINTF("=== Serial Link Performance Evaluation (SIM) ===\n");
    PRINTF("Clock: 125MHz, clk_div=8, DDR clock=~15MHz\n");
    PRINTF("Lanes: 4, Channels: 1\n\n");

    volatile int32_t *addr_p_fifo = SL_READ;

    // =========================================================================
    // TEST 1: FIFO MODE
    // =========================================================================
    PRINTF("--- FIFO Mode ---\n");
    for (int s = 0; s < NUM_SIZES; s++) {
        int n = test_sizes[s];
        sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);

        // Warmup
        *SL_EXTERNAL_WRITE = test_data[0];
        rcv_data = *addr_p_fifo;

        CSR_READ(CSR_REG_MCYCLE, &cycles_start);
        for (int i = 0; i < n; i++) {
            *SL_EXTERNAL_WRITE = test_data[i];
            rcv_data = *addr_p_fifo;
            if (rcv_data != test_data[i]) errors++;
        }
        CSR_READ(CSR_REG_MCYCLE, &cycles_end);
        fifo_cycles[s] = cycles_end - cycles_start;
    }

    // =========================================================================
    // TEST 2: DIRECT WRITE MODE
    // =========================================================================
    PRINTF("--- Direct Write Mode ---\n");
    for (int s = 0; s < NUM_SIZES; s++) {
        int n = test_sizes[s];
        sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
        volatile int32_t *addr_p_direct = (volatile int32_t *)DIRECT_WRITE_TARGET_ADDR;
        volatile int32_t *addr_p_direct_send = SL_EXTERNAL_DIRECT_WRITE;

        // Clear
        for (int i = 0; i < n; i++) addr_p_direct[i] = 0;

        // Warmup
        *(addr_p_direct_send) = test_data[0];
        rcv_data = addr_p_direct[0];
        addr_p_direct[0] = 0;

        CSR_READ(CSR_REG_MCYCLE, &cycles_start);
        for (int i = 0; i < n; i++) {
            *(addr_p_direct_send + i) = test_data[i];
            rcv_data = addr_p_direct[i];
            if (rcv_data != test_data[i]) errors++;
        }
        CSR_READ(CSR_REG_MCYCLE, &cycles_end);
        dw_cycles[s] = cycles_end - cycles_start;
    }

    // =========================================================================
    // RESULTS
    // =========================================================================
    PRINTF("\n=== Results ===\n");
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

#elif FPGA_RECEIVE
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
    for (int s = 0; s < NUM_SIZES; s++) {
        int n = test_sizes[s];
        volatile int32_t *addr_p_fifo = SL_READ;
        sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);

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
    for (int s = 0; s < NUM_SIZES; s++) {
        int n = test_sizes[s];
        sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);

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

// Example version

// // Copyright 2026 EPFL
// // Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// // SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// // Description: Example application to test the Serial Link direct write mode.
// //              Tests both FIFO mode and direct write mode, measuring cycle counts
// //              for each to enable performance comparison 

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

// // 1 = receiver board, 0 = sender board (FPGA only)
// #define FPGA_RECEIVE 1

// /* By default, printfs are activated for FPGA and disabled for simulation. */
// #define PRINTF_IN_FPGA  1
// #define PRINTF_IN_SIM   1

// #if TARGET_SIM && PRINTF_IN_SIM
//     #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
// #elif PRINTF_IN_FPGA && !TARGET_SIM
//     #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
// #else
//     #define PRINTF(...)
// #endif

// #define DIRECT_WRITE_TARGET_ADDR    0x00007F00
// #define NUM_WORDS                   4

// // Simulation only
// #if TARGET_SIM
//     #define EXT_SLAVE_LENGTH            0x400
//     #define SL_EXTERNAL_WRITE           (volatile int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH)
//     #define SL_EXTERNAL_CTRL_REG_ADDR   (int32_t *)(EXT_PERIPHERAL_START_ADDRESS + 0x06000 + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
//     #define SL_EXTERNAL_DIRECT_WRITE    (int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH + DIRECT_WRITE_TARGET_ADDR)
// #endif

// const int32_t test_data[NUM_WORDS] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};

// int main(int argc, char *argv[]) {

//     // PAD MUX configuration
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
    
// #if TARGET_SIM
//     // =========================================================================
//     // SIMULATION: single board loopback test
//     // =========================================================================
    
//     sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR,
//             (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);

//     int errors = 0;
//     int32_t rcv_data;
//     uint32_t cycles_start, cycles_end;

//     PRINTF("=== Serial Link MUX Mode Test (SIM) ===\n");

//     // Test 1: FIFO mode
//     volatile int32_t *addr_p_fifo   = SL_READ;
//     sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
//     CSR_READ(CSR_REG_MCYCLE, &cycles_start);
//     for (int i = 0; i < NUM_WORDS; i++) {
//         *SL_EXTERNAL_WRITE = test_data[i];
//         rcv_data = *addr_p_fifo; 
//         if (rcv_data != test_data[i]) {
//             PRINTF("FIFO ERROR [%d]: got 0x%08x, expected 0x%08x\n", i, rcv_data, test_data[i]);
//             errors++;
//         }
//     }
//     CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//     uint32_t fifo_cycles = cycles_end - cycles_start;

//     // Test 2: Direct write mode
//     sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
//     volatile int32_t *addr_p_direct = (volatile int32_t *)DIRECT_WRITE_TARGET_ADDR;
//     volatile int32_t *addr_p_direct_send = SL_EXTERNAL_DIRECT_WRITE;
//     for (int i = 0; i < NUM_WORDS; i++) addr_p_direct[i] = 0;

//     CSR_READ(CSR_REG_MCYCLE, &cycles_start);
//     for (int i = 0; i < NUM_WORDS; i++) {
//         *(addr_p_direct_send + i) = test_data[i];
//         rcv_data = addr_p_direct[i];
//         if (rcv_data != test_data[i]) {
//             PRINTF("DIRECT WRITE ERROR [%d]: got 0x%08x, expected 0x%08x\n", i, rcv_data, test_data[i]);
//             errors++;
//         }
//     }
//     CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//     uint32_t direct_write_cycles = cycles_end - cycles_start;

//     PRINTF("\n=== Results ===\n");
//     PRINTF("FIFO mode:         %u cycles\n", fifo_cycles);
//     PRINTF("Direct write mode: %u cycles\n", direct_write_cycles);
//     if (direct_write_cycles < fifo_cycles)
//         PRINTF("Direct write is %u cycles faster\n", fifo_cycles - direct_write_cycles);
//     else
//         PRINTF("FIFO is %u cycles faster\n", direct_write_cycles - fifo_cycles);

//     if (errors == 0) {
//         PRINTF("\nDONE - All tests passed\n");
//         return EXIT_SUCCESS;
//     } else {
//         PRINTF("\nFAILED - %d errors\n", errors);
//         return EXIT_FAILURE;
//     }

// #elif FPGA_RECEIVE
//     // =========================================================================
//     // FPGA RECEIVER
//     // =========================================================================
//     int errors = 0;
//     int32_t rcv_data;
//     uint32_t cycles_start, cycles_end;

//     PRINTF("=== Serial Link MUX Mode Test (FPGA RECEIVE) ===\n");

//     // Test 1: FIFO mode
//     PRINTF("--- Test 1: FIFO mode ---\n");
//     sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
//     CSR_READ(CSR_REG_MCYCLE, &cycles_start);
//     for (int i = 0; i < NUM_WORDS; i++) {
//         rcv_data = *SL_READ;
//         if (rcv_data != test_data[i]) {
//             PRINTF("FIFO ERROR [%d]: got 0x%08x, expected 0x%08x\n", i, rcv_data, test_data[i]);
//             errors++;
//         } else {
//             PRINTF("FIFO OK [%d]: 0x%08x\n", i, rcv_data);
//         }
//     }
//     CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//     uint32_t fifo_cycles = cycles_end - cycles_start;

//     // Test 2: Direct write mode
//     PRINTF("--- Test 2: Direct write mode ---\n");
//     sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
//     CSR_READ(CSR_REG_MCYCLE, &cycles_start);
//     for (int i = 0; i < NUM_WORDS; i++) {
//         volatile uint32_t *target = (volatile uint32_t *)(DIRECT_WRITE_TARGET_ADDR + i * 4);
//         *target = 0; // clear before waiting
//         while(*target == 0); // poll until data arrives
//         rcv_data = (int32_t)*target;
//         if (rcv_data != test_data[i]) {
//             PRINTF("DIRECT WRITE ERROR [%d]: got 0x%08x, expected 0x%08x\n", i, rcv_data, test_data[i]);
//             errors++;
//         } else {
//             PRINTF("DIRECT WRITE OK [%d]: 0x%08x\n", i, rcv_data);
//         }
//     }
//     CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//     uint32_t direct_write_cycles = cycles_end - cycles_start;

//     PRINTF("\n=== Cycle Counts ===\n");
//     PRINTF("FIFO mode:         %u cycles\n", fifo_cycles);
//     PRINTF("Direct write mode: %u cycles\n", direct_write_cycles);
//     if (direct_write_cycles < fifo_cycles)
//         PRINTF("Direct write is %u cycles faster\n", fifo_cycles - direct_write_cycles);
//     else
//         PRINTF("FIFO is %u cycles faster\n", direct_write_cycles - fifo_cycles);

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

//     PRINTF("=== Serial Link MUX Mode Test (FPGA SEND) ===\n");

//     // Test 1: FIFO mode
//     PRINTF("--- Test 1: FIFO mode ---\n");
//     CSR_READ(CSR_REG_MCYCLE, &cycles_start);
//     for (int i = 0; i < NUM_WORDS; i++) {
//         *SL_WRITE = test_data[i];
//         PRINTF("FIFO sent [%d]: 0x%08x\n", i, test_data[i]);
//     }
//     CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//     uint32_t fifo_cycles = cycles_end - cycles_start;

//     // Test 2: Direct write mode
//     PRINTF("--- Test 2: Direct write mode ---\n");
//     CSR_READ(CSR_REG_MCYCLE, &cycles_start);
//     for (int i = 0; i < NUM_WORDS; i++) {
//         sl_wrapper_direct_write(DIRECT_WRITE_TARGET_ADDR + i * 4, (uint32_t)test_data[i]);
//         PRINTF("Direct write sent [%d]: 0x%08x\n", i, test_data[i]);
//     }
//     CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//     uint32_t direct_write_cycles = cycles_end - cycles_start;

//     PRINTF("\n=== Cycle Counts ===\n");
//     PRINTF("FIFO mode:         %u cycles\n", fifo_cycles);
//     PRINTF("Direct write mode: %u cycles\n", direct_write_cycles);
//     if (direct_write_cycles < fifo_cycles)
//         PRINTF("Direct write is %u cycles faster\n", fifo_cycles - direct_write_cycles);
//     else
//         PRINTF("FIFO is %u cycles faster\n", direct_write_cycles - fifo_cycles);

//     PRINTF("\nDONE\n");
//     return EXIT_SUCCESS;
// #endif
// }

//Old version 

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

// /* By default, printfs are activated for FPGA and disabled for simulation. */
// #define PRINTF_IN_FPGA  1
// #define PRINTF_IN_SIM   1

// #if TARGET_SIM && PRINTF_IN_SIM
//     #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
// #elif PRINTF_IN_FPGA && !TARGET_SIM
//     #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
// #else
//     #define PRINTF(...)
// #endif

// // Use upper area of RAM0 as direct write target (safe, away from code/data)
// #define DIRECT_WRITE_TARGET_ADDR    0x00007F00

// // simulation only -> Testharness last slave address on the external bus
// #if TARGET_SIM
//     #define EXT_SLAVE_LENGTH            0x400
//     #define SL_EXTERNAL_WRITE           (volatile int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH)
//     #define SL_EXTERNAL_CTRL_REG_ADDR   (int32_t *)(EXT_PERIPHERAL_START_ADDRESS + 0x06000 + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
//     #define SL_EXTERNAL_DIRECT_WRITE    (int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH + DIRECT_WRITE_TARGET_ADDR)
// #endif

// // Test data
// #define NUM_WORDS   4
// const int32_t test_data[NUM_WORDS] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};

// int main(int argc, char *argv[]) {

//     // MUX of the PADS from GPIO to Serial Link
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

//     volatile int32_t *addr_p_fifo   = SL_READ;
//     volatile int32_t *addr_p_direct = (volatile int32_t *)DIRECT_WRITE_TARGET_ADDR;

//     uint32_t cycles_start, cycles_end;
//     uint32_t fifo_cycles, direct_write_cycles;
//     int32_t rcv_data;
//     int errors = 0;

//     // -------------------------------------------------------------------------
//     // Initialize both Serial Link instances
//     // -------------------------------------------------------------------------
//     sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);
// #if TARGET_SIM
//     sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR,
//             (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);
// #endif

//     PRINTF("=== Serial Link MUX Mode Test ===\n");

//     // =========================================================================
//     // TEST 1: FIFO MODE (rx_mode = 0)
//     // =========================================================================

//     sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);

//     CSR_READ(CSR_REG_MCYCLE, &cycles_start);

//     for (int i = 0; i < NUM_WORDS; i++) {
// #if TARGET_SIM
//         *SL_EXTERNAL_WRITE = test_data[i];  // send from external side
// #else
//         *SL_WRITE = test_data[i];           // send from internal Serial Link TX
// #endif
//         rcv_data = *addr_p_fifo;            // CPU reads from FIFO
//         if (rcv_data != test_data[i]) {
//             PRINTF("FIFO ERROR [%d]: got 0x%08x, expected 0x%08x\n",
//                    i, rcv_data, test_data[i]);
//             errors++;
//         }
//     }

//     CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//     fifo_cycles = cycles_end - cycles_start;

//     // =========================================================================
//     // TEST 2: DIRECT WRITE MODE (rx_mode = 1)
//     // =========================================================================

//     sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);

//     // Clear target memory first
//     for (int i = 0; i < NUM_WORDS; i++) {
//         addr_p_direct[i] = 0x00000000;
//     }

//     CSR_READ(CSR_REG_MCYCLE, &cycles_start);

// #if TARGET_SIM
//     volatile int32_t *addr_p_direct_send = SL_EXTERNAL_DIRECT_WRITE;
//     for (int i = 0; i < NUM_WORDS; i++) {
//         *(addr_p_direct_send + i) = test_data[i];
//         rcv_data = addr_p_direct[i];
//         if (rcv_data != test_data[i]) {
//             PRINTF("DIRECT WRITE ERROR [%d]: got 0x%08x, expected 0x%08x\n",
//                    i, rcv_data, test_data[i]);
//             errors++;
//         }
//     }
// #else
//     for (int i = 0; i < NUM_WORDS; i++) {
//         sl_wrapper_direct_write(DIRECT_WRITE_TARGET_ADDR + i * 4, test_data[i]);
//         rcv_data = sl_wrapper_direct_read(DIRECT_WRITE_TARGET_ADDR + i * 4);
//         if (rcv_data != test_data[i]) {
//             PRINTF("DIRECT WRITE ERROR [%d]: got 0x%08x, expected 0x%08x\n",
//                    i, rcv_data, test_data[i]);
//             errors++;
//         }
//     }
// #endif

//     CSR_READ(CSR_REG_MCYCLE, &cycles_end);
//     direct_write_cycles = cycles_end - cycles_start;

//     // =========================================================================
//     // SUMMARY
//     // =========================================================================
//     PRINTF("\n=== Results ===\n");
//     PRINTF("FIFO mode:         %u cycles\n", fifo_cycles);
//     PRINTF("Direct write mode: %u cycles\n", direct_write_cycles);
//     if (direct_write_cycles < fifo_cycles)
//         PRINTF("Direct write is %u cycles faster\n", fifo_cycles - direct_write_cycles);
//     else
//         PRINTF("FIFO is %u cycles faster\n", direct_write_cycles - fifo_cycles);

//     if (errors == 0) {
//         PRINTF("\nDONE - All tests passed\n");
//         return EXIT_SUCCESS;
//     } else {
//         PRINTF("\nFAILED - %d errors\n", errors);
//         return EXIT_FAILURE;
//     }
// }

