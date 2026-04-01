//
// Copied from soft/common/apps/baremetal/transformer_ESP/param.h
//

#ifndef FVLLMONTITRANSFORMER_PARAM_H
#define FVLLMONTITRANSFORMER_PARAM_H

#include "stdint.h"

#define HAVE_FPU 0
#define HAVE_QUADRILATERO 1

#define D_Q 4
#define D_SEQ 120
#define D_MODEL 16
#define NUM_HEAD 4
#define NUM_LAYERS 4
#define D_FF 4
#define D_EMBEDDING 400

#define NUM_FRACTION_BITS 0
// #define MUL(x, y) (int32_t) (((int32_t)(x) * (int32_t)(y)))
// #define MUL_LONG(x, y) (int64_t) (((int64_t)(x) * (int64_t)(y)))
// #define MUL_HQ(x, y) (int32_t) (((int32_t)(x) * (int32_t)(y)))
#define MUL(x, y) x*y
#define MUL_LONG(x, y) x*y
#define MUL_HQ(x, y) x*y
#define SHIFT(x) ((x) >> NUM_FRACTION_BITS)

#define CONTINUE_RUN 0u
#define USE_P2P 0u
#define CONTINUE_RUN_PROFILE 1u
#define CONTINUE_RUN_CHECK_RESULT 1u
#define CONTINUE_RUN_DEBUG 1u
#if CONTINUE_RUN
#undef USE_P2P
#define USE_P2P 0u
#undef CONTINUE_RUN_PROFILE
#undef CONTINUE_RUN_CHECK_RESULT
#undef CONTINUE_RUN_DEBUG
#define CONTINUE_RUN_PROFILE 0u
#define CONTINUE_RUN_CHECK_RESULT 0u
#define CONTINUE_RUN_DEBUG 0u
#endif

/* Pull-based P2P uses source slot 1 on the consumer side. */
#define XHEEP_LAYER_P2P_SRC_SLOT 1u
#define XHEEP_LAYER_P2P_USER_IN  XHEEP_LAYER_P2P_SRC_SLOT
#define XHEEP_LAYER_P2P_USER_OUT 1u
#define XHEEP_LAYER_MEM_USER_IN  0u
#define XHEEP_LAYER_MEM_USER_OUT 0u

#if USE_P2P
#define XHEEP_LAYER_USE_P2P_IN  1u
#define XHEEP_LAYER_USE_P2P_OUT 1u
#else
#define XHEEP_LAYER_USE_P2P_IN  0u
#define XHEEP_LAYER_USE_P2P_OUT 0u
#endif

typedef int16_t quant_bit_width;

#endif // FVLLMONTITRANSFORMER_PARAM_H
