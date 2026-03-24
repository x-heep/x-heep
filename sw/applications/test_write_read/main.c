/**
 * @file main.c
 * @brief Example application for W25Q128JW flash write test.
 *
 * This application demonstrates writing data to the W25Q128JW flash memory
 * then reading it back and verifying the contents match the original data.
 *
 * Test parameters:
 * - Transfer size: 4100 bytes (spanning over 2 sectors) (write operation is word precise)
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "memory.h"

#include "core_v_mini_mcu.h"
#include "x-heep.h"

#include "w25q128jw_controller.h"
#include "sram_data.h"
#include "csr.h" // For CSR macros
#include "rv_plic.h" // For PLIC functions
#include "w25q128jw.h"
#include "dma.h"

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   1

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

#define MAGIC_TEST_NUM 0xda41de

int32_t sram_buffer_read_flash_back[NUM_WORDS];
int32_t dma_mem_copy[NUM_WORDS];


//
// ISR
//
void handler_irq_w25q128jw_controller(uint32_t id) {
    // Set the done flag
    w25q128jw_controller_set_done_flag();

    // Clear the interrupt status register (interrupt handled)
    w25q128jw_controller_clear_status_register();
}

/**
 * @brief Runs the flash write test sequence.
 *
 * This function:
 * 1. Initializes the SPI flash
 * 2. Launches write operation
 * 3. Waits for write completion
 * 4. Clears the software done flag for the next run
 *
 */
__attribute__ ((noinline)) void w25q128jw_controller_run(char use_interrupt, char use_quad, int32_t* flash_ptr) {

    w25q128jw_controller_enable_interrupt(use_interrupt);

    //write
    w25q128jw_controller_write((void*)&flash_ptr[0], (void*) &sram_data[0], (size_t) LENGTH_BYTES, use_quad);

    if(use_interrupt) {
        // Wait for interrupt
        while(!w25q128jw_controller_is_ready_intr()) {
            asm volatile("wfi");  // Wait For Interrupt - CPU sleeps
        }
    } else {
        while(!w25q128jw_controller_is_ready_polling());
    }

    //reset flag
    w25q128jw_controller_clear_done_flag();

}

int main(void) {

    uint32_t res;
    int32_t error = 0;

    // Initialize the DMA
    dma_init(NULL);
    // Pick the correct spi device based on simulation type
    spi_host_t* spi;
    spi = spi_flash;

    // Init SPI host and SPI<->Flash bridge parameters and Flash Power Up
    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    int32_t* flash_ptr_test1 = heep_get_flash_address_offset(flash_buffer_test1);
    int32_t* flash_ptr_test2 = heep_get_flash_address_offset(flash_buffer_test2);


    PRINTF("Test w25q128jw Controller write\n");

        /**************************************************************** */
    PRINTF("Test 4: Hardware Write, standard speed, DMA, interrupt\n");
    // Reset the flash data buffer
    memset(sram_buffer_read_flash_back, 0, LENGTH_BYTES);

    //change sram_data
    for(int i=0;i<NUM_WORDS;i++)
       sram_data[i] |= 0xAAAA0000;

    // Write to flash memory at specific address (i.e. flash_buffer_test2) the value from sram_data in HW
    // we use interrupt now
    // Clear HW regs before starting operation
    w25q128jw_controller_clear_status_register();
    // Clear SW flag of ISR before starting operation
    w25q128jw_controller_clear_done_flag();
    // Activate interrupt in PLIC
    plic_Init();
    plic_irq_set_priority(W25Q128JW_CONTROLLER_INTR_EVENT, 1);
    plic_irq_set_enabled(W25Q128JW_CONTROLLER_INTR_EVENT, kPlicToggleEnabled);
    // Activate global CPU interrupts
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);   // Global interrupt enable for machine mode (MIE) bit in Machine Status Registers
    CSR_SET_BITS(CSR_REG_MIE, (1 << 11)); // Machine External Interrupt Enable (MEIE) bit in Machine Interrupt Pending Register

    w25q128jw_controller_run(1, 0, flash_ptr_test1);

    PRINTF("TEST 2\n");
    for(int i=0;i<NUM_WORDS;i++)
       sram_data[i] = MAGIC_TEST_NUM + (2*i);
    w25q128jw_controller_run(1, 0, flash_ptr_test2);
    memset(sram_buffer_read_flash_back, 0, LENGTH_BYTES);
    //change sram_data
    


    PRINTF("Test 2: Hardware Read, standard speed, DMA, no interrupt\n");
    // First, check that the Flash has been programmed/initialized correctly
    // we read in SW as we assume the SW is the golden model
    w25q128jw_controller_read((void*) &sram_buffer_read_flash_back[0], (void*) &flash_ptr_test1[0], LENGTH_BYTES,0);
    while(!w25q128jw_controller_is_ready_polling());

    for(int i=0;i<NUM_WORDS;i++){
        sram_data[i] = 0x1000 + i;
        sram_data[i] |= 0xAAAA0000;
    }
    for(int i=0;i<NUM_WORDS;i++) {
        //in the .h, flash_buffer_test1 contains numbers from 0 to NUM_WORDS in order
        if(sram_buffer_read_flash_back[i]!=sram_data[i]) {
            PRINTF("At %d: expected %x, got %x\n", i, sram_data[i], sram_buffer_read_flash_back[i]);
            error = 1;
        }
        
    }
    if (error)
            return 1;

    PRINTF("All tests passed!\n");
    return EXIT_SUCCESS;
}
