//
// Created by alireza on 10/6/23.
//

#include "matMulC.h"

#if HAVE_QUADRILATERO
#include "matmul_quadrilatero.h"
#endif

void MatMul_multiply(size_t seq_len, quant_bit_width* input, quant_bit_width* weight,
                     quant_bit_width* output, size_t input_size, size_t output_size) {
#if HAVE_QUADRILATERO
    MatMul_multiply_quadrilatero(seq_len, input, weight, output, input_size, output_size);
#else
    for (size_t length = 0; length < seq_len; length++) {
        for (size_t out_idx = 0; out_idx < output_size; out_idx++) {

            quant_bit_width* weight_ptr = weight + out_idx;
            quant_bit_width* output_ptr = output + (length * output_size) + out_idx;
            quant_bit_width* input_ptr = input + (length * input_size);

            int32_t sum = 0;

            for (size_t i = 0; i < input_size; i++) {
                sum += MUL_HQ(*weight_ptr, *input_ptr); // MUL_HQ macro
                input_ptr++;
                weight_ptr += output_size;
            }

            *output_ptr = (quant_bit_width)(sum >> NUM_FRACTION_BITS); // NUM_FRACTION_BITS macro
        }
    }
#endif
}

void MatMul_scale(quant_bit_width* input, int shift_scale, size_t mat_size) {

    for (size_t i = 0; i < mat_size; i++) {
        *input = (*input) >> shift_scale;
        input++;
    }
}
