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

void __attribute__ ((optimize("00"))) axi_isolate(int32_t * addr){
    int32_t *addr_p_reg_ISOLATE_IN = (int32_t *) (addr); // for SL addr = CTRL_REG_ADDR
    *addr_p_reg_ISOLATE_IN &= ~(1<<8);
    int32_t *addr_p_reg_ISOLATE_OUT =(int32_t *)(addr);
    *addr_p_reg_ISOLATE_OUT &= ~(1<<9); // axi_out_isolate
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
