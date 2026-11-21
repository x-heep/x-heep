
// Copyright 2023 EPFL and Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: timer_sdk.h
// Authors: Michele Caon, Luigi Giuffrida, Francesco Poluzzi
// Date: 23/07/2024
// Description: Execution time measurements utilities

#ifndef TIMER_SDK_H_
#define TIMER_SDK_H_

#include <stdint.h>

#include "csr.h"
#include "gpio.h"
#include "rv_timer.h"
#include "rv_timer_regs.h"
#include "core_v_mini_mcu.h"
#include "x-heep.h"

#define FREQ_1MHz 1000000

/******************************/
/* ---- GLOBAL VARIABLES ---- */
/******************************/

// Timer value
extern int32_t hw_timer_value;

extern rv_timer_t timer;

/********************************/
/* ---- EXPORTED FUNCTIONS ---- */
/********************************/

/**
 * @brief Get the current value of the HW timer
 * 
* @return uint32_t The low 32 bits of the HW timer count
 */
uint32_t timer_get_cycles();

/**
 * @brief Start the timer
 * 
 */
void timer_start();

/**
 * @brief Stop and reset the timer to 0
 * 
 */
void timer_reset();

/**
 * @brief Stop the HW timer
 * 
 * @return uint32_t Elapsed time in clock cycles
 */
uint32_t timer_stop();

/**
 * @brief Initialize the timer for counting clock cycles
 * 
 * @return kRvTimerBadArg for a zero clock frequency or when no tick
 * parameters fit the frequency, otherwise the result of rv_timer_init() or
 * rv_timer_set_tick_params().
 */
rv_timer_result_t timer_cycles_init(void);

/**
 * @brief Enable the timer IRQ
 */
void timer_irq_enable();

/**
 * @brief Clear the timer IRQ
 */
void timer_irq_clear();

/**
 * @brief Arms the timer to go off once the counter value is greater than or equal to threshold
 * and starts the timer
 */
void timer_arm_start(uint32_t threshold);

/**
 * @brief Stop to output when timer is greater than or equal to threshold previously set
 */
void timer_arm_stop();

/**
 * @brief Set the timer to go off once the counter value is greater than or equal to threshold,
 * without starting the timer
 */
void timer_arm_set(uint32_t threshold);

/**
 * @brief Enable the timer machine-level interrupts for X-Heep
 */
void enable_timer_interrupt();

/**
 * @brief Wait for a certain amount of microseconds. 
 * You need to enable timer interrupts with enable_timer_interrupt() before using this function
 */
void timer_wait_us(uint32_t us);

/**
 * @brief Enable the timer machine-level interrupts for X-Heep
 */
void enable_timer_interrupt();

/**
 * @brief Get the time taken to execute a certain number of cycles
 * 
 * @return float value representing the time taken in microseconds
 */
float get_time_from_cycles(uint32_t cycles);

#endif /* TIMER_SDK_H_ */