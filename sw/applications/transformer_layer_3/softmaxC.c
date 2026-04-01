//
// Created by alireza on 10/6/23.
//

#include "softmaxC.h"


void computeSoftmax(int16_t* input, size_t seq_len) {
    size_t width = seq_len;
#if HAVE_FPU
    float input_float = 0.0f;
    for (int i = 0; i < seq_len; i++) {
        int16_t max_val = input[i * seq_len];
        for (int j = 1; j < width; j++) {
            if (input[i * seq_len + j] > max_val) {
                max_val = input[i * seq_len + j];
            }
        }
        for (int j = 0; j < width; j++) {
            input[i * seq_len + j] = (int16_t) fmax(input[i * seq_len + j] - max_val, -32767);
        }
        int32_t sum = 0;
        for (int j = 0; j < width; j++) {
            input_float = (float) input[i * seq_len + j] / (float) (1 << NUM_FRACTION_BITS);
            input_float = expf(input_float);
            input[i * seq_len + j] = (int16_t) (input_float * (1 << NUM_FRACTION_BITS));
            sum += input[i * seq_len + j];
        }
        float sum_float = (float) sum / (float) (1 << NUM_FRACTION_BITS);
        float sum_inv = (float) (1 / (sum_float + 0.00001)); // prevent zero divide!
        int16_t sum_inv_int = (int16_t) (sum_inv * (1 << NUM_FRACTION_BITS));
        for (int j = 0; j < width; j++) {
            input[i * seq_len + j] = (int16_t) MUL(input[i * seq_len + j], sum_inv_int);
        }
    }
#else
    for (int i = 0; i < seq_len; i++) {
        int16_t max_val = input[i * seq_len];
        for (int j = 1; j < width; j++) {
            if (input[i * seq_len + j] > max_val) {
                max_val = input[i * seq_len + j];
            }
        }
        for (int j = 0; j < width; j++) {
            int16_t v = (int16_t)((int32_t)input[i * seq_len + j] - (int32_t)max_val);
            input[i * seq_len + j] = fxp_max_i16(v, (int16_t)-32767);
        }
        int32_t sum = 0;
        for (int j = 0; j < width; j++) {
            int32_t exp_qn = fxp_exp_qn((int32_t)input[i * seq_len + j]);
            input[i * seq_len + j] = (int16_t)exp_qn;
            sum += input[i * seq_len + j];
        }
        int32_t sum_inv_qn = fxp_reciprocal_qn((sum > 0) ? sum : 1);
        int16_t sum_inv_int = (int16_t)sum_inv_qn;
        for (int j = 0; j < width; j++) {
            input[i * seq_len + j] = (int16_t)MUL(input[i * seq_len + j], sum_inv_int);
        }
    }
#endif
}
