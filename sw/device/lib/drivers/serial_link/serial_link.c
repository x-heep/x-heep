#include <stdio.h>
#include <stdint.h>
#include "serial_link.h"
#include "serial_link_single_channel_regs.h" 
#include "serial_link_regs.h"

/*
 * ============================================================================
 * Serial Link (SL) driver – single-channel adaptation
 * ============================================================================
 *
 * This file provides low-level bring-up routines for the
 * Serial Link IP, adapted specifically for SINGLE-CHANNEL configurations.
 *
 * Core responsibilities:
 *  - Board-level pad mux configuration 
 *  - Wake up the Serial Link by programming configuration registers
 *  - De-assert AXI isolation to enable data transfers
 *
 * IMPORTANT:
 *  - sl_init() must be called before any sl_cpu_trans or sl_dma_trans
 *  - Register configuration differs for single vs multi-channel designs
 *
 * AXI isolation and RAW mode behavior are documented in:
 * https://github.com/pulp-platform/serial_link
 */

void sl_pad_mux_init(void) {
    pad_control_t pad_control;
    pad_control.base_addr = mmio_region_from_addr((uintptr_t)PAD_CONTROL_START_ADDRESS);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_1_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_2_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_3_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_6_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_7_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_8_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_9_REG_OFFSET),  1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_10_REG_OFFSET), 1);
}

void __attribute__ ((optimize("00"))) sl_init(volatile uint32_t * addr_reg, int32_t * addr_isolate){
    sl_pad_mux_init(); 
    reg_config(addr_reg);
    axi_isolate(addr_isolate);
}

void __attribute__ ((optimize("00"))) reg_config(volatile uint32_t * addr){
    volatile uint32_t * const ctrl = (volatile uint32_t *)addr; // for single channel addr = CTRL_REG_ADDR
    // Step 1: clock enabled, reset asserted (RESET_N = 0)
    *ctrl = CTRL_CLK_EN_MASK;
    // Step 2: clock enabled, reset de-asserted (RESET_N = 1)
    *ctrl = CTRL_CLK_EN_MASK | CTRL_RESET_N_MASK;
}


void __attribute__ ((optimize("00"))) reg_config_multi(void){
    volatile uint32_t * const ctrl = (volatile uint32_t *)CTRL_REG_ADDR_MULTI;
    // Step 1: clock enabled, reset asserted (RESET_N = 0)
    *ctrl = CTRL_CLK_EN_MASK;
    // Step 2: clock enabled, reset de-asserted (RESET_N = 1)
    *ctrl = CTRL_CLK_EN_MASK | CTRL_RESET_N_MASK;
}

void __attribute__ ((optimize("00"))) raw_mode_enable(void){
    int32_t *addr_p_reg_RAW_MODE =(int32_t *)(SERIAL_LINK_REG_START_ADDRESS + SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_EN_REG_OFFSET); 
    *addr_p_reg_RAW_MODE = (*addr_p_reg_RAW_MODE)| 0x00000001; // raw mode en

    int32_t *addr_p_RAW_MODE_IN_CH_SEL_REG =(int32_t *)(SERIAL_LINK_REG_START_ADDRESS + SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_IN_CH_SEL_REG_OFFSET); 

    int32_t *addr_p_RAW_MODE_OUT_CH_MASK_REG =(int32_t *)(SERIAL_LINK_REG_START_ADDRESS + SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_CH_MASK_REG_OFFSET); 
    *addr_p_RAW_MODE_OUT_CH_MASK_REG= (*addr_p_RAW_MODE_OUT_CH_MASK_REG)| 0x00000008; // raw mode mask

    int32_t *addr_p_RAW_MODE_OUT_DATA_FIFO_REG =(int32_t *)(SERIAL_LINK_REG_START_ADDRESS + SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_REG_OFFSET); 
    *addr_p_RAW_MODE_OUT_DATA_FIFO_REG = (*addr_p_RAW_MODE_OUT_DATA_FIFO_REG)| 0x00000001;

    int32_t *addr_p_RAW_MODE_OUT_DATA_FIFO_CTRL_REG =(int32_t *)(SERIAL_LINK_REG_START_ADDRESS + SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_CTRL_REG_OFFSET); 
    *addr_p_RAW_MODE_OUT_DATA_FIFO_CTRL_REG = (*addr_p_RAW_MODE_OUT_DATA_FIFO_CTRL_REG)| 0x00000001;

    int32_t *addr_p_RAW_MODE_OUT_EN_REG =(int32_t *)(SERIAL_LINK_REG_START_ADDRESS + SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_EN_REG_OFFSET); 
    *addr_p_RAW_MODE_OUT_EN_REG = (*addr_p_RAW_MODE_OUT_EN_REG)| 0x00000001; 

    int32_t *addr_p_RAW_MODE_IN_DATA_REG =(int32_t *)(SERIAL_LINK_REG_START_ADDRESS + SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_IN_DATA_REG_OFFSET); 
    *addr_p_RAW_MODE_IN_DATA_REG = (*addr_p_RAW_MODE_IN_DATA_REG)| 0x00000001; 
}

void __attribute__ ((optimize("00"))) axi_isolate(int32_t * addr){
    int32_t *addr_p_reg_ISOLATE_IN = (int32_t *) (addr); // for SL addr = CTRL_REG_ADDR
    *addr_p_reg_ISOLATE_IN &= ~(1<<8);
    int32_t *addr_p_reg_ISOLATE_OUT =(int32_t *)(addr);
    *addr_p_reg_ISOLATE_OUT &= ~(1<<9); // axi_out_isolate
}
    