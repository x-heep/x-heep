/*
 * Simple test for OBI -> W25Q128JW register bridge
 *
 * This program writes and reads the W25Q128JW flash memory through the OBI interface
 * Bus NEEDS to be NtoM to be able to write.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "core_v_mini_mcu.h"
#include "x-heep.h"
#include "w25q128jw.h"
#include "w25q128jw_controller.h"
#include "dma.h"
#include "data.h"


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

#define PATTERN8 0xA5
#define PATTERN16 0xA5A5

uint32_t __attribute__((section(".xheep_data_flash_only"))) Avect[] = {1,2,3,4};
uint32_t __attribute__((section(".xheep_data_flash_only"))) Bvect[] = {6,7,8,9};

uint32_t __attribute__((section(".xheep_data_flash_only"))) Cdotp = 0;
uint32_t goldC = 1*6 + 2*7 + 3*8 + 4*9;

void __attribute__ ((noinline)) dot_product(uint32_t *  A, uint32_t *  B, uint32_t *  C, int N)
{
    uint32_t acc = 0;
    for(int i = 0; i < N; i++)
        acc+= A[i] * B[i];

    *C = acc;
}

int main(void)
{
    uint32_t v32;
    uint16_t v16;
    uint8_t v8;
    uintptr_t *base = (uintptr_t *)FLASH_MEM_START_ADDRESS; // Base address for memory-mapped SPI flash

    spi_host_t* spi;
    spi = spi_flash;

    // Init SPI host and SPI<->Flash bridge parameters and Flash Power Up
    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    if (w25q128jw_controller_get_cache_available() == 0) {
        PRINTF("Cache not available, aborting.\n");
        return EXIT_FAILURE;
    }

    PRINTF("Memory-mapped SPI flash test\n");
    // Mandatory because w25q128jw_controller_is_ready_polling reset it
    dma_set_hw_configuration_mode(1,0);

    //on Flash dotp
    uint32_t* Cptr = heep_get_flash_address_offset(&Cdotp);
    uint32_t* Aptr = heep_get_flash_address_offset(Avect);
    uint32_t* Bptr = heep_get_flash_address_offset(Bvect);
    if (((uint32_t)(Cptr) & (uint32_t)(base)) != (uint32_t)base)
        Cptr = (uint32_t*)((uint32_t)(base) + (uint32_t)(Cptr));
    if (((uint32_t)(Aptr) & (uint32_t)(base)) != (uint32_t)base)
        Aptr = (uint32_t*)((uint32_t)(base) + (uint32_t)(Aptr));
    if (((uint32_t)(Bptr) & (uint32_t)(base)) != (uint32_t)base)
        Bptr = (uint32_t*)((uint32_t)(base) + (uint32_t)(Bptr));

    dot_product(Aptr, Bptr, Cptr, 4);

    if(Cptr[0] != goldC) {
        PRINTF("Dot product calculation failed: expected %d, got %d\n", goldC, Cptr[0]);
        return EXIT_FAILURE;
    } else {
        PRINTF("Dot product calculation succeeded: %d\n", Cptr[0]);
    }

    uint32_t* heep_data_address = heep_get_flash_address_offset(flash_source_pattern);

    if (((uint32_t)(heep_data_address) & (uint32_t)(base)) != (uint32_t)base)
    {
        heep_data_address = (uint32_t*)((uint32_t)(base) + (uint32_t)(heep_data_address));
    }

    PRINTF("Write bytes at sector 0...\n");
    // Using the controller to write data from SRAM to flash
    w25q128jw_controller_write(flash_source_pattern, (void*)data_sram, NUM_BYTES, 0, 1);
    while(!w25q128jw_controller_is_ready_polling());

    // Mandatory because w25q128jw_controller_is_ready_polling reset it
    dma_set_hw_configuration_mode(1,0);

    PRINTF("Read obi words at sector 0...\n");
    for(int i = 0; i < NUM_WORDS; i++) {
        if (heep_data_address[i] != data_sram[i]) {
            PRINTF("Mismatch at index %d: expected 0x%x, got 0x%x\n", i, data_sram[i], heep_data_address[i]);
            exit(EXIT_FAILURE);
        }
    }

    PRINTF("Write obi bytes at sector 1...\n");
    // Using memcpy to write data from SRAM to flash through the OBI interface
    memcpy((void*)&(heep_data_address[SECTOR_WSIZE]), (void*)data_sram, NUM_BYTES);

    PRINTF("Read obi bytes at sector 1...\n");
    uint8_t *heep8 = (uint8_t *)(&(heep_data_address[SECTOR_WSIZE]));
    uint8_t *data8 = (uint8_t *)(&(data_sram[0]));
    for(int i = 0; i < NUM_BYTES; i++) {
        if (heep8[i] != data8[i]) {
            PRINTF("Mismatch at index %d: expected 0x%x, got 0x%x\n", i, data8[i], heep8[i]);
            exit(EXIT_FAILURE);
        }
    }

    PRINTF("Write obi bytes at sector 4...\n");
    memset((void*)&(heep_data_address[SECTOR_WSIZE*4]), PATTERN8, NUM_BYTES);

    PRINTF("Read obi short at sector 4...\n");
    uint16_t *heep16 = (uint16_t *)(&(heep_data_address[SECTOR_WSIZE*4]));
    for(int i = 0; i < NUM_WORDS; i++) {
        if (heep16[i] != PATTERN16) {
            PRINTF("Mismatch at index %d: expected 0x%x, got 0x%x\n", i, PATTERN16, heep16[i]);
            exit(EXIT_FAILURE);
        }
    }

    PRINTF("Read obi words at sector 0 (check cache)...\n");
    for(int i = 0; i < NUM_WORDS; i++) {
        if (heep_data_address[i] != data_sram[i]) {
            PRINTF("Mismatch at index %d: expected 0x%x, got 0x%x\n", i, data_sram[i], heep_data_address[i]);
            exit(EXIT_FAILURE);
        }
    }

    PRINTF("All tests passed.\n");
    return EXIT_SUCCESS;
}
