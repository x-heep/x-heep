//
// Created by alireza on 10/6/23.
//

#include "dense_layerC.h"
#include <stdio.h>
#include "matMulC.h"

static inline int32_t wrap_add_i32(int32_t a, int32_t b)
{
    return (int32_t)((uint32_t)a + (uint32_t)b);
}

static inline int32_t wrap_mul_i32(int32_t a, int32_t b)
{
    return (int32_t)((uint32_t)a * (uint32_t)b);
}

static inline int32_t qmul_wrap_i32(int32_t a, int32_t b)
{
    int32_t prod = wrap_mul_i32(a, b);
    return prod >> NUM_FRACTION_BITS;
}

void createDense(Dense *dense, size_t input_dim, size_t output_dim, quant_bit_width *weight, quant_bit_width *bias)
{
    dense->input_size_ = input_dim;
    dense->output_size_ = output_dim;
    dense->weight = weight;
    dense->bias = bias;
}

void destroyDense(Dense *dense)
{
    // Free the memory allocated for the Dense struct
    // free(dense);
}

void multiplyweight(Dense *dense, size_t seq_len, int16_t *input, int16_t *output)
{
    MatMul_multiply(seq_len, input, dense->weight, output, dense->input_size_, dense->output_size_);
}

void addbias(Dense *dense, size_t seq_len, int16_t *output)
{
    for (size_t idx = 0; idx < seq_len; idx++)
    {
        for (size_t feature_idx = 0; feature_idx < dense->output_size_; feature_idx++)
        {
            output[idx * dense->output_size_ + feature_idx] += dense->bias[feature_idx];
        }
    }
}

void computeDense(Dense *dense, size_t seq_len, int16_t *input, int16_t *output)
{
    multiplyweight(dense, seq_len, input, output);
    if (dense->bias != NULL)
    {
        addbias(dense, seq_len, output);
    }
}

void activation(Dense *dense, size_t length, int16_t *input, int16_t *output) // GELU activations
{
    (void)dense;
#if HAVE_FPU
    float in_float, in_tanh;
#endif
    int32_t x3, in_tanh_fxp;
    for (int i = 0; i < length; i++)
    {
        int32_t x = (int32_t)input[i];
        int32_t x2 = qmul_wrap_i32(x, x);
        x3 = qmul_wrap_i32(x2, x);
        x3 = qmul_wrap_i32(x3, 183); // 183 = 0.044715 in fixed-point Q12
        x3 = wrap_add_i32(x3, x);
        x3 = qmul_wrap_i32(x3, 3268); // 3268 = sqrt(2/PI) in fixed-point Q12
#if HAVE_FPU
        in_float = (float)x3 / (float)(1 << NUM_FRACTION_BITS);
        in_tanh = tanhf(in_float);
        in_tanh_fxp = (int16_t)(in_tanh * (1 << NUM_FRACTION_BITS));
#else
        int32_t in_qn = (NUM_FRACTION_BITS == 0) ? x3 : (x3 >> NUM_FRACTION_BITS);
        int32_t in_tanh_qn = fxp_tanh_qn(in_qn);
        in_tanh_fxp = (int16_t)in_tanh_qn;
#endif
        in_tanh_fxp = wrap_add_i32(in_tanh_fxp, (1 << NUM_FRACTION_BITS));
        output[i] = (int16_t)qmul_wrap_i32(in_tanh_fxp, (x >> 1));
    }
}
