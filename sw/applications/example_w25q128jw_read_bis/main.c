/**
 * @file main.c
 * @brief Simple spi write example using BSP
 *
 * Simple example that writes a 1kB buffer to flash memory at a specific address
 * and then read it back to check if the data was written correctly.
 *
*/

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "x-heep.h"
#include "w25q128jw.h" //Soft
#include "w25q128jw_controller.h" //HW

#include "csr.h" // For CSR macros
#include "rv_plic.h" // For PLIC functions

/* By default, PRINTFs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   1

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

// Start buffers (the original data)
#include "buffer.h"
// End buffer (where what is read is stored)
uint32_t flash_data[256];

/*
 * Assign the test buffer to the buffer to write to flash.
 * The buffer is defined in the file buffer.h. As multiple buffers can
 * be defined, this is userful to pick the right one.
 * Also the length is specified, to test different length cases. In any case
 * length <= test_buffer length.
*/
#define TEST_BUFFER flash_original_1024B
#define LENGTH 1024

// Test functions
uint32_t test_read_quad_dma(uint32_t *test_buffer, uint32_t len);
uint32_t test_ctrl_read_quad_dma(uint32_t *test_buffer, uint32_t len);
uint32_t test_ctrl_read_quad_dma_interrupt(uint32_t *test_buffer, uint32_t len);
uint32_t test_ctrl_read_standard_dma_interrupt(uint32_t *test_buffer, uint32_t len);

// Check function
uint32_t check_result(uint8_t *test_buffer, uint32_t len);


//
// ISR
//
void handler_irq_w25q128jw_controller(uint32_t id) {
    // Set the done flag
    w25q128jw_controller_set_done_flag();

    // Clear the interrupt status register (interrupt handled)
    w25q128jw_controller_clear_status_register();
}

// Define global status variable
w25q_error_codes_t global_status;

int main(int argc, char *argv[]) {
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);

    if ( get_spi_flash_mode(&soc_ctrl) == SOC_CTRL_SPI_FLASH_MODE_SPIMEMIO ) {
        PRINTF("This application cannot work with the memory mapped SPI FLASH"
            "module - do not use the FLASH_EXEC linker script for this application\n");
        return EXIT_SUCCESS;
    }

    PRINTF("BSP and controller read test\n", LENGTH);

    // Pick the correct spi device based on simulation type
    spi_host_t* spi;
    spi = spi_flash;

    // Define status variable
    int32_t errors = 0;

    // Init SPI host and SPI<->Flash bridge parameters
    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    // Test quad read with DMA
    PRINTF("Testing quad read with DMA...\n");
    errors += test_read_quad_dma(TEST_BUFFER, LENGTH);

    if (errors) {
        PRINTF("test_read_quad_dma FAILED\n");
        return EXIT_FAILURE;
    }

    // Test quad read with DMA using the controller
    PRINTF("Testing quad read with DMA using the controller...\n");
    errors += test_ctrl_read_quad_dma(TEST_BUFFER, LENGTH);

    if (errors) {
        PRINTF("test_ctrl_read_quad_dma FAILED\n");
        return EXIT_FAILURE;
    }

    // Test quad read with DMA using the controller and interrupts
    PRINTF("Testing quad read with DMA using the controller and interrupts...\n");
    errors += test_ctrl_read_quad_dma_interrupt(TEST_BUFFER, LENGTH);

    if (errors) {
        PRINTF("test_ctrl_read_quad_dma_interrupt FAILED\n");
        return EXIT_FAILURE;
    }

        // Test quad read with DMA using the controller and interrupts
    PRINTF("Testing standard read with DMA using the controller and interrupts...\n");
    errors += test_ctrl_read_standard_dma_interrupt(TEST_BUFFER, LENGTH);

    if (errors) {
        PRINTF("test_ctrl_read_standard_dma_interrupt FAILED\n");
        return EXIT_FAILURE;
    }

    PRINTF("\n--------TEST FINISHED--------\n");
    if (errors == 0) {
        PRINTF("All tests passed!\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("Some tests failed!\n");
        return EXIT_FAILURE;
    }

}

uint32_t test_read_quad_dma(uint32_t *test_buffer, uint32_t len) {

    uint32_t *test_buffer_flash = test_buffer;

    // Read from flash memory at the same address
    w25q_error_codes_t status = w25q128jw_read_quad_dma((uint32_t)test_buffer_flash, flash_data, len);
    if (status != FLASH_OK) exit(EXIT_FAILURE);

    // Check if what we read is correct (i.e. flash_data == test_buffer)
    uint32_t res = check_result((uint8_t *)test_buffer, len);

    // Reset the flash data buffer
    memset(flash_data, 0, len * sizeof(uint8_t));

    return res;
}

uint32_t test_ctrl_read_quad_dma(uint32_t *test_buffer, uint32_t len) {

    uint32_t *test_buffer_flash = test_buffer;

    // Read from flash memory at the same address
    w25q128jw_controller_enable_interrupt(0);
    w25q128jw_controller_read(flash_data, test_buffer_flash, len, 1);

    while(!w25q128jw_controller_is_ready_polling());
    w25q128jw_controller_clear_done_flag();


    // Check if what we read is correct (i.e. flash_data == test_buffer)
    uint32_t res = check_result((uint8_t *)test_buffer, len);

    // Reset the flash data buffer
    memset(flash_data, 0, len * sizeof(uint8_t));

    return res;
}

uint32_t test_ctrl_read_quad_dma_interrupt(uint32_t *test_buffer, uint32_t len) {

    uint32_t *test_buffer_flash = test_buffer;

    // Clear HW regs before starting operation
    w25q128jw_controller_clear_status_register();

    // Clear HW regs before starting operation
    w25q128jw_controller_clear_status_register();

    // Activate interrupt in PLIC
    plic_Init();
    plic_irq_set_priority(W25Q128JW_CONTROLLER_INTR_EVENT, 1);
    plic_irq_set_enabled(W25Q128JW_CONTROLLER_INTR_EVENT, kPlicToggleEnabled);
    // Activate global CPU interrupts
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);   // Global interrupt enable for machine mode (MIE) bit in Machine Status Registers
    CSR_SET_BITS(CSR_REG_MIE, (1 << 11)); // Machine External Interrupt Enable (MEIE) bit in Machine Interrupt Pending Register
    
    // Read from flash memory at the same address
    w25q128jw_controller_enable_interrupt(1);
    w25q128jw_controller_read(flash_data, test_buffer_flash, len, 1);

    while(!w25q128jw_controller_is_ready_intr()) {
            asm volatile("wfi");  // Wait For Interrupt - CPU sleeps
        }
    w25q128jw_controller_clear_done_flag();


    // Check if what we read is correct (i.e. flash_data == test_buffer)
    uint32_t res = check_result((uint8_t *)test_buffer, len);

    // Reset the flash data buffer
    memset(flash_data, 0, len * sizeof(uint8_t));

    return res;
}

uint32_t test_ctrl_read_standard_dma_interrupt(uint32_t *test_buffer, uint32_t len) {

    uint32_t *test_buffer_flash = test_buffer;

    // Clear HW regs before starting operation
    w25q128jw_controller_clear_status_register();

    // Clear HW regs before starting operation
    w25q128jw_controller_clear_status_register();

    // Activate interrupt in PLIC
    plic_Init();
    plic_irq_set_priority(W25Q128JW_CONTROLLER_INTR_EVENT, 1);
    plic_irq_set_enabled(W25Q128JW_CONTROLLER_INTR_EVENT, kPlicToggleEnabled);
    // Activate global CPU interrupts
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);   // Global interrupt enable for machine mode (MIE) bit in Machine Status Registers
    CSR_SET_BITS(CSR_REG_MIE, (1 << 11)); // Machine External Interrupt Enable (MEIE) bit in Machine Interrupt Pending Register
    
    // Read from flash memory at the same address
    w25q128jw_controller_enable_interrupt(1);
    w25q128jw_controller_read(flash_data, test_buffer_flash, len, 0);

    while(!w25q128jw_controller_is_ready_intr()) {
            asm volatile("wfi");  // Wait For Interrupt - CPU sleeps
        }
    w25q128jw_controller_clear_done_flag();


    // Check if what we read is correct (i.e. flash_data == test_buffer)
    uint32_t res = check_result((uint8_t *)test_buffer, len);

    // Reset the flash data buffer
    memset(flash_data, 0, len * sizeof(uint8_t));

    return res;
}

uint32_t check_result(uint8_t *test_buffer, uint32_t len) {
    uint32_t errors = 0;
    uint8_t *flash_data_char = (uint8_t *)flash_data;

    for (uint32_t i = 0; i < len; i++) {
        if (test_buffer[i] != flash_data_char[i]) {
            PRINTF("Error at position %d: expected %x, got %x\n", i, test_buffer[i], flash_data_char[i]);
            errors++;
            // break;
        }
    }

    return errors;
}
