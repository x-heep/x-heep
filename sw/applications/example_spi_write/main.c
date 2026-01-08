/**
 * @file main.c
 * @brief Simple spi write example using BSP
 *
 * Simple example that writes a 1kB buffer to flash memory at a specific address
 * and then read it back to check if the data was written correctly.
 * For buffers bigger than 4kB (or even smaller buffers that are not aligned to 4kB),
 * the erase operation must be tweeked to erase all the sectors that contain the
 * buffer.
 *
 * @note The application assume the correct functioning of the read operation.
 *
*/

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "x-heep.h"
#include "w25q128jw.h"

/* By default, PRINTFs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

// what to write in flash
uint32_t flash_original_1024B[256] = {
    0x76543211, 0xfedcba99, 0x579a6f91, 0x657d5bef, 0x758ee420, 0x01234568, 0xfedbca97, 0x89abde00,
    0x76543212, 0xfedcba9a, 0x579a6f92, 0x657d5bf0, 0x758ee421, 0x01234569, 0xfedbca98, 0x89abde01,
    0x76543213, 0xfedcba9b, 0x579a6f93, 0x657d5bf1, 0x758ee422, 0x0123456a, 0xfedbca99, 0x89abde02,
    0x76543214, 0xfedcba9c, 0x579a6f94, 0x657d5bf2, 0x758ee423, 0x0123456b, 0xfedbca9a, 0x89abde03,
    0x76543215, 0xfedcba9d, 0x579a6f95, 0x657d5bf3, 0x758ee424, 0x0123456c, 0xfedbca9b, 0x89abde04,
    0x76543216, 0xfedcba9e, 0x579a6f96, 0x657d5bf4, 0x758ee425, 0x0123456d, 0xfedbca9c, 0x89abde05,
    0x76543217, 0xfedcba9f, 0x579a6f97, 0x657d5bf5, 0x758ee426, 0x0123456e, 0xfedbca9d, 0x89abde06,
    0x76543218, 0xfedcbaa0, 0x579a6f98, 0x657d5bf6, 0x758ee427, 0x0123456f, 0xfedbca9e, 0x89abde07,
    0x76543219, 0xfedcbaa1, 0x579a6f99, 0x657d5bf7, 0x758ee428, 0x01234570, 0xfedbca9f, 0x89abde08,
    0x7654321a, 0xfedcbaa2, 0x579a6f9a, 0x657d5bf8, 0x758ee429, 0x01234571, 0xfedbcaa0, 0x89abde09,
    0x7654321b, 0xfedcbaa3, 0x579a6f9b, 0x657d5bf9, 0x758ee42a, 0x01234572, 0xfedbcaa1, 0x89abde0a,
    0x7654321c, 0xfedcbaa4, 0x579a6f9c, 0x657d5bfa, 0x758ee42b, 0x01234573, 0xfedbcaa2, 0x89abde0b,
    0x7654321d, 0xfedcbaa5, 0x579a6f9d, 0x657d5bfb, 0x758ee42c, 0x01234574, 0xfedbcaa3, 0x89abde0c,
    0x7654321e, 0xfedcbaa6, 0x579a6f9e, 0x657d5bfc, 0x758ee42d, 0x01234575, 0xfedbcaa4, 0x89abde0d,
    0x7654321f, 0xfedcbaa7, 0x579a6f9f, 0x657d5bfd, 0x758ee42e, 0x01234576, 0xfedbcaa5, 0x89abde0e,
    0x76543220, 0xfedcbaa8, 0x579a6fa0, 0x657d5bfe, 0x758ee42f, 0x01234577, 0xfedbcaa6, 0x89abde0f,
    0x76543221, 0xfedcbaa9, 0x579a6fa1, 0x657d5bff, 0x758ee430, 0x01234578, 0xfadbcaa7, 0x89abde10,
    0x76543222, 0xfedcbaaa, 0x579a6fa2, 0x657d5c00, 0x758ee431, 0x01234579, 0xfadbcaa8, 0x89abde11,
    0x76543223, 0xfedcbaab, 0x579a6fa3, 0x657d5c01, 0x758ee432, 0x0123457a, 0xfadbcaa9, 0x89abde12,
    0x76543224, 0xfedcbaac, 0x579a6fa4, 0x657d5c02, 0x758ee433, 0x0123457b, 0xfadbcaaa, 0x89abde13,
    0x76543225, 0xfedcbaad, 0x579a6fa5, 0x657d5c03, 0x758ee434, 0x0123457c, 0xfadbcaab, 0x89abde14,
    0x76543226, 0xfedcbaae, 0x579a6fa6, 0x657d5c04, 0x758ee435, 0x0123457d, 0xfadbcaac, 0x89abde15,
    0x76543227, 0xfedcbaaf, 0x579a6fa7, 0x657d5c05, 0x758ee436, 0x0123457e, 0xfadbcaad, 0x89abde16,
    0x76543228, 0xfedcbab0, 0x579a6fa8, 0x657d5c06, 0x758ee437, 0x0123457f, 0xfadbcaae, 0x89abde17,
    0x76543220, 0xfedcbaa8, 0x579a6fa0, 0x657d5bfe, 0x758ee42f, 0x01234577, 0xfedbcaa6, 0x89abde0f,
    0x76543221, 0xfedcbaa9, 0x579a6fa1, 0x657d5bff, 0x758ee430, 0x01234578, 0xfadbcaa7, 0x89abde10,
    0x76543222, 0xfedcbaaa, 0x579a6fa2, 0x657d5c00, 0x758ee431, 0x01234579, 0xfadbcaa8, 0x89abde11,
    0x76543223, 0xfedcbaab, 0x579a6fa3, 0x657d5c01, 0x758ee432, 0x0123457a, 0xfadbcaa9, 0x89abde12,
    0x76543224, 0xfedcbaac, 0x579a6fa4, 0x657d5c02, 0x758ee433, 0x0123457b, 0xfadbcaaa, 0x89abde13,
    0x76543225, 0xfedcbaad, 0x579a6fa5, 0x657d5c03, 0x758ee434, 0x0123457c, 0xfadbcaab, 0x89abde14,
    0x76543226, 0xfedcbaae, 0x579a6fa6, 0x657d5c04, 0x758ee435, 0x0123457d, 0xfadbcaac, 0x89abde15,
    0x76543227, 0xfedcbaaf, 0x579a6fa7, 0x657d5c05, 0x758ee436, 0x0123457e, 0xfadbcaad, 0x89abde16,
    0x76543228, 0xfedcbab0, 0x579a6fa8, 0x657d5c06, 0x758ee437, 0x0123457f, 0xfadbcaae, 0x89abde17
};

// End buffer (where what is read is stored)
uint32_t flash_read_data[256];

#define BYTES_TO_WRITE 533 //in bytes, must be less than 256*4=1024

// address to which we write in FLASH, we do not initiliaze it to 0 as we do not want into the BSS
// otherwise the compilers/linker won't allocate this to the .data section, thus not written in flash
// If not written in flash, after erasing the block this array would be all '0xFF', and this would loose
// generality of the testing as without erasing, the write operation in flash can bring 1->0 but not viceversa
// by initializing to another number, we are sure it goes to .data section and written in flash
uint32_t __attribute__ ((aligned (16))) flash_write_buffer[256] = {
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
    0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA
};

#ifndef ON_CHIP
int32_t __attribute__((section(".xheep_data_flash_only"))) __attribute__ ((aligned (16))) flash_only_write_buffer[256];
#endif

// Test functions
uint32_t test_write(uint32_t *test_buffer, uint32_t len);
uint32_t test_write_dma(uint32_t *test_buffer, uint32_t len);
uint32_t test_write_quad(uint32_t *test_buffer, uint32_t len);
uint32_t test_write_quad_dma(uint32_t *test_buffer, uint32_t len);
uint32_t test_write_flash_only(uint32_t *test_buffer, uint32_t len);

// Check function
uint32_t check_result(uint8_t *test_buffer, uint32_t len);

// Erase memory function
void erase_memory(uint32_t addr);

// Define global status variable
w25q_error_codes_t global_status;

int main(int argc, char *argv[]) {
    // Initialize the DMA
    dma_init(NULL);
    
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);

    if ( get_spi_flash_mode(&soc_ctrl) == SOC_CTRL_SPI_FLASH_MODE_SPIMEMIO ) {
        PRINTF("This application cannot work with the memory mapped SPI FLASH"
            "module - do not use the FLASH_EXEC linker script for this application\n");
        return EXIT_SUCCESS;
    }

    PRINTF("BSP write test\n");

    // Pick the correct spi device based on simulation type
    spi_host_t* spi;
    spi = spi_flash;

    // Define status variable
    int32_t errors = 0;

    // Init SPI host and SPI<->Flash bridge parameters
    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    // Test simple write
    PRINTF("Testing simple write...\n");
    errors += test_write(flash_original_1024B, BYTES_TO_WRITE);

    if (errors) {
        PRINTF("test_write FAILED\n");
        return EXIT_FAILURE;
    }

#ifndef ON_CHIP
    // Test simple write on flash_only data
    PRINTF("Testing simple write. on flash only data..\n");
    errors += test_write_flash_only(flash_original_1024B, BYTES_TO_WRITE);

    if (errors) {
        PRINTF("test_write_flash_only FAILED\n");
        return EXIT_FAILURE;
    }

#endif


    // Test simple write with DMA
    PRINTF("Testing simple write with DMA...\n");
    errors += test_write_dma(flash_original_1024B, BYTES_TO_WRITE);

    if (errors) {
        PRINTF("test_write_dma FAILED\n");
        return EXIT_FAILURE;
    }

    // Test quad write
    PRINTF("Testing quad write...\n");
    errors += test_write_quad(flash_original_1024B, BYTES_TO_WRITE);

    if (errors) {
        PRINTF("test_write_quad FAILED\n");
        return EXIT_FAILURE;
    }

    // Test quad write with DMA
    PRINTF("Testing quad write with DMA...\n");
    errors += test_write_quad_dma(flash_original_1024B, BYTES_TO_WRITE);

    if (errors) {
        PRINTF("test_write_quad_dma FAILED\n");
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


uint32_t test_write(uint32_t *test_buffer, uint32_t len) {

    uint32_t *test_buffer_flash = flash_write_buffer;

    // Write to flash memory at specific address
    global_status = w25q128jw_erase_and_write_standard(test_buffer_flash, test_buffer, len);
    if (global_status != FLASH_OK) exit(EXIT_FAILURE);

    // Read from flash memory at the same address
    global_status = w25q128jw_read(test_buffer_flash, flash_read_data, len);
    if (global_status != FLASH_OK) exit(EXIT_FAILURE);

    // Check if what we read is correct (i.e. flash_original == flash_read_data)
    int32_t result = check_result(test_buffer, len);

    // Clean memory for next test
    erase_memory(test_buffer_flash);

    // Reset the flash data buffer
    memset(flash_read_data, 0, len * sizeof(uint8_t));

    return result;
}

uint32_t test_write_dma(uint32_t *test_buffer, uint32_t len) {

    uint32_t *test_buffer_flash = flash_write_buffer;

    // Write to flash memory at specific address
    global_status = w25q128jw_erase_and_write_standard_dma(test_buffer_flash, test_buffer, len);
    if (global_status != FLASH_OK) exit(EXIT_FAILURE);

    // Read from flash memory at the same address
    global_status = w25q128jw_read(test_buffer_flash, flash_read_data, len);
    if (global_status != FLASH_OK) exit(EXIT_FAILURE);

    // Check if what we read is correct (i.e. flash_original == flash_read_data)
    int32_t result = check_result(test_buffer, len);

    // Clean memory for next test
    erase_memory(test_buffer_flash);

    // Reset the flash data buffer
    memset(flash_read_data, 0, len * sizeof(uint8_t));

    return result;
}

uint32_t test_write_quad(uint32_t *test_buffer, uint32_t len) {

    uint32_t *test_buffer_flash = flash_write_buffer;

    // Write to flash memory at specific address
    global_status = w25q128jw_erase_and_write_quad(test_buffer_flash, test_buffer, len);
    if (global_status != FLASH_OK) exit(EXIT_FAILURE);

    // Read from flash memory at the same address
    global_status = w25q128jw_read(test_buffer_flash, flash_read_data, len);
    if (global_status != FLASH_OK) exit(EXIT_FAILURE);

    // Check if what we read is correct (i.e. flash_original == flash_read_data)
    int32_t result = check_result(test_buffer, len);

    // Clean memory for next test
    erase_memory(test_buffer_flash);

    // Reset the flash data buffer
    memset(flash_read_data, 0, len * sizeof(uint8_t));

    return result;
}

uint32_t test_write_quad_dma(uint32_t *test_buffer, uint32_t len) {

    uint32_t *test_buffer_flash = flash_write_buffer;

    // Write to flash memory at specific address
    global_status = w25q128jw_erase_and_write_quad_dma(test_buffer_flash, test_buffer, len);
    if (global_status != FLASH_OK) exit(EXIT_FAILURE);

    // Read from flash memory at the same address
    global_status = w25q128jw_read(test_buffer_flash, flash_read_data, len);
    if (global_status != FLASH_OK) exit(EXIT_FAILURE);

    // Check if what we read is correct (i.e. flash_original == flash_read_data)
    int32_t result = check_result(test_buffer, len);

    // Clean memory for next test
    erase_memory(test_buffer_flash);

    // Reset the flash data buffer
    memset(flash_read_data, 0, len * sizeof(uint8_t));

    return result;
}
#ifndef ON_CHIP
uint32_t test_write_flash_only(uint32_t *test_buffer, uint32_t len) {

    //remove FLASH offset as required by the BSP, flash_only_write_buffer is only mapped to the LMA
    uint32_t *test_buffer_flash = heep_get_flash_address_offset(flash_only_write_buffer);

    // Clean memory
    erase_memory(test_buffer_flash);

    // Write to flash memory at specific address
    global_status = w25q128jw_erase_and_write_standard(test_buffer_flash, test_buffer, len);
    if (global_status != FLASH_OK) exit(EXIT_FAILURE);

    // Read from flash memory at the same address
    global_status = w25q128jw_read(test_buffer_flash, flash_read_data, len);
    if (global_status != FLASH_OK) exit(EXIT_FAILURE);

    // Check if what we read is correct (i.e. flash_original == flash_read_data)
    int32_t result = check_result(test_buffer, len);

    // Clean memory for next test
    erase_memory(test_buffer_flash);

    // Reset the flash data buffer
    memset(flash_read_data, 0, len * sizeof(uint8_t));

    return result;
}
#endif
uint32_t check_result(uint8_t *test_buffer, uint32_t len) {
    uint32_t errors = 0;
    uint8_t *flash_read_data_char = (uint8_t *)flash_read_data;

    for (uint32_t i = 0; i < len; i++) {
        if (test_buffer[i] != flash_read_data_char[i]) {
            PRINTF("Error at position %d: expected %x, got %x\n", i, test_buffer[i], flash_read_data_char[i]);
            errors++;
            break;
        }
    }

    return errors;
}

// Erase the memory only if FPGA is used
void erase_memory(uint32_t addr) {
    #ifndef TARGET_SIM
    w25q128jw_4k_erase(addr);
    #endif
}