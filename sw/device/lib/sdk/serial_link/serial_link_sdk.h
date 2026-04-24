// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: serial_link_sdk.h
// Author: Thomas Tran 
// Date: 24/04/2026
// Description: Serial Link utility functions

#ifndef SERIAL_LINK_SDK_H
#define SERIAL_LINK_SDK_H

#include <stdint.h>
#include "core_v_mini_mcu.h"
#include "dma.h"
#include "csr.h"
#include "rv_plic.h"
#include "serial_link.h"
#include "serial_link_xheep_wrapper_regs.h"
#include "serial_link_xheep_wrapper_driver.h"

// ============================================================================
// Interrupt flags
// ============================================================================

/**
 * Set by dma_intr_handler_trans_done() when the DMA transfer launched by
 * sl_wrapper_dma_read_launch() completes. Poll to detect completion:
 *
 *   sl_wrapper_dma_read_launch(buf, N);
 *   while (!sl_wrapper_dma_intr_flag) { do_useful_work(); }
 *   sl_wrapper_dma_intr_flag = 0;
 */
extern volatile int8_t sl_wrapper_dma_intr_flag;

/**
 * Set by handler_irq_sl_direct_write() when the expected number of direct
 * write words have been committed to RAM. Poll to detect completion:
 *
 *   sl_wrapper_direct_write_arm(N);
 *   while (!sl_wrapper_direct_write_intr_flag) { wait_for_interrupt(); }
 *   sl_wrapper_direct_write_intr_flag = 0;
 */
extern volatile int8_t sl_wrapper_direct_write_intr_flag;

// ============================================================================
// CPU-driven data transfers
// ============================================================================

/**
 * @brief Transmit data using CPU-driven transfers.
 *
 * This function performs a simple, blocking data transfer:
 *  - Writes data from src_d into the SL transmit register (src)
 *  - Reads data from the SL receive register (dst) into dst_d
 *
 * The parameter "large" must not exceed the SL FIFO depth
 * (default FIFO size is 8 entries).
 */
void sl_cpu_send(uint32_t *src_d, uint32_t *src, uint32_t large);
void sl_cpu_read(uint32_t *dst_d, uint32_t *dst, uint32_t large);

// ============================================================================
// DMA-driven data transfers
// ============================================================================
/**
 * @brief Transmit data using the DMA engine.
 *
 * This function performs a two-phase DMA transfer:
 *  1) Memory → SL transmit register
 *  2) SL receive register → Memory
 *
 * DMA is preferred for large transfers or when CPU load must be minimized.
 *
 * The parameter "large" must be less than or equal to the SL FIFO size.
 * See example_serial_link_simulation_dma for usage patterns.
 */
void sl_dma_send(uint32_t *src_d, uint32_t *src, uint32_t large);
void sl_dma_read(uint32_t *dst_d, uint32_t *dst, uint32_t large);
void wait_for_interrupt(void);

// ============================================================================
// HW-triggered DMA receive (FIFO mode)
// ============================================================================

/**
 * @brief Launch a HW-triggered DMA transfer from the Serial Link FIFO to RAM.
 *
 * Returns immediately. The DMA is triggered autonomously by the FIFO
 * not-empty signal (DMA_TRIG_SLOT_SL_FIFO_RX = slot 5), with no CPU
 * involvement per word. Monitor sl_wrapper_dma_intr_flag for completion.
 *
 * Automatically switches to SL_WRAPPER_RX_MODE_FIFO if not already set.
 *
 * @param dst    Destination buffer in RAM (must be 4-byte aligned)
 * @param count  Number of 32-bit words to transfer
 * @return DMA_CONFIG_OK on success, error flag otherwise
 */
dma_config_flags_t sl_wrapper_dma_read_launch(uint32_t *dst, uint32_t count);

// ============================================================================
// Direct write interrupt (direct write mode)
// ============================================================================

/**
 * @brief Arm the PLIC interrupt for an incoming direct write transfer.
 *
 * Programs the DIRECT_WRITE_WORD_COUNT wrapper register, initialises the
 * PLIC, and enables the interrupt. The interrupt fires once when `count`
 * words have been committed to RAM.
 *
 * @param count  Number of words to expect 
 */
void sl_wrapper_direct_write_arm(uint32_t count);

/**
 * @brief Default weak IRQ handler for Serial Link direct write done interrupt.
 * Override in your application to handle the interrupt.
 */
void handler_irq_sl_direct_write(uint32_t id);

#endif // SERIAL_LINK_SDK_H