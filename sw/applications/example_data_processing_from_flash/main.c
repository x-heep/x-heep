// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: sw/applications/example_data_processing_from_flash/main.c
// Author:  Francesco Poluzzi
// Date: 29/07/2024

/**
 * @file main.c
 * @brief Example of data processing (matrix multiplication) reading data from flash memory
 *
 * Simple example that read a matrix from flash memory in many step and performs
 * matrix multiplication. This is useful for applications where the
 * data size does not fit in the available SRAM memory, so some data needs to be
 * stored as "flash_only" and read trough the spi interface. This usually requires
 * filling a buffer and tiling the data processing.
*/

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "x-heep.h"
#include "w25q128jw.h"
#include "main.h"
#include "dma_sdk.h"

#define TILING_ROWS 2

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

int32_t buffer_data[MATRIX_SIZE*TILING_ROWS] = {0};
int32_t output_matrix[MATRIX_SIZE*MATRIX_SIZE] = {0};

int main(int argc, char *argv[]) {
#ifndef FLASH_LOAD
    PRINTF("This application is meant to run with the FLASH_LOAD linker script\n");
    return EXIT_SUCCESS;
#else

    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);

    #ifdef TARGET_SIM
        PRINTF("This application is meant to run on FPGA only\n");
        return EXIT_SUCCESS;
    #endif

    // Pick the correct spi device based on simulation type
    spi_host_t* spi = spi_flash;

    // Init SPI host and SPI<->Flash bridge parameters
    if (w25q128jw_init(spi) != FLASH_OK){
        PRINTF("Error initializing SPI flash\n");
        return EXIT_FAILURE;
    } 

    for (int i = 0; i < MATRIX_SIZE; i+=TILING_ROWS) {
        // read first half matrix A from flash and perform matmul
        if(fill_buffer(&A[i*MATRIX_SIZE], buffer_data, MATRIX_SIZE*TILING_ROWS)!=FLASH_OK){
            PRINTF("Error reading from flash\n");
            return EXIT_FAILURE;
        }
        matmul(buffer_data, B, &output_matrix[i*MATRIX_SIZE], TILING_ROWS, MATRIX_SIZE, MATRIX_SIZE);
    }

    for(int i = 0; i < MATRIX_SIZE*MATRIX_SIZE; i++){
        if (output_matrix[i] != C[i]){
             PRINTF("Result[%d][%d]:golden model   %d : %d\n", (i/MATRIX_SIZE), (i % MATRIX_SIZE), output_matrix[i], C[i]);
            return EXIT_FAILURE;
       }
    }
    PRINTF("All tests passed!\n");
    return EXIT_SUCCESS;

#endif
}
