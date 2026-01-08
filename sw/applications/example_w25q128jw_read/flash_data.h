/**
 * @file flash_data.h
 * @brief Test data buffers for flash read operations.
 *
 * This file contains:
 * - Golden data in RAM for verification purposes
 * - Flash buffer with identical data to be read by the controller
 */

#include <stdint.h>

// Copy of data stored in flash to be able to verify read operation 
// After a read operation, ram_buffer should match this golden data.
int32_t __attribute__ ((aligned (16))) ram_golden_data[32] = {
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

// Generate artificial FLASH memory data
int32_t __attribute__((section(".xheep_data_flash_only"))) __attribute__ ((aligned (16))) flash_buffer[32] = {
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