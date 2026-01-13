/**
 * @file main.c
 * @brief Example application for W25Q128JW flash write test.
 *
 * This application demonstrates writing data to the W25Q128JW flash memory
 * then reading it back and verifying the contents match the original data.
 *
 * Test parameters:
 * - Transfer size: 4100 bytes (spanning over 2 sectors) (write operation is word precise)
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
#include "sram_data.h"
#include "csr.h" // For CSR macros
#include "rv_plic.h" // For PLIC functions

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

#if TARGET_SIM && PRINTF_IN_SIM
        #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

// Number of bytes to transfer
#define LENGTH_BYTES NUM_WORDS*4

// Flash buffer - use two buffers for the two tests to be sure we wrote twice
int32_t __attribute__((section(".xheep_data_flash_only"))) __attribute__ ((aligned (16))) flash_buffer_test1[NUM_WORDS];
int32_t __attribute__((section(".xheep_data_flash_only"))) __attribute__ ((aligned (16))) flash_buffer_test2[NUM_WORDS];

int32_t sram_buffer_read_flash_back[NUM_WORDS];

/**
 * @brief Compares read data against expected data.
 *
 * @param test_buffer   Pointer to the expected data buffer (what one should read back).
 * @param len           Number of bytes to compare (byte precise).
 * @return              0 if data matches, 1 otherwise.
 */
uint32_t check_result(uint8_t *test_buffer, uint32_t len);

/**
 * @brief Runs the flash write test sequence.
 *
 * This function:
 * 1. Initializes the SPI flash
 * 2. Launches write operation
 * 3. Waits for write completion (polling)
 * 4. Launches read operation
 * 5. Waits for read completion (polling)
 *
 */
__attribute__ ((noinline)) int w25q128jw_controller_run(char interrupt_test, int32_t* flash_ptr) {

    spi_host_t* spi;
    spi = spi_flash;

    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    //write
    w25q128jw_controller_write((void*)&flash_ptr[0], (void*) &sram_data[0], (size_t) LENGTH_BYTES);

    if(interrupt_test) {
        // Wait for interrupt
        while(!w25q128jw_controller_is_ready_intr()) {
            asm volatile("wfi");  // Wait For Interrupt - CPU sleeps
        }
    } else {
        while(!w25q128jw_controller_is_ready_polling());
    }

    //read back what you wrote
    w25q128jw_controller_read(((void*) &sram_buffer_read_flash_back[0], (void*) &flash_ptr[0], (size_t) LENGTH_BYTES);

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

int main(void) {

    if (w25q128jw_controller_run(0, flash_buffer_test1)!= EXIT_SUCCESS) return EXIT_FAILURE;
    uint32_t res =  check_result((uint8_t *)sram_buffer_read_flash_back, LENGTH_BYTES);

    if (res){
        return EXIT_FAILURE;
    }

    // Clear the interrupt status register (of previous transaction)
    w25q128jw_controller_clear_status_register();

    memset(sram_buffer_read_flash_back, 0, sizeof(sram_buffer_read_flash_back));

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
    if (w25q128jw_controller_run(1, flash_buffer_test2) != EXIT_SUCCESS) return EXIT_FAILURE;

    res =  check_result((uint8_t *)sram_buffer_read_flash_back, LENGTH_BYTES);

    if (res){
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;


}

uint32_t check_result(uint8_t *test_buffer, uint32_t len) {
    uint32_t errors = 0;
    uint8_t *sram_data_ptr = (uint8_t *)sram_data;

    for (uint32_t i = 0; i < len; i++) {
        if (test_buffer[i] != sram_data_ptr[i]) {
            PRINTF("Error at position %d: expected %x, got %x\n", i, test_buffer[i], ram_buffer_char[i]);
            errors++;
            break; // Stop at first error
        }
    }

    return errors;
}