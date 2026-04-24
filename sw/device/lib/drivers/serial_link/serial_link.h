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
 * @brief Enable RAW mode for single-channel Serial Link.
 *
 * RAW mode allows direct access to the SL input/output data paths,
 * bypassing higher-level protocol layers.
 *
 * This function:
 *  - Enables RAW mode
 *  - Selects the input channel
 *  - Enables output channel masking
 *  - Enables RAW-mode FIFOs and data paths
 *
 * RAW mode usage and limitations are documented in the official SL repository.
 */
void raw_mode_en(void);

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

