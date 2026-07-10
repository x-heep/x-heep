// Generated register defines for ECC_manager

#ifndef _ECC_MANAGER_REG_DEFS_
#define _ECC_MANAGER_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define ECC_MANAGER_PARAM_REG_WIDTH 32

// Correctable mismatches caught by ecc on access
#define ECC_MANAGER_MISMATCH_COUNT_REG_OFFSET 0x0

// Interval between scrubs
#define ECC_MANAGER_SCRUB_INTERVAL_REG_OFFSET 0x4

// Correctable mismatches caught by ecc on scrub
#define ECC_MANAGER_SCRUB_FIX_COUNT_REG_OFFSET 0x8

// Uncorrectable mismatches caught by ecc on scrub
#define ECC_MANAGER_SCRUB_UNCORRECTABLE_COUNT_REG_OFFSET 0xc

// Testing: Inverted write mask for data bits
#define ECC_MANAGER_WRITE_MASK_DATA_N_REG_OFFSET 0x10

// Testing: Inverted write mask for ECC bits
#define ECC_MANAGER_WRITE_MASK_ECC_N_REG_OFFSET 0x14
#define ECC_MANAGER_WRITE_MASK_ECC_N_WRITE_MASK_ECC_N_MASK 0x7f
#define ECC_MANAGER_WRITE_MASK_ECC_N_WRITE_MASK_ECC_N_OFFSET 0
#define ECC_MANAGER_WRITE_MASK_ECC_N_WRITE_MASK_ECC_N_FIELD \
  ((bitfield_field32_t) { .mask = ECC_MANAGER_WRITE_MASK_ECC_N_WRITE_MASK_ECC_N_MASK, .index = ECC_MANAGER_WRITE_MASK_ECC_N_WRITE_MASK_ECC_N_OFFSET })

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _ECC_MANAGER_REG_DEFS_
// End generated register defines for ECC_manager