/*
                              *******************
******************************* C SOURCE FILE *****************************
**                            *******************
**
** project  : X-HEEP
** filename : w25q.c
** version  : 1
** date     : 1/11/2023
**
***************************************************************************
**
** Copyright (c) EPFL contributors.
** All rights reserved.
**
***************************************************************************
*/

/***************************************************************************/
/***************************************************************************/
/**
* @file   w25q.c
* @date   1/11/2023
* @brief  Source file of the W25Q-family flash memory driver.
*/

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/****************************************************************************/
/**                                                                        **/
/*                             MODULES USED                                 */
/**                                                                        **/
/****************************************************************************/
#include "string.h"

#include "w25q128jw.h"

/* To manage addresses. */
#include "mmio.h"

/* To manage interrupts. */
#include "fast_intr_ctrl.h"
#include "csr.h"
#include "stdasm.h"

/* To manage DMA. */
#include "dma.h"

/* To get TX and RX FIFO depth */
#include "spi_host_regs.h"
/* To get SPI functions */
#include "spi_host.h"

/* To get the target of the compilation (sim or pynq) */
#include "x-heep.h"

/* To get the soc_ctrl base address */
#include "soc_ctrl_structs.h"

/* For word swap operations*/
#include "bitfield.h"

/****************************************************************************/
/**                                                                        **/
/*                        DEFINITIONS AND MACROS                            */
/**                                                                        **/
/****************************************************************************/

/**
 * The flash is expecting the address in Big endian format, so a swap is needed
 * in order to provide the MSB first.
 * Shift is needed as the byteswap is performed on 32-bit words.
*/
#define REVERT_24b_ADDR(addr) (bitfield_byteswap32(addr) >> 8)

/****************************************************************************/
/**                                                                        **/
/*                      PROTOTYPES OF LOCAL FUNCTIONS                       */
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Power up the flash.
*/
static void flash_power_up(void);

/**
 * @brief Set the QE bit in the flash status register.
 *
 * @return FLASH_OK if the QE bit is set, @ref error_codes otherwise.
*/
static w25q_error_codes_t set_QE_bit(void);

/**
 * @brief Configure the SPI<->Flash connection paramethers.
*/
static void configure_spi(void);

/**
 * @brief Wait for the flash to be ready.
 *
 * It pools the BUSY bit in the flash status register.
 * It is not checking the SUS bit status.
*/
static void flash_wait(void);

/**
 * @brief Reset the flash.
*/
static void flash_reset(void);

/**
 * @brief Erase the flash and write the data.
 *
 * It read 4k (a sector) at a time, erase it and write the data back.
 * Befor writing the data back, it modifies the buffer in order to
 * add the new data without modifing the other bytes. All the bytes
 * that are not going to be modified will be copied back as is.
 *
 * @param addr 24-bit address to write to.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
static w25q_error_codes_t erase_and_write(uint32_t addr, uint8_t *data ,uint32_t length);

/**
 * @brief Wrapper for page write.
 *
 * It performs the sanity checks and calls the page_write function with
 * the correct speed paramether. A wrapper is necessary as it is not possible
 * to program more than a page (256 bytes) at a time. So multiple calls
 * to page_write can be needed.
 *
 * @param addr 24-bit address to write to.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @param quad if 1, the write is performed at quad speed.
 * @param dma if 1, the write is performed using DMA.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
static w25q_error_codes_t page_write_wrapper(uint32_t addr, uint8_t *data, uint32_t length, uint8_t quad, uint8_t dma);

/**
 * @brief Write (up to) a page to the flash.
 *
 * @param addr 24-bit address to write to.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @param quad if 1, the write is performed at quad speed.
 * @param dma if 1, the write is performed using DMA.
*/
static w25q_error_codes_t page_write(uint32_t addr, uint8_t *data, uint32_t length, uint8_t quad, uint8_t dma);

/**
 * @brief Copy length bytes from data to the SPI TX FIFO, using DMA.
 *
 * @param data pointer to the data buffer.
 * @param length number of bytes to copy.

 * @return FLASH_OK if the operation is successful, @ref error_codes otherwise.
*/
static w25q_error_codes_t dma_send_toflash(uint8_t *data, uint32_t length);

/**
 * @brief Enable flash write.
 *
 * It sets the WEL bit in the flash status register.
 * Every action that require the WEL to be set is goig to automatically
 * clear it.
*/
static void flash_write_enable(void);

/**
 * @brief Performs sanity checks on the input parameters.
 *
 * Checks if the address is valid, the data pointer is not NULL
 * and the length is not 0.
 *
 * @param addr 24-bit address.
 * @param data pointer to the data buffer.
 * @param length number of bytes to read/write.
 * @return FLASH_OK if the sanity checks are passed, @ref error_codes otherwise.
*/
static w25q_error_codes_t w25q128jw_sanity_checks(uint32_t addr, uint8_t *data, uint32_t length);

/**
 * @brief Return the minimum between two numbers.
 *
 * The function uses signed integers in order to handle also negative numbers.
 *
 * @param a first number.
 * @param b second number.
 * @return the minimum between a and b.
*/
static int32_t MIN(int32_t a, int32_t b) {
    return (a < b) ? a : b;
}


/****************************************************************************/
/**                                                                        **/
/*                            GLOBAL VARIABLES                              */
/**                                                                        **/
/****************************************************************************/

/**
 * @brief SPI structure.
*/
spi_host_t* __attribute__((section(".xheep_init_data_crt0"))) spi; //this variable is also used by the crt0, thus keep it in this section

/**
 * @brief Static vector used in the erase_and_write function.
 *
 * It is used to store the data of a sector (4k) of the flash. Given the dimensions
 * of the vector, is not possible to allocate it dinamically as it would cause a stack
 * or heap overflow.
*/
uint8_t sector_data[FLASH_SECTOR_SIZE];


/****************************************************************************/
/**                                                                        **/
/*                           EXPORTED FUNCTIONS                             */
/**                                                                        **/
/****************************************************************************/


void w25q128jw_init_crt0() {
    //make sure spi variable is into the xheep_init_data_crt0 section
    spi = spi_flash;
    return;
}

w25q_error_codes_t w25q128jw_init(spi_host_t* spi_host) {
    /*
     * Check if memory mapped SPI is enabled. Current version of the bsp
     * does not support memory mapped SPI.
    */
    if (soc_ctrl_peri->USE_SPIMEMIO == 1) {
        return FLASH_ERROR; // Error
    }

    // Set the global spi variable to the one passed as argument.
    spi = spi_host;

    // Select SPI host as SPI output
    soc_ctrl_select_spi_host((soc_ctrl_t*)soc_ctrl_peri);

    // Enable SPI host device
    spi_set_enable(spi, true);

    // Enable SPI output
    spi_output_enable(spi, true);

    // Configure SPI<->Flash connection on CSID 0
    configure_spi();

    // Set CSID
    spi_set_csid(spi, 0);

    // Power up flash
    flash_power_up();

    // Set QE bit (only FPGA, simulation do not support status registers at all)
    #ifndef TARGET_SIM
    if (set_QE_bit() == FLASH_ERROR) return FLASH_ERROR; // Error occurred while setting QE bit
    #endif // TARGET_SIM

    return FLASH_OK; // Success
}

w25q_error_codes_t w25q128jw_read(uint32_t addr, void *data, uint32_t length) {
    // Sanity checks
    if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return FLASH_ERROR;

    // Define the status variable
    w25q_error_codes_t status;

    if (length < RX_DMA_THRESHOLD) {
        status = w25q128jw_read_quad(addr, data, length);
        if (status != FLASH_OK) return status;
    } else {
        // Wait DMA to be free
        while(!dma_is_ready(0));
        status = w25q128jw_read_quad_dma(addr, data, length);
        if (status != FLASH_OK) return status;
    }

    return FLASH_OK;
}

w25q_error_codes_t w25q128jw_write(uint32_t addr, void *data, uint32_t length, uint8_t erase_before_write) {
    // Sanity checks
    if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return FLASH_ERROR;

    // Define the status variable
    w25q_error_codes_t status = FLASH_OK;

    if (erase_before_write == 1) {
        status = erase_and_write(addr, data, length);
    } else {
        // Wait DMA to be free
        while(!dma_is_ready(0));
        status = w25q128jw_write_quad_dma(addr, data, length);
    }

    return status;
}

uint32_t* w25q128jw_read_standard_setup(uint32_t addr, void *data, uint32_t length) {

    // Sanity checks
    if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return NULL;

    // Take into account the extra bytes (if any)
    if (length % 4 != 0) {
        //only multiple of 4 bytes are supported in this function
        return NULL;
    }

    /*
     * SET UP DMA
    */
    // SPI and SPI_FLASH are the same IP so same register map
    uint32_t *fifo_ptr_rx = (uint32_t *)((uintptr_t)spi + SPI_HOST_RXDATA_REG_OFFSET);

    // Address + Read command
    uint32_t read_byte_cmd = ((REVERT_24b_ADDR(addr & 0x00ffffff) << 8) | FC_RD);
    // Load command to TX FIFO
    spi_write_word(spi, read_byte_cmd);
    spi_wait_for_ready(spi);

    // Set up segment parameters -> send command and address
    const uint32_t cmd_read_1 = spi_create_command((spi_command_t){
        .len        = 3,                 // 4 Bytes
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    // Load segment parameters to COMMAND register
    spi_set_command(spi, cmd_read_1);
    spi_wait_for_ready(spi);

    // Set up segment parameters -> read length bytes
    const uint32_t cmd_read_2 = spi_create_command((spi_command_t){
        .len        = length-1,          // len bytes
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_RX_ONLY      // Read only
    });
    spi_set_command(spi, cmd_read_2);
    spi_wait_for_ready(spi);

    
    return fifo_ptr_rx;
}

w25q_error_codes_t w25q128jw_read_standard(uint32_t addr, void* data, uint32_t length) {
    // Sanity checks
    if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return FLASH_ERROR;

    // Address + Read command
    uint32_t read_byte_cmd = ((REVERT_24b_ADDR(addr & 0x00ffffff) << 8) | FC_RD);
    // Load command to TX FIFO
    spi_write_word(spi, read_byte_cmd);
    spi_wait_for_ready(spi);

    // Set up segment parameters -> send command and address
    const uint32_t cmd_read_1 = spi_create_command((spi_command_t){
        .len        = 3,                 // 4 Bytes
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    // Load segment parameters to COMMAND register
    spi_set_command(spi, cmd_read_1);
    spi_wait_for_ready(spi);

    // Set up segment parameters -> read length bytes
    const uint32_t cmd_read_2 = spi_create_command((spi_command_t){
        .len        = length-1,          // len bytes
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_RX_ONLY      // Read only
    });
    spi_set_command(spi, cmd_read_2);
    spi_wait_for_ready(spi);

    /*
     * Set RX watermark to length. The watermark is in words.
     * If the length is not a multiple of 4, the RX watermark is set to length/4+1
     * to take into account the extra bytes.
     * If the length is higher then the RX FIFO depth, the RX watermark is set to
     * RX FIFO depth. In this case the flag is not set to 0, so the loop will
     * continue until all the data is read.
    */
    int flag = 1;
    int to_read = 0;
    int i_start = 0;
    int length_original = length;
    uint32_t *data_32bit = (uint32_t *)data;
    while (flag) {
        if (length >= SPI_HOST_PARAM_RX_DEPTH) {
            spi_set_rx_watermark(spi, SPI_HOST_PARAM_RX_DEPTH>>2);
            length -= SPI_HOST_PARAM_RX_DEPTH;
            to_read += SPI_HOST_PARAM_RX_DEPTH;
        }
        else {
            spi_set_rx_watermark(spi, (length%4==0 ? length>>2 : (length>>2)+1));
            to_read += length;
            flag = 0;
        }
        // Wait till SPI RX FIFO is full (or I read all the data)
        spi_wait_for_rx_watermark(spi);
        // Read data from SPI RX FIFO
        for (int i = i_start; i < to_read>>2; i++) {
            spi_read_word(spi, &data_32bit[i]); // Writes a full word
        }
        // Update the starting index
        i_start += SPI_HOST_PARAM_RX_DEPTH>>2;
    }
    // Take into account the extra bytes (if any)
    if (length_original % 4 != 0) {
        uint32_t last_word = 0;
        spi_read_word(spi, &last_word);
        memcpy(&data_32bit[length_original>>2], &last_word, length%4);
    }

    return FLASH_OK; // Success
}

w25q_error_codes_t w25q128jw_write_standard(uint32_t addr, void* data, uint32_t length) {
    // Call the wrapper with quad = 0, dma = 0
    return page_write_wrapper(addr, data, length, 0, 0);
}


w25q_error_codes_t w25q128jw_erase_and_write_standard(uint32_t addr, void* data, uint32_t length){

    uint32_t remaining_length = length;
    uint32_t current_addr = addr;
    uint8_t *current_data = data;

    w25q_error_codes_t status;

    while (remaining_length > 0) {
        // Start address of the sector to erase, 4kB aligned
        uint32_t sector_start_addr = current_addr & 0xfffff000;

        // Read the full sector and save it into RAM
        status = w25q128jw_read_standard(sector_start_addr, sector_data, FLASH_SECTOR_SIZE);
        if (status != FLASH_OK) return FLASH_ERROR;

        // Erase the sector (no need to do so in simulation)
        #ifndef TARGET_SIM
        w25q128jw_4k_erase(sector_start_addr);
        #endif // TARGET_SIM

        // Calculate the length of data to write in this sector
        uint32_t write_length = MIN(FLASH_SECTOR_SIZE - (current_addr - sector_start_addr), remaining_length);

        // Modify the data in RAM to include the new data
        memcpy(&sector_data[current_addr - sector_start_addr], current_data, write_length);

        // Write the modified data back to the flash
        status = w25q128jw_write_standard(sector_start_addr, sector_data, FLASH_SECTOR_SIZE);
        if (status != FLASH_OK) return FLASH_ERROR;

        // Update the remaining length, address and data pointer
        remaining_length -= write_length;
        current_addr += write_length;
        current_data += write_length;
    }

    return FLASH_OK;

}

w25q_error_codes_t w25q128jw_read_standard_dma(uint32_t addr, void *data, uint32_t length, uint8_t no_wait_init_dma, uint8_t no_sanity_checks) {

    // Sanity checks
    if (!no_sanity_checks)  if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return FLASH_ERROR;

    /*
     * SET UP DMA
    */
    // SPI and SPI_FLASH are the same IP so same register map
    uint32_t *fifo_ptr_rx = (uint32_t *)((uintptr_t)spi + SPI_HOST_RXDATA_REG_OFFSET);

    // Init DMA, the integrated DMA is used (peri == NULL)
    if(!no_wait_init_dma)    dma_init(NULL);

    // The DMA will wait for the SPI FLASH RX FIFO valid signal
    uint8_t slot = DMA_TRIG_SLOT_SPI_FLASH_RX;

    // Set up DMA source target
    static dma_target_t tgt_src = {
        .inc_d1_du = 0, // Target is peripheral, no increment
        .type = DMA_DATA_TYPE_WORD, // Data type is word
    };
    // Target is SPI RX FIFO
    tgt_src.ptr = (uint8_t*)fifo_ptr_rx;
    // Trigger to control the data flow
    tgt_src.trig = slot;

    // Set up DMA destination target
    static dma_target_t tgt_dst = {
        .inc_d1_du = 1, // Increment by 1 data unit (word)
        .type = DMA_DATA_TYPE_WORD, // Data type is byte
        .trig = DMA_TRIG_MEMORY, // Read-write operation to memory
    };
    tgt_dst.ptr = (uint8_t*)data; // Target is the data buffer

    // Set up DMA transaction
    static dma_trans_t trans = {
        .src = &tgt_src,
        .dst = &tgt_dst,
        .end = DMA_TRANS_END_POLLING,
    };
    // Size is in data units (words in this case)
    trans.size_d1_du = length>>2;

    // Validate, load and launch DMA transaction

    dma_config_flags_t res;
    res = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY );
    res = dma_load_transaction(&trans);
    res = dma_launch(&trans);

    // Address + Read command
    uint32_t read_byte_cmd = ((REVERT_24b_ADDR(addr & 0x00ffffff) << 8) | FC_RD);
    // Load command to TX FIFO
    spi_write_word(spi, read_byte_cmd);
    spi_wait_for_ready(spi);

    // Set up segment parameters -> send command and address
    const uint32_t cmd_read_1 = spi_create_command((spi_command_t){
        .len        = 3,                 // 4 Bytes
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    // Load segment parameters to COMMAND register
    spi_set_command(spi, cmd_read_1);
    spi_wait_for_ready(spi);

    // Set up segment parameters -> read length bytes
    const uint32_t cmd_read_2 = spi_create_command((spi_command_t){
        .len        = length-1,          // len bytes
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_RX_ONLY      // Read only
    });
    spi_set_command(spi, cmd_read_2);
    spi_wait_for_ready(spi);

    // Wait for DMA to finish transaction
    if(!no_wait_init_dma) while(!dma_is_ready(0));

    // Take into account the extra bytes (if any)
    if (length % 4 != 0) {
        uint32_t last_word = 0;

        spi_read_word((spi_host_t *)spi, &last_word);
    #ifdef __cplusplus
        memcpy(static_cast<uint8_t*>(data) + length - (length % 4), &last_word, length % 4);
    #else
        memcpy(&data[length - length%4], &last_word, length%4);
    #endif
    }

    return FLASH_OK;
}

w25q_error_codes_t w25q128jw_read_standard_dma_async(uint32_t addr, void *data, uint32_t length) {

    // Sanity checks
    if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return FLASH_ERROR;

    // Take into account the extra bytes (if any)
    if (length % 4 != 0) {
        //only multiple of 4 bytes are supported in this function
        return FLASH_ERROR;
    }

    /*
     * SET UP DMA
    */
    // SPI and SPI_FLASH are the same IP so same register map
    uint32_t *fifo_ptr_rx = (uint32_t *)((uintptr_t)spi + SPI_HOST_RXDATA_REG_OFFSET);

    // Init DMA, the integrated DMA is used (peri == NULL)
    dma_init(NULL);

    // The DMA will wait for the SPI FLASH RX FIFO valid signal
    uint8_t slot = DMA_TRIG_SLOT_SPI_FLASH_RX;

    // Set up DMA source target
    static dma_target_t tgt_src = {
        .inc_d1_du = 0, // Target is peripheral, no increment
        .type = DMA_DATA_TYPE_WORD, // Data type is word
    };
    // Target is SPI RX FIFO
    tgt_src.ptr = (uint8_t*)fifo_ptr_rx;
    // Trigger to control the data flow
    tgt_src.trig = slot;

    // Set up DMA destination target
    static dma_target_t tgt_dst = {
        .inc_d1_du = 1, // Increment by 1 data unit (word)
        .type = DMA_DATA_TYPE_WORD, // Data type is byte
        .trig = DMA_TRIG_MEMORY, // Read-write operation to memory
    };
    tgt_dst.ptr = (uint8_t*)data; // Target is the data buffer

    // Set up DMA transaction
    static dma_trans_t trans = {
        .src = &tgt_src,
        .dst = &tgt_dst,
        .end = DMA_TRANS_END_INTR, //so that you can wait for interrupt
    };
    // Size is in data units (words in this case)
    trans.size_d1_du = length>>2;
    // Validate, load and launch DMA transaction
    dma_config_flags_t res;
    res = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY );
    res = dma_load_transaction(&trans);
    res = dma_launch(&trans);

    // Address + Read command
    uint32_t read_byte_cmd = ((REVERT_24b_ADDR(addr & 0x00ffffff) << 8) | FC_RD);
    // Load command to TX FIFO
    spi_write_word(spi, read_byte_cmd);
    spi_wait_for_ready(spi);

    // Set up segment parameters -> send command and address
    const uint32_t cmd_read_1 = spi_create_command((spi_command_t){
        .len        = 3,                 // 4 Bytes
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    // Load segment parameters to COMMAND register
    spi_set_command(spi, cmd_read_1);
    spi_wait_for_ready(spi);

    // Set up segment parameters -> read length bytes
    const uint32_t cmd_read_2 = spi_create_command((spi_command_t){
        .len        = length-1,          // len bytes
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_RX_ONLY      // Read only
    });
    spi_set_command(spi, cmd_read_2);
    spi_wait_for_ready(spi);

    // Wait for DMA to finish transaction outside this function, the DMA generates also an interrupt
    // However, you need to enable the interrupt in the INT controllers, and CPU

    return FLASH_OK;
}


w25q_error_codes_t w25q128jw_write_standard_dma(uint32_t addr, void *data, uint32_t length) {
    // Call the wrapper with quad = 0, dma = 1
    return page_write_wrapper(addr, data, length, 0, 1);
}

w25q_error_codes_t w25q128jw_erase_and_write_standard_dma(uint32_t addr, void* data, uint32_t length){

    uint32_t remaining_length = length;
    uint32_t current_addr = addr;
    uint8_t *current_data = data;

    w25q_error_codes_t status;

    while (remaining_length > 0) {
        // Start address of the sector to erase, 4kB aligned
        uint32_t sector_start_addr = current_addr & 0xfffff000;

        // Read the full sector and save it into RAM
        status = w25q128jw_read_standard_dma(sector_start_addr, sector_data, FLASH_SECTOR_SIZE, 0, 0);
        if (status != FLASH_OK) return FLASH_ERROR;

        // Erase the sector (no need to do so in simulation)
        #ifndef TARGET_SIM
        w25q128jw_4k_erase(sector_start_addr);
        #endif // TARGET_SIM

        // Calculate the length of data to write in this sector
        uint32_t write_length = MIN(FLASH_SECTOR_SIZE - (current_addr - sector_start_addr), remaining_length);

        // Modify the data in RAM to include the new data
        memcpy(&sector_data[current_addr - sector_start_addr], current_data, write_length);

        // Write the modified data back to the flash
        status = w25q128jw_write_standard_dma(sector_start_addr, sector_data, FLASH_SECTOR_SIZE);
        if (status != FLASH_OK) return FLASH_ERROR;

        // Update the remaining length, address and data pointer
        remaining_length -= write_length;
        current_addr += write_length;
        current_data += write_length;
    }

    return FLASH_OK;

}

uint32_t* w25q128jw_read_quad_setup(uint32_t addr, void *data, uint32_t length) {
    // Sanity checks
    if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return NULL;

    // Send quad read command at standard speed
    uint32_t cmd_read_quadIO = FC_RDQIO;
    spi_write_word(spi, cmd_read_quadIO);
    const uint32_t cmd_read = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_read);
    spi_wait_for_ready(spi);

    /*
     * Send address at quad speed.
     * Last byte is Fxh (here FFh) required by W25Q128JW
    */
    uint32_t read_byte_cmd = (REVERT_24b_ADDR(addr) | (0xFF << 24));
    spi_write_word(spi, read_byte_cmd);
    const uint32_t cmd_address = spi_create_command((spi_command_t){
        .len        = 3,                // 3 Byte
        .csaat      = true,             // Command not finished
        .speed      = SPI_SPEED_QUAD,    // Quad speed
        .direction  = SPI_DIR_TX_ONLY     // Write only
    });
    spi_set_command(spi, cmd_address);
    spi_wait_for_ready(spi);

    // Quad read requires dummy clocks
    const uint32_t dummy_clocks_cmd = spi_create_command((spi_command_t){
        #ifndef TARGET_SIM
        .len        = DUMMY_CLOCKS_FAST_READ_QUAD_IO-1, // W25Q128JW flash needs 4 dummy cycles
        #else
        .len        = DUMMY_CLOCKS_SIM-1, // SPI flash simulation model needs 8 dummy cycles
        #endif
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_QUAD,     // Quad speed
        .direction  = SPI_DIR_DUMMY       // Dummy
    });
    spi_set_command(spi, dummy_clocks_cmd);
    spi_wait_for_ready(spi);

    // Read back the requested data at quad speed
    const uint32_t cmd_read_rx = spi_create_command((spi_command_t){
        .len        = length-1,        // length bytes
        .csaat      = false,           // End command
        .speed      = SPI_SPEED_QUAD,   // Quad speed
        .direction  = SPI_DIR_RX_ONLY    // Read only
    });
    spi_set_command(spi, cmd_read_rx);
    spi_wait_for_ready(spi);

    /* COMMAND FINISHED */

    // SPI and SPI_FLASH are the same IP so same register map
    return (uint32_t *)((uintptr_t)spi + SPI_HOST_RXDATA_REG_OFFSET);

}

w25q_error_codes_t w25q128jw_read_quad(uint32_t addr, void *data, uint32_t length) {
    // Sanity checks
    if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return FLASH_ERROR;

    // Send quad read command at standard speed
    uint32_t cmd_read_quadIO = FC_RDQIO;
    spi_write_word(spi, cmd_read_quadIO);
    const uint32_t cmd_read = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_read);
    spi_wait_for_ready(spi);

    /*
     * Send address at quad speed.
     * Last byte is Fxh (here FFh) required by W25Q128JW
    */
    uint32_t read_byte_cmd = (REVERT_24b_ADDR(addr) | (0xFF << 24));
    spi_write_word(spi, read_byte_cmd);
    const uint32_t cmd_address = spi_create_command((spi_command_t){
        .len        = 3,                // 3 Byte
        .csaat      = true,             // Command not finished
        .speed      = SPI_SPEED_QUAD,    // Quad speed
        .direction  = SPI_DIR_TX_ONLY     // Write only
    });
    spi_set_command(spi, cmd_address);
    spi_wait_for_ready(spi);

    // Quad read requires dummy clocks
    const uint32_t dummy_clocks_cmd = spi_create_command((spi_command_t){
        #ifndef TARGET_SIM
        .len        = DUMMY_CLOCKS_FAST_READ_QUAD_IO-1,
        #else
        .len        = DUMMY_CLOCKS_SIM-1,
        #endif
        .csaat      = true,            // Command not finished
        .speed      = SPI_SPEED_QUAD,   // Quad speed
        .direction  = SPI_DIR_DUMMY     // Dummy
    });
    spi_set_command(spi, dummy_clocks_cmd);
    spi_wait_for_ready(spi);

    // Read back the requested data at quad speed
    const uint32_t cmd_read_rx = spi_create_command((spi_command_t){
        .len        = length-1,        // 32 Byte
        .csaat      = false,           // End command
        .speed      = SPI_SPEED_QUAD,   // Quad speed
        .direction  = SPI_DIR_RX_ONLY    // Read only
    });
    spi_set_command(spi, cmd_read_rx);
    spi_wait_for_ready(spi);

    /* COMMAND FINISHED */

    /*
     * Set RX watermark to length. The watermark is in words.
     * If the length is not a multiple of 4, the RX watermark is set to length/4+1
     * to take into account the extra bytes.
     * If the length is higher then the RX FIFO depth, the RX watermark is set to
     * RX FIFO depth. In this case the flag is not set to 0, so the loop will
     * continue until all the data is read.
    */
    int flag = 1;
    int to_read = 0;
    int i_start = 0;
    int length_original = length;
    uint32_t *data_32bit = (uint32_t *)data;
    while (flag) {
        if (length >= SPI_HOST_PARAM_RX_DEPTH) {
            spi_set_rx_watermark(spi, SPI_HOST_PARAM_RX_DEPTH>>2);
            length -= SPI_HOST_PARAM_RX_DEPTH;
            to_read += SPI_HOST_PARAM_RX_DEPTH;
        }
        else {
            spi_set_rx_watermark(spi, (length%4==0 ? length>>2 : (length>>2)+1));
            to_read += length;
            flag = 0;
        }
        // Wait till SPI RX FIFO is full (or I read all the data)
        spi_wait_for_rx_watermark(spi);
        // Read data from SPI RX FIFO
        for (int i = i_start; i < to_read>>2; i++) {
            spi_read_word(spi, &data_32bit[i]); // Writes a full word
        }
        // Update the starting index
        i_start += SPI_HOST_PARAM_RX_DEPTH>>2;
    }
    // Take into account the extra bytes (if any)
    if (length_original%4 != 0) {
        uint32_t last_word = 0;
        spi_read_word(spi, &last_word);
        memcpy(&data_32bit[length_original>>2], &last_word, length%4);
    }

    return FLASH_OK; // Success
}

w25q_error_codes_t w25q128jw_write_quad(uint32_t addr, void *data, uint32_t length) {
    // Call the wrapper with quad = 1, dma = 0
    return page_write_wrapper(addr, data, length, 1, 0);
}


w25q_error_codes_t w25q128jw_erase_and_write_quad(uint32_t addr, void *data, uint32_t length) {

    uint32_t remaining_length = length;
    uint32_t current_addr = addr;
    uint8_t *current_data = data;

    w25q_error_codes_t status;

    while (remaining_length > 0) {
        // Start address of the sector to erase, 4kB aligned
        uint32_t sector_start_addr = current_addr & 0xfffff000;

        // Read the full sector and save it into RAM
        status = w25q128jw_read_quad(sector_start_addr, sector_data, FLASH_SECTOR_SIZE);
        if (status != FLASH_OK) return FLASH_ERROR;

        // Erase the sector (no need to do so in simulation)
        #ifndef TARGET_SIM
        w25q128jw_4k_erase(sector_start_addr);
        #endif // TARGET_SIM

        // Calculate the length of data to write in this sector
        uint32_t write_length = MIN(FLASH_SECTOR_SIZE - (current_addr - sector_start_addr), remaining_length);

        // Modify the data in RAM to include the new data
        memcpy(&sector_data[current_addr - sector_start_addr], current_data, write_length);

        // Write the modified data back to the flash
        status = w25q128jw_write_quad(sector_start_addr, sector_data, FLASH_SECTOR_SIZE);
        if (status != FLASH_OK) return FLASH_ERROR;

        // Update the remaining length, address and data pointer
        remaining_length -= write_length;
        current_addr += write_length;
        current_data += write_length;
    }

    return FLASH_OK;

}


w25q_error_codes_t w25q128jw_read_quad_dma(uint32_t addr, void *data, uint32_t length) {
    // Sanity checks
    if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return FLASH_ERROR;

    // Send quad read command at standard speed
    uint32_t cmd_read_quadIO = FC_RDQIO;
    spi_write_word(spi, cmd_read_quadIO);
    const uint32_t cmd_read = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_read);
    spi_wait_for_ready(spi);

    /*
     * Send address at quad speed.
     * Last byte is Fxh (here FFh) required by W25Q128JW
    */
    uint32_t read_byte_cmd = (REVERT_24b_ADDR(addr) | (0xFF << 24));
    spi_write_word(spi, read_byte_cmd);
    const uint32_t cmd_address = spi_create_command((spi_command_t){
        .len        = 3,                // 3 Byte
        .csaat      = true,             // Command not finished
        .speed      = SPI_SPEED_QUAD,    // Quad speed
        .direction  = SPI_DIR_TX_ONLY     // Write only
    });
    spi_set_command(spi, cmd_address);
    spi_wait_for_ready(spi);

    // Quad read requires dummy clocks
    const uint32_t dummy_clocks_cmd = spi_create_command((spi_command_t){
        #ifndef TARGET_SIM
        .len        = DUMMY_CLOCKS_FAST_READ_QUAD_IO-1, // W25Q128JW flash needs 4 dummy cycles
        #else
        .len        = DUMMY_CLOCKS_SIM-1, // SPI flash simulation model needs 8 dummy cycles
        #endif
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_QUAD,     // Quad speed
        .direction  = SPI_DIR_DUMMY       // Dummy
    });
    spi_set_command(spi, dummy_clocks_cmd);
    spi_wait_for_ready(spi);

    // Read back the requested data at quad speed
    const uint32_t cmd_read_rx = spi_create_command((spi_command_t){
        .len        = length-1,        // length bytes
        .csaat      = false,           // End command
        .speed      = SPI_SPEED_QUAD,   // Quad speed
        .direction  = SPI_DIR_RX_ONLY    // Read only
    });
    spi_set_command(spi, cmd_read_rx);
    spi_wait_for_ready(spi);

    /* COMMAND FINISHED */

    /*
     * SET UP DMA
    */
    // SPI and SPI_FLASH are the same IP so same register map
    uint32_t *fifo_ptr_rx = (uint32_t *)((uintptr_t)spi + SPI_HOST_RXDATA_REG_OFFSET);

    // Init DMA, the integrated DMA is used (peri == NULL)
    dma_init(NULL);

    // The DMA will wait for the SPI FLASH RX FIFO valid signal
    uint8_t slot = DMA_TRIG_SLOT_SPI_FLASH_RX;

    // Set up DMA source target
    static dma_target_t tgt_src = {
        .inc_d1_du = 0, // Target is peripheral, no increment
        .type = DMA_DATA_TYPE_WORD, // Data type is byte
    };
    // Target is SPI RX FIFO
    tgt_src.ptr = (uint8_t*)fifo_ptr_rx;
    // Trigger to control the data flow
    tgt_src.trig = slot;

    // Set up DMA destination target
    static dma_target_t tgt_dst = {
        .inc_d1_du = 1, // Increment by 1 data unit (word)
        .type = DMA_DATA_TYPE_WORD, // Data type is byte
        .trig = DMA_TRIG_MEMORY, // Read-write operation to memory
    };
    tgt_dst.ptr = (uint8_t*)data; // Target is the data buffer

    // Set up DMA transaction
    static dma_trans_t trans = {
        .src = &tgt_src,
        .dst = &tgt_dst,
        .end = DMA_TRANS_END_POLLING,
    };
    // Size is in data units (words in this case)
    trans.size_d1_du = length>>2;

    // Validate, load and launch DMA transaction
    dma_config_flags_t res;
    res = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY );
    res = dma_load_transaction(&trans);
    res = dma_launch(&trans);

    // Wait for DMA to finish transaction
    while(!dma_is_ready(0));

    // Take into account the extra bytes (if any)
    if (length % 4 != 0) {
        uint32_t last_word = 0;
      
        spi_read_word((spi_host_t *)spi, &last_word);

    #ifdef __cplusplus
        memcpy(static_cast<uint8_t*>(data) + length - (length % 4), &last_word, length % 4);
    #else
        memcpy(&data[length - length%4], &last_word, length%4);
    #endif
     
    }

    return FLASH_OK;
}

w25q_error_codes_t w25q128jw_read_quad_dma_async(uint32_t addr, void *data, uint32_t length) {
    // Sanity checks
    if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return FLASH_ERROR;

    // Send quad read command at standard speed
    uint32_t cmd_read_quadIO = FC_RDQIO;
    spi_write_word(spi, cmd_read_quadIO);
    const uint32_t cmd_read = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_read);
    spi_wait_for_ready(spi);

    /*
     * Send address at quad speed.
     * Last byte is Fxh (here FFh) required by W25Q128JW
    */
    uint32_t read_byte_cmd = (REVERT_24b_ADDR(addr) | (0xFF << 24));
    spi_write_word(spi, read_byte_cmd);
    const uint32_t cmd_address = spi_create_command((spi_command_t){
        .len        = 3,                // 3 Byte
        .csaat      = true,             // Command not finished
        .speed      = SPI_SPEED_QUAD,    // Quad speed
        .direction  = SPI_DIR_TX_ONLY     // Write only
    });
    spi_set_command(spi, cmd_address);
    spi_wait_for_ready(spi);

    // Quad read requires dummy clocks
    const uint32_t dummy_clocks_cmd = spi_create_command((spi_command_t){
        #ifndef TARGET_SIM
        .len        = DUMMY_CLOCKS_FAST_READ_QUAD_IO-1, // W25Q128JW flash needs 4 dummy cycles
        #else
        .len        = DUMMY_CLOCKS_SIM-1, // SPI flash simulation model needs 8 dummy cycles
        #endif
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_QUAD,     // Quad speed
        .direction  = SPI_DIR_DUMMY       // Dummy
    });
    spi_set_command(spi, dummy_clocks_cmd);
    spi_wait_for_ready(spi);

    // Read back the requested data at quad speed
    const uint32_t cmd_read_rx = spi_create_command((spi_command_t){
        .len        = length-1,        // length bytes
        .csaat      = false,           // End command
        .speed      = SPI_SPEED_QUAD,   // Quad speed
        .direction  = SPI_DIR_RX_ONLY    // Read only
    });
    spi_set_command(spi, cmd_read_rx);
    spi_wait_for_ready(spi);

    /* COMMAND FINISHED */

    /*
     * SET UP DMA
    */
    // SPI and SPI_FLASH are the same IP so same register map
    uint32_t *fifo_ptr_rx = (uint32_t *)((uintptr_t)spi + SPI_HOST_RXDATA_REG_OFFSET);

    // Init DMA, the integrated DMA is used (peri == NULL)
    dma_init(NULL);

    // The DMA will wait for the SPI FLASH RX FIFO valid signal
    uint8_t slot = DMA_TRIG_SLOT_SPI_FLASH_RX;

    // Set up DMA source target
    static dma_target_t tgt_src = {
        .inc_d1_du = 0, // Target is peripheral, no increment
        .type = DMA_DATA_TYPE_WORD, // Data type is byte
    };
    // Target is SPI RX FIFO
    tgt_src.ptr = (uint8_t*)fifo_ptr_rx;
    // Trigger to control the data flow
    tgt_src.trig = slot;

    // Set up DMA destination target
    static dma_target_t tgt_dst = {
        .inc_d1_du = 1, // Increment by 1 data unit (word)
        .type = DMA_DATA_TYPE_WORD, // Data type is byte
        .trig = DMA_TRIG_MEMORY, // Read-write operation to memory
    };
    tgt_dst.ptr = (uint8_t*)data; // Target is the data buffer

    // Set up DMA transaction
    static dma_trans_t trans = {
        .src = &tgt_src,
        .dst = &tgt_dst,
        .end = DMA_TRANS_END_POLLING,
    };
    // Size is in data units (words in this case)
    trans.size_d1_du = length>>2;

    // Validate, load and launch DMA transaction
    dma_config_flags_t res;
    res = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY );
    res = dma_load_transaction(&trans);
    res = dma_launch(&trans);

    return FLASH_OK;
}

void w25q128jw_wait_quad_dma_async(void *data, uint32_t length){
    // Wait for DMA to finish transaction
    while(!dma_is_ready(0));

    // Take into account the extra bytes (if any)
    if (length % 4 != 0) {
        uint32_t last_word = 0;
      
        spi_read_word((spi_host_t *)spi, &last_word);

    #ifdef __cplusplus
        memcpy(static_cast<uint8_t*>(data) + length - (length % 4), &last_word, length % 4);
    #else
        memcpy(&data[length - length%4], &last_word, length%4);
    #endif
     
    }
}

w25q_error_codes_t w25q128jw_write_quad_dma(uint32_t addr, void *data, uint32_t length) {
    // Call the wrapper with quad = 1, dma = 1
    return page_write_wrapper(addr, (uint8_t *)data, length, 1, 1);
}

w25q_error_codes_t w25q128jw_erase_and_write_quad_dma(uint32_t addr, void *data, uint32_t length) {

    uint32_t remaining_length = length;
    uint32_t current_addr = addr;
    uint8_t *current_data = (uint8_t *)data;

    w25q_error_codes_t status;

    while (remaining_length > 0) {
        // Start address of the sector to erase, 4kB aligned
        uint32_t sector_start_addr = current_addr & 0xfffff000;

        // Read the full sector and save it into RAM
        status = w25q128jw_read_quad_dma(sector_start_addr, sector_data, FLASH_SECTOR_SIZE);
        if (status != FLASH_OK) return FLASH_ERROR;

        // Erase the sector (no need to do so in simulation)
        #ifndef TARGET_SIM
        w25q128jw_4k_erase(sector_start_addr);
        #endif // TARGET_SIM

        // Calculate the length of data to write in this sector
        uint32_t write_length = MIN(FLASH_SECTOR_SIZE - (current_addr - sector_start_addr), remaining_length);

        // Modify the data in RAM to include the new data
        memcpy(&sector_data[current_addr - sector_start_addr], current_data, write_length);

        // Write the modified data back to the flash
        status = w25q128jw_write_quad_dma(sector_start_addr, sector_data, FLASH_SECTOR_SIZE);
        if (status != FLASH_OK) return FLASH_ERROR;

        // Update the remaining length, address and data pointer
        remaining_length -= write_length;
        current_addr += write_length;
        current_data += write_length;
    }

    return FLASH_OK;

}

w25q_error_codes_t w25q128jw_4k_erase(uint32_t addr) {
    // Sanity checks
    if (addr > MAX_FLASH_ADDR || addr < 0) return FLASH_ERROR;

    // Wait any other operation to finish
    flash_wait();

    // Enable flash write in order to erase
    flash_write_enable();

    // Build and send erase command
    uint32_t erase_4k_cmd = ((REVERT_24b_ADDR(addr & 0x00ffffff) << 8) | FC_SE);
    spi_write_word(spi, erase_4k_cmd);
    spi_wait_for_ready(spi);
    const uint32_t cmd_erase = spi_create_command((spi_command_t){
        .len        = 3,                 // 4 Bytes
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_erase);
    spi_wait_for_ready(spi);

    // Wait for the erase operation to be finished
    flash_wait();
}

w25q_error_codes_t w25q128jw_32k_erase(uint32_t addr) {
    // Sanity checks
    if (addr > 0x00ffffff || addr < 0) return FLASH_ERROR;

    // Wait any other operation to finish
    flash_wait();

    // Enable flash write in order to erase
    flash_write_enable();

    // Build and send erase command
    uint32_t erase_32k_cmd = ((REVERT_24b_ADDR(addr & 0x00ffffff) << 8) | FC_BE32);
    spi_write_word(spi, erase_32k_cmd);
    spi_wait_for_ready(spi);
    const uint32_t cmd_erase = spi_create_command((spi_command_t){
        .len        = 3,                 // 4 Bytes
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_erase);
    spi_wait_for_ready(spi);

    // Wait for the erase operation to be finished
    flash_wait();
}

w25q_error_codes_t w25q128jw_64k_erase(uint32_t addr) {
    // Sanity checks
    if (addr > 0x00ffffff || addr < 0) return FLASH_ERROR;

    // Wait any other operation to finish
    flash_wait();

    // Enable flash write in order to erase
    flash_write_enable();

    // Build and send erase command
    uint32_t erase_64k_cmd = ((REVERT_24b_ADDR(addr & 0x00ffffff) << 8) | FC_BE64);
    spi_write_word(spi, erase_64k_cmd);
    spi_wait_for_ready(spi);
    const uint32_t cmd_erase = spi_create_command((spi_command_t){
        .len        = 3,                 // 4 Bytes
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_erase);
    spi_wait_for_ready(spi);

    // Wait for the erase operation to be finished
    flash_wait();
}

void w25q128jw_chip_erase(void) {
    // Wait any other operation to finish
    flash_wait();

    // Enable flash write in order to erase
    flash_write_enable();

    // Build and send erase command
    spi_write_word(spi, FC_CE);
    spi_wait_for_ready(spi);
    const uint32_t cmd_erase = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Bytes
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_erase);
    spi_wait_for_ready(spi);

    // Wait for the erase operation to be finished
    flash_wait();
}

void w25q128jw_reset(void) {
    // Wait for ongoing operation to finish (if any)
    flash_wait();

    // Build and send reset command
    flash_reset();

    // Wait for the reset operation to be finished
    flash_wait();
}

void w25q128jw_reset_force(void) {
    // Build and send reset command without waiting for ongoing operation
    flash_reset();

    // Wait for the reset operation to be finished
    flash_wait();
}

void w25q128jw_power_down(void) {
    // Build and send power down command
    spi_write_word(spi, FC_PD);
    const uint32_t cmd_power_down = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_power_down);
    spi_wait_for_ready(spi);
}


/****************************************************************************/
/**                                                                        **/
/*                            LOCAL FUNCTIONS                               */
/**                                                                        **/
/****************************************************************************/

static void flash_power_up(void) {
    spi_write_word(spi, FC_RPD);
    spi_wait_for_ready(spi);
    const uint32_t cmd_powerup = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_powerup);
    spi_wait_for_ready(spi);
}

static w25q_error_codes_t set_QE_bit(void) {
    spi_set_rx_watermark(spi,1);

    // Read Status Register 2
    const uint32_t reg2_read_cmd = FC_RSR2;
    spi_write_word(spi, reg2_read_cmd);

    const uint32_t reg2_read_1 = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, reg2_read_1);
    spi_wait_for_ready(spi);

    const uint32_t reg2_read_2 = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Standard speed
        .direction  = SPI_DIR_RX_ONLY      // Read only
    });
    spi_set_command(spi, reg2_read_2);
    spi_wait_for_ready(spi);
    spi_wait_for_rx_watermark(spi);

    /*
     * the partial word will be zero-padded and inserted into the RX FIFO once the segment is completed
     * The actual register is 8 bit, but the SPI host gives a full word
    */
    uint32_t reg2_data;
    spi_read_word(spi, &reg2_data);

    // Set bit in position 1 (QE bit), leaving the others unchanged
    reg2_data |= 0x2;

    // Enable write operation
    flash_write_enable();

    // Write Status Register 2 (set QE bit)
    const uint32_t reg2_write_cmd = FC_WSR2;
    spi_write_word(spi, reg2_write_cmd);

    const uint32_t reg2_write_1 = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = true,              // Command not finished
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, reg2_write_1);
    spi_wait_for_ready(spi);

    // Load data to TX FIFO
    spi_write_word(spi, reg2_data);

    // Create command segment
    const uint32_t reg2_write_2 = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Standard speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, reg2_write_2);
    spi_wait_for_ready(spi);

    // Wait flash to complete write routine
    flash_wait();

    // Read back Status Register 2
    spi_write_word(spi, reg2_read_cmd);
    spi_set_command(spi, reg2_read_1);
    spi_wait_for_ready(spi);
    spi_set_command(spi, reg2_read_2);
    spi_wait_for_ready(spi);
    spi_wait_for_rx_watermark(spi);
    uint32_t reg2_data_check = 0x00;
    spi_read_word(spi, &reg2_data_check);

    // Check if the QE bit is set
    if ((reg2_data_check & 0x2) == 0) return FLASH_ERROR;
    else return FLASH_OK;
}

static void configure_spi(void) {
    // Configure SPI clock
    uint32_t core_clk = soc_ctrl_peri->SYSTEM_FREQUENCY_HZ;
    uint16_t clk_div = 0;
    if(FLASH_CLK_MAX_HZ < core_clk/2){
        clk_div = (core_clk/(FLASH_CLK_MAX_HZ) - 2)/2; // The value is truncated
        if (core_clk/(2 + 2 * clk_div) > FLASH_CLK_MAX_HZ) clk_div += 1; // Adjust if the truncation was not 0
    }
    // SPI Configuration
    // Configure chip 0 (flash memory)
    const uint32_t chip_cfg = spi_create_configopts((spi_configopts_t){
        .clkdiv     = clk_div,
        .csnidle    = 0xF,
        .csntrail   = 0xF,
        .csnlead    = 0xF,
        .fullcyc    = false,
        .cpha       = 0,
        .cpol       = 0
    });
    spi_set_configopts(spi, 0, chip_cfg);
}

static void flash_wait(void) {
    spi_set_rx_watermark(spi,1);
    bool flash_busy = true;
    uint8_t flash_resp[4] = {0xff,0xff,0xff,0xff};

    while(flash_busy){
        uint32_t flash_cmd = FC_RSR1; // [CMD] Read status register 1
        spi_write_word(spi, flash_cmd); // Push TX buffer
        uint32_t spi_status_cmd = spi_create_command((spi_command_t){
            .len        = 0,
            .csaat      = true,
            .speed      = SPI_SPEED_STANDARD,
            .direction  = SPI_DIR_TX_ONLY
        });
        uint32_t spi_status_read_cmd = spi_create_command((spi_command_t){
            .len        = 0,
            .csaat      = false,
            .speed      = SPI_SPEED_STANDARD,
            .direction  = SPI_DIR_RX_ONLY
        });
        spi_set_command(spi, spi_status_cmd);
        spi_wait_for_ready(spi);
        spi_set_command(spi, spi_status_read_cmd);
        spi_wait_for_ready(spi);
        spi_wait_for_rx_watermark(spi);
        spi_read_word(spi, (uint32_t *)flash_resp);
        if ((flash_resp[0] & 0x01) == 0) flash_busy = false;
    }
}

static void flash_reset(void) {
    spi_write_word(spi, FC_ERESET);
    spi_write_word(spi, FC_RESET);
    spi_wait_for_ready(spi);

    const uint32_t cmd_reset_enable = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_reset_enable);
    spi_wait_for_ready(spi);
    const uint32_t cmd_reset = spi_create_command((spi_command_t){
        .len        = 0,                 // 1 Byte
        .csaat      = false,             // End command
        .speed      = SPI_SPEED_STANDARD, // Single speed
        .direction  = SPI_DIR_TX_ONLY      // Write only
    });
    spi_set_command(spi, cmd_reset);
    spi_wait_for_ready(spi);
}

w25q_error_codes_t erase_and_write(uint32_t addr, uint8_t *data, uint32_t length) {

    uint32_t remaining_length = length;
    uint32_t current_addr = addr;
    uint8_t *current_data = data;

    w25q_error_codes_t status;

    while (remaining_length > 0) {
        // Start address of the sector to erase, 4kB aligned
        uint32_t sector_start_addr = current_addr & 0xfffff000;

        // Read the full sector and save it into RAM
        status = w25q128jw_read(sector_start_addr, sector_data, FLASH_SECTOR_SIZE);
        if (status != FLASH_OK) return FLASH_ERROR;

        // Erase the sector (no need to do so in simulation)
        #ifndef TARGET_SIM
        w25q128jw_4k_erase(sector_start_addr);
        #endif // TARGET_SIM

        // Calculate the length of data to write in this sector
        uint32_t write_length = MIN(FLASH_SECTOR_SIZE - (current_addr - sector_start_addr), remaining_length);

        // Modify the data in RAM to include the new data
        memcpy(&sector_data[current_addr - sector_start_addr], current_data, write_length);

        // Write the modified data back to the flash (without erasing this time)
        status = w25q128jw_write(sector_start_addr, sector_data, FLASH_SECTOR_SIZE, 0);
        if (status != FLASH_OK) return FLASH_ERROR;

        // Update the remaining length, address and data pointer
        remaining_length -= write_length;
        current_addr += write_length;
        current_data += write_length;
    }

    return FLASH_OK;
}

static w25q_error_codes_t page_write_wrapper(uint32_t addr, uint8_t *data, uint32_t length, uint8_t quad, uint8_t dma) {
    // Sanity checks
    if (w25q128jw_sanity_checks(addr, data, length) != FLASH_OK) return FLASH_ERROR;

    // Pointer arithmetics is not allowed on void pointers
    uint8_t *data_8bit = (uint8_t *)data;

    /*
     * Set speed and DMA flags.
     * Robust implementation: no need to perform safety checks on the flags.
    */
    uint8_t speed = quad==1 ? 1 : 0;
    uint8_t dma_flag = dma==1 ? 1 : 0;

    /*
     * Taking care of misalligned start address.
     * If the start address is not aligned to a 256 bytes boundary,
     * the first page is written with the first 256 - (addr % 256) bytes.
    */
    if (addr % FLASH_PAGE_SIZE != 0) {
        uint8_t tmp_len = FLASH_PAGE_SIZE - (addr % FLASH_PAGE_SIZE);
        tmp_len = MIN(tmp_len, length);
        page_write(addr, data_8bit, tmp_len, speed, dma_flag);
        addr += tmp_len;
        data_8bit += tmp_len;
        length -= tmp_len;
    }

    // Check if we already finished
    if (length == 0) return FLASH_OK;

    // I cannot program more than a page (256 Bytes) at a time.
    int flag = 1;
    while (flag) {
        if (length > FLASH_PAGE_SIZE) {
            page_write(addr, data_8bit, FLASH_PAGE_SIZE, speed, dma_flag);
            addr += FLASH_PAGE_SIZE;
            data_8bit += FLASH_PAGE_SIZE;
            length -= FLASH_PAGE_SIZE;
        } else {
            page_write(addr, data_8bit, length, speed, dma_flag);
            flag = 0;
        }
    }
    return FLASH_OK;
}

static w25q_error_codes_t page_write(uint32_t addr, uint8_t *data, uint32_t length, uint8_t quad, uint8_t dma) {
    // Required every time before issuing a write command
    flash_write_enable();

    /*
     * Build and send write command (24bit address + command).
     * The command is picked based on the quad flag.
    */
    const uint32_t write_byte_cmd = ((REVERT_24b_ADDR(addr & 0x00ffffff) << 8) | (quad ? FC_PPQ : FC_PP));
    spi_write_word(spi, write_byte_cmd);
    const uint32_t cmd_write = spi_create_command((spi_command_t){
        .len        = 3,
        .csaat      = true,
        .speed      = SPI_SPEED_STANDARD,
        .direction  = SPI_DIR_TX_ONLY
    });
    spi_set_command(spi, cmd_write);
    spi_wait_for_ready(spi);

    /*
     * Place data in TX FIFO
     * In simulation it do not wait for the flash to be ready, so we must check
     * if the FIFO is full before writing.
    */
    if (dma) {
        dma_send_toflash(data, length);
    } else {
        uint32_t *data_32bit = (uint32_t *)data;
        for (int i = 0; i < length>>2; i++) {
            spi_wait_for_tx_not_full(spi);
            spi_write_word(spi, data_32bit[i]);
        }
        if (length % 4 != 0) {
            uint32_t last_word = 0;
            memcpy(&last_word, &data[length - length % 4], length % 4);
            spi_wait_for_tx_not_full(spi);
            spi_write_word(spi, last_word);
        }
    }

    /*
     * Set up segment parameters -> send data.
     * Speed is quad if quad flag is set, standard otherwise.
    */
    const uint32_t cmd_write_2 = spi_create_command((spi_command_t){
        .len        = length-1,
        .csaat      = false,
        .speed      = quad ? SPI_SPEED_QUAD : SPI_SPEED_STANDARD,
        .direction  = SPI_DIR_TX_ONLY
    });
    spi_set_command(spi, cmd_write_2);
    spi_wait_for_ready(spi);

    // Wait for flash to be ready again (FPGA only)
    #ifndef TARGET_SIM
    flash_wait();
    #endif // TARGET_SIM
}

static w25q_error_codes_t dma_send_toflash(uint8_t *data, uint32_t length) {
    // SPI and SPI_FLASH are the same IP so same register map
    uint32_t *fifo_ptr_tx = (uint32_t *)((uintptr_t)spi + SPI_HOST_TXDATA_REG_OFFSET);

    // Init DMA, the integrated DMA is used (peri == NULL)
    dma_init(NULL);

    // The DMA will wait for the SPI FLASH TX FIFO valid signal
    uint8_t slot = DMA_TRIG_SLOT_SPI_FLASH_TX;

    // Set up DMA source target
    static dma_target_t tgt_src = {
        .inc_d1_du = 1, // Increment by 1 data unit (word)
        .type = DMA_DATA_TYPE_WORD, // Data type is word
    };
    // Target is data buffer
    tgt_src.ptr = data;
    // Reads from memory
    tgt_src.trig = DMA_TRIG_MEMORY;

    // Set up DMA destination target
    static dma_target_t tgt_dst = {
        .inc_d1_du = 0, // It's a peripheral, no increment
        .type = DMA_DATA_TYPE_WORD, // Data type is word
    };
    tgt_dst.trig = slot;
    tgt_dst.ptr = (uint8_t*)fifo_ptr_tx; // Target is SPI TX FIFO

    // Set up DMA transaction
    static dma_trans_t trans = {
        .src = &tgt_src,
        .dst = &tgt_dst,
        .mode = DMA_TRANS_MODE_SINGLE,
        .win_du = 0,
        .end = DMA_TRANS_END_POLLING,
    };
    // Size is in data units (words in this case)
    trans.size_d1_du = length>>2;

    // Validate, load and launch DMA transaction
    dma_config_flags_t res;
    res = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY );
    if (res != DMA_CONFIG_OK) return FLASH_ERROR_DMA;
    res = dma_load_transaction(&trans);
    if (res != DMA_CONFIG_OK) return FLASH_ERROR_DMA;
    res = dma_launch(&trans);
    if (res != DMA_CONFIG_OK) return FLASH_ERROR_DMA;

    // Wait for DMA to finish transaction
    while(!dma_is_ready(0));

    // Take into account the extra bytes (if any)
    if (length % 4 != 0) {
        uint32_t last_word = 0;
        memcpy(&last_word, &data[length - length % 4], length % 4);
        spi_wait_for_tx_not_full(spi);
        spi_write_word(spi, last_word);
    }
    return FLASH_OK;
}

static void flash_write_enable(void) {
    spi_write_word(spi, FC_WE);
    const uint32_t cmd_write_en = spi_create_command((spi_command_t){
        .len        = 0,
        .csaat      = false,
        .speed      = SPI_SPEED_STANDARD,
        .direction  = SPI_DIR_TX_ONLY
    });
    spi_set_command(spi, cmd_write_en);
    spi_wait_for_ready(spi);
}

static w25q_error_codes_t w25q128jw_sanity_checks(uint32_t addr, uint8_t *data, uint32_t length) {
    // Check if address is out of range
    if (addr > MAX_FLASH_ADDR || addr < 0) return FLASH_ERROR;

    // Check if data pointer is NULL
    if (data == NULL) return FLASH_ERROR;

    // Check if length is 0
    if (length <= 0) return FLASH_ERROR;

    // Check if current address + length is out of range
    if (addr + length > MAX_FLASH_ADDR) return FLASH_ERROR;

    return FLASH_OK; // Success
}
#ifdef __cplusplus
} // extern "C"
#endif  // __cplusplus
/****************************************************************************/
/**                                                                        **/
/*                                 EOF                                      */
/**                                                                        **/
/****************************************************************************/
