// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "x-heep.h"
#include "w25q128jw.h"
#include "csr.h"
#include "core_v_mini_mcu.h"
#include "power_manager.h"

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

#define FLASH_ONLY_WORDS 32
#define FLASH_ONLY_BYTES (FLASH_ONLY_WORDS*4)

uint32_t on_chip_buffer[FLASH_ONLY_WORDS];

int32_t __attribute__((section(".xheep_data_flash_only"))) __attribute__ ((aligned (16))) flash_only_buffer[FLASH_ONLY_WORDS] = {
    0xABCDEF00,
    0xABCDEF01,
    0xABCDEF02,
    0xABCDEF03,
    0xABCDEF04,
    0xABCDEF05,
    0xABCDEF06,
    0xABCDEF07,
    0xABCDEF08,
    0xABCDEF09,
    0xABCDEF0A,
    0xABCDEF0B,
    0xABCDEF0C,
    0xABCDEF0D,
    0xABCDEF0E,
    0xABCDEF0F,
    0xABCDEF10,
    0xABCDEF11,
    0xABCDEF12,
    0xABCDEF13,
    0xABCDEF14,
    0xABCDEF15,
    0xABCDEF16,
    0xABCDEF17,
    0xABCDEF18,
    0xABCDEF19,
    0xABCDEF1A,
    0xABCDEF1B,
    0xABCDEF1C,
    0xABCDEF1D,
    0xABCDEF1E,
    0xABCDEF1F,
};

int32_t __attribute__ ((aligned (16))) flash_only_buffer_golden_value[FLASH_ONLY_WORDS] = {
    0xABCDEF00,
    0xABCDEF01,
    0xABCDEF02,
    0xABCDEF03,
    0xABCDEF04,
    0xABCDEF05,
    0xABCDEF06,
    0xABCDEF07,
    0xABCDEF08,
    0xABCDEF09,
    0xABCDEF0A,
    0xABCDEF0B,
    0xABCDEF0C,
    0xABCDEF0D,
    0xABCDEF0E,
    0xABCDEF0F,
    0xABCDEF10,
    0xABCDEF11,
    0xABCDEF12,
    0xABCDEF13,
    0xABCDEF14,
    0xABCDEF15,
    0xABCDEF16,
    0xABCDEF17,
    0xABCDEF18,
    0xABCDEF19,
    0xABCDEF1A,
    0xABCDEF1B,
    0xABCDEF1C,
    0xABCDEF1D,
    0xABCDEF1E,
    0xABCDEF1F,
};


int main(int argc, char *argv[])
{
    // Pick the correct spi device based on simulation type
    spi_host_t* spi;
    spi = spi_flash;

    // Setup power_manager
    power_manager_t power_manager;
    mmio_region_t power_manager_reg = mmio_region_from_addr(POWER_MANAGER_START_ADDRESS);
    power_manager.base_addr = power_manager_reg;
    power_manager_counters_t power_manager_counters;
    //counters
    uint32_t reset_off, reset_on, switch_off, switch_on, iso_off, iso_on;

    //Turn off: first, isolate the CPU outputs, then I reset it, then I switch it off (reset and switch off order does not really matter)
    iso_off = 10;
    reset_off = iso_off + 5;
    switch_off = reset_off + 5;
    //Turn on: first, give back power by switching on, then deassert the reset, the unisolate the CPU outputs
    switch_on = 10;
    reset_on = switch_on + 20; //give 20 cycles to emulate the turn on time, this number depends on technology and here it is just a random number
    iso_on = reset_on + 5;

    if (power_gate_counters_init(&power_manager_counters, reset_off, reset_on, switch_off, switch_on, iso_off, iso_on, 0, 0) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail. Check the reset and powergate counters value\n\r");
        return EXIT_FAILURE;
    }

    // Define status variable
    int32_t errors = 0;

    // Init SPI host and SPI<->Flash bridge parameters
    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    uint32_t *test_buffer_flash = heep_get_flash_address_offset(flash_only_buffer);
    // Read from flash memory at the same address
    w25q_error_codes_t status = w25q128jw_read_standard_dma_async(test_buffer_flash, on_chip_buffer, FLASH_ONLY_BYTES);
    if (status != FLASH_OK) exit(EXIT_FAILURE);

    //wait for the DMA to finish in DEEP SLEEP mode
    while (!dma_is_ready(0))
    {
        CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
        if (dma_is_ready(0) == 0)
        {
                PRINTF("Going to sleep...\r\n");
                if (power_gate_core(&power_manager, kDma_pm_e, &power_manager_counters) != kPowerManagerOk_e)
                {
                    PRINTF("Error: power manager fail.\n\r");
                    return EXIT_FAILURE;
                }
                PRINTF("Woken up...\r\n");

        }
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    }


    PRINTF("Check results...\r\n");

    // Check if what we read is correct (i.e. on_chip_buffer == flash_only_buffer_golden_value)
    for(int i = 0; i < FLASH_ONLY_WORDS; i++) {
        if (on_chip_buffer[i] != flash_only_buffer_golden_value[i]) {
            errors++;
            PRINTF("Error: on_chip_buffer[%d] = 0x%08x, flash_only_buffer_golden_value[%d] = 0x%08x\n", i, on_chip_buffer[i], i, flash_only_buffer_golden_value[i]);
        }
    }

    if(errors==0) PRINTF("TEST RUN SUCCEFFULLY\r\n");

    return errors;
}
