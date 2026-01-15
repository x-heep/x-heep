// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef X_HEEP
#define X_HEEP

#pragma message ( "the x-heep.h for SIMULATION in SYSTEMC is used" )

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus


#define REFERENCE_CLOCK_Hz (100*1000*1000) // 100 MHz for simulation
#define UART_BAUDRATE (REFERENCE_CLOCK_Hz / 20) // close to maximum baud rate (/16)
// Calculation formula: NCO = 16 * 2^nco_width * baud / fclk.
// Note that this will be calculated at compile time, so no 64-bit operations will be performed in CPU.
#define UART_NCO ((uint32_t)( (((uint64_t)UART_BAUDRATE * 16) << 16) / REFERENCE_CLOCK_Hz ))
#define TARGET_SYSTEMC 1

/**
 * As the hw is configurable, we can have setups with different number of
 * Gpio pins
 */
#define MAX_PIN     32


#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // X_HEEP
