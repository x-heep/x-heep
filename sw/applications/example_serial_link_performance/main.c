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
#include "example_serial_link_performance.h"

#if TARGET_SIM
#error "example_serial_link_performance is FPGA only and cannot be built for simulation."
#endif

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