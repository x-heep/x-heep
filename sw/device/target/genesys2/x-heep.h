// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef X_HEEP
#define X_HEEP

#pragma message ( "the x-heep.h for GENESYS2 is used" )

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus


#define REFERENCE_CLOCK_Hz 15*1000*1000
#define UART_BAUDRATE 9600
// Calculation formula: NCO = 16 * 2^nco_width * baud / fclk.
// NCO creates 16x of baudrate. So, in addition to the nco_width,
// 2^4 should be multiplied.
// We assume that the lowest baudrate will be 9600, and the largest 256000. 
// Given this range, by dividing by 100 it always remains integer and below 32-bits.
// This saves us the need of performing 64-bit divisions to compute NCO. 
#define UART_NCO ((uint32_t)(((uint32_t)((uint32_t)(UART_BAUDRATE/100))<<20)/((uint32_t)(REFERENCE_CLOCK_Hz/100))))
#define TARGET_GENESYS2 1
#define TARGET_IS_FPGA 1

/**
 * As the hw is configurable, we can have setups with different number of
 * Gpio pins
 */
#define MAX_PIN     32


#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // X_HEEP
