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

#include "dma.h" // To use write_register function

/**
 * @brief Internal flag to indicate operation completion.
 */
static volatile uint32_t w25q128jw_controller_done_flag = 0;

// ============== POLLING  ==============
__attribute__((optimize("O0"))) uint32_t w25q128jw_controller_is_ready_polling()
{
    /* The transaction READY bit is read from the status register*/
    uint32_t ret = ( w25q128jw_controller_peri->STATUS & (1<<W25Q128JW_CONTROLLER_STATUS_READY_BIT) ); 
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
__attribute__((optimize("O0"))) void w25q128jw_controller_rnw(uint32_t rnw,
                                                            uint32_t length_bytes,
                                                            uint32_t flash_address,
                                                            uint32_t *ram_buffer,
                                                            uint32_t *ram_w_new_data) {
    // Send flash address to controller
    write_register( (uint32_t)flash_address,
                    W25Q128JW_CONTROLLER_F_ADDRESS_REG_OFFSET,
                    0xFFFFFFFF,
                    0,
                    W25Q128JW_CONTROLLER_START_ADDRESS
                );
    // Send RAM buffer address to controller
    write_register( (uint32_t)ram_buffer,
                    W25Q128JW_CONTROLLER_S_ADDRESS_REG_OFFSET,
                    0xFFFFFFFF,
                    0,
                    W25Q128JW_CONTROLLER_START_ADDRESS
                );
    // Send RAM new data address to controller (with data to write into flash memory)
    write_register( (uint32_t)ram_w_new_data,
                    W25Q128JW_CONTROLLER_MD_ADDRESS_REG_OFFSET,
                    0xFFFFFFFF,
                    0,
                    W25Q128JW_CONTROLLER_START_ADDRESS
                );          
    // Send length (in bytes) to controller (byte precision for read operation and word precision for write operation)
    write_register( length_bytes,
                    W25Q128JW_CONTROLLER_LENGTH_REG_OFFSET,
                    0xFFFFFFFF,
                    0,
                    W25Q128JW_CONTROLLER_START_ADDRESS
                );
    // Specify operation type (rnw = 1 for read, 0 for write)
    write_register( rnw,
                    W25Q128JW_CONTROLLER_CONTROL_REG_OFFSET,
                    0x1,
                    W25Q128JW_CONTROLLER_CONTROL_RNW_BIT,
                    W25Q128JW_CONTROLLER_START_ADDRESS
                );
    // Start operation
    write_register( 0x1,
                    W25Q128JW_CONTROLLER_CONTROL_REG_OFFSET,
                    0x1,
                    W25Q128JW_CONTROLLER_CONTROL_START_BIT,
                    W25Q128JW_CONTROLLER_START_ADDRESS
                );
}

