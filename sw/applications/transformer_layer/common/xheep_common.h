/* Shared definitions between X-HEEP and ESP host for transformer layer offload. */
#ifndef __XHEEP_TRANSFORMER_LAYER_COMMON_H__
#define __XHEEP_TRANSFORMER_LAYER_COMMON_H__

#include <stdint.h>
#include <stddef.h>
#include "core_v_mini_mcu.h"
#include "../param.h"

// ---------------------------------------------------------------------------
// Layer sizes (from docs/x-heep-tranformer-layer-app.md)
// ---------------------------------------------------------------------------
#define XHEEP_LAYER_SEQ_LEN   121u
#define XHEEP_LAYER_D_MODEL   16u
#define XHEEP_LAYER_D_Q       4u
#define XHEEP_LAYER_NUM_HEADS 4u
#define XHEEP_LAYER_D_FF      4u

// Fixed-point element size (int16_t). This can be changed later for FP16/FP32.
#define XHEEP_LAYER_ELEM_BYTES 2u

// Element counts.
#define XHEEP_LAYER_ELEMS           (XHEEP_LAYER_SEQ_LEN * XHEEP_LAYER_D_MODEL)
#define XHEEP_LAYER_QKV_ELEMS       (4u * XHEEP_LAYER_SEQ_LEN * XHEEP_LAYER_D_Q)
#define XHEEP_LAYER_INTERMEDIATE_ELEMS (XHEEP_LAYER_SEQ_LEN * XHEEP_LAYER_SEQ_LEN)
#define XHEEP_LAYER_ELEMS_BYTES     (XHEEP_LAYER_ELEMS * XHEEP_LAYER_ELEM_BYTES)
#define XHEEP_LAYER_QKV_BYTES       (XHEEP_LAYER_QKV_ELEMS * XHEEP_LAYER_ELEM_BYTES)
#define XHEEP_LAYER_INTERMEDIATE_BYTES (XHEEP_LAYER_INTERMEDIATE_ELEMS * XHEEP_LAYER_ELEM_BYTES)

// Optional done flag written after output (external address).
#define XHEEP_LAYER_DONE_BYTES  4u
#define XHEEP_LAYER_DONE_OFFSET (XHEEP_SHARED_IO_OFFSET + (XHEEP_LAYER_ELEMS * XHEEP_LAYER_ELEM_BYTES))

#if XHEEP_LAYER_USE_P2P_OUT
#define XHEEP_LAYER_DONE_ADDR (XHEEP_P2P_BASE_ADDR(XHEEP_LAYER_P2P_USER) + (uintptr_t)(XHEEP_LAYER_DONE_OFFSET))
#else
#define XHEEP_LAYER_DONE_ADDR (XHEEP_ESP_ADDR(XHEEP_LAYER_MEM_USER, XHEEP_LAYER_DONE_OFFSET))
#endif

// ---------------------------------------------------------------------------
// Shared I/O address (same for MEM and P2P paths)
// ---------------------------------------------------------------------------
#define XHEEP_SHARED_IO_OFFSET 0x00000000u

// Macro to generate memory-mapped P2P/ESP addresses (user field in [27:22]).
#ifndef XHEEP_P2P_BASE_ADDR
#define XHEEP_P2P_BASE_ADDR(user_val) \
    (EXT_SLAVE_START_ADDRESS | ((uintptr_t)((user_val) & 0x3Fu) << 22))
#endif

#ifndef XHEEP_ESP_ADDR
#define XHEEP_ESP_ADDR(user, offset) \
    (XHEEP_P2P_BASE_ADDR(user) + (uintptr_t)(offset))
#endif

// Configure the transport at compile time.
#define XHEEP_LAYER_USE_P2P_IN   0u
#define XHEEP_LAYER_USE_P2P_OUT  0u
#define XHEEP_LAYER_P2P_USER     1u
#define XHEEP_LAYER_MEM_USER     0u

#if XHEEP_LAYER_USE_P2P_IN
#define XHEEP_LAYER_IN_ADDR (XHEEP_P2P_BASE_ADDR(XHEEP_LAYER_P2P_USER) + (uintptr_t)(XHEEP_SHARED_IO_OFFSET))
#else
#define XHEEP_LAYER_IN_ADDR (XHEEP_ESP_ADDR(XHEEP_LAYER_MEM_USER, XHEEP_SHARED_IO_OFFSET))
#endif

#if XHEEP_LAYER_USE_P2P_OUT
#define XHEEP_LAYER_OUT_ADDR (XHEEP_P2P_BASE_ADDR(XHEEP_LAYER_P2P_USER) + (uintptr_t)(XHEEP_SHARED_IO_OFFSET))
#else
#define XHEEP_LAYER_OUT_ADDR (XHEEP_ESP_ADDR(XHEEP_LAYER_MEM_USER, XHEEP_SHARED_IO_OFFSET))
#endif


// ---------------------------------------------------------------------------
// X-HEEP local SRAM layout for buffers
// ---------------------------------------------------------------------------
// Place scratch buffers in the interleaved RAM window (ram2 in linker script).
// In this generated config, RAM8 maps to [0x00040000, 0x00050000).
#if HAVE_QUADRILATERO
// matmul_quadrilatero scratch buffers are placed in .xheep_data_interleaved (ram2).
// Reserve headroom to avoid overlap with layer input/output scratch pointers.
#define XHEEP_LAYER_LOCAL_RESERVED_BYTES 0x4000u
#else
#define XHEEP_LAYER_LOCAL_RESERVED_BYTES 0u
#endif

#define XHEEP_LAYER_LOCAL_BASE_OFFSET (RAM8_START_ADDRESS + XHEEP_LAYER_LOCAL_RESERVED_BYTES)
#define XHEEP_LAYER_LOCAL_END_OFFSET  RAM8_END_ADDRESS

#define XHEEP_LAYER_IN_OFFSET   XHEEP_LAYER_LOCAL_BASE_OFFSET
#define XHEEP_LAYER_OUT_OFFSET  (XHEEP_LAYER_IN_OFFSET + XHEEP_LAYER_ELEMS_BYTES)
#define XHEEP_LAYER_NORM_OFFSET (XHEEP_LAYER_OUT_OFFSET + XHEEP_LAYER_ELEMS_BYTES)
#define XHEEP_LAYER_INTERMEDIATE_OFFSET (XHEEP_LAYER_NORM_OFFSET + XHEEP_LAYER_ELEMS_BYTES)
#define XHEEP_LAYER_QKV_OFFSET  (XHEEP_LAYER_INTERMEDIATE_OFFSET + XHEEP_LAYER_INTERMEDIATE_BYTES)
#define XHEEP_LAYER_LOCAL_REQUIRED_BYTES (3u * XHEEP_LAYER_ELEMS_BYTES + XHEEP_LAYER_INTERMEDIATE_BYTES + XHEEP_LAYER_QKV_BYTES)

#if (XHEEP_LAYER_QKV_OFFSET + XHEEP_LAYER_QKV_BYTES) > XHEEP_LAYER_LOCAL_END_OFFSET
#error "Transformer layer scratch buffers exceed interleaved RAM bank capacity"
#endif

#endif /* __XHEEP_TRANSFORMER_LAYER_COMMON_H__ */
