#include "activations.h"
#include "csr.h"

/* ============================================
 *    Type Conversion
 * ============================================ */

void int32_to_fp32_scaled(const int32_t* input, float* output, int size, float scale) {
    CSR_SET_BITS(CSR_REG_MSTATUS, (0x1 << 13));
    
    for (int i = 0; i < size; i++) {
        output[i] = (float)input[i] * scale;
    }
}

void fp32_to_int8_quantize(const float* input, int8_t* output, int size, float scale, int8_t zero_point) {
    CSR_SET_BITS(CSR_REG_MSTATUS, (0x1 << 13));
    
    for (int i = 0; i < size; i++) {
        float scaled = input[i] / scale + (float)zero_point;
        int32_t val = (int32_t)(scaled + 0.5f);
        if (val < -128) val = -128;
        if (val > 127) val = 127;
        output[i] = (int8_t)val;
    }
}

/* ============================================
 *    Activation Functions
 * ============================================ */

void relu_fp32(float* data, int size) {
    CSR_SET_BITS(CSR_REG_MSTATUS, (0x1 << 13));
    
    for (int i = 0; i < size; i++) {
        if (data[i] < 0.0f) data[i] = 0.0f;
    }
}

void relu6_fp32(float* data, int size) {
    CSR_SET_BITS(CSR_REG_MSTATUS, (0x1 << 13));
    
    for (int i = 0; i < size; i++) {
        if (data[i] < 0.0f) data[i] = 0.0f;
        else if (data[i] > 6.0f) data[i] = 6.0f;
    }
}

void hard_sigmoid_fp32(float* data, int size) {
    CSR_SET_BITS(CSR_REG_MSTATUS, (0x1 << 13));
    
    for (int i = 0; i < size; i++) {
        float x = (data[i] + 3.0f) / 6.0f;
        if (x < 0.0f) x = 0.0f;
        if (x > 1.0f) x = 1.0f;
        data[i] = x;
    }
}

void hard_swish_fp32(float* data, int size) {
    CSR_SET_BITS(CSR_REG_MSTATUS, (0x1 << 13));
    
    for (int i = 0; i < size; i++) {
        float x = data[i];
        float hs = (x + 3.0f) / 6.0f;
        if (hs < 0.0f) hs = 0.0f;
        if (hs > 1.0f) hs = 1.0f;
        data[i] = x * hs;
    }
}

/* ============================================
 *    Batch Normalization
 * ============================================ */

void batchnorm_fp32(float* data, const float* gamma, const float* beta,
                    const float* mean, const float* var, int C, int H, int W) {
    CSR_SET_BITS(CSR_REG_MSTATUS, (0x1 << 13));
    
    for (int c = 0; c < C; c++) {
        float g = gamma[c];
        float b = beta[c];
        float m = mean[c];
        float v = var[c];  // Precomputed: 1/sqrt(var + eps)
        
        float* channel = data + c * H * W;
        
        for (int i = 0; i < H * W; i++) {
            channel[i] = (channel[i] - m) * v * g + b;
        }
    }
}

/* ============================================
 *    SE Block Operations
 * ============================================ */

void global_avg_pool_fp32(const float* input, float* output, int C, int H, int W) {
    CSR_SET_BITS(CSR_REG_MSTATUS, (0x1 << 13));
    
    float inv_hw = 1.0f / (float)(H * W);
    
    for (int c = 0; c < C; c++) {
        float sum = 0.0f;
        const float* channel = input + c * H * W;
        
        for (int i = 0; i < H * W; i++) {
            sum += channel[i];
        }
        
        output[c] = sum * inv_hw;
    }
}

void channel_multiply_fp32(float* data, const float* scales, int C, int H, int W) {
    CSR_SET_BITS(CSR_REG_MSTATUS, (0x1 << 13));
    
    for (int c = 0; c < C; c++) {
        float scale = scales[c];
        float* channel = data + c * H * W;
        
        for (int i = 0; i < H * W; i++) {
            channel[i] *= scale;
        }
    }
}