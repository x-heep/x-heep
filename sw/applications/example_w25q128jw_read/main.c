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

#include "core_v_mini_mcu.h"
#include "x-heep.h"
#include "w25q128jw.h"

#include "w25q128jw_controller.h"
#include "flash_data.h"

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
__attribute__((optimize("O0"))) void w25q128jw_controller_run(){
    spi_host_t* spi;
    spi = spi_flash;

    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    w25q128jw_controller_rnw(1, LENGTH_BYTES, flash_address, ram_buffer_address, 0x00000000);

    while(!w25q128jw_controller_is_ready_polling());
}

int main(void) {

    printf("Read test with 128 bytes\n");

    w25q128jw_controller_run();

    uint32_t res =  check_result(ram_golden_data, LENGTH_BYTES);

    if (res == 0){
        return EXIT_SUCCESS;
    } else {
        return EXIT_FAILURE;
    }
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
