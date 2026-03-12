// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Description: Example application to test the Serial Link direct write mode.
//              Tests both FIFO mode and direct write mode, measuring cycle counts
//              for each to enable performance comparison 

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

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   1

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

// Use upper area of RAM0 as direct write target (safe, away from code/data)
#define DIRECT_WRITE_TARGET_ADDR    0x00007F00

// simulation only -> Testharness last slave address on the external bus
#if TARGET_SIM
    #define EXT_SLAVE_LENGTH            0x400
    #define SL_EXTERNAL_WRITE           (volatile int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH)
    #define SL_EXTERNAL_CTRL_REG_ADDR   (int32_t *)(EXT_PERIPHERAL_START_ADDRESS + 0x06000 + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
    #define SL_EXTERNAL_DIRECT_WRITE    (int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH + DIRECT_WRITE_TARGET_ADDR)
#endif

// Test data
#define NUM_WORDS   4
const int32_t test_data[NUM_WORDS] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};

int main(int argc, char *argv[]) {

    // MUX of the PADS from GPIO to Serial Link
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

    volatile int32_t *addr_p_fifo   = SL_READ;
    volatile int32_t *addr_p_direct = (volatile int32_t *)DIRECT_WRITE_TARGET_ADDR;

    uint32_t cycles_start, cycles_end;
    uint32_t fifo_cycles, direct_write_cycles;
    int32_t rcv_data;
    int errors = 0;

    // -------------------------------------------------------------------------
    // Initialize both Serial Link instances
    // -------------------------------------------------------------------------
    sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);
#if TARGET_SIM
    sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR,
            (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);
#endif

    PRINTF("=== Serial Link MUX Mode Test ===\n");

    // =========================================================================
    // TEST 1: FIFO MODE (rx_mode = 0)
    // =========================================================================

    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);

    CSR_READ(CSR_REG_MCYCLE, &cycles_start);

    for (int i = 0; i < NUM_WORDS; i++) {
#if TARGET_SIM
        *SL_EXTERNAL_WRITE = test_data[i];  // send from external side
#else
        *SL_WRITE = test_data[i];           // send from internal Serial Link TX
#endif
        rcv_data = *addr_p_fifo;            // CPU reads from FIFO
        if (rcv_data != test_data[i]) {
            PRINTF("FIFO ERROR [%d]: got 0x%08x, expected 0x%08x\n",
                   i, rcv_data, test_data[i]);
            errors++;
        }
    }

    CSR_READ(CSR_REG_MCYCLE, &cycles_end);
    fifo_cycles = cycles_end - cycles_start;

    // =========================================================================
    // TEST 2: DIRECT WRITE MODE (rx_mode = 1)
    // =========================================================================

    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);

    // Clear target memory first
    for (int i = 0; i < NUM_WORDS; i++) {
        addr_p_direct[i] = 0x00000000;
    }

    CSR_READ(CSR_REG_MCYCLE, &cycles_start);

#if TARGET_SIM
    volatile int32_t *addr_p_direct_send = SL_EXTERNAL_DIRECT_WRITE;
    for (int i = 0; i < NUM_WORDS; i++) {
        *(addr_p_direct_send + i) = test_data[i];
        rcv_data = addr_p_direct[i];
        if (rcv_data != test_data[i]) {
            PRINTF("DIRECT WRITE ERROR [%d]: got 0x%08x, expected 0x%08x\n",
                   i, rcv_data, test_data[i]);
            errors++;
        }
    }
#else
    for (int i = 0; i < NUM_WORDS; i++) {
        sl_wrapper_direct_write(DIRECT_WRITE_TARGET_ADDR + i * 4, test_data[i]);
        rcv_data = sl_wrapper_direct_read(DIRECT_WRITE_TARGET_ADDR + i * 4);
        if (rcv_data != test_data[i]) {
            PRINTF("DIRECT WRITE ERROR [%d]: got 0x%08x, expected 0x%08x\n",
                   i, rcv_data, test_data[i]);
            errors++;
        }
    }
#endif

    CSR_READ(CSR_REG_MCYCLE, &cycles_end);
    direct_write_cycles = cycles_end - cycles_start;

    // =========================================================================
    // SUMMARY
    // =========================================================================
    PRINTF("\n=== Results ===\n");
    PRINTF("FIFO mode:         %u cycles\n", fifo_cycles);
    PRINTF("Direct write mode: %u cycles\n", direct_write_cycles);
    if (direct_write_cycles < fifo_cycles)
        PRINTF("Direct write is %u cycles faster\n", fifo_cycles - direct_write_cycles);
    else
        PRINTF("FIFO is %u cycles faster\n", direct_write_cycles - fifo_cycles);

    if (errors == 0) {
        PRINTF("\nDONE - All tests passed\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("\nFAILED - %d errors\n", errors);
        return EXIT_FAILURE;
    }
}

// Old verion without driver : 

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
// #include "serial_link_xheep_wrapper_regs.h"
// #include "core_v_mini_mcu.h"
// #include "csr.h"

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

// // simulation only -> Testharness last slave address on the external bus (size of the Slow memory in testharness pkg))
// #if TARGET_SIM
//     #define EXT_SLAVE_LENGTH            0x400
//     #define SL_EXTERNAL_WRITE           (int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH)
//     #define SL_EXTERNAL_CTRL_REG_ADDR   (int32_t *)(EXT_PERIPHERAL_START_ADDRESS + 0x06000 + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
// #endif

// // Wrapper mode register address
// #define SL_WRAPPER_RX_MODE_ADDR \
//     (volatile uint32_t *)(SERIAL_LINK_WRAPPER_REG_START_ADDRESS + SERIAL_LINK_XHEEP_WRAPPER_RX_MODE_REG_OFFSET)
// // Use upper area of RAM0 as direct write target (safe, away from code/data)
// #define DIRECT_WRITE_TARGET_ADDR    (int32_t *)(0x00007F00)
// #define SL_EXTERNAL_DIRECT_WRITE    (int32_t *)(EXT_SLAVE_START_ADDRESS + EXT_SLAVE_LENGTH + 0x7F00)

// // Test data
// #define NUM_WORDS   4
// const int32_t test_data[NUM_WORDS] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};

// int main(int argc, char *argv[]) {

//     volatile int32_t *addr_p_external = SL_EXTERNAL_WRITE;
//     volatile int32_t *addr_p_fifo     = SL_READ;
//     volatile int32_t *addr_p_direct   = DIRECT_WRITE_TARGET_ADDR;
//     volatile uint32_t *rx_mode_reg    = SL_WRAPPER_RX_MODE_ADDR;

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

//     // Set rx_mode = 0 (FIFO)
//     *rx_mode_reg &= ~(1u << SERIAL_LINK_XHEEP_WRAPPER_RX_MODE_DIRECT_WRITE_EN_BIT);

//     CSR_READ(CSR_REG_MCYCLE, &cycles_start);

//     for (int i = 0; i < NUM_WORDS; i++) {
//         *addr_p_external = test_data[i];  // send from external side
//         rcv_data = *addr_p_fifo;          // CPU reads from FIFO
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

//     // Set rx_mode = 1 (direct write)
//     *rx_mode_reg |= (1u << SERIAL_LINK_XHEEP_WRAPPER_RX_MODE_DIRECT_WRITE_EN_BIT);

//     // Clear target memory first
//     for (int i = 0; i < NUM_WORDS; i++) {
//         addr_p_direct[i] = 0x00000000;
//     }

//     CSR_READ(CSR_REG_MCYCLE, &cycles_start);

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
