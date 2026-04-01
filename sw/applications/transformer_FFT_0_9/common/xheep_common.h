/* Shared definitions between X-HEEP FFT firmware and ESP host. */
#ifndef __XHEEP_TRANSFORMER_FFT_COMMON_H__
#define __XHEEP_TRANSFORMER_FFT_COMMON_H__

#include <stddef.h>
#include <stdint.h>
#include "core_v_mini_mcu.h"
#include "../param.h"

#ifndef HAVE_QUADRILATERO
#define HAVE_QUADRILATERO 0
#endif

// ---------------------------------------------------------------------------
// FFT / STFT constants
// ---------------------------------------------------------------------------
#define XHEEP_FFT_INPUT_REAL_SAMPLES 256u
#define XHEEP_FFT_SIZE               512u
#define XHEEP_FFT_BITS               9u

#define XHEEP_STFT_CHANNELS          20u
#define XHEEP_STFT_TIME_STEPS        15u
#define XHEEP_STFT_PATCH_HEIGHT      80u
#define XHEEP_STFT_PATCH_WIDTH       5u
#define XHEEP_STFT_OVERLAP           64u
#define XHEEP_STFT_WINDOW_STRIDE     (XHEEP_FFT_INPUT_REAL_SAMPLES - XHEEP_STFT_OVERLAP)

#define XHEEP_RAW_SIGNAL_CH_SAMPLES  3072u
#define XHEEP_RAW_SIGNAL_TOTAL_SAMPLES (XHEEP_STFT_CHANNELS * XHEEP_RAW_SIGNAL_CH_SAMPLES)

// ---------------------------------------------------------------------------
// Model dimensions for pre-layer output
// ---------------------------------------------------------------------------
#define XHEEP_D_EMBEDDING            400u
#define XHEEP_D_MODEL                16u
#define XHEEP_D_SEQ                  120u
#define XHEEP_D_SEQ_WITH_CLS         (XHEEP_D_SEQ + 1u)

// ---------------------------------------------------------------------------
// Split configuration: channels [0, 9]
// ---------------------------------------------------------------------------
#define XHEEP_SPLIT_CHANNEL_START    0u
#define XHEEP_SPLIT_CHANNEL_END      10u
#define XHEEP_SPLIT_TOKENS_PER_CH    6u
#define XHEEP_SPLIT_EMIT_CLS         1u

#define XHEEP_SPLIT_OUT_OFFSET_ROWS  0u
#define XHEEP_SPLIT_OUT_ROWS         (1u + (XHEEP_SPLIT_CHANNEL_END - XHEEP_SPLIT_CHANNEL_START) * XHEEP_SPLIT_TOKENS_PER_CH)
#define XHEEP_SPLIT_OUT_OFFSET_ELEMS (XHEEP_SPLIT_OUT_OFFSET_ROWS * XHEEP_D_MODEL)
#define XHEEP_SPLIT_OUT_ELEMS        (XHEEP_SPLIT_OUT_ROWS * XHEEP_D_MODEL)

// Fixed-point element size (int16_t)
#define XHEEP_LAYER_ELEM_BYTES       2u
#define XHEEP_SPLIT_OUT_OFFSET_BYTES (XHEEP_SPLIT_OUT_OFFSET_ELEMS * XHEEP_LAYER_ELEM_BYTES)
#define XHEEP_SPLIT_OUT_BYTES        (XHEEP_SPLIT_OUT_ELEMS * XHEEP_LAYER_ELEM_BYTES)

#if (XHEEP_SPLIT_CHANNEL_END > XHEEP_STFT_CHANNELS) || (XHEEP_SPLIT_CHANNEL_START >= XHEEP_SPLIT_CHANNEL_END)
#error "Invalid split channel range for transformer_FFT_0_9"
#endif

// ---------------------------------------------------------------------------
// Input payload layout (all int16_t arrays)
// ---------------------------------------------------------------------------
#define XHEEP_PRE_RAW_OFFSET_ELEMS           0u
#define XHEEP_PRE_RAW_ELEMS                  XHEEP_RAW_SIGNAL_TOTAL_SAMPLES

#define XHEEP_PRE_NORM1_WEIGHT_OFFSET_ELEMS  (XHEEP_PRE_RAW_OFFSET_ELEMS + XHEEP_PRE_RAW_ELEMS)
#define XHEEP_PRE_NORM1_WEIGHT_ELEMS         XHEEP_D_EMBEDDING

#define XHEEP_PRE_NORM1_BIAS_OFFSET_ELEMS    (XHEEP_PRE_NORM1_WEIGHT_OFFSET_ELEMS + XHEEP_PRE_NORM1_WEIGHT_ELEMS)
#define XHEEP_PRE_NORM1_BIAS_ELEMS           XHEEP_D_EMBEDDING

#define XHEEP_PRE_DENSE_WEIGHT_OFFSET_ELEMS  (XHEEP_PRE_NORM1_BIAS_OFFSET_ELEMS + XHEEP_PRE_NORM1_BIAS_ELEMS)
#define XHEEP_PRE_DENSE_WEIGHT_ELEMS         (XHEEP_D_EMBEDDING * XHEEP_D_MODEL)

#define XHEEP_PRE_DENSE_BIAS_OFFSET_ELEMS    (XHEEP_PRE_DENSE_WEIGHT_OFFSET_ELEMS + XHEEP_PRE_DENSE_WEIGHT_ELEMS)
#define XHEEP_PRE_DENSE_BIAS_ELEMS           XHEEP_D_MODEL

#define XHEEP_PRE_NORM2_WEIGHT_OFFSET_ELEMS  (XHEEP_PRE_DENSE_BIAS_OFFSET_ELEMS + XHEEP_PRE_DENSE_BIAS_ELEMS)
#define XHEEP_PRE_NORM2_WEIGHT_ELEMS         XHEEP_D_MODEL

#define XHEEP_PRE_NORM2_BIAS_OFFSET_ELEMS    (XHEEP_PRE_NORM2_WEIGHT_OFFSET_ELEMS + XHEEP_PRE_NORM2_WEIGHT_ELEMS)
#define XHEEP_PRE_NORM2_BIAS_ELEMS           XHEEP_D_MODEL

#define XHEEP_PRE_CLS_OFFSET_ELEMS           (XHEEP_PRE_NORM2_BIAS_OFFSET_ELEMS + XHEEP_PRE_NORM2_BIAS_ELEMS)
#define XHEEP_PRE_CLS_ELEMS                  XHEEP_D_MODEL

#define XHEEP_PRE_POS_OFFSET_ELEMS           (XHEEP_PRE_CLS_OFFSET_ELEMS + XHEEP_PRE_CLS_ELEMS)
#define XHEEP_PRE_POS_ELEMS                  (XHEEP_D_SEQ_WITH_CLS * XHEEP_D_MODEL)

#define XHEEP_LAYER_IN_ELEMS                 (XHEEP_PRE_POS_OFFSET_ELEMS + XHEEP_PRE_POS_ELEMS)
#define XHEEP_LAYER_OUT_ELEMS                (XHEEP_D_SEQ_WITH_CLS * XHEEP_D_MODEL)

#define XHEEP_LAYER_IN_BYTES                 (XHEEP_LAYER_IN_ELEMS * XHEEP_LAYER_ELEM_BYTES)
#define XHEEP_LAYER_OUT_BYTES                (XHEEP_LAYER_OUT_ELEMS * XHEEP_LAYER_ELEM_BYTES)

// Optional done flag written after shared I/O payload (external address)
#define XHEEP_LAYER_DONE_BYTES               4u
#define XHEEP_LAYER_SHARED_BYTES             ((XHEEP_LAYER_IN_BYTES > XHEEP_LAYER_OUT_BYTES) ? XHEEP_LAYER_IN_BYTES : XHEEP_LAYER_OUT_BYTES)
#define XHEEP_LAYER_DONE_OFFSET              (XHEEP_SHARED_IO_OFFSET + XHEEP_LAYER_SHARED_BYTES)

// ---------------------------------------------------------------------------
// Shared I/O address (same for MEM and P2P paths)
// ---------------------------------------------------------------------------
#define XHEEP_SHARED_IO_OFFSET 0x00000000u

// Macro to generate memory-mapped P2P/ESP addresses (user field in [27:22])
#ifndef XHEEP_P2P_BASE_ADDR
#define XHEEP_P2P_BASE_ADDR(user_val) \
    (EXT_SLAVE_START_ADDRESS | ((uintptr_t)((user_val) & 0x3Fu) << 22))
#endif

#ifndef XHEEP_ESP_ADDR
#define XHEEP_ESP_ADDR(user, offset) \
    (XHEEP_P2P_BASE_ADDR(user) + (uintptr_t)(offset))
#endif

// Configure the transport at compile time
#define XHEEP_LAYER_USE_P2P_IN   0u
#if USE_P2P
#define XHEEP_LAYER_USE_P2P_OUT  1u
#else
#define XHEEP_LAYER_USE_P2P_OUT  0u
#endif
#define XHEEP_LAYER_P2P_USER_IN  1u
#define XHEEP_LAYER_P2P_USER_OUT 1u
#define XHEEP_LAYER_MEM_USER_IN  0u
#define XHEEP_LAYER_MEM_USER_OUT 0u
#define XHEEP_LAYER_MEM_USER_DBG 0u

#if XHEEP_LAYER_USE_P2P_IN
#define XHEEP_LAYER_IN_ADDR (XHEEP_P2P_BASE_ADDR(XHEEP_LAYER_P2P_USER_IN) + (uintptr_t)(XHEEP_SHARED_IO_OFFSET))
#else
#define XHEEP_LAYER_IN_ADDR (XHEEP_ESP_ADDR(XHEEP_LAYER_MEM_USER_IN, XHEEP_SHARED_IO_OFFSET))
#endif

#if XHEEP_LAYER_USE_P2P_OUT
#define XHEEP_LAYER_OUT_ADDR (XHEEP_P2P_BASE_ADDR(XHEEP_LAYER_P2P_USER_OUT) + (uintptr_t)(XHEEP_SHARED_IO_OFFSET))
#else
#define XHEEP_LAYER_OUT_ADDR (XHEEP_ESP_ADDR(XHEEP_LAYER_MEM_USER_OUT, XHEEP_SHARED_IO_OFFSET))
#endif

/* Keep debug status in host-visible memory even when data output is P2P. */
#define XHEEP_LAYER_DONE_ADDR (XHEEP_ESP_ADDR(XHEEP_LAYER_MEM_USER_DBG, XHEEP_LAYER_DONE_OFFSET))

// ---------------------------------------------------------------------------
// X-HEEP local SRAM layout for buffers
// ---------------------------------------------------------------------------
// Keep scratch above firmware .text/.rodata; RAM5..RAM11 gives 160 KB here.
#define XHEEP_LAYER_LOCAL_BASE_OFFSET RAM5_START_ADDRESS
#define XHEEP_LAYER_LOCAL_END_OFFSET  RAM11_END_ADDRESS

#define XHEEP_LAYER_IN_OFFSET         XHEEP_LAYER_LOCAL_BASE_OFFSET
#define XHEEP_LAYER_OUT_OFFSET        (XHEEP_LAYER_IN_OFFSET + XHEEP_LAYER_IN_BYTES)
#define XHEEP_LAYER_LOCAL_REQUIRED_BYTES (XHEEP_LAYER_IN_BYTES + XHEEP_LAYER_OUT_BYTES)

#if (XHEEP_LAYER_OUT_OFFSET + XHEEP_LAYER_OUT_BYTES) > XHEEP_LAYER_LOCAL_END_OFFSET
#error "Transformer FFT+prelayer scratch buffers exceed local RAM capacity"
#endif

#endif /* __XHEEP_TRANSFORMER_FFT_COMMON_H__ */
