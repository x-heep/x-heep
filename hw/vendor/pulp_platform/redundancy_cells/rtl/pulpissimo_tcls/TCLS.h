// Generated register defines for TCLS_manager

#ifndef _TCLS_MANAGER_REG_DEFS_
#define _TCLS_MANAGER_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define TCLS_MANAGER_PARAM_REG_WIDTH 32

// Stack Pointer storage register
#define TCLS_MANAGER_SP_STORE_REG_OFFSET 0x0

// Re-synchronization configuration
#define TCLS_MANAGER_TCLS_CONFIG_REG_OFFSET 0x4
#define TCLS_MANAGER_TCLS_CONFIG_SETBACK_BIT 0
#define TCLS_MANAGER_TCLS_CONFIG_RELOAD_SETBACK_BIT 1
#define TCLS_MANAGER_TCLS_CONFIG_FORCE_RESYNCH_BIT 2

// Mismatch counter of core 0
#define TCLS_MANAGER_MISMATCHES_0_REG_OFFSET 0x8

// Mismatch counter of core 1
#define TCLS_MANAGER_MISMATCHES_1_REG_OFFSET 0xc

// Mismatch counter of core 2
#define TCLS_MANAGER_MISMATCHES_2_REG_OFFSET 0x10

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _TCLS_MANAGER_REG_DEFS_
// End generated register defines for TCLS_manager