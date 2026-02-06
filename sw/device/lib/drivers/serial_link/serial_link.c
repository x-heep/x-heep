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
 * This file provides low-level bring-up and data transfer routines for the
 * Serial Link IP, adapted specifically for SINGLE-CHANNEL configurations.
 *
 * Core responsibilities:
 *  - Wake up the Serial Link by programming configuration registers
 *  - De-assert AXI isolation to enable data transfers
 *  - Provide CPU-based and DMA-based data transmission helpers
 *
 * IMPORTANT:
 *  - INIT() must be called before any SL_CPU_TRANS or SL_DMA_TRANS
 *  - SIM_INIT() must be used only in simulation environments
 *  - Register configuration differs for single vs multi-channel designs
 *
 * AXI isolation and RAW mode behavior are documented in:
 * https://github.com/pulp-platform/serial_link
 */


/* ----------------------------------------------------------------------------
 * Initialization functions
 * ----------------------------------------------------------------------------
 */

/**
 * @brief Initialize Serial Link for SIMULATION.
 *
 * This function performs the full Serial Link bring-up sequence for simulation:
 *  1) Programs the SL configuration registers
 *  2) De-asserts AXI isolation on the SL IP
 *  3) Programs the SL instance located in the simulation testharness
 *
 * SIM_INIT must NOT be used on real hardware or FPGA, as it accesses
 * testharness-only address space.
 */

void __attribute__ ((optimize("00"))) sl_init(volatile uint32_t * addr_reg, int32_t * addr_isolate){
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
    
void __attribute__ ((optimize("00"))) sl_cpu_send(uint32_t *src_d,uint32_t *src,  uint32_t large ){

    for (int i = 0; i < large; i++) {
        *src = *(src_d + i);
    }
}

void __attribute__ ((optimize("00"))) sl_cpu_read(uint32_t *dst_d, uint32_t *dst,  uint32_t large ){
    
    for (int i = 0; i < large; i++) {
        *(dst_d + i) = *dst;
    }
}

void __attribute__ ((optimize("00"))) sl_dma_send(uint32_t *src_d, uint32_t *src,uint32_t large){
    volatile static dma_config_flags_t res;
    volatile static dma_target_t tgt_src_d;
    volatile static dma_target_t tgt_dst_d;
    volatile static dma_trans_t trans;


        dma_init(NULL);
        tgt_src_d.ptr = (uint8_t *)src_d;
        tgt_src_d.inc_d1_du = 1;
        tgt_src_d.trig = DMA_TRIG_MEMORY;
        tgt_src_d.type = DMA_DATA_TYPE_WORD;

        tgt_dst_d.ptr = (uint8_t *)src;
        tgt_dst_d.inc_d1_du = 0;
        tgt_dst_d.trig = DMA_TRIG_MEMORY;
        tgt_dst_d.type = DMA_DATA_TYPE_WORD;

        trans.src = &tgt_src_d;
        trans.dst = &tgt_dst_d;
        trans.size_d1_du = large;
        trans.mode = DMA_TRANS_MODE_SINGLE;
        trans.win_du = 0;
        trans.sign_ext = 0;
        trans.end = DMA_TRANS_END_INTR;

        res |= dma_validate_transaction(&trans, false, false);
        res |= dma_load_transaction(&trans);
        res |= dma_launch(&trans);
        
        if(!dma_is_ready(0)) {
            CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
                    if (!dma_is_ready(0)) {
                        wait_for_interrupt();
                    }
            CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
        }
}

void __attribute__ ((optimize("00"))) sl_dma_read( uint32_t *dst_d, uint32_t *dst,uint32_t large){
    volatile static dma_config_flags_t res;
    volatile static dma_target_t tgt_src_d;
    volatile static dma_target_t tgt_dst_d;
    volatile static dma_trans_t trans;
        dma_init(NULL);
        tgt_src_d.ptr = (uint8_t *)dst;
        tgt_src_d.inc_d1_du = 0;
        tgt_src_d.trig = DMA_TRIG_MEMORY;
        tgt_src_d.type = DMA_DATA_TYPE_WORD;

        tgt_dst_d.ptr = (uint8_t *)dst_d;
        tgt_dst_d.inc_d1_du = 1;
        tgt_dst_d.trig = DMA_TRIG_MEMORY;
        tgt_dst_d.type = DMA_DATA_TYPE_WORD;

        trans.src = &tgt_src_d;
        trans.dst = &tgt_dst_d;
        trans.size_d1_du = large;
        trans.mode = DMA_TRANS_MODE_SINGLE;
        trans.win_du = 0;
        trans.sign_ext = 0;
        trans.end = DMA_TRANS_END_INTR;

        res |= dma_validate_transaction(&trans, false, false);
        res |= dma_load_transaction(&trans);
        res |= dma_launch(&trans);

        if(!dma_is_ready(0)) {
            CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
                    if (!dma_is_ready(0)) {
                        wait_for_interrupt();
                    }
            CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
        }
}