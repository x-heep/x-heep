//
// Created by alireza on 10/6/23.
//

#include "addNormC.h"



// Function implementations
AddNormalize createAddNormalize(int seq_len, int input_dim, quant_bit_width *weight, quant_bit_width *bias) {
    AddNormalize addNorm;
    addNorm.seq_len_ = seq_len;
    addNorm.input_dim_ = input_dim;
    addNorm.weight_ = weight;
    addNorm.bias_ = bias;
    // Initialize other fields as needed
    return addNorm;
}




void normalize(AddNormalize *addNorm, quant_bit_width *input, quant_bit_width *input_normalized) {
    for (int i = 0; i < addNorm->seq_len_; i++) {
        quant_bit_width *input_ptr = input + i * (addNorm->input_dim_);
        quant_bit_width *input_normalized_ptr = input_normalized + i * (addNorm->input_dim_);

        int sum = 0;
        for (int j = 0; j < addNorm->input_dim_; j++) {
            sum += *input_ptr;
            input_ptr++;
        }

        input_ptr = input + i * (addNorm->input_dim_);
#if HAVE_FPU
        quant_bit_width mean = (quant_bit_width)((float)sum / (float)addNorm->input_dim_);
#else
        quant_bit_width mean = (quant_bit_width)fxp_div_int_round(sum, addNorm->input_dim_);
#endif

        int64_t variance = 0;
        for (int j = 0; j < addNorm->input_dim_; j++) {
            variance += MUL_HQ((*input_ptr - mean), (*input_ptr - mean));
            input_ptr++;
        }

        // variance = SHIFT(variance);
#if HAVE_FPU
        float variance_float = (float)variance / (float)(addNorm->input_dim_);
        variance_float = variance_float / (float)(1 << NUM_FRACTION_BITS);
        float sd = sqrtf(variance_float);
        float sd_inv = (float)(1 / (sd + 0.00001)); // prevent zero divide!
        quant_bit_width sd_inv_int = (quant_bit_width)(sd_inv * (1 << NUM_FRACTION_BITS));
#else
        int64_t variance_div = fxp_div_int64_round(variance, addNorm->input_dim_);
        int32_t variance_qn = (int32_t)(variance_div >> NUM_FRACTION_BITS);
        int32_t sd_qn = fxp_sqrt_qn(variance_qn);
        int32_t sd_inv_qn = fxp_reciprocal_qn((sd_qn > 0) ? sd_qn : 1);
        quant_bit_width sd_inv_int = (quant_bit_width)sd_inv_qn;
#endif

        input_ptr = input + i * (addNorm->input_dim_);
        input_normalized_ptr = input_normalized + i * (addNorm->input_dim_);

        for (int j = 0; j < addNorm->input_dim_; j++) {
            *input_normalized_ptr = (quant_bit_width)MUL((*input_ptr - mean), sd_inv_int);
            *input_normalized_ptr = (quant_bit_width)(MUL((*input_normalized_ptr), addNorm->weight_[j]) + addNorm->bias_[j]);
            input_ptr++;
            input_normalized_ptr++;
        }
    }
}

void add(quant_bit_width *input, quant_bit_width *to_be_added, int seq_len, int input_dim) {
    int32_t sum;
    for (int i = 0; i < seq_len * input_dim; i++) {
        sum = input[i] + to_be_added[i];
        if ((quant_bit_width)sum != sum) // In case of overflow in 16 bits
            input[i] = (sum > 0) ? INT16_MAX : INT16_MIN;
        else
            input[i] = (quant_bit_width)sum;
    }
}
