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

#define SL_RAW_REG(offset) \
    ((volatile uint32_t *)(SERIAL_LINK_REG_START_ADDRESS + (offset)))

void __attribute__((optimize("O0"))) sl_raw_mode_enable(uint8_t ch_sel, uint8_t ch_mask) {
    volatile uint32_t *ctrl = (volatile uint32_t *)CTRL_REG_ADDR;

    // Re-assert AXI isolation, raw mode and AXI are mutually exclusive
    *ctrl |= (1u << SERIAL_LINK_SINGLE_CHANNEL_CTRL_AXI_IN_ISOLATE_BIT);
    *ctrl |= (1u << SERIAL_LINK_SINGLE_CHANNEL_CTRL_AXI_OUT_ISOLATE_BIT);

    // Clear TX FIFO before enabling
    sl_raw_mode_tx_clear();

    // Configure RX channel select
    *SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_IN_CH_SEL_REG_OFFSET) = ch_sel;

    // Configure TX channel mask
    *SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_CH_MASK_REG_OFFSET) = ch_mask;

    // Enable raw mode
    *SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_EN_REG_OFFSET) = 1u;

    // Enable TX output, must be held high while sending
    *SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_EN_REG_OFFSET) = 1u;
}

void __attribute__((optimize("O0"))) sl_raw_mode_disable(void) {
    // Disable TX output first, then raw mode
    *SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_EN_REG_OFFSET) = 0u;
    *SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_EN_REG_OFFSET) = 0u;

    // De-assert AXI isolation to restore normal AXI operation
    volatile uint32_t *ctrl = (volatile uint32_t *)CTRL_REG_ADDR;
    *ctrl &= ~(1u << SERIAL_LINK_SINGLE_CHANNEL_CTRL_AXI_IN_ISOLATE_BIT);
    *ctrl &= ~(1u << SERIAL_LINK_SINGLE_CHANNEL_CTRL_AXI_OUT_ISOLATE_BIT);
}

void __attribute__((optimize("O0"))) sl_raw_mode_send_word(uint8_t data) {
    // Wait until TX FIFO has space
    while (sl_raw_mode_tx_full());

    *SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_REG_OFFSET) = data;
}

void __attribute__((optimize("O0"))) sl_raw_mode_send(uint8_t *data, uint32_t count) {
    for (uint32_t i = 0; i < count; i++) {
        sl_raw_mode_send_word(data[i]);
    }
}

uint8_t __attribute__((optimize("O0"))) sl_raw_mode_recv_word(void) {
    // Wait until data is valid on the selected channel
    while (!(*SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_IN_DATA_VALID_REG_OFFSET)));

    // Reading IN_DATA automatically pops the entry (hwre: true in hjson)
    return (uint8_t)(*SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_IN_DATA_REG_OFFSET)
            & SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_IN_DATA_RAW_MODE_IN_DATA_MASK);
}

void __attribute__((optimize("O0"))) sl_raw_mode_recv(uint8_t *dst, uint32_t count) {
    for (uint32_t i = 0; i < count; i++) {
        dst[i] = sl_raw_mode_recv_word();
    }
}

uint8_t __attribute__((optimize("O0"))) sl_raw_mode_tx_full(void) {
    return (*SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_CTRL_REG_OFFSET)
            >> SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_CTRL_IS_FULL_BIT) & 1u;
}

uint8_t __attribute__((optimize("O0"))) sl_raw_mode_tx_fill_state(void) {
    return (*SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_CTRL_REG_OFFSET)
            >> SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_CTRL_FILL_STATE_OFFSET)
           & SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_CTRL_FILL_STATE_MASK;
}

void __attribute__((optimize("O0"))) sl_raw_mode_tx_clear(void) {
    *SL_RAW_REG(SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_CTRL_REG_OFFSET)
        = (1u << SERIAL_LINK_SINGLE_CHANNEL_RAW_MODE_OUT_DATA_FIFO_CTRL_CLEAR_BIT);
}