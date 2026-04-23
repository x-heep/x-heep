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

// Flag set by handler when direct write transfer completes
extern volatile int8_t sl_wrapper_direct_write_intr_flag;

// ============================================================================
// API
// ============================================================================

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

/**
 * @brief Arm the direct write interrupt for an incoming transfer of `count` words.
 * Call after sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE) and
 * before signalling the sender. Fires once when `count` words hit RAM.
 * @param count  Number of words to expect (must match sender's NUM_WORDS)
 */
void sl_wrapper_direct_write_arm(uint32_t count);

/**
 * @brief Default weak IRQ handler for Serial Link direct write done interrupt.
 * Override in your application to handle the interrupt.
 */
void handler_irq_sl_direct_write(uint32_t id);

#endif // SERIAL_LINK_SDK_H