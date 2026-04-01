//
// Created by alireza on 10/6/23.
//

#ifndef FVLLMONTITRANSFORMER_TRANSPOSEC_H
#define FVLLMONTITRANSFORMER_TRANSPOSEC_H



#include <stddef.h>
#include "param.h"

// Replace class with struct
typedef struct {
    // struct members
} Transpose;

// Function prototypes
void transpose_quant(const quant_bit_width* input, quant_bit_width* output, size_t width, size_t height);
void multihead_transpose(const quant_bit_width * input, quant_bit_width* output, size_t seq_len, size_t head_hidden_size, size_t num_head);

#endif //FVLLMONTITRANSFORMER_TRANSPOSEC_H
