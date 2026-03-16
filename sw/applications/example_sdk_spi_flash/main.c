/**
 * @file main.c
 * @brief Simple spi communication example using SDK
 *
 * Simple example that reads a sector (4096 Bytes) from flash, overwrites the
 * specified location range with new data, erases that sector from flash, writes
 * the modified sector back to the flash and finally reads the modified location
 * range directly from the flash to verify the operation has succeeded.
 * 
 * The flash device being used is the w25q128jw
 *
*/

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "x-heep.h"
#include "core_v_mini_mcu.h"
#include "spi_sdk.h"

#include "fast_intr_ctrl.h"
#include "csr.h"
#include "csr_registers.h"

/* By default, PRINTFs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

#if TARGET_SIM && PRINTF_IN_SIM
        #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif TARGET_IS_FPGA && PRINTF_IN_FPGA
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

// =========================== VARS & DEFS ==================================

// 1 to print the modified data at the end of program 0 to disable
#define PRINT_DATA 1

// Flash w25q128jw SPI commands
#define FC_WE      0x06 /** Write Enable */
#define FC_RD      0x03 /** Read Data */
#define FC_PP      0x02 /** Page Program */
#define FC_SE      0x20 /** Sector Erase 4kb */
#define FC_RSR1    0x05 /** Read Status Register 1 */

#define READ_WRITE_LEN 16                           // Amount words to read/write
#define START_ADDRESS  ((FLASH_MEM_SIZE / 2) + 256) // Flash address where read/write
#define SECT_ADDRESS   (START_ADDRESS & 0xfffff000) // Start sector address
#define SECT_LEN       4096             // Length bytes of a sector
#define PAGE_LEN       256              // Length bytes of a page
#define FLASH_MAX_FREQ (133*1000*1000)  // Device max spi frequency
#define FIC_FLASH_MEIE 21               // SPI Flash fast interrupt bit enable
#define CSR_INTR_EN    0x08             // CPU Global interrupt enable

// Hold sector data
uint8_t sect_data[SECT_LEN];

// Data to write
uint32_t flash_original_1024B[PAGE_LEN] = {
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

// ====================== PROTOTYPES ======================

bool flash_read(spi_t* spi, uint32_t addr, uint32_t* dest_buff, uint32_t len);
bool flash_read_non_blocking(spi_t* spi, uint32_t addr, uint32_t* dest_buff, uint32_t len);
bool flash_write_enable(spi_t* spi);
bool flash_erase_sector(spi_t* spi, uint32_t addr);
bool flash_write_sector(spi_t* spi, uint32_t addr, uint32_t* src_buff);
void flash_wait(spi_t* spi);

void done_cb(const uint32_t* txbuff, uint32_t txlen, uint32_t* rxbuff, uint32_t rxlen);
void rxwm_cb(const uint32_t* txbuff, uint32_t txlen, uint32_t* rxbuff, uint32_t rxlen);

// ========================= MAIN =========================

int main(int argc, char *argv[]) {
    // Create our slave (flash device) with its specifications
    spi_slave_t slave = SPI_SLAVE(0, FLASH_MAX_FREQ);

    // Initialize the spi device that is CONNECTED to the flash with our slave
    spi_t spi = spi_init(SPI_IDX_FLASH, slave);

    // Check if initialization succeeded
    if (!spi.init) {
        PRINTF("\nFailed to initialize spi\n");
        return EXIT_FAILURE;
    }

    PRINTF("\nSPI initialized\n");

    // Enable global interrupt for machine-level interrupts
    CSR_SET_BITS(CSR_REG_MSTATUS, CSR_INTR_EN);
    // Set mie.MEIE bit to one to enable machine-level fast spi_flash interrupt
    const uint32_t mask = 1 << FIC_FLASH_MEIE;
    CSR_SET_BITS(CSR_REG_MIE, mask);

    // Buffer to hold data for final comparison
    uint32_t rxbuffer[READ_WRITE_LEN] = {0};

    // Read whole sector containing the desired START_ADDRESS
    if (!flash_read_non_blocking(&spi, SECT_ADDRESS, (uint32_t*)sect_data, SECT_LEN)) 
        return EXIT_FAILURE;

    // Erase that sector
    if (!flash_erase_sector(&spi, START_ADDRESS)) return EXIT_FAILURE;

    // Copy the data to overwrite
    memcpy(&sect_data[START_ADDRESS - SECT_ADDRESS], flash_original_1024B, READ_WRITE_LEN * 4);
    // Write the whole sector with the new data back to flash
    if (!flash_write_sector(&spi, START_ADDRESS, (uint32_t*)sect_data)) return EXIT_FAILURE;
    // Read the modified part
    if (!flash_read(&spi, START_ADDRESS, rxbuffer, 4*READ_WRITE_LEN)) return EXIT_FAILURE;

    // Compare the modified part with the data used to modify
    if (memcmp(rxbuffer, flash_original_1024B, 4*READ_WRITE_LEN))
         PRINTF("\nMISMATCH\n\n");
    else PRINTF("\nSUCCESS\n\n");

    // If wanted display the data
    #if PRINT_DATA
    PRINTF(" address     original  on flash\n");
    PRINTF("-------------------------------\n");
    for (int i = 0; i < READ_WRITE_LEN; i++)
    {
        PRINTF("0x%08X:  %08X  %08X\n", START_ADDRESS+4*i, flash_original_1024B[i], rxbuffer[i]);
    }
    #endif

    PRINTF("\n==================================================\n\n");
    

    return EXIT_SUCCESS;
}

// ========================= FUNCTIONS =========================

bool flash_read(spi_t* spi, uint32_t addr, uint32_t* dest_buff, uint32_t len) {
    // Transaction segments
    spi_segment_t segments[2] = { SPI_SEG_TX(4), SPI_SEG_RX(len) };

    // TX SPI command to send to flash for read
    // Flash uses Big Endian, CPU Little Endian, hence swap bytes
    uint32_t read_byte_cmd = ((bitfield_byteswap32(addr & 0x00ffffff)) | FC_RD);

    PRINTF("Blocking Reading %4i Bytes at 0x%08X\n", len, addr);

    // Start transaction
    spi_codes_e error = spi_execute(spi, segments, 2, &read_byte_cmd, dest_buff);
    if (error) {
        PRINTF("FAILED! Error Code: %i\n", error);
        return false;
    }
    return true;
}

bool flash_read_non_blocking(spi_t* spi, uint32_t addr, uint32_t* dest_buff, uint32_t len) {
    // Transaction segments
    spi_segment_t segments[2] = { SPI_SEG_TX(4), SPI_SEG_RX(len) };

    // TX SPI command to send to flash for read
    // Flash uses Big Endian, CPU Little Endian, hence swap bytes
    uint32_t read_byte_cmd = ((bitfield_byteswap32(addr & 0x00ffffff)) | FC_RD);

    PRINTF("\nNon-Blocking Reading %4i Bytes at 0x%08X\n", len, addr);
    PRINTF("Counter set to 0.\n");

    uint32_t counter = 0;
    spi_callbacks_t callbacks = {
        .done_cb  = &done_cb,
        .error_cb = NULL,//&done_cb,
        .rxwm_cb  = &rxwm_cb,
        .txwm_cb  = NULL
    };

    // Save previous watermark to reset it after transaction completes
    uint8_t watermark;
    spi_get_rxwm(spi, &watermark);
    spi_set_rxwm(spi, 12); // Arbitrarily chosen watermark

    // Start transaction
    spi_codes_e error = spi_execute_nb(spi, segments, 2, &read_byte_cmd, dest_buff, callbacks);
    if (error) {
        PRINTF("FAILED! Error Code: %i\n", error);
        return false;
    }

    while(spi_get_state(spi) == SPI_STATE_BUSY) counter++;
    // Check if the communication ended because of an error
    if (spi_get_state(spi) == SPI_STATE_ERROR) {
        PRINTF("FAILED! Hardware ERROR !\n");
        return false;
    }

    // Reset the watermark to its previous value
    spi_set_rxwm(spi, watermark);

    PRINTF("Counter reached %4i. => Non Blocking\n\n", counter);

    return true;
}

bool flash_erase_sector(spi_t* spi, uint32_t addr) {
    // Sector start address
    const uint32_t sect_start = addr & 0xfffff000;
    // Sector erase command
    // Flash uses Big Endian, CPU Little Endian, hence swap bytes
    const uint32_t cmd = ((bitfield_byteswap32(sect_start & 0x00ffffff)) | FC_SE);

    PRINTF("Blocking Erasing 4096 Bytes at 0x%08X\n", sect_start);

    // Enable write before erase
    if (!flash_write_enable(spi)) return false;

    // Start TX Only transaction
    spi_codes_e error = spi_transmit(spi, &cmd, 4);
    if (error) {
        PRINTF("FAILED! Error Code: %i\n", error);
        return false;
    }

    // Wait flash finished processing
    flash_wait(spi);

    return true;
}

bool flash_write_sector(spi_t* spi, uint32_t addr, uint32_t* src_buff) {
    // Sector start address
    uint32_t sect = addr & 0xfffff000;
    // Current page (256 bytes) address (can't write more than one page at a time...)
    uint32_t curr_addr = sect;

    for (int i = 0; i < SECT_LEN / PAGE_LEN; i++)
    {
        // Our TX Buffer
        uint32_t wbuff[PAGE_LEN/4 + 1] = {0};
        // Our segments for the SPI transaction
        spi_segment_t segments[2] = { SPI_SEG_TX(4), SPI_SEG_TX(PAGE_LEN) };

        // Flash uses Big Endian, CPU Little Endian, hence swap bytes
        wbuff[0] = ((bitfield_byteswap32(curr_addr & 0x00ffffff)) | FC_PP);
        memcpy(&wbuff[1], &src_buff[i * (PAGE_LEN/4)], PAGE_LEN);

        if (!flash_write_enable(spi)) return false;

        // Start transaction
        // Note that since segments are only TX we could have used spi_transmit
        // instead of spi_execute, but both work perfectly fine
        spi_codes_e error = spi_execute(spi, segments, 2, wbuff, NULL);
        if (error) {
            PRINTF("FAILED! Error Code: %i\n", error);
            return false;
        }
        curr_addr += PAGE_LEN;

        PRINTF("\rBlocking Written %4i/4096 Bytes at 0x%08X", (i+1) * PAGE_LEN, sect);

        // Wait flash finished processing
        flash_wait(spi);
    }

    PRINTF("\n");
    
    return true;
}

bool flash_write_enable(spi_t* spi) {
    // SPI Flash command
    const uint32_t cmd = FC_WE;
    // Start TX Only transaction
    spi_codes_e error = spi_transmit(spi, &cmd, 1);
    if (error) {
        PRINTF("FAILED! Error Code: %i\n", error);
        return false;
    }
    return true;
}

void flash_wait(spi_t* spi) {
    // Response buffer
    uint32_t resp;
    // SPI Flash command
    uint32_t cmd = FC_RSR1;
    // Here we have to use segments and execute since our transaction is composed
    // of a TX Only part and thereafter a RX Only
    spi_segment_t segments[2] = {SPI_SEG_TX(1), SPI_SEG_RX(2)};
    // Flash busy flag
    bool busy = true;
    while (busy)
    {
        spi_execute(spi, segments, 2, &cmd, &resp);
        busy = resp & 0x01;
    }
}

void done_cb(const uint32_t* txbuff, uint32_t txlen, uint32_t* rxbuff, uint32_t rxlen) {
    PRINTF("\x1b[33mTXN DONE CALLBACK with txlen: %i, rxlen: %i\x1b[m\n", txlen, rxlen);
}

void rxwm_cb(const uint32_t* txbuff, uint32_t txlen, uint32_t* rxbuff, uint32_t rxlen) {
    PRINTF("\x1b[36mTXN RXWM CALLBACK with txlen: %i, rxlen: %i\x1b[m\n", txlen, rxlen);
}

// ========================= THE END =========================