// Copyright 2025 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Description: Example application to test the Serial Link in simulation. Will count the clock cycles to execute a full write read transaction.



#include "serial_link_single_channel_regs.h" 
#include "serial_link_regs.h"
#include "serial_link.h"
#include "csr.h"


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


int32_t NUM_TO_CHECK = 525;
int main(int argc, char *argv[])
{

    volatile int32_t *addr_p_external = SL_EXTERNAL_WRITE;
    volatile int32_t *addr_p_recreg = SL_READ;
    int32_t rcv_data;

    sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);
    sl_init((volatile uint32_t *)SL_EXTERNAL_CTRL_REG_ADDR, (int32_t *)SL_EXTERNAL_CTRL_REG_ADDR);
    
    *addr_p_external = NUM_TO_CHECK;
    rcv_data = *addr_p_recreg;
    if (rcv_data != NUM_TO_CHECK){
        PRINTF("Received data (%u) does not match expected (%d)\n", rcv_data, NUM_TO_CHECK);
        return EXIT_FAILURE;
    }

    PRINTF("DONE\n");
    
    return EXIT_SUCCESS;
}

