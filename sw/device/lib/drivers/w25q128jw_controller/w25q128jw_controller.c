/**
 * @file w25q128jw_controller.c
 * @brief W25Q128JW flash controller driver.
 *
 * This file contains the implementation of the driver functions for
 * controlling the W25Q128JW flash memory controller.
 */

#include "w25q128jw_controller_structs.h"
#include "w25q128jw_controller_regs.h"
#include "w25q128jw_controller.h"
#include "dma.h"

/**
 * @brief Internal flag to indicate operation completion.
 */
static volatile uint32_t w25q128jw_controller_done_flag = 0;

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
__attribute__((optimize("O0"))) uint32_t w25q128jw_controller_is_ready_intr()
{
    return w25q128jw_controller_done_flag;
}

__attribute__((optimize("O0"))) void w25q128jw_controller_clear_done_flag()
{
    w25q128jw_controller_done_flag = 0;
}

__attribute__((optimize("O0"))) void w25q128jw_controller_set_done_flag()
{
    w25q128jw_controller_done_flag = 1;
}

__attribute__((weak, optimize("O0"))) void handler_irq_w25q128jw_controller(uint32_t id)
{
 // Replace this function with a non-weak implementation
}


// ============== OPERATION  ==============
void w25q128jw_controller_rnw(uint32_t rnw,
                                                            uint32_t length_bytes,
                                                            uint32_t flash_address,
                                                            uint32_t *ram_buffer,
                                                            uint32_t *ram_w_new_data) {
    // Send flash address to controller
    w25q128jw_controller_peri->F_ADDRESS = flash_address;
    // Send RAM buffer address to controller
    w25q128jw_controller_peri->S_ADDRESS = (uint32_t)ram_buffer;
    // Send RAM new data address to controller (with data to write into flash memory)
    w25q128jw_controller_peri->MD_ADDRESS = (uint32_t)ram_w_new_data;
    // Send length (in bytes) to controller (byte precision for read operation and word precision for write operation)
    w25q128jw_controller_peri->LENGTH = length_bytes;
    // Specify operation type (rnw = 1 for read, 0 for write)
    w25q128jw_controller_peri->CONTROL = w25q128jw_controller_peri->CONTROL & ~(1 << W25Q128JW_CONTROLLER_CONTROL_RNW_BIT);
    w25q128jw_controller_peri->CONTROL = w25q128jw_controller_peri->CONTROL | ((rnw & 0x1) << W25Q128JW_CONTROLLER_CONTROL_RNW_BIT);
    // Tell the DMA to accept write operations from w25q128jw_controller in HW
    dma_set_hw_configuration_mode(1,0);
    // Start operation
    w25q128jw_controller_peri->CONTROL = w25q128jw_controller_peri->CONTROL & ~(1 << W25Q128JW_CONTROLLER_CONTROL_START_BIT);
    w25q128jw_controller_peri->CONTROL = w25q128jw_controller_peri->CONTROL | (0x1 << W25Q128JW_CONTROLLER_CONTROL_START_BIT);

}

