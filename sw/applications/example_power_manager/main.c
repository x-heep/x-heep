// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdio.h>
#include <stdlib.h>
#include "csr.h"
#include "hart.h"
#include "handler.h"
#include "core_v_mini_mcu.h"
#include "core_v_mini_mcu_memory.h"
#include "rv_timer.h"
#include "power_manager.h"
#include "soc_ctrl.h"
#include "rv_plic.h"
#include "rv_plic_regs.h"
#include "gpio.h"
#include "pad_control.h"
#include "pad_control_regs.h"
#include "x-heep.h"
#include "dma.h"

#ifndef RV_PLIC_IS_INCLUDED
  #error ( "This app does NOT work as the RV_PLIC peripheral is not included" )
#endif


#define EXTERNAL_CSR_REG_MIE_MASK (1<<11)

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

static rv_timer_t timer_0_1;
static rv_timer_t timer_2_3;
static const uint64_t kTickFreqHz = 1000 * 1000; // 1 MHz

#ifndef TARGET_IS_FPGA
    #define GPIO_TB_OUT 30
    #define GPIO_TB_IN  31
    #define GPIO_INTR  GPIO_INTR_31
#endif

#define TEST_WORD
//this data has to be big to allow the CPU to power gate
#define TEST_DATA_SIZE 450

// Source and destination addresses have to be aligned on a 4 bytes address
uint32_t test_data_4B[TEST_DATA_SIZE] __attribute__ ((aligned (4))) = { 0 };
uint32_t copied_data_4B[TEST_DATA_SIZE] __attribute__ ((aligned (4))) = { 0 };

uint8_t gpio_intr_flag = 0;

void gpio_handler_in()
{
    gpio_intr_flag = 1;
}

//defined in the linker script
extern uint32_t __ram1_used_limit_plus_4;

int main(int argc, char *argv[])
{

    // Setup power_manager
    power_manager_counters_t power_manager_counters;
    power_manager_init();
    //counters
    uint32_t reset_off, reset_on, switch_off, switch_on, iso_off, iso_on;

    CSR_CLEAR_BITS(CSR_REG_MIE, EXTERNAL_CSR_REG_MIE_MASK );
    /* Enable machine-level external interrupt. */
    CSR_SET_BITS(CSR_REG_MIE, EXTERNAL_CSR_REG_MIE_MASK );

    // Setup pads
#ifndef TARGET_IS_FPGA
    pad_control_t pad_control;
    pad_control.base_addr = mmio_region_from_addr((uintptr_t)PAD_CONTROL_START_ADDRESS);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_I2C_SCL_REG_OFFSET), 1);
    pad_control_set_mux(&pad_control, (ptrdiff_t)(PAD_CONTROL_PAD_MUX_I2C_SDA_REG_OFFSET), 1);
#endif

    // Setup plic
    plic_Init();

    // Get current Frequency
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);
    uint32_t freq_hz = soc_ctrl_get_frequency(&soc_ctrl);

    // Setup rv_timer_0_1
    mmio_region_t timer_0_1_reg = mmio_region_from_addr(RV_TIMER_AO_START_ADDRESS);
    rv_timer_init(timer_0_1_reg, (rv_timer_config_t){.hart_count = 2, .comparator_count = 1}, &timer_0_1);
    rv_timer_tick_params_t tick_params;
    rv_timer_approximate_tick_params(freq_hz, kTickFreqHz, &tick_params);

    // Setup rv_timer_2_3
    mmio_region_t timer_2_3_reg = mmio_region_from_addr(RV_TIMER_START_ADDRESS);
    rv_timer_init(timer_2_3_reg, (rv_timer_config_t){.hart_count = 2, .comparator_count = 1}, &timer_2_3);

    // Init cpu_subsystem's counters

    //Turn off: first, isolate the CPU outputs, then I reset it, then I switch it off (reset and switch off order does not really matter)
    iso_off = 10;
    reset_off = iso_off + 5;
    switch_off = reset_off + 5;
    //Turn on: first, give back power by switching on, then deassert the reset, the unisolate the CPU outputs
    switch_on = 10;
    reset_on = switch_on + 20; //give 20 cycles to emulate the turn on time, this number depends on technology and here it is just a random number
    iso_on = reset_on + 5;

    if (power_manager_pwr_gate_counters_init(&power_manager_counters, reset_off, reset_on, switch_off, switch_on, iso_off, iso_on, 0, 0) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail. Check the reset and powergate counters value\n\r");
        return EXIT_FAILURE;
    }

    // Power-gate and wake-up due to timer_0
    rv_timer_set_tick_params(&timer_0_1, 0, tick_params);
    rv_timer_irq_enable(&timer_0_1, 0, 0, kRvTimerEnabled);
    rv_timer_arm(&timer_0_1, 0, 0, 64);
    rv_timer_counter_set_enabled(&timer_0_1, 0, kRvTimerEnabled);

    CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
    if (power_manager_pwr_gate_core(kTimer_0_pm_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);

    // Power-gate and wake-up due to timer_1
    rv_timer_set_tick_params(&timer_0_1, 1, tick_params);
    rv_timer_irq_enable(&timer_0_1, 1, 0, kRvTimerEnabled);
    rv_timer_arm(&timer_0_1, 1, 0, 64);
    rv_timer_counter_set_enabled(&timer_0_1, 1, kRvTimerEnabled);

    CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
    if (power_manager_pwr_gate_core(kTimer_1_pm_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);

    // Power-gate and wake-up due to timer_2
    rv_timer_set_tick_params(&timer_2_3, 0, tick_params);
    rv_timer_irq_enable(&timer_2_3, 0, 0, kRvTimerEnabled);
    rv_timer_arm(&timer_2_3, 0, 0, 70);
    rv_timer_counter_set_enabled(&timer_2_3, 0, kRvTimerEnabled);

    CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
    if (power_manager_pwr_gate_core(kTimer_2_pm_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);

    // Power-gate and wake-up due to timer_3
    rv_timer_set_tick_params(&timer_2_3, 1, tick_params);
    rv_timer_irq_enable(&timer_2_3, 1, 0, kRvTimerEnabled);
    rv_timer_arm(&timer_2_3, 1, 0, 70);
    rv_timer_counter_set_enabled(&timer_2_3, 1, kRvTimerEnabled);

    CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
    if (power_manager_pwr_gate_core(kTimer_3_pm_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);

    // Power-gate and wake-up due to DMA

    //prepare data
    for(int i=0; i<TEST_DATA_SIZE;i++){
        test_data_4B[i] = i;
    }

    dma_init(NULL);
    static dma_config_flags_t res;
    static dma_target_t tgt_src;
    static dma_target_t tgt_dst;
    static dma_trans_t trans;

    // Initialize the DMA for the next tests
    tgt_src.ptr = (uint8_t *)test_data_4B;
    tgt_src.inc_d1_du = 1;
    tgt_src.trig = DMA_TRIG_MEMORY;
    tgt_src.type = DMA_DATA_TYPE_WORD;
    tgt_src.env = NULL;
    tgt_src.inc_d2_du = 0;

    tgt_dst.ptr = (uint8_t *)copied_data_4B;
    tgt_dst.inc_d1_du = 1;
    tgt_dst.trig = DMA_TRIG_MEMORY;
    tgt_dst.type = DMA_DATA_TYPE_WORD;
    tgt_dst.env = NULL;
    tgt_dst.inc_d2_du = 0;

    trans.size_d1_du = TEST_DATA_SIZE;
    trans.src = &tgt_src;
    trans.dst = &tgt_dst;
    trans.src_type = DMA_DATA_TYPE_WORD;
    trans.dst_type = DMA_DATA_TYPE_WORD;
    trans.mode = DMA_TRANS_MODE_SINGLE;
    trans.win_du = 0;
    trans.sign_ext = 0;
    trans.end = DMA_TRANS_END_INTR;
    trans.dim = DMA_DIM_CONF_1D;
    trans.dim_inv = 0;
    trans.channel = 0;

    trans.pad_top_du = 0;
    trans.pad_bottom_du = 0;
    trans.pad_left_du = 0;
    trans.pad_right_du = 0;

    trans.flags = 0x0;
    res = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    res = dma_load_transaction(&trans);
    res = dma_launch(&trans);

    while (!dma_is_ready(0))
    {
        CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
        if (dma_is_ready(0) == 0)
        {
                if (power_manager_pwr_gate_core(kDma_pm_e, &power_manager_counters) != kPowerManagerOk_e)
                {
                    PRINTF("Error: power manager fail.\n\r");
                    return EXIT_FAILURE;
                }
        }
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    }

    for(int i=0; i<TEST_DATA_SIZE; i++) {
        if (copied_data_4B[i] != test_data_4B[i]) {
            PRINTF("ERROR COPY [%d]: %08x != %08x : %04x != %04x\n", i, &copied_data_4B[i], &test_data_4B[i], copied_data_4B[i], test_data_4B[i]);
            return -1;
        }
    }

#ifndef TARGET_IS_FPGA
    // Power-gate and wake-up due to plic GPIO

    gpio_assign_irq_handler( GPIO_INTR_31, &gpio_handler_in );

    bool state = false;
    plic_irq_set_priority(GPIO_INTR_31, 1);
    plic_irq_set_enabled(GPIO_INTR_31, kPlicToggleEnabled);

    gpio_cfg_t pin2_cfg = {.pin = GPIO_TB_IN, .mode = GpioModeIn,.en_input_sampling = true,
        .en_intr = true, .intr_type = GpioIntrEdgeRising};
    gpio_config (pin2_cfg);

    gpio_cfg_t pin1_cfg = {.pin = GPIO_TB_OUT, .mode = GpioModeOutPushPull};
    gpio_config (pin1_cfg);
    gpio_write(GPIO_TB_OUT, true);

    CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
    if (power_manager_pwr_gate_core(kPlic_pm_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);

    uint32_t intr_num;
    plic_irq_complete(&intr_num);

    if(gpio_intr_flag == 0){
        PRINTF("Error: GPIO interrupt not detected\n\r");
        return EXIT_FAILURE;
    }

#endif

    /* write something to stdout */
    PRINTF("CPU Power Gating Test Successefull\n\r");

    // ------------ PERIPHERAL SUBSYSTEM  ------------
    PRINTF("Testing Peripheral Subsystem...\n\r");

    // ------------ clock gating ------------
    power_manager_clk_gate_periph(0x1);
    // Wait some time
    for (int i=0; i<100; i++) asm volatile("nop;");
    // Enabling the peripheral subsystem
    power_manager_clk_gate_periph(0x0);

    PRINTF("Peripheral Clock Gating Test Successefull\n\r");

    // ------------ power gating ------------
    if (power_manager_pwr_gate_counters_init(&power_manager_counters, 30, 30, 30, 30, 30, 30, 0, 0) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail. Check the reset and powergate counters value\n\r");
        return EXIT_FAILURE;
    }

    // Power off peripheral_subsystem domain
    if (power_manager_pwr_gate_periph(kOff_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }

    // Check that the peripheral_subsystem domain is actually OFF
    while(!power_manager_periph_domain_is_off());

    // Wait some time
    for (int i=0; i<100; i++) asm volatile("nop;");

    // Power on peripheral_subsystem domain
    if (power_manager_pwr_gate_periph(kOn_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }

    PRINTF("Peripheral Power Gating Test Successefull\n\r");

#if MEMORY_BANKS > 2
    // ------------ MEMORY SUBSYSTEM  ------------
    PRINTF("Testing Memory Subsystem...\n\r");

    // ------------ clock gating ------------
    // do not clock gate instruction and data memory (usually first 2 banks)
    uint32_t end_data_addr = (uint32_t)(&__ram1_used_limit_plus_4);
    //printf("%x\n", end_data_addr);
    for(uint32_t i = 0; i < MEMORY_BANKS; ++i) {
        if (end_data_addr < xheep_memory_regions[i].start) 
            power_manager_clk_gate_ram_block(0x1, i);
    }

    // Wait some time
    for (int i=0; i<100; i++) asm volatile("nop;");

    // Enabling ram-banks
    for(uint32_t i = 0; i < MEMORY_BANKS; ++i) {
        if (end_data_addr < xheep_memory_regions[i].start) 
            power_manager_clk_gate_ram_block(0x0, i);
    }

    PRINTF("Memory Clock Gating Test Successefull\n\r");

    // ------------ power gating ------------
    if (power_manager_pwr_gate_counters_init(&power_manager_counters, 30, 30, 30, 30, 30, 30, 0, 0) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail. Check the reset and powergate counters value\n\r");
        return EXIT_FAILURE;
    }
    // Power off one ram block domain
    for(uint32_t i = 0; i < MEMORY_BANKS; ++i) {
        if (end_data_addr < xheep_memory_regions[i].start) {
            if (power_manager_pwr_gate_ram_block(i, kOff_e, &power_manager_counters) != kPowerManagerOk_e)
            {
                PRINTF("Error: power manager fail.\n\r");
                return EXIT_FAILURE;
            }
            // Check that the ram block i domain is actually OFF
            while(!power_manager_ram_block_domain_is_off(i));

            // Wait some time
            for (int i=0; i<100; i++) asm volatile("nop");
            // Power on ram block i domain
            if (power_manager_pwr_gate_ram_block(i, kOn_e, &power_manager_counters) != kPowerManagerOk_e)
            {
                PRINTF("Error: power manager fail.\n\r");
                return EXIT_FAILURE;
            }

            PRINTF("Memory Power Gating Test Successefull\n\r");

            // ------------ set retentive ------------
            if (power_manager_pwr_gate_counters_init(&power_manager_counters, 0, 0, 0, 0, 0, 0, 30, 30) != kPowerManagerOk_e)
            {
                PRINTF("Error: power manager fail. Check the reset and powergate counters value\n\r");
                return EXIT_FAILURE;
            }
            // Set retention mode on for ram block i domain
            if (power_manager_pwr_gate_ram_block(i, kRetOn_e, &power_manager_counters) != kPowerManagerOk_e)
            {
                PRINTF("Error: power manager fail.\n\r");
                return EXIT_FAILURE;
            }
            // Wait some time
            for (int i=0; i<100; i++) asm volatile("nop");
            // Set retention mode off for ram block i domain
            if (power_manager_pwr_gate_ram_block(i, kRetOff_e, &power_manager_counters) != kPowerManagerOk_e)
            {
                PRINTF("Error: power manager fail.\n\r");
                return EXIT_FAILURE;
            }

            PRINTF("Memory Set Retentive Test Successefull\n\r");
            break;

        }
    }

#else
    #pragma message ( "the memory test can only run if MEMORY_BANKS > 2" )
#endif

#if EXTERNAL_DOMAINS > 0

    // ------------ External SUBSYSTEM  ------------
    PRINTF("Testing External Domain Subsystems...\n\r");

    // ------------ clock gating ------------
    for(uint32_t i = 0; i < EXTERNAL_DOMAINS; ++i)
       power_manager_clk_gate_external(0x1, i);
    // Wait some time
    for (int i=0; i<100; i++) asm volatile("nop;");
    // Enabling external subsystems
    for(uint32_t i = 0; i < EXTERNAL_DOMAINS; ++i)
       power_manager_clk_gate_external(0x0, i);

    PRINTF("External Clock Gating Test Successefull\n\r");

    // ------------ power gating domain 0 ------------
    if (power_manager_pwr_gate_counters_init(&power_manager_counters, 30, 30, 30, 30, 30, 30, 0, 0) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail. Check the reset and powergate counters value\n\r");
        return EXIT_FAILURE;
    }
    // Power off external domain
    if (power_manager_pwr_gate_external(0, kOff_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }
    // Check that the external domain is actually OFF
    while(!power_manager_external_domain_is_off(0));
    // Wait some time
    for (int i=0; i<100; i++) asm volatile("nop");
    // Power on external domain
    if (power_manager_pwr_gate_external(0, kOn_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }

    PRINTF("External Power Gating Test Successefull\n\r");

    // ------------ set retentive domain 0------------
   if (power_manager_pwr_gate_counters_init(&power_manager_counters, 0, 0, 0, 0, 0, 0, 30, 30) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail. Check the reset and powergate counters value\n\r");
        return EXIT_FAILURE;
    }
    // Set retention mode on for external domain block 0
    if (power_manager_pwr_gate_external(0, kRetOn_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }
    // Wait some time
    for (int i=0; i<100; i++) asm volatile("nop");
    // Set retention mode off for external domain block 0
    if (power_manager_pwr_gate_external(0, kRetOff_e, &power_manager_counters) != kPowerManagerOk_e)
    {
        PRINTF("Error: power manager fail.\n\r");
        return EXIT_FAILURE;
    }

    PRINTF("External Set Retentive Test Successefull\n\r");
#else
    #pragma message ( "the external domain test can only run if EXTERNAL_DOMAINS > 0" )
#endif
    return EXIT_SUCCESS;

}