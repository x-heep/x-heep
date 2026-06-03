// Generated register defines for serial_link_xheep_wrapper

// Copyright information found in source file:
// Copyright 2026 EPFL

// Licensing information found in source file:
// 
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#ifndef _SERIAL_LINK_XHEEP_WRAPPER_REG_DEFS_
#define _SERIAL_LINK_XHEEP_WRAPPER_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define SERIAL_LINK_XHEEP_WRAPPER_PARAM_REG_WIDTH 32

// Receiver mode configuration
#define SERIAL_LINK_XHEEP_WRAPPER_RX_MODE_REG_OFFSET 0x0
#define SERIAL_LINK_XHEEP_WRAPPER_RX_MODE_DIRECT_WRITE_EN_BIT 0

// Expected word count for direct write transfer. Set before arming.
// Interrupt fires when this many words have been committed to RAM. Write 0
// to disable.
#define SERIAL_LINK_XHEEP_WRAPPER_DIRECT_WRITE_WORD_COUNT_REG_OFFSET 0x4
#define SERIAL_LINK_XHEEP_WRAPPER_DIRECT_WRITE_WORD_COUNT_COUNT_MASK 0xffff
#define SERIAL_LINK_XHEEP_WRAPPER_DIRECT_WRITE_WORD_COUNT_COUNT_OFFSET 0
#define SERIAL_LINK_XHEEP_WRAPPER_DIRECT_WRITE_WORD_COUNT_COUNT_FIELD \
  ((bitfield_field32_t) { .mask = SERIAL_LINK_XHEEP_WRAPPER_DIRECT_WRITE_WORD_COUNT_COUNT_MASK, .index = SERIAL_LINK_XHEEP_WRAPPER_DIRECT_WRITE_WORD_COUNT_COUNT_OFFSET })

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _SERIAL_LINK_XHEEP_WRAPPER_REG_DEFS_
// End generated register defines for serial_link_xheep_wrapper