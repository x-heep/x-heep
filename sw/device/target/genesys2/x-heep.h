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
#define TARGET_GENESYS2 1
#define TARGET_IS_FPGA 1

/**
 * As the hw is configurable, we can have setups with different number of
 * Gpio pins
 */
#define MAX_PIN 32

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // X_HEEP
