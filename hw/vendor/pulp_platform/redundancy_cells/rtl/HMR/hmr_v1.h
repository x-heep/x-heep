/*
 * Copyright (C) 2023 ETH Zurich and University of Bologna
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef __ARCHI_HMR_HMR_V1_H__
#define __ARCHI_HMR_HMR_V1_H__

#define HMR_IN_INTERLEAVED 1

#define HMR_TOP_OFFSET 0x000
#define HMR_CORE_OFFSET   0x100
#define HMR_DMR_OFFSET    0x200
#define HMR_TMR_OFFSET    0x300

#define HMR_CORE_INCREMENT 0x010
#define HMR_CORE_SLL       0x004
#define HMR_DMR_INCREMENT  0x010
#define HMR_DMR_SLL        0x004
#define HMR_TMR_INCREMENT  0x010
#define HMR_TMR_SLL        0x004

// Generated register defines for HMR_registers

#ifndef _HMR_REGISTERS_REG_DEFS_
#define _HMR_REGISTERS_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
#define HMR_REGISTERS_PARAM_NUM_CORES 12

#define HMR_REGISTERS_PARAM_NUM_D_M_R_GROUPS 6

#define HMR_REGISTERS_PARAM_NUM_T_M_R_GROUPS 4

// Register width
#define HMR_REGISTERS_PARAM_REG_WIDTH 32

// Available Configurations from implemented hardware.
#define HMR_REGISTERS_AVAIL_CONFIG_REG_OFFSET 0x0
#define HMR_REGISTERS_AVAIL_CONFIG_INDEPENDENT_BIT 0
#define HMR_REGISTERS_AVAIL_CONFIG_DUAL_BIT 1
#define HMR_REGISTERS_AVAIL_CONFIG_TRIPLE_BIT 2
#define HMR_REGISTERS_AVAIL_CONFIG_RAPID_RECOVERY_BIT 8

// Enabled cores, based on the configuration. Can be used for barriers.
#define HMR_REGISTERS_CORES_EN_REG_OFFSET 0x4
#define HMR_REGISTERS_CORES_EN_CORES_EN_MASK 0xfff
#define HMR_REGISTERS_CORES_EN_CORES_EN_OFFSET 0
#define HMR_REGISTERS_CORES_EN_CORES_EN_FIELD \
  ((bitfield_field32_t) { .mask = HMR_REGISTERS_CORES_EN_CORES_EN_MASK, .index = HMR_REGISTERS_CORES_EN_CORES_EN_OFFSET })

// DMR configuration enable, on bit per DMR group.
#define HMR_REGISTERS_DMR_ENABLE_REG_OFFSET 0x8
#define HMR_REGISTERS_DMR_ENABLE_DMR_ENABLE_MASK 0x3f
#define HMR_REGISTERS_DMR_ENABLE_DMR_ENABLE_OFFSET 0
#define HMR_REGISTERS_DMR_ENABLE_DMR_ENABLE_FIELD \
  ((bitfield_field32_t) { .mask = HMR_REGISTERS_DMR_ENABLE_DMR_ENABLE_MASK, .index = HMR_REGISTERS_DMR_ENABLE_DMR_ENABLE_OFFSET })

// TMR configuration enable, one bit per TMR group.
#define HMR_REGISTERS_TMR_ENABLE_REG_OFFSET 0xc
#define HMR_REGISTERS_TMR_ENABLE_TMR_ENABLE_MASK 0xf
#define HMR_REGISTERS_TMR_ENABLE_TMR_ENABLE_OFFSET 0
#define HMR_REGISTERS_TMR_ENABLE_TMR_ENABLE_FIELD \
  ((bitfield_field32_t) { .mask = HMR_REGISTERS_TMR_ENABLE_TMR_ENABLE_MASK, .index = HMR_REGISTERS_TMR_ENABLE_TMR_ENABLE_OFFSET })

// DMR configuration bits.
#define HMR_REGISTERS_DMR_CONFIG_REG_OFFSET 0x10
#define HMR_REGISTERS_DMR_CONFIG_RAPID_RECOVERY_BIT 0
#define HMR_REGISTERS_DMR_CONFIG_FORCE_RECOVERY_BIT 1

// TMR configuration bits.
#define HMR_REGISTERS_TMR_CONFIG_REG_OFFSET 0x14
#define HMR_REGISTERS_TMR_CONFIG_DELAY_RESYNCH_BIT 0
#define HMR_REGISTERS_TMR_CONFIG_SETBACK_BIT 1
#define HMR_REGISTERS_TMR_CONFIG_RELOAD_SETBACK_BIT 2
#define HMR_REGISTERS_TMR_CONFIG_RAPID_RECOVERY_BIT 3
#define HMR_REGISTERS_TMR_CONFIG_FORCE_RESYNCH_BIT 4

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _HMR_REGISTERS_REG_DEFS_
// End generated register defines for HMR_registers

// Generated register defines for HMR_core_regs

#ifndef _HMR_CORE_REGS_REG_DEFS_
#define _HMR_CORE_REGS_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define HMR_CORE_REGS_PARAM_REG_WIDTH 32

// Value to determine wich redundancy mode the core with that ID is in.
#define HMR_CORE_REGS_CURRENT_MODE_REG_OFFSET 0x0
#define HMR_CORE_REGS_CURRENT_MODE_INDEPENDENT_BIT 0
#define HMR_CORE_REGS_CURRENT_MODE_DUAL_BIT 1
#define HMR_CORE_REGS_CURRENT_MODE_TRIPLE_BIT 2

// Mismatches of the core
#define HMR_CORE_REGS_MISMATCHES_REG_OFFSET 0x4

// Stack Pointer storage register
#define HMR_CORE_REGS_SP_STORE_REG_OFFSET 0x8

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _HMR_CORE_REGS_REG_DEFS_
// End generated register defines for HMR_core_regs

// Generated register defines for HMR_dmr_regs

#ifndef _HMR_DMR_REGS_REG_DEFS_
#define _HMR_DMR_REGS_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define HMR_DMR_REGS_PARAM_REG_WIDTH 32

// DMR configuration enable.
#define HMR_DMR_REGS_DMR_ENABLE_REG_OFFSET 0x0
#define HMR_DMR_REGS_DMR_ENABLE_DMR_ENABLE_BIT 0

// DMR configuration bits.
#define HMR_DMR_REGS_DMR_CONFIG_REG_OFFSET 0x4
#define HMR_DMR_REGS_DMR_CONFIG_RAPID_RECOVERY_BIT 0
#define HMR_DMR_REGS_DMR_CONFIG_FORCE_RECOVERY_BIT 1

// Address for the last checkpoint.
#define HMR_DMR_REGS_CHECKPOINT_ADDR_REG_OFFSET 0x8

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _HMR_DMR_REGS_REG_DEFS_
// End generated register defines for HMR_dmr_regs

// Generated register defines for HMR_tmr_regs

#ifndef _HMR_TMR_REGS_REG_DEFS_
#define _HMR_TMR_REGS_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define HMR_TMR_REGS_PARAM_REG_WIDTH 32

// TMR configuration enable.
#define HMR_TMR_REGS_TMR_ENABLE_REG_OFFSET 0x0
#define HMR_TMR_REGS_TMR_ENABLE_TMR_ENABLE_BIT 0

// TMR configuration bits.
#define HMR_TMR_REGS_TMR_CONFIG_REG_OFFSET 0x4
#define HMR_TMR_REGS_TMR_CONFIG_DELAY_RESYNCH_BIT 0
#define HMR_TMR_REGS_TMR_CONFIG_SETBACK_BIT 1
#define HMR_TMR_REGS_TMR_CONFIG_RELOAD_SETBACK_BIT 2
#define HMR_TMR_REGS_TMR_CONFIG_RAPID_RECOVERY_BIT 3
#define HMR_TMR_REGS_TMR_CONFIG_FORCE_RESYNCH_BIT 4

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _HMR_TMR_REGS_REG_DEFS_
// End generated register defines for HMR_tmr_regs


#endif // __ARCHI_HMR_HMR_V1_H__
