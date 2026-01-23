/**
 * @file main.c
 * @brief Example application for W25Q128JW flash read test.
 *
 * This application demonstrates reading data from the W25Q128JW flash memory
 *
 * Test parameters:
 * - Transfer size: 4100 bytes (spanning over 2 sectors)
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
#include "w25q128jw.h"
#include "dma.h"

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

#define MAGIC_TEST_NUM 0xda41de

int32_t sram_buffer_read_flash_back[NUM_WORDS];

int32_t dma_mem_copy[NUM_WORDS];

/**
 * @brief Compares read data against expected data.
 *
 * @param test_buffer   Pointer to the expected data buffer (what one should read back).
 * @param len           Number of bytes to compare (byte precise).
 * @return              0 if data matches, 1 otherwise.
 */
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
__attribute__ ((noinline)) void w25q128jw_controller_run(char use_interrupt, int32_t* flash_ptr) {

    spi_host_t* spi;
    spi = spi_flash;

    w25q128jw_controller_enable_interrupt(use_interrupt);

    //read
    w25q128jw_controller_read((void*) &sram_buffer_read_flash_back[0], (void*) &flash_ptr[0], (size_t) LENGTH_BYTES);

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

    // Initialize the DMA
    dma_init(NULL);
    // Pick the correct spi device based on simulation type
    spi_host_t* spi;
    spi = spi_flash;

    // Init SPI host and SPI<->Flash bridge parameters and Flash Power Up
    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    int32_t* flash_ptr_test1 = heep_get_flash_address_offset(flash_buffer_test1);
    int32_t* flash_ptr_test2 = heep_get_flash_address_offset(flash_buffer_test2);

    /**************************************************************
     * _______  ______   _____  _______        __   
     * |__   __||  ____| / ____||__   __|      /_ |  
     * | |   | |__   | (___     | |          | |  
     * | |   |  __|   \___ \    | |          | |  
     * | |   | |____  ____) |   | |          | |  
     * |_|   |______||_____/    |_|          |_|  
     * * [ TEST ]                            [ NO. 1 ]
     **************************************************************/

    // First, check that the Flash has been programmed/initialized correctly
    // we read in SW as we assume the SW is the golden model
    w25q128jw_read_standard_dma((uint32_t)flash_ptr_test1, sram_buffer_read_flash_back, LENGTH_BYTES, 0, 0);
    for(int i=0;i<NUM_WORDS;i++) {
        //in the .h, flash_buffer_test1 contains numbers from 0 to NUM_WORDS in order
        if(sram_buffer_read_flash_back[i]!=i) {
            PRINTF("At %d: expected %x, got %x\n", i, i, sram_buffer_read_flash_back[i]);
            return 1;
        }
    }

    /**************************************************************
     * _______  ______   _____  _______        ___  
     * |__   __||  ____| / ____||__   __|      |__ \ 
     * | |   | |__   | (___     | |            ) |
     * | |   |  __|   \___ \    | |           / / 
     * | |   | |____  ____) |   | |          / /_ 
     * |_|   |______||_____/    |_|         |____|
     * * [ TEST ]                            [ NO. 2 ]
     * **************************************************************/

    // Reset the flash data buffer
    memset(sram_buffer_read_flash_back, 0, LENGTH_BYTES);

    // Read from flash memory at specific address (i.e. flash_buffer_test1) in HW
    // we use polling
    //disable interrupts
    w25q128jw_controller_enable_interrupt(0);
    w25q128jw_controller_run(0, flash_ptr_test1);

    // Check Results
    for(int i=0;i<NUM_WORDS;i++) {
        //in the .h, flash_buffer_test1 contains numbers from 0 to NUM_WORDS in order
        if(sram_buffer_read_flash_back[i]!=i) {
            PRINTF("At %d: expected %x, got %x\n", i, i, sram_buffer_read_flash_back[i]);
            return 2;
        }
    }

    /**************************************************************
     * _______  ______   _____  _______        ____  
     * |__   __||  ____| / ____||__   __|      |___ \ 
     * | |   | |__   | (___     | |            __) |
     * | |   |  __|   \___ \    | |           |__ < 
     * | |   | |____  ____) |   | |           ___) |
     * |_|   |______||_____/    |_|          |____/ 
     * * [ TEST ]                            [ NO. 3 ]
     * **************************************************************/

    // Reset the flash data buffer
    memset(sram_buffer_read_flash_back, 0, LENGTH_BYTES);

    // First, check that the Flash has been programmed/initialized correctly
    // we read in SW as we assume the SW is the golden model
    w25q128jw_read_standard_dma((uint32_t)flash_ptr_test2, sram_buffer_read_flash_back, LENGTH_BYTES, 0, 0);

    // Check Results
    for(int i=0;i<NUM_WORDS;i++) {
        if(sram_buffer_read_flash_back[i]!=(i+0x800)) {
            PRINTF("At %d: expected %x, got %x\n", i, (i+0x800), sram_buffer_read_flash_back[i]);
            return 3;
        }
    }

    /**************************************************************
     * _______  ______   _____  _______        _  _   
     * |__   __||  ____| / ____||__   __|      | || |  
     * | |   | |__   | (___     | |         | || |_ 
     * | |   |  __|   \___ \    | |         |__   _|
     * | |   | |____  ____) |   | |            | |  
     * |_|   |______||_____/    |_|            |_|  
     * * [ TEST ]                            [ NO. 4 ]
     * **************************************************************/

    // Reset the flash data buffer
    memset(sram_buffer_read_flash_back, 0, LENGTH_BYTES);

    // Read the flash memory at specific address (i.e. flash_buffer_test2) in HW
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
    // Enable interrupts
    w25q128jw_controller_enable_interrupt(1);

    w25q128jw_controller_run(1, flash_ptr_test2);

     // Check Results
    for(int i=0;i<NUM_WORDS;i++) {
        if(sram_buffer_read_flash_back[i]!=(i+0x800)) {
            PRINTF("At %d: expected %x, got %x\n", i, (i+0x800), sram_buffer_read_flash_back[i]);
            return 4;
        }
    }

    /**************************************************************
     * _______  ______   _____  _______        _____ 
     * |__   __||  ____| / ____||__   __|      | ____|
     * | |   | |__   | (___     | |         | |__  
     * | |   |  __|   \___ \    | |         |___ \ 
     * | |   | |____  ____) |   | |          ___) |
     * |_|   |______||_____/    |_|         |____/ 
     * * [ TEST ]                            [ NO. 5 ]
     * **************************************************************/

     // Reset the flash data buffer
    memset(sram_buffer_read_flash_back, 0, LENGTH_BYTES);

    // Read the flash memory at specific address (i.e. flash_buffer_test1) in HW, but we use wait counters
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
    // Enable interrupts
    w25q128jw_controller_enable_interrupt(1);

    //we also use the dma slot delay counter (we wait 12 cycles after rvalid in both reads and writes)
    w25q128jw_set_dma_slot_wait_counter(12);

    w25q128jw_controller_run(1, flash_ptr_test1);

     // Check Results
    for(int i=0;i<NUM_WORDS;i++) {
        if(sram_buffer_read_flash_back[i]!=i) {
            PRINTF("At %d: expected %x, got %x\n", i, (i+0x800), sram_buffer_read_flash_back[i]);
            return 5;
        }
    }

    /**************************************************************
     * _______  ______   _____  _______         __   
     * |__   __||  ____| / ____||__   __|       / /   
     * | |   | |__   | (___     | |         / /_   
     * | |   |  __|   \___ \    | |        |  _ \  
     * | |   | |____  ____) |   | |        | (_) | 
     * |_|   |______||_____/    |_|         \___/  
     * * [ TEST ]                            [ NO. 6 ]
     * **************************************************************/

    //As the controller uses the DMA, check you can use it as before soon after
    dma_init(NULL);
    dma_trans_t dma_trans = {0};
    dma_target_t tgt_src  = {0};
    dma_target_t tgt_dst  = {0};

    memset(sram_buffer_read_flash_back, 0, LENGTH_BYTES);
    for(int i=0;i<NUM_WORDS;i++) dma_mem_copy[i] = i*i;

    // Initialize the DMA for the next tests
    tgt_src.ptr = (uint8_t *)dma_mem_copy;
    tgt_src.inc_d1_du = 1;
    tgt_src.trig = DMA_TRIG_MEMORY;
    tgt_src.type = DMA_DATA_TYPE_WORD;

    tgt_dst.ptr = (uint8_t *)sram_buffer_read_flash_back;
    tgt_dst.inc_d1_du = 1;
    tgt_dst.trig = DMA_TRIG_MEMORY;
    tgt_dst.type = DMA_DATA_TYPE_WORD;

    dma_trans.src = &tgt_src;
    dma_trans.dst = &tgt_dst;
    dma_trans.src_addr = NULL;
    dma_trans.size_d1_du = NUM_WORDS;
    dma_trans.src_type = DMA_DATA_TYPE_WORD;
    dma_trans.dst_type = DMA_DATA_TYPE_WORD;
    dma_trans.mode = DMA_TRANS_MODE_SINGLE;
    dma_trans.win_du = 0;
    dma_trans.sign_ext = 0;
    dma_trans.end = DMA_TRANS_END_POLLING;
    dma_load_transaction(&dma_trans);                                                       \
    dma_launch(&dma_trans);

     // Check Results
    for(int i=0;i<NUM_WORDS;i++) {
        if(sram_buffer_read_flash_back[i]!=dma_mem_copy[i]) {
            PRINTF("At %d: expected %x, got %x\n", i, dma_mem_copy[i], sram_buffer_read_flash_back[i]);
            return 6;
        }
    }


    return EXIT_SUCCESS;


}
