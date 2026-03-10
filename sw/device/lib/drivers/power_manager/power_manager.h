// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#ifndef _POWER_MANAGER_H_
#define _POWER_MANAGER_H_

#include <stddef.h>
#include <stdint.h>

#include "mmio.h"
#include "power_manager_regs.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Results.
 */
typedef enum power_manager_result {
  kPowerManagerOk_e    = 0,
  kPowerManagerError_e = 1,
} power_manager_result_t;


/**
 * Domain states.
 */
typedef enum power_manager_sel_state {
  kOn_e     = 0,
  kOff_e    = 1,
  kRetOn_e  = 2,
  kRetOff_e = 3,
} power_manager_sel_state_t;

/**
 * Interrupt source.
 */
typedef enum power_manager_sel_intr {
  kTimer_0_pm_e  = 0,
  kPlic_pm_e     = 1,
  kTimer_1_pm_e  = 2,
  kTimer_2_pm_e  = 3,
  kTimer_3_pm_e  = 4,
  kDma_pm_e      = 5,
  kSpi_pm_e      = 6,
  kSpiFlash_pm_e = 7,
  kGpio_0_pm_e   = 8,
  kGpio_1_pm_e   = 9,
  kGpio_2_pm_e   = 10,
  kGpio_3_pm_e   = 11,
  kGpio_4_pm_e   = 12,
  kGpio_5_pm_e   = 13,
  kGpio_6_pm_e   = 14,
  kGpio_7_pm_e   = 15,
  kExt_0_pm_e    = 16,
  kExt_1_pm_e    = 17,
  kExt_2_pm_e    = 18,
  kExt_3_pm_e    = 19,
} power_manager_sel_intr_t;

/**
 * Monitor signals.
 */
typedef struct monitor_signals {
  uint32_t kSwitch_e;
  uint32_t kIso_e;
  uint32_t kReset_e;
} monitor_signals_t;

/**
 * Initialization parameters for POWER MANAGER.
 *
 */
typedef struct power_manager {
  /**
   * The base address for the power_manager hardware registers.
   */
  mmio_region_t base_addr;
} power_manager_t;

typedef struct power_manager_counters {
  /**
   * The counter to set and unset the reset and switch of the CPU.
   */
  uint32_t reset_off;
  uint32_t reset_on;
  uint32_t switch_off;
  uint32_t switch_on;
  uint32_t iso_off;
  uint32_t iso_on;
  uint32_t retentive_off;
  uint32_t retentive_on;
} power_manager_counters_t;

// this struct is used to collect in an array 
// pointers to the power manager to control vectors of power domains
// as memory banks or external domains 
typedef struct power_manager_vector_sram_map_t {
  uint32_t* clk_gate;
  uint32_t* power_gate_ack;
  uint32_t* switch_off;
  uint32_t* wait_ack_switch;
  uint32_t* iso;
  uint32_t* retentive;
} power_manager_vector_sram_map_t;

typedef struct power_manager_vector_ext_map_t {
  uint32_t* clk_gate;
  uint32_t* power_gate_ack;
  uint32_t* switch_off;
  uint32_t* wait_ack_switch;
  uint32_t* iso;
  uint32_t* retentive;
  uint32_t* reset;
} power_manager_vector_ext_map_t;

void power_manager_init();

power_manager_result_t power_manager_pwr_gate_counters_init(power_manager_counters_t* counters, uint32_t reset_off, uint32_t reset_on, uint32_t switch_off, uint32_t switch_on, uint32_t iso_off, uint32_t iso_on, uint32_t retentive_off, uint32_t retentive_on);

power_manager_result_t power_manager_pwr_gate_core(power_manager_sel_intr_t sel_intr, power_manager_counters_t* cpu_counters);

power_manager_result_t power_manager_pwr_gate_periph(power_manager_sel_state_t sel_state, power_manager_counters_t* periph_counters);
power_manager_result_t power_manager_clk_gate_periph(uint32_t enable);

power_manager_result_t power_manager_pwr_gate_ram_block(uint32_t sel_block, power_manager_sel_state_t sel_state, power_manager_counters_t* ram_block_counters);
power_manager_result_t power_manager_clk_gate_ram_block(uint32_t enable, uint32_t sel_block);

power_manager_result_t power_manager_pwr_gate_external(uint32_t sel_external, power_manager_sel_state_t sel_state, power_manager_counters_t* external_counters);
power_manager_result_t power_manager_clk_gate_external(uint32_t enable, uint32_t sel_external);

uint32_t power_manager_periph_domain_is_off();

uint32_t power_manager_ram_block_domain_is_off(uint32_t sel_block);

uint32_t power_manager_external_domain_is_off(uint32_t sel_external);


#ifdef __cplusplus
}
#endif

#endif  // _POWER_MANAGER_H_
