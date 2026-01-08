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
__attribute__((optimize("O0"))) void w25q128jw_controller_clear_done_flag();

/**
 * Sets the internal done flag.
 *
 * This function is typically called by the interrupt handler to
 * signal that an operation has completed.
 */
__attribute__((optimize("O0"))) void w25q128jw_controller_set_done_flag();

// ============== OPERATION ==============

/**
 * This function initiates a transfer between RAM and flash memory W25Q128JW.
 *
 * For a read operation (rnw=1):
 *   - Data is read from flash at `flash_address`
 *   - Data is written to RAM at `ram_buffer`
 *   - `ram_w_new_data` is ignored
 *
 * For a write operation (rnw=0):
 *   - Data from 'flash_address' is read into 'ram_buffer'
 *   - Data at 'flash_address' is erased to enable new writing at this location
 *   - Data from 'ram_buffer' is modified with data from 'ram_w_new_data'
 *   - Data from 'ram_buffer' is written back to flash at 'flash_address'
 *
 * @param rnw Read (1) or Write (0) operation. Read Not Write.
 * @param length_bytes Number of bytes to transfer. Byte precision for read operation and word precision for write operation.
 * @param flash_address Target address in flash memory.
 * @param ram_buffer Pointer to RAM buffer for read operation/sector save for write operation.
 * @param ram_w_new_data Pointer to RAM buffer containing data to write into flash memory.
 */
void w25q128jw_controller_rnw(uint32_t rnw, 
                            uint32_t length_bytes, 
                            uint32_t flash_address, 
                            uint32_t *ram_buffer, 
                            uint32_t *ram_w_new_data);

#endif // W25Q128JW_CONTROLLER_H