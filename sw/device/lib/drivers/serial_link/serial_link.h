// Generated register defines for serial_link

// Copyright information found in source file:
// Copyright 2025 EPFL

// Licensing information found in source file:
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "x-heep.h"
#include "core_v_mini_mcu.h"
#include "csr.h"
#include "dma.h"
#include "dma_regs.h"
#include "fast_intr_ctrl.h"
#include "pad_control.h"
#include "pad_control_regs.h"




// ADDRESSING
#define SL_WRITE  (int32_t *)(SERIAL_LINK_START_ADDRESS)
#define SL_READ   (int32_t *)(SERIAL_LINK_RECEIVER_FIFO_START_ADDRESS)

// CFG REGISTERS
#define CTRL_REG_ADDR  (SERIAL_LINK_REG_START_ADDRESS + SERIAL_LINK_SINGLE_CHANNEL_CTRL_REG_OFFSET)
#define CTRL_REG_ADDR_MULTI  (SERIAL_LINK_REG_START_ADDRESS + SERIAL_LINK_CTRL_REG_OFFSET)
#define CTRL_CLK_EN_MASK   (1u << SERIAL_LINK_SINGLE_CHANNEL_CTRL_CLK_ENA_BIT)
#define CTRL_RESET_N_MASK  (1u << SERIAL_LINK_SINGLE_CHANNEL_CTRL_RESET_N_BIT)
 




/**
 * @brief Configure SL control registers (single-channel).
 *
 * This function enables the SL clock and performs a reset sequence:
 *  - Step 1: Clock enabled, reset asserted
 *  - Step 2: Clock enabled, reset de-asserted
 *
 * This is required to bring the SL into a known operational state.
 */
void reg_config(volatile uint32_t * addr);

/**
 * @brief Configure SL control registers (multi-channel variant).
 *
 * Same as REG_CONFIG(), but targeting the multi-channel control register base.
 * This must be used only when the SL is synthesized with multiple channels.
 */
void reg_config_multi(void);

/**
 * @brief Disable AXI isolation for the Serial Link IP.
 *
 * When AXI isolation is enabled, the SL is disconnected from the AXI fabric.
 * This function clears the isolation bits for both AXI input and output,
 * allowing normal memory-mapped accesses and data transfers.
 */
void axi_isolate(int32_t * addr);

/**
 * @brief Configure the pad mux for the Serial Link DDR pins.
 *
 * Muxes GPIOs 1, 2, 3, 6, 7, 8, 9, 10 to the Serial Link DDR function.
 * Called in sl_init(). 
 */
void sl_pad_mux_init(void);

/**
 * @brief Initialize Serial Link for FPGA / silicon.
 *
 * This function wakes up the Serial Link IP by:
 *  - Enabling its clock
 *  - Releasing reset
 *  - Disabling AXI isolation
 *
 * This is the minimal initialization required before using the SL.
 */
void sl_init(volatile uint32_t * addr_reg, int32_t * addr_isolate);

// ============================================================================
// Raw Mode API
// ============================================================================

/**
 * @brief Enable raw mode for single-channel Serial Link.
 *
 * Raw mode bypasses the AXI data link layer entirely, allowing direct
 * 8-bit word transfers over the DDR physical layer with no protocol
 * overhead (no framing, no credits, no flow control).
 *
 * Note: data width is 8 bits (2 * NumLanes = 2 * 4) for this config.
 *
 * This function:
 *  - Re-asserts AXI isolation (raw mode and AXI are mutually exclusive)
 *  - Clears the TX FIFO
 *  - Configures RX channel select and TX channel mask
 *  - Enables raw mode and TX output
 *
 * Must be called after sl_init(). Call sl_raw_mode_disable() to return
 * to normal AXI operation.
 * 
 * RAW mode usage and limitations are documented in the official SL repository.
 *
 * @param ch_sel   RX channel to listen on. Always 0 for this single-channel
 *                 config (1 channel of 4 lanes). Parameter kept for
 *                 compatibility with multi-channel configurations.
 * @param ch_mask  TX channel bitmask. Always 0x1 for this single-channel
 *                 config. Parameter kept for compatibility with
 *                 multi-channel configurations.
 */
void sl_raw_mode_enable(uint8_t ch_sel, uint8_t ch_mask);

/**
 * @brief Disable raw mode and restore normal AXI operation.
 *
 * Disables TX output and raw mode, then de-asserts AXI isolation
 * to restore the normal AXI data path.
 */
void sl_raw_mode_disable(void);

/**
 * @brief Send a single 8-bit word in raw mode.
 *
 * Blocks until the TX FIFO has space before writing.
 * sl_raw_mode_enable() must be called before using this function.
 *
 * @param data  8-bit word to send
 */
void sl_raw_mode_send_word(uint8_t data);

/**
 * @brief Send multiple 8-bit words in raw mode.
 *
 * Calls sl_raw_mode_send_word() for each word sequentially.
 * sl_raw_mode_enable() must be called before using this function.
 *
 * @param data   Pointer to array of 8-bit words
 * @param count  Number of words to send
 */
void sl_raw_mode_send(uint8_t *data, uint32_t count);

/**
 * @brief Receive a single 8-bit word in raw mode.
 *
 * Blocks until data is valid on the selected RX channel.
 * Reading the IN_DATA register automatically pops the entry.
 * sl_raw_mode_enable() must be called before using this function.
 *
 * @return Received 8-bit word
 */
uint8_t sl_raw_mode_recv_word(void);

/**
 * @brief Receive multiple 8-bit words in raw mode.
 *
 * Calls sl_raw_mode_recv_word() for each word sequentially.
 * sl_raw_mode_enable() must be called before using this function.
 *
 * @param dst    Destination buffer (must hold at least count uint8_t)
 * @param count  Number of words to receive
 */
void sl_raw_mode_recv(uint8_t *dst, uint32_t count); 

/**
 * @brief Check if the TX FIFO is full.
 * @return 1 if full, 0 otherwise
 */
uint8_t sl_raw_mode_tx_full(void);

/**
 * @brief Get the current TX FIFO fill state.
 * @return Number of words currently in the TX FIFO (0-8)
 */
uint8_t sl_raw_mode_tx_fill_state(void);

/**
 * @brief Clear the TX FIFO.
 */
void sl_raw_mode_tx_clear(void);
