/**
 * @file w25q128jw_controller.c
 * @brief W25Q128JW flash controller driver.
 *
 * This file contains the implementation of the driver functions for
 * controlling the W25Q128JW flash memory controller.
 */

#include <stddef.h>
#include "w25q128jw_controller_structs.h"
#include "w25q128jw_controller_regs.h"
#include "w25q128jw_controller.h"
#include "w25q128jw_sector_size.h"
#include "dma.h"
/**
 * @brief Internal flag to indicate operation completion.
 */
static volatile uint32_t w25q128jw_controller_done_flag = 0;

/**
 * @brief Static vector used in the erase_and_write function.
 *
 * It is used to store the data of a sector (4k) of the flash. Given the dimensions
 * of the vector, is not possible to allocate it dinamically as it would cause a stack
 * or heap overflow.
*/
uint8_t w25q128jw_sector_data_buffer[FLASH_SECTOR_SIZE];

// ============== POLLING  ==============
uint32_t w25q128jw_controller_is_ready_polling()
{
    /* The transaction READY bit is read from the status register*/
    uint32_t ret = ( w25q128jw_controller_peri->STATUS & (1<<W25Q128JW_CONTROLLER_STATUS_READY_BIT) ); 

    // Tell the DMA to do not accept write operations from w25q128jw_controller in HW anymore
    if (ret) dma_set_hw_configuration_mode(0,0);

    return ret;
}

// ============== INTERRUPT  ==============
uint32_t w25q128jw_controller_is_ready_intr()
{
    return w25q128jw_controller_done_flag;
}

void w25q128jw_controller_clear_done_flag()
{
    w25q128jw_controller_done_flag = 0;
}

void w25q128jw_controller_set_done_flag()
{
    w25q128jw_controller_done_flag = 1;
}

void w25q128jw_controller_clear_status_register()
{
   w25q128jw_controller_peri->INTR_STATUS &= ~(1 << W25Q128JW_CONTROLLER_INTR_STATUS_INTR_STATUS_BIT);
}

void w25q128jw_controller_enable_interrupt(uint32_t intr_enable)
{
   w25q128jw_controller_peri->INTR_ENABLE = intr_enable;
}

__attribute__((weak, optimize("O0"))) void handler_irq_w25q128jw_controller(uint32_t id)
{
 // Replace this function with a non-weak implementation
}


/* This function initiates a transfer between RAM and flash memory W25Q128JW.
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
                                                            size_t length_bytes,
                                                            void* flash_address,
                                                            void* ram_buffer,
                                                            void* ram_w_new_data) {
    // Send flash address to controller
    w25q128jw_controller_peri->F_ADDRESS = (uint32_t)flash_address;
    // Send RAM buffer address to controller
    w25q128jw_controller_peri->S_ADDRESS = (uint32_t)ram_buffer;
    // Send RAM new data address to controller (with data to write into flash memory)
    w25q128jw_controller_peri->MD_ADDRESS = (uint32_t)ram_w_new_data;
    // Send length (in bytes) to controller (byte precision for read operation and word precision for write operation)
    w25q128jw_controller_peri->LENGTH = (uint32_t)length_bytes;
    // Specify operation type (rnw = 1 for read, 0 for write)
    w25q128jw_controller_peri->CONTROL &= ~(1 << W25Q128JW_CONTROLLER_CONTROL_RNW_BIT);
    w25q128jw_controller_peri->CONTROL |= ((rnw & 0x1) << W25Q128JW_CONTROLLER_CONTROL_RNW_BIT);
    // Tell the DMA to accept write operations from w25q128jw_controller in HW
    dma_set_hw_configuration_mode(1,0);
    // Start operation
    w25q128jw_controller_peri->CONTROL &= ~(1 << W25Q128JW_CONTROLLER_CONTROL_START_BIT);
    w25q128jw_controller_peri->CONTROL |= (0x1 << W25Q128JW_CONTROLLER_CONTROL_START_BIT);

}

/**
 * @param dest Pointer to the on-chip SRAM
 * @param src  Pointer to the Flash
 * @param length_bytes Number of bytes to transfer.
 */
void w25q128jw_controller_read(void* dest, void* src, size_t length_bytes) {
    w25q128jw_controller_rnw(1, length_bytes, src, dest, NULL);
}

/**
 * @param dest Pointer to the Flash
 * @param src  Pointer to the on-chip SRAM
 * @param length_bytes Number of bytes to transfer.
 */
void w25q128jw_controller_write(void* dest, void* src, size_t length_bytes) {
    w25q128jw_controller_rnw(0, length_bytes, dest, w25q128jw_sector_data_buffer, src);
}

/**
 * @param slot_wait_counter Number of bytes to transfer.
 */
void w25q128jw_set_dma_slot_wait_counter(uint32_t slot_wait_counter)
{
    w25q128jw_controller_peri->DMA_SLOT_WAIT_COUNTER = slot_wait_counter;
}
