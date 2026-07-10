// Generated register defines for ODRG_manager

#ifndef _ODRG_MANAGER_REG_DEFS_
#define _ODRG_MANAGER_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define ODRG_MANAGER_PARAM_REG_WIDTH 32

// Stack Pointer storage register
#define ODRG_MANAGER_SP_STORE_REG_OFFSET 0x0

// Redundancy Mode configuration
#define ODRG_MANAGER_MODE_REG_OFFSET 0x4
#define ODRG_MANAGER_MODE_MODE_BIT 0
#define ODRG_MANAGER_MODE_DELAY_RESYNCH_BIT 1
#define ODRG_MANAGER_MODE_SETBACK_BIT 2
#define ODRG_MANAGER_MODE_RELOAD_SETBACK_BIT 3
#define ODRG_MANAGER_MODE_FORCE_RESYNCH_BIT 4

// Mismatch counter of core 0
#define ODRG_MANAGER_MISMATCHES_0_REG_OFFSET 0x8

// Mismatch counter of core 1
#define ODRG_MANAGER_MISMATCHES_1_REG_OFFSET 0xc

// Mismatch counter of core 2
#define ODRG_MANAGER_MISMATCHES_2_REG_OFFSET 0x10

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _ODRG_MANAGER_REG_DEFS_
// End generated register defines for ODRG_manager