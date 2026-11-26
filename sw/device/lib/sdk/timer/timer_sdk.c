// Copyright 2023 EPFL and Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: timer_sdk.c
// Author: Michele Caon, Francesco Poluzzi
// Date: 23/07/2024
// Description: Timer functions

#include <stdint.h>

#include "timer_sdk.h"
#include "csr.h"
#include "soc_ctrl.h"


/******************************/
/* ---- GLOBAL VARIABLES ---- */
/******************************/

// Timer value
int32_t hw_timer_value = 0;

rv_timer_t timer;

rv_timer_config_t timer_cfg = {
    .hart_count = RV_TIMER_PARAM_N_HARTS,
    .comparator_count = RV_TIMER_PARAM_N_TIMERS,
};

mmio_region_t timer_base = {
    .base = (void *)RV_TIMER_AO_START_ADDRESS,
};

rv_timer_tick_params_t tick_params;


/*************************************/
/* ---- FUNCTION IMPLEMENTATION ---- */
/*************************************/

uint32_t timer_get_cycles()
{
    uint64_t cycle_count;
    rv_timer_counter_read(&timer, 0, &cycle_count);
    return (uint32_t)cycle_count;
}

void timer_irq_enable()
{
  rv_timer_irq_enable(&timer, 0, 0, kRvTimerEnabled);
}

void timer_irq_clear()
{
  rv_timer_irq_clear(&timer, 0, 0);
}

void timer_arm_start(uint32_t threshold)
{
    rv_timer_arm(&timer, 0, 0, threshold);
    timer_start();
}

void timer_arm_stop()
{
    rv_timer_counter_set_enabled(&timer, 0, kRvTimerDisabled);
}


void timer_arm_set(uint32_t threshold)
{
    rv_timer_arm(&timer, 0, 0, threshold);
}

void timer_start()
{
    hw_timer_value = -timer_get_cycles();
    rv_timer_counter_set_enabled(&timer, 0, kRvTimerEnabled);
}

void timer_reset()
{  
    hw_timer_value = 0;
    rv_timer_reset(&timer);
}

uint32_t timer_stop()
{
    hw_timer_value += timer_get_cycles();
    rv_timer_counter_set_enabled(&timer, 0, kRvTimerDisabled);
    return  hw_timer_value;
}

// Initialize the timer
rv_timer_result_t timer_cycles_init(void)
{
    // Get current Frequency
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);
    uint32_t freq_hz = soc_ctrl_get_frequency(&soc_ctrl);
    // A zero frequency divides by zero in the tick parameter search.
    if (freq_hz == 0)
    {
        return kRvTimerBadArg;
    }

    // rv_timer_init() binds the handle and resets the timer. Do not reset the
    // timer before it: on the first call the handle is unbound, and a reset
    // through it writes to address 0.
    rv_timer_result_t result = rv_timer_init(timer_base, timer_cfg, &timer);
    if (result != kRvTimerOk)
    {
        return result;
    }
    hw_timer_value = 0;
    if (rv_timer_approximate_tick_params(freq_hz, freq_hz, &tick_params) !=
        kRvTimerApproximateTickParamsOk)
    {
        return kRvTimerBadArg;
    }
    return rv_timer_set_tick_params(&timer, 0, tick_params);
}

// Wait for us microseconds with the timer interrupt
void timer_wait_us(uint32_t us)
{
    // Get current Frequency
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);
    uint32_t freq_hz = soc_ctrl_get_frequency(&soc_ctrl);

    // The arm value leaves init_cycles for the initialization. A wait of
    // init_cycles or fewer has nothing left to wait for, so return before the
    // timer is reset. Below init_cycles the unsigned subtraction would also
    // wrap to a wait of about 2^32 cycles.
    const uint32_t init_cycles = 50;
    uint32_t wait_cycles = us*(freq_hz/FREQ_1MHz);
    if (wait_cycles <= init_cycles)
    {
        return;
    }
    // Without a configured timer, no timer interrupt ends the wfi below.
    if (timer_cycles_init() != kRvTimerOk)
    {
        return;
    }
    timer_irq_enable();
    timer_arm_start(wait_cycles - init_cycles);
    asm volatile ("wfi");
    timer_irq_clear();
    return;
}

void enable_timer_interrupt()
{
    //enable timer interrupt
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    // Set mie.MTIE (bit 7) to enable machine-level timer interrupts
    const uint32_t mask = 1 << 7;
    CSR_SET_BITS(CSR_REG_MIE, mask);
}

float get_time_from_cycles(uint32_t cycles){
    // Get current Frequency
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);
    uint32_t freq_hz = soc_ctrl_get_frequency(&soc_ctrl);

    return (float)cycles/((float)freq_hz/1000000);
}