// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include "power_manager.h"
#include <stddef.h>
#include <stdint.h>
#include "core_v_mini_mcu.h"
#include "power_manager_regs.h"
#include "power_manager_structs.h"
#include "x-heep.h"

extern void power_manager_cpu_store();


#define power_manager_peri ((volatile power_manager *) POWER_MANAGER_START_ADDRESS)

static power_manager_vector_sram_map_t power_manager_ram_map[MEMORY_BANKS];
static power_manager_vector_ext_map_t power_manager_external_map[EXTERNAL_DOMAINS];

power_manager_result_t __attribute__ ((noinline)) power_manager_pwr_gate_core(power_manager_sel_intr_t sel_intr, power_manager_counters_t* cpu_counter)
{
    uint32_t reg = 0;

    power_manager_peri->CPU_RESET_ASSERT_COUNTER = (cpu_counter->reset_off & POWER_MANAGER_CPU_RESET_ASSERT_COUNTER_CPU_RESET_ASSERT_COUNTER_MASK);
    power_manager_peri->CPU_RESET_DEASSERT_COUNTER = (cpu_counter->reset_on & POWER_MANAGER_CPU_RESET_DEASSERT_COUNTER_CPU_RESET_DEASSERT_COUNTER_MASK);
    power_manager_peri->CPU_SWITCH_OFF_COUNTER = (cpu_counter->switch_off & POWER_MANAGER_CPU_SWITCH_OFF_COUNTER_CPU_SWITCH_OFF_COUNTER_MASK);
    power_manager_peri->CPU_SWITCH_ON_COUNTER = (cpu_counter->switch_on & POWER_MANAGER_CPU_SWITCH_ON_COUNTER_CPU_SWITCH_ON_COUNTER_MASK);
    power_manager_peri->CPU_ISO_OFF_COUNTER = (cpu_counter->iso_off & POWER_MANAGER_CPU_ISO_OFF_COUNTER_CPU_ISO_OFF_COUNTER_MASK);
    power_manager_peri->CPU_ISO_ON_COUNTER = (cpu_counter->iso_on & POWER_MANAGER_CPU_ISO_ON_COUNTER_CPU_ISO_ON_COUNTER_MASK);


    // enable wakeup timers
    power_manager_peri->EN_WAIT_FOR_INTR = 1 << sel_intr;
    power_manager_peri->INTR_STATE = 0x0;

    // enable wait for SWITCH ACK
    power_manager_peri->CPU_WAIT_ACK_SWITCH_ON_COUNTER = (0x1 << POWER_MANAGER_CPU_WAIT_ACK_SWITCH_ON_COUNTER_CPU_WAIT_ACK_SWITCH_ON_COUNTER_BIT);

    power_manager_cpu_store();

    // clean up states
    power_manager_peri->EN_WAIT_FOR_INTR = 0;
    power_manager_peri->INTR_STATE = 0x0;

    // stop counters
    reg = 0;


    reg |= (0x1 << POWER_MANAGER_CPU_COUNTERS_STOP_CPU_RESET_ASSERT_STOP_BIT_COUNTER_BIT);
    reg |= (0x1 << POWER_MANAGER_CPU_COUNTERS_STOP_CPU_RESET_DEASSERT_STOP_BIT_COUNTER_BIT);
    reg |= (0x1 << POWER_MANAGER_CPU_COUNTERS_STOP_CPU_SWITCH_OFF_STOP_BIT_COUNTER_BIT);
    reg |= (0x1 << POWER_MANAGER_CPU_COUNTERS_STOP_CPU_SWITCH_ON_STOP_BIT_COUNTER_BIT);
    reg |= (0x1 << POWER_MANAGER_CPU_COUNTERS_STOP_CPU_ISO_OFF_STOP_BIT_COUNTER_BIT);
    reg |= (0x1 << POWER_MANAGER_CPU_COUNTERS_STOP_CPU_ISO_ON_STOP_BIT_COUNTER_BIT);

    power_manager_peri->CPU_COUNTERS_STOP = reg;

    return kPowerManagerOk_e;
}

power_manager_result_t __attribute__ ((noinline)) power_manager_pwr_gate_periph(power_manager_sel_state_t sel_state, power_manager_counters_t* periph_counters)
{
    uint32_t reg = 0;

    power_manager_peri->PERIPH_WAIT_ACK_SWITCH_ON = 0x1;

    if (sel_state == kOn_e)
    {
        for (int i=0; i<periph_counters->switch_on; i++) asm volatile ("nop;");
        power_manager_peri->PERIPH_SWITCH = 0x0;
        for (int i=0; i<periph_counters->iso_off; i++) asm volatile ("nop;");
        power_manager_peri->PERIPH_ISO = 0x0;
        for (int i=0; i<periph_counters->reset_off; i++) asm volatile ("nop;");
        power_manager_peri->PERIPH_RESET = 0x0;
    }
    else
    {
        for (int i=0; i<periph_counters->iso_on; i++) asm volatile ("nop;");
        power_manager_peri->PERIPH_ISO = 0x1;
        for (int i=0; i<periph_counters->switch_off; i++) asm volatile ("nop;");
        power_manager_peri->PERIPH_SWITCH = 0x1;
        for (int i=0; i<periph_counters->reset_on; i++) asm volatile ("nop;");
        power_manager_peri->PERIPH_RESET = 0x1;
    }

    return kPowerManagerOk_e;
}

power_manager_result_t __attribute__ ((noinline)) power_manager_clk_gate_periph(uint32_t enable)
{
    power_manager_peri->PERIPH_CLK_GATE = enable;
    return kPowerManagerOk_e;
}

power_manager_result_t __attribute__ ((noinline)) power_manager_pwr_gate_ram_block(uint32_t sel_block, power_manager_sel_state_t sel_state, power_manager_counters_t* ram_block_counters)
{
    uint32_t reg = 0;

    if (sel_state == kOn_e)
    {
        *(power_manager_ram_map[sel_block].wait_ack_switch) =  0x1;
        for (int i=0; i<ram_block_counters->switch_on; i++) asm volatile ("nop;");
        *(power_manager_ram_map[sel_block].switch_off) = 0x0;
        for (int i=0; i<ram_block_counters->iso_off; i++) asm volatile ("nop;");
        *(power_manager_ram_map[sel_block].iso) = 0x0;
    }
    else if (sel_state == kOff_e)
    {
        *(power_manager_ram_map[sel_block].wait_ack_switch) = 0x1;
        for (int i=0; i<ram_block_counters->iso_on; i++) asm volatile ("nop;");
        *(power_manager_ram_map[sel_block].iso) = 0x1;
        for (int i=0; i<ram_block_counters->switch_off; i++) asm volatile ("nop;");
        *(power_manager_ram_map[sel_block].switch_off) = 0x1;
    }
    else if (sel_state == kRetOn_e)
    {
        *(power_manager_ram_map[sel_block].wait_ack_switch) = 0x0;
        for (int i=0; i<ram_block_counters->retentive_on; i++) asm volatile ("nop;");
        *(power_manager_ram_map[sel_block].retentive) = 0x1;
    }
    else
    {
        *(power_manager_ram_map[sel_block].wait_ack_switch) = 0x0;
        for (int i=0; i<ram_block_counters->retentive_off; i++) asm volatile ("nop;");
        *(power_manager_ram_map[sel_block].retentive) = 0x0;
    }

    return kPowerManagerOk_e;
}

power_manager_result_t __attribute__ ((noinline)) power_manager_clk_gate_ram_block(uint32_t enable, uint32_t sel_block) {
    *(power_manager_ram_map[sel_block].clk_gate) = enable;
    return kPowerManagerOk_e;
}


void  __attribute__ ((noinline)) power_manager_init() {

    volatile uint32_t *ram_block_ptr = (volatile uint32_t *)&(power_manager_peri->RAM_0_CLK_GATE);

    for (int i = 0; i < MEMORY_BANKS; i++) {
        // every SRAM power domain has 6 uint32_t fields
        // they are all consecutive
        volatile uint32_t *this_ram_hw = ram_block_ptr + (i * 6);
        //the order matters and has to match the one on the struct
        power_manager_ram_map[i].clk_gate           = (uint32_t *)&(this_ram_hw[0]);
        power_manager_ram_map[i].power_gate_ack     = (uint32_t *)&(this_ram_hw[1]);
        power_manager_ram_map[i].switch_off         = (uint32_t *)&(this_ram_hw[2]);
        power_manager_ram_map[i].wait_ack_switch    = (uint32_t *)&(this_ram_hw[3]);
        power_manager_ram_map[i].iso                = (uint32_t *)&(this_ram_hw[4]);
        power_manager_ram_map[i].retentive          = (uint32_t *)&(this_ram_hw[5]);
    }

    //same for external domain
#if EXTERNAL_DOMAINS > 0
    volatile uint32_t *external_domain_ptr = (volatile uint32_t *)&(power_manager_peri->EXTERNAL_0_CLK_GATE);

    for (int i = 0; i < EXTERNAL_DOMAINS; i++) {
        // every SRAM power domain has 6 uint32_t fields
        // they are all consecutive
        volatile uint32_t *this_ext_domain_hw = external_domain_ptr + (i * 7);
        //the order matters and has to match the one on the struct
        power_manager_external_map[i].clk_gate           = (uint32_t *)&(this_ext_domain_hw[0]);
        power_manager_external_map[i].power_gate_ack     = (uint32_t *)&(this_ext_domain_hw[1]);
        power_manager_external_map[i].reset              = (uint32_t *)&(this_ext_domain_hw[2]);
        power_manager_external_map[i].switch_off         = (uint32_t *)&(this_ext_domain_hw[3]);
        power_manager_external_map[i].wait_ack_switch    = (uint32_t *)&(this_ext_domain_hw[4]);
        power_manager_external_map[i].iso                = (uint32_t *)&(this_ext_domain_hw[5]);
        power_manager_external_map[i].retentive          = (uint32_t *)&(this_ext_domain_hw[6]);
    }
#endif

}

power_manager_result_t __attribute__ ((noinline)) power_manager_pwr_gate_external(uint32_t sel_external, power_manager_sel_state_t sel_state, power_manager_counters_t* external_counters)
{
    uint32_t reg = 0;

    if (sel_state == kOn_e)
    {
        *(power_manager_external_map[sel_external].wait_ack_switch) =  0x1;
        for (int i=0; i<external_counters->switch_on; i++) asm volatile ("nop;");
        *(power_manager_external_map[sel_external].switch_off) = 0x0;
        for (int i=0; i<external_counters->iso_off; i++) asm volatile ("nop;");
        *(power_manager_external_map[sel_external].iso) = 0x0;
        for (int i=0; i<external_counters->reset_off; i++) asm volatile ("nop;");
        *(power_manager_external_map[sel_external].reset) = 0x0;
    }
    else if (sel_state == kOff_e)
    {
        *(power_manager_external_map[sel_external].wait_ack_switch) =  0x1;
        for (int i=0; i<external_counters->iso_on; i++) asm volatile ("nop;");
        *(power_manager_external_map[sel_external].iso) = 0x1;
        for (int i=0; i<external_counters->switch_off; i++) asm volatile ("nop;");
        *(power_manager_external_map[sel_external].switch_off) = 0x1;
        for (int i=0; i<external_counters->reset_on; i++) asm volatile ("nop;");
        *(power_manager_external_map[sel_external].reset) = 0x1;
    }
    else if (sel_state == kRetOn_e)
    {
        *(power_manager_external_map[sel_external].wait_ack_switch) =  0x0;
        for (int i=0; i<external_counters->retentive_on; i++) asm volatile ("nop;");
        *(power_manager_external_map[sel_external].retentive) =  0x1;
    }
    else
    {
        *(power_manager_external_map[sel_external].wait_ack_switch) =  0x0;
        for (int i=0; i<external_counters->retentive_off; i++) asm volatile ("nop;");
        *(power_manager_external_map[sel_external].retentive) =  0x0;
    }

    return kPowerManagerOk_e;
}

power_manager_result_t __attribute__ ((noinline)) power_manager_clk_gate_external(uint32_t enable, uint32_t sel_external) {
    *(power_manager_external_map[sel_external].clk_gate) = enable;
    return kPowerManagerOk_e;
}

uint32_t power_manager_periph_domain_is_off()
{
    uint32_t switch_state;

    switch_state = power_manager_peri->POWER_GATE_PERIPH_ACK;

    return switch_state == 0;
}

uint32_t power_manager_ram_block_domain_is_off(uint32_t sel_block)
{
    uint32_t switch_state;

    switch_state = *(power_manager_ram_map[sel_block].power_gate_ack);

    return switch_state == 0;
}

uint32_t power_manager_external_domain_is_off(uint32_t sel_external)
{
    uint32_t switch_state;

    switch_state = *(power_manager_external_map[sel_external].power_gate_ack);

    return switch_state == 0;
}

power_manager_result_t power_manager_pwr_gate_counters_init(power_manager_counters_t* counters, uint32_t reset_off, uint32_t reset_on, uint32_t switch_off, uint32_t switch_on, uint32_t iso_off, uint32_t iso_on, uint32_t retentive_off, uint32_t retentive_on)
{
    counters->reset_off     = reset_off;
    counters->reset_on      = reset_on;
    counters->switch_off    = switch_off;
    counters->switch_on     = switch_on;
    counters->iso_off       = iso_off;
    counters->iso_on        = iso_on;
    counters->retentive_off = retentive_off;
    counters->retentive_on  = retentive_on;

    return kPowerManagerOk_e;
}


