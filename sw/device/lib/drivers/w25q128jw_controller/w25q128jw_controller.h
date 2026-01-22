/**
 * @file w25q128jw_controller.h
 * @brief Driver for the W25Q128JW flash controller.
 *
 * This driver provides an interface to control the W25Q128JW flash memory
 * controller, which handles read and write operations to the SPI
 * flash memory. The controller supports both polling and interrupt-based
 * completion detection.
 */

#ifndef W25Q128JW_CONTROLLER_H
#define W25Q128JW_CONTROLLER_H

#include <stdint.h>

// ============== POLLING ==============

/**
 * Checks if the controller is ready (polling mode).
 *
 * This function reads the status register to determine if the controller
 * has completed its current operation.
 *
 * @return 1 if the controller is ready, 0 otherwise.
 */
uint32_t w25q128jw_controller_is_ready_polling(void);

// ============== INTERRUPT ==============

/**
 * Checks if the controller operation is complete (interrupt mode).
 *
 * This function checks a done flag which is set by the
 * interrupt handler when an operation completes.
 *
 * @return 1 if the operation is complete, 0 otherwise.
 */
uint32_t w25q128jw_controller_is_ready_intr(void);

/**
 * Interrupt handler for the W25Q128JW controller.
 *
 * Called by the PLIC when the controller raises an
 * interrupt. Declared as weak so it can be overridden by the application.
 *
 * @param id The interrupt ID from the PLIC.
 */
__attribute__((weak, optimize("O0"))) void handler_irq_w25q128jw_controller(uint32_t id);

/**
 * Clears the internal done flag.
 *
 * This function should be called before/after starting a new operation
 * when using interrupt-based completion detection.
 */
void w25q128jw_controller_clear_done_flag();

/**
 * Sets the internal done flag.
 *
 * This function is typically called by the interrupt handler to
 * signal that an operation has completed.
 */
void w25q128jw_controller_set_done_flag();

/**
 * Clear the interrupt status flag.
 */
void w25q128jw_controller_clear_status_register();

/**
 * Enable interrupts (1 enable, 0 not enable).
 */
void w25q128jw_controller_enable_interrupt(uint32_t intr_enable);

// ============== OPERATION ==============
/**
 * @param dest Pointer to the on-chip SRAM
 * @param src  Pointer to the Flash
 * @param length_bytes Number of bytes to transfer.
 */
void w25q128jw_controller_read(void* dest, void* src, size_t length_bytes);

/**
 * @param dest Pointer to the Flash
 * @param src  Pointer to the on-chip SRAM
 * @param length_bytes Number of bytes to transfer.
 */
void w25q128jw_controller_write(void* dest, void* src, size_t length_bytes);

/**
 * @brief This function sets the DMA_SLOT_WAIT_COUNTER so that the DMA
 * waits the given cycles before sending another request to its slot target.
*/
void w25q128jw_set_dma_slot_wait_counter(uint32_t slot_wait_counter);

#endif // W25Q128JW_CONTROLLER_H