//
// Created by alireza on 10/5/23.
//

#ifndef FVLLMONTITRANSFORMER_ADDNORMC_H
#define FVLLMONTITRANSFORMER_ADDNORMC_H


#include <stdint.h>
// #include <stdlib.h>
#include "param.h"
#include <math.h>
#if !HAVE_FPU
#include "integer_approx_fpops.h"
#endif

typedef struct {
    int seq_len_;
    int input_dim_;
    quant_bit_width *weight_;
    quant_bit_width *bias_;
} AddNormalize;


AddNormalize createAddNormalize(int seq_len, int input_dim, quant_bit_width *weight, quant_bit_width *bias);
void normalize(AddNormalize *addNorm, quant_bit_width *input, quant_bit_width *input_normalized);
void add(quant_bit_width *input, quant_bit_width *to_be_added, int seq_len, int input_dim);

#endif //FVLLMONTITRANSFORMER_ADDNORMC_H
