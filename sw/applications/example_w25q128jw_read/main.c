/**
 * @file main.c
 * @brief Example application for W25Q128JW flash read test.
 *
 * This application demonstrates reading data from the W25Q128JW flash memory 
 * and verifying the contents match to the golden data.
 *
 * Test parameters:
 * - Transfer size: 128 bytes (read operation is byte precise)
 * - Mode: Polling-based completion detection (see "example_w25q128jw_interrupt" for interrupt-based)
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "memory.h"

#include "core_v_mini_mcu.h"
#include "x-heep.h"
#include "w25q128jw.h"

#include "w25q128jw_controller.h"
#include "flash_data.h"
#include "csr.h" // For CSR macros
#include "rv_plic.h" // For PLIC functions

// Number of bytes to transfer
#define LENGTH_BYTES 128 
// Number of words to transfer
#define LENGTH_WORDS ((LENGTH_BYTES + 3) / 4) // To deal with non-multiple of 4 bytes

// RAM buffer to store data read from FLASH
uint32_t ram_buffer[256];
// flash buffer address
uint32_t *flash_address = flash_buffer;
// RAM buffer address
uint32_t *ram_buffer_address = ram_buffer;

/**
 * @brief Compares read data against expected data.
 *
 * @param test_buffer   Pointer to the expected data buffer (what one should read back).
 * @param len           Number of bytes to compare (byte precise).
 * @return              0 if data matches, 1 otherwise.
 */
uint32_t check_result(uint8_t *test_buffer, uint32_t len);

/**
 * @brief Runs the flash read test sequence.
 *
 * This function:
 * 1. Initializes the SPI flash
 * 2. Launches read operation
 * 3. Waits for read completion (polling)
 *
 */
__attribute__ ((noinline)) int w25q128jw_controller_run(char interrupt_test) {
    spi_host_t* spi;
    spi = spi_flash;

    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    w25q128jw_controller_rnw(1, LENGTH_BYTES, (uint32_t)flash_address, ram_buffer_address, 0x00000000);


    if(interrupt_test) {
        // Wait for interrupt
        while(!w25q128jw_controller_is_ready_intr()) {
            asm volatile("wfi");  // Wait For Interrupt - CPU sleeps
        }
    } else {
        while(!w25q128jw_controller_is_ready_polling());
    }

    return EXIT_SUCCESS;
}

//
// ISR
//
void handler_irq_w25q128jw_controller(uint32_t id) {
    // Set the done flag
    w25q128jw_controller_set_done_flag();

    // Clear the interrupt status register (interrupt handled)
    w25q128jw_controller_clear_status_register();
}

int main(void) {

    w25q128jw_controller_enable_interrupt(0);
    if (w25q128jw_controller_run(0) != EXIT_SUCCESS) return EXIT_FAILURE;

    uint32_t res =  check_result((uint8_t *)ram_golden_data, LENGTH_BYTES);

    if (res){
        return EXIT_FAILURE;
    }

    // Clear the interrupt status register (of previous transaction)
    w25q128jw_controller_clear_status_register();

    memset(ram_buffer, 0, sizeof(ram_buffer));

    // Clear flag before starting operation
    w25q128jw_controller_clear_done_flag();

    // Activate interrupt in PLIC
    plic_Init();
    plic_irq_set_priority(W25Q128JW_CONTROLLER_INTR_EVENT, 1);
    plic_irq_set_enabled(W25Q128JW_CONTROLLER_INTR_EVENT, kPlicToggleEnabled);

    // Activate global interrupts
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);   // Global interrupt enable for machine mode (MIE) bit in Machine Status Registers
    CSR_SET_BITS(CSR_REG_MIE, (1 << 11)); // Machine External Interrupt Enable (MEIE) bit in Machine Interrupt Pending Register

    w25q128jw_controller_enable_interrupt(1);
    if (w25q128jw_controller_run(1) != EXIT_SUCCESS) return EXIT_FAILURE;

    res =  check_result((uint8_t *)ram_golden_data, LENGTH_BYTES);

    if (res){
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;

}

uint32_t check_result(uint8_t *test_buffer, uint32_t len) {
    uint32_t errors = 0;
    uint8_t *ram_buffer_char = (uint8_t *)ram_buffer;

    for (uint32_t i = 0; i < len; i++) {
        if (test_buffer[i] != ram_buffer_char[i]) {
            printf("Error at position %d: expected %x, got %x\n", i, test_buffer[i], ram_buffer_char[i]);
            errors++;
            break;
        }
    }

    return errors;
}
