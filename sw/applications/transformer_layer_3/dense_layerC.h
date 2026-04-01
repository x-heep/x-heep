//
// Created by alireza on 10/5/23.
//

#ifndef FVLLMONTITRANSFORMER_DENSE_LAYERC_H
#define FVLLMONTITRANSFORMER_DENSE_LAYERC_H


// // #include <stdlib.h>
// #include <stddef.h>
#include "param.h"
#include <math.h>
#if !HAVE_FPU
#include "integer_approx_fpops.h"
#endif

// Define the struct
typedef struct {
    size_t input_size_;
    size_t output_size_;
    int16_t* weight; // quant_bit_width is a typedef for int16_t
    int16_t* bias; // quant_bit_width is a typedef for int16_t
} Dense;

void createDense(Dense* dense, size_t input_dim, size_t output_dim, quant_bit_width *weight, quant_bit_width* bias);
void destroyDense(Dense* dense);
void multiplyweight(Dense* dense, size_t seq_len, int16_t* input, int16_t* output);
void addbias(Dense* dense, size_t seq_len, int16_t* output);
void computeDense(Dense* dense, size_t seq_len, int16_t* input, int16_t* output);
void activation(Dense* dense, size_t length, int16_t* input, int16_t* output);

#endif //FVLLMONTITRANSFORMER_DENSE_LAYERC_H
