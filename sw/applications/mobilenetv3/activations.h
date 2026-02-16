#ifndef _ACTIVATIONS_H_
#define _ACTIVATIONS_H_

#include <stdint.h>
#include "mobilenet_config.h"

/* ============================================
 *    FP32 Activation Functions
 * ============================================ */

// Type conversion
void int32_to_fp32_scaled(const int32_t* input, float* output, int size, float scale);
void fp32_to_int8_quantize(const float* input, int8_t* output, int size, float scale, int8_t zero_point);

// Activations
void relu_fp32(float* data, int size);
void relu6_fp32(float* data, int size);
void hard_sigmoid_fp32(float* data, int size);
void hard_swish_fp32(float* data, int size);

// Batch normalization
void batchnorm_fp32(float* data, const float* gamma, const float* beta,
                    const float* mean, const float* var, int C, int H, int W);

// SE block operations
void global_avg_pool_fp32(const float* input, float* output, int C, int H, int W);
void channel_multiply_fp32(float* data, const float* scales, int C, int H, int W);

#endif /* _ACTIVATIONS_H_ */