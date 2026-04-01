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

typedef int16_t quant_bit_width;

#endif // FVLLMONTITRANSFORMER_PARAM_H
