// Copyright 2025 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Description: Example application to test the Serial Link in simulation. Will count the clock cycles to execute a full write read transaction.



#include "serial_link_single_channel_regs.h" 
#include "serial_link_regs.h"
#include "serial_link.h"
#include "serial_link_xheep_wrapper_driver.h"
#include "csr.h"
#include "pad_control.h"
#include "pad_control_regs.h"


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

#define DIRECT_WRITE_TARGET_ADDR 0x00007F00
uint32_t NUM_TO_CHECK = 525;
int main(int argc, char *argv[])
{
    PRINTF("hi i am in receive\n");

    *SL_WRAPPER_DIRECT_READ_ADDR(DIRECT_WRITE_TARGET_ADDR) = 0;

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

    volatile int32_t *addr_p_recreg = SL_READ;
    int32_t rcv_data;
    sl_init((volatile uint32_t *)CTRL_REG_ADDR, (int32_t *)CTRL_REG_ADDR);
    
    sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
    //sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE);
    //PRINTF("rx mode set to direct write, waiting for data...\n");
    PRINTF("rx mode set\n");
    
    PRINTF("waiting for data...\n");
    rcv_data = *addr_p_recreg;
    PRINTF("got data!\n");

    //while(*SL_WRAPPER_DIRECT_READ_ADDR(DIRECT_WRITE_TARGET_ADDR) == 0);
    
    //uint32_t rcv_data = sl_wrapper_direct_read(DIRECT_WRITE_TARGET_ADDR);
    if (rcv_data != NUM_TO_CHECK){
        PRINTF("Received data (%u) does not match expected (%d)\n", rcv_data, NUM_TO_CHECK);
        return EXIT_FAILURE;
    }
    PRINTF("Received data (%u) -> DONE\n", rcv_data);
  
    return EXIT_SUCCESS;
}
