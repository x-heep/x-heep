/*
                              *******************
******************************* H HEADER FILE *****************************
**                            *******************
**
** project  : X-HEEP
** filename : w25q128jw.h
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
* @file   w25q128jw.h
* @date   13/02/23
* @brief  Header file for the W25Q128JW flash memory.
*/

#ifndef W25Q128JW_H
#define W25Q128JW_H

/****************************************************************************/
/**                                                                        **/
/**                            MODULES USED                                **/
/**                                                                        **/
/****************************************************************************/

#include "spi_host.h"
#include "soc_ctrl.h"
#include "core_v_mini_mcu.h"

/****************************************************************************/
/**                                                                        **/
/**                       DEFINITIONS AND MACROS                           **/
/**                                                                        **/
/****************************************************************************/

/**
 * In Hz (133 MHz for the flash w25q128jvsim used in the EPFL Programmer)
*/
#define FLASH_CLK_MAX_HZ (133*1000*1000)


/**
 * @defgroup flash_commands Flash commands
 * @{
 */
#define FC_WE      0x06 /** Write Enable */
#define FC_SRWE    0x50 /** Volatile SR Write Enable */
#define FC_WD      0x04 /** Write Disable */
#define FC_RPD     0xAB /** Release Power-Down, returns Device ID */
#define FC_MFGID   0x90 /** Read Manufacturer/Device ID */
#define FC_JEDECID 0x9F /** Read JEDEC ID */
#define FC_UID     0x4B /** Read Unique ID */
#define FC_RD      0x03 /** Read Data */
#define FC_FR      0x0B /** Fast Read */
#define FC_RDQIO   0xEB /** Fast Read Quad I/O */
#define FC_PP      0x02 /** Page Program */
#define FC_PPQ     0x32 /** Quad Input Page Program */
#define FC_SE      0x20 /** Sector Erase 4kb */
#define FC_BE32    0x52 /** Block Erase 32kb */
#define FC_BE64    0xD8 /** Block Erase 64kb */
#define FC_CE      0xC7 /** Chip Erase */
#define FC_RSR1    0x05 /** Read Status Register 1 */
#define FC_WSR1    0x01 /** Write Status Register 1 */
#define FC_RSR2    0x35 /** Read Status Register 2 */
#define FC_WSR2    0x31 /** Write Status Register 2 */
#define FC_RSR3    0x15 /** Read Status Register 3 */
#define FC_WSR3    0x11 /** Write Status Register 3 */
#define FC_RSFDP   0x5A /** Read SFDP Register */
#define FC_ESR     0x44 /** Erase Security Register */
#define FC_PSR     0x42 /** Program Security Register */
#define FC_RSR     0x48 /** Read Security Register */
#define FC_GBL     0x7E /** Global Block Lock */
#define FC_GBU     0x98 /** Global Block Unlock */
#define FC_RBL     0x3D /** Read Block Lock */
#define FC_RPR     0x3C /** Read Sector Protection Registers (adesto) */
#define FC_IBL     0x36 /** Individual Block Lock */
#define FC_IBU     0x39 /** Individual Block Unlock */
#define FC_EPS     0x75 /** Erase / Program Suspend */
#define FC_EPR     0x7A /** Erase / Program Resume */
#define FC_PD      0xB9 /** Power-down */
#define FC_QPI     0x38 /** Enter QPI mode */
#define FC_ERESET  0x66 /** Enable Reset */
#define FC_RESET   0x99 /** Reset Device */
/** @} */

/**
 * @defgroup error_codes Error codes
 * @{
*/
#define FLASH_OK    0      /** No error @hideinitializer*/
#define FLASH_ERROR 1      /** Generic error @hideinitializer*/
#define FLASH_ERROR_DMA 2  /** DMA error @hideinitializer*/
/** @} */

/**
/**
 * @brief Threshold value for switching to DMA in read mode.
 *        If the number of bytes to be read exceeds this threshold,
 *        DMA is the more efficient data transfer.
 */
#define RX_DMA_THRESHOLD 75

/**
 * @brief Threshold value for switching to DMA in write mode.
 *        If the number of bytes to be wrote exceeds this threshold,
 *        DMA is the more efficient data transfer.
 */
#define TX_DMA_THRESHOLD 0

/**
 * @brief Dimension of a flash page, in bytes.
*/
#define FLASH_PAGE_SIZE 256

/**
 * @brief Number of dummy clocks cycles required by the simulation model.
*/
#define DUMMY_CLOCKS_SIM 8

/**
 * @brief Number of dummy clocks cycles required by the flash during
 * fast read quad I/O operations (command code: EBh).
*/
#define DUMMY_CLOCKS_FAST_READ_QUAD_IO 4

/**
 * @brief Upper bound for the flash address.
*/
#define MAX_FLASH_ADDR 0x00ffffff

#ifdef __cplusplus
extern "C" {
#endif

/****************************************************************************/
/**                                                                        **/
/**                       TYPEDEFS AND STRUCTURES                          **/
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Return status type.
*/
typedef uint8_t w25q_error_codes_t;

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED VARIABLES                            **/
/**                                                                        **/
/****************************************************************************/

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED FUNCTIONS                            **/
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Initialize data structure used by crt0 flash_load.
 *
*/
void w25q128jw_init_crt0();

/**
 * @brief Power up and itialize the flash.
 *
 * Enable the SPI interface.
 * Power up the flash and set the SPI configuration specific to the flash.
 * It also set the QE bit in order to accept Quad I/O commands.
 * By default both error and event interrupts are disabled.
 *
 * @param spi_host SPI host to use.
 *
 * @note The flash uses CSID 0. If the CSID register value is changed, it must be
 * restored back to 0 before using the flash again.
 *
 * @return FLASH_OK if the flash is correctly initialized, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_init(spi_host_t* spi_host);

/**
 * @brief Read from flash.
 *
 * The function automatically uses the best parameters based on
 * the current state of the system and the length of the data to read.
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer to be filled.
 * @param length number of bytes to read.
 * @return FLASH_OK if the read is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_read(uint32_t addr, void* data, uint32_t length);

/**
 * @brief Write to flash.
 *
 * The function automatically uses the best parameters based on
 * the current state of the system and the length of the data to write.
 * If erase_before_write is set, the function will take care of erasing
 * the correct sectors before writing. All the bytes not written will be
 * copied back in their current state before the write operation.
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @param erase_before_write if set to 1, the function will take care of erasing
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_write(uint32_t addr, void* data, uint32_t length, uint8_t erase_before_write);

/**
 * @brief Setup SPI to read from flash at standard speed. (NEEDS TO BE FOLLOWED BY MANUAL SETUP OF THE DMA)
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return ptr to SPI data register.
*/
uint32_t* w25q128jw_read_standard_setup(uint32_t addr, void *data, uint32_t length);

/**
 * @brief Read from flash at standard speed.
 *
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer to be filled.
 * @param length number of bytes to read.
 * @retval FLASH_OK if the read is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_read_standard(uint32_t addr, void* data, uint32_t length);


/**
 * @brief Write to flash at standard speed. Use this function only to write to unitialized data
 *
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_write_standard(uint32_t addr, void* data, uint32_t length);


/**
 * @brief Erase and Write to flash at standard speed.
 *
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_erase_and_write_standard(uint32_t addr, void* data, uint32_t length);

/**
 * @brief Read from flash at standard speed using DMA
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to read.
 * @return FLASH_OK if the read is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_read_standard_dma(uint32_t addr, void *data, uint32_t length, uint8_t no_wait_init_dma, uint8_t no_sanity_checks);

/**
 * @brief Read from flash at standard speed using DMA but wait for DMA in the application
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to read, must be multiple of 4
 * @return FLASH_OK if the read is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_read_standard_dma_async(uint32_t addr, void *data, uint32_t length);

/**
 * @brief Write to flash at standard speed using DMA. Use this function only to write to unitialized data
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_write_standard_dma(uint32_t addr, void* data, uint32_t length);

/**
 * @brief Erase and Write to flash at standard speed using DMA
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_erase_and_write_standard_dma(uint32_t addr, void* data, uint32_t length);

/**
 * @brief Read from flash at quad speed.
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_read_quad(uint32_t addr, void* data, uint32_t length);

/**
 * @brief Setup SPI to read from flash at quad speed. (NEEDS TO BE FOLLOWED BY MANUAL SETUP OF THE DMA)
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return ptr to SPI data register.
*/
uint32_t* w25q128jw_read_quad_setup(uint32_t addr, void *data, uint32_t length);

/**
 * @brief Write to flash at quad speed. Use this function only to write to unitialized data
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_write_quad(uint32_t addr, void* data, uint32_t length);

/**
 * @brief Erase and Write to flash at quad speed.
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_erase_and_write_quad(uint32_t addr, void* data, uint32_t length);

/**
 * @brief Read from flash at quad speed using DMA.
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_read_quad_dma(uint32_t addr, void* data, uint32_t length);

/**
 * @brief Read from flash at quad speed using DMA but wait for DMA in the application using w25q128jw_wait_quad_dma()
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_read_quad_dma_async(uint32_t addr, void *data, uint32_t length);

/**
 * @brief Wait for w25q128jw_read_quad_dma_async (works only used along with that function) and take care of the last bytes, if present
 *
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
void w25q128jw_wait_quad_dma_async(void *data, uint32_t length);

/**
 * @brief Write to flash at quad speed using DMA. Use this function only to write to unitialized data
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_write_quad_dma(uint32_t addr, void* data, uint32_t length);

/**
 * @brief Erase and Write to flash at quad speed using DMA. Use this function only to write to unitialized data
 *
 * @param addr 24-bit flash address to read from.
 * @param data pointer to the data buffer.
 * @param length number of bytes to write.
 * @return FLASH_OK if the write is successful, @ref error_codes otherwise.
*/
w25q_error_codes_t w25q128jw_erase_and_write_quad_dma(uint32_t addr, void* data, uint32_t length);

/**
 * @brief Erase a 4kb sector.
 *
 * Sets all memory within a 4kb sector to the erased state of all 1s (FFh).
 * After the erase is issued, waits for the flash to be ready.
 *
 * @param addr 24-bit address of the sector to erase.
*/
w25q_error_codes_t w25q128jw_4k_erase(uint32_t addr);

/**
 * @brief Erase a 32kb block.
 *
 * Sets all memory within a 32kb block to the erased state of all 1s (FFh).
 * After the erase is issued, waits for the flash to be ready.
 *
 * @param addr 24-bit address of the block to erase.
*/
w25q_error_codes_t w25q128jw_32k_erase(uint32_t addr);

/**
 * @brief Erase a 64kb block.
 *
 * Sets all memory within a 64kb block to the erased state of all 1s (FFh).
 * After the erase is issued, waits for the flash to be ready.
 *
 * @param addr 24-bit address of the block to erase.
*/
w25q_error_codes_t w25q128jw_64k_erase(uint32_t addr);

/**
 * @brief Erase the entire chip.
 *
 * Sets all memory within the chip to the erased state of all 1s (FFh).
 * After the erase is issued, waits for the flash to be ready.
*/
void w25q128jw_chip_erase(void);


/**
 * @brief Reset the flash.
 *
 * Before issuing the reset command, the function checks (and eventually wait)
 * any ongoing read/write operation in order to preserve data integrity.
 * After the reset is issued, wait for the flash to be ready.
*/
void w25q128jw_reset(void);

/**
 * @brief Reset the flash without checking for ongoing operations.
 *
 * This function is used to reset the flash when it is not possible to check
 * for ongoing operations (e.g. when the flash is not responding).
 * Upon receiving the reset command, the flash will abort any ongoing operation.
 * After the reset is issued, waits for the flash to be ready.
*/
void w25q128jw_reset_force(void);

/**
 * @brief Power down the flash.
 *
 * During power down state, the only command that can be issued is the
 * release power down command. All other commands are going to be ignored
 * by the flash.
*/
void w25q128jw_power_down(void);

/****************************************************************************/
/**                                                                        **/
/**                          INLINE FUNCTIONS                              **/
/**                                                                        **/
/****************************************************************************/
#ifdef __cplusplus
} // extern "C"
#endif

#endif /* W25Q128JW_H */
/****************************************************************************/
/**                                                                        **/
/**                                EOF                                     **/
/**                                                                        **/
/****************************************************************************/
