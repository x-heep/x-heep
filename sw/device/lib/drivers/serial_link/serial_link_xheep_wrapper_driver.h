// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Driver for the serial_link_xheep_wrapper IP.
//
// This wrapper extends the PULP Serial Link with two RX modes:
//
//  - FIFO mode (default): incoming data is stored in a memory-mapped FIFO
//    and read by the CPU via SL_READ (SERIAL_LINK_RECEIVER_FIFO_START_ADDRESS).
//
//  - Direct write mode : incoming AXI transactions are routed
//    through axi_to_mem directly into X-HEEP memory space, bypassing the FIFO.
//    The sender encodes the destination address as an offset within the
//    Serial Link TX window (SERIAL_LINK_START_ADDRESS + dest). The wrapper
//    subtracts AxiAddrOffset so that axi_to_mem writes to dest in the
//    receiver's memory space (RAM, peripherals, or any valid address).


#ifndef SERIAL_LINK_XHEEP_WRAPPER_DRIVER_H
#define SERIAL_LINK_XHEEP_WRAPPER_DRIVER_H

#include <stdint.h>
#include "core_v_mini_mcu.h"
#include "dma.h"
#include "csr.h"
#include "serial_link.h"
#include "serial_link_xheep_wrapper_regs.h"

// ============================================================================
// Address macros
// ============================================================================

/**
 * Wrapper RX mode control register address.
 */
#define SL_WRAPPER_RX_MODE_REG \
    ((volatile uint32_t *)(SERIAL_LINK_WRAPPER_REG_START_ADDRESS + \
     SERIAL_LINK_XHEEP_WRAPPER_RX_MODE_REG_OFFSET))

/**
 * Direct write TX address macro.
 *
 * The CPU writes to SERIAL_LINK_START_ADDRESS + dest_offset.
 * The system bus routes this to the Serial Link TX window.
 * The wrapper's AxiAddrOffset subtracts SERIAL_LINK_START_ADDRESS,
 * so axi_to_mem on the receiver writes to dest_offset in remote RAM.
 *
 * @param dest  Byte offset in the remote chiplet's memory space.
 *              Can target RAM, peripherals, or any valid address.
 *              Range: 0x00000000 to 0x00FFFFFF (16MB window)
 */
#define SL_WRAPPER_DIRECT_WRITE_ADDR(dest) \
    ((volatile uint32_t *)(SERIAL_LINK_START_ADDRESS + (uint32_t)(dest)))

// ============================================================================
// Types
// ============================================================================

/**
 * RX mode selector for the serial_link_xheep_wrapper.
 */
typedef enum {
    SL_WRAPPER_RX_MODE_FIFO         = 0, 
    SL_WRAPPER_RX_MODE_DIRECT_WRITE = 1  
} sl_wrapper_rx_mode_t;

// ============================================================================
// DMA interrupt flag
// ============================================================================

/**
 * Flag set by dma_intr_handler_trans_done() when the DMA transfer launched
 * by sl_wrapper_dma_read_launch() completes. The application can poll this
 * flag directly to interleave useful work with the DMA transfer:
 *
 *   sl_wrapper_dma_read_launch(buf, N);
 *   while (!sl_wrapper_dma_intr_flag) { do_useful_work(); }
 *   sl_wrapper_dma_intr_flag = 0;
 */
extern volatile int8_t sl_wrapper_dma_intr_flag;

// ============================================================================
// API
// ============================================================================

/**
 * @brief Set the RX mode of the Serial Link wrapper.
 *
 * Must be called before sending data. In direct write mode the receiver's
 * axi_to_mem will write incoming data directly to RAM. In FIFO mode the
 * receiver stores data in the FIFO for CPU polling.
 *
 * @param mode  SL_WRAPPER_RX_MODE_FIFO or SL_WRAPPER_RX_MODE_DIRECT_WRITE
 */
void sl_wrapper_set_rx_mode(sl_wrapper_rx_mode_t mode);

/**
 * @brief Get the current RX mode of the Serial Link wrapper.
 *
 * @return SL_WRAPPER_RX_MODE_FIFO or SL_WRAPPER_RX_MODE_DIRECT_WRITE
 */
sl_wrapper_rx_mode_t sl_wrapper_get_rx_mode(void);

/**
 * @brief Write a 32-bit word directly to a destination address on the remote chiplet.
 *
 * The CPU writes to SERIAL_LINK_START_ADDRESS + dest. The AxiAddrOffset
 * parameter in the wrapper subtracts the base address so that axi_to_mem
 * on the receiver writes to dest in the remote chiplet's RAM.
 *
 * The wrapper must be in SL_WRAPPER_RX_MODE_DIRECT_WRITE before calling this.
 *
 * @param dest  Destination byte offset in remote chiplet memory space.
 *              Can address RAM, peripherals, or any valid address within
 *              the 16MB Serial Link TX window (0 to 0x00FFFFFF).
 * @param data  32-bit word to write
 */
void sl_wrapper_direct_write(uint32_t dest, uint32_t data);

/**
 * @brief Write multiple 32-bit words directly to the remote chiplet.
 *
 * Calls sl_wrapper_direct_write for each word sequentially.
 *
 * @param dest   Starting destination byte offset in remote chiplet RAM
 * @param data   Pointer to array of 32-bit words to write
 * @param count  Number of words to write
 */
void sl_wrapper_direct_write_multiple(uint32_t dest, const uint32_t *data, uint32_t count);

/**
 * @brief Configure and launch a HW-triggered DMA transfer from the Serial
 *        Link FIFO to a RAM buffer.
 *
 * Returns immediately after launching, the CPU is free to do other work
 * while the DMA autonomously waits for and transfers data from the FIFO.
 * The DMA transfer is triggered by the FIFO not-empty signal
 * (dma_global_trigger_slots[5] = DMA_TRIG_SLOT_SL_FIFO_RX) with no CPU
 * involvement per word.
 *
 * Monitor sl_wrapper_dma_intr_flag to detect completion:
 *
 *   sl_wrapper_dma_read_launch(buf, N);
 *   while (!sl_wrapper_dma_intr_flag) { do_useful_work(); }
 *   sl_wrapper_dma_intr_flag = 0;
 *
 * The wrapper must be in SL_WRAPPER_RX_MODE_FIFO before calling this.
 * If not, this function will automatically switch to FIFO mode.
 *
 * @param dst    Destination buffer in RAM (must be 4-byte aligned)
 * @param count  Number of 32-bit words to transfer
 * @return DMA_CONFIG_OK on success, error flag otherwise
 */
dma_config_flags_t sl_wrapper_dma_read_launch(uint32_t *dst, uint32_t count);

#endif // SERIAL_LINK_XHEEP_WRAPPER_DRIVER_H