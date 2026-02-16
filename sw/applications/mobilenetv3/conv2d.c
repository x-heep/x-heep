// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include "conv2d.h"
#include "im2col.h"
#include "matmul_int8.h"

/* Workspace buffers */
static int8_t INTERLEAVED_SECTION im2col_buffer[TILE_SIZE_K * TILE_SIZE_N * 64];
static int32_t INTERLEAVED_SECTION output_tile[TILE_SIZE_M * TILE_SIZE_N];

/* ============================================
 *    Tiled Convolution (INT8)
 * ============================================ */

void conv2d_tiled_int8(
    const int8_t* input,
    const int8_t* weights,
    int32_t* output,
    int C_in, int H_in, int W_in,
    int C_out,
    int K,
    int stride,
    int pad
) {
    int H_out = (H_in + 2 * pad - K) / stride + 1;
    int W_out = (W_in + 2 * pad - K) / stride + 1;
    int K_matmul = C_in * K * K;
    int K_padded = pad_k_dimension(K_matmul);
    int K_simd = K_padded / SIMD_FACTOR;
    int N_total = H_out * W_out;
    
    // Perform im2col
    im2col_int8(input, im2col_buffer, C_in, H_in, W_in, K, stride, pad, H_out, W_out);
    
    // Tile over output channels (M)
    for (int oc_tile = 0; oc_tile < C_out; oc_tile += TILE_SIZE_M) {
        int M_tile = (oc_tile + TILE_SIZE_M < C_out) ? TILE_SIZE_M : (C_out - oc_tile);
        int M_padded = ((M_tile + 7) / 8) * 8;
        
        // Tile over spatial (N)
        for (int sp_tile = 0; sp_tile < N_total; sp_tile += TILE_SIZE_N) {
            int N_tile = (sp_tile + TILE_SIZE_N < N_total) ? TILE_SIZE_N : (N_total - sp_tile);
            int N_padded = ((N_tile + 7) / 8) * 8;
            
            const int8_t* weight_ptr = weights + oc_tile * K_padded;
            const int8_t* im2col_ptr = im2col_buffer + sp_tile;
            
            // Zero output tile
            for (int i = 0; i < M_padded * N_padded; i++) {
                output_tile[i] = 0;
            }
            
            if (M_padded >= 8 && N_padded >= 8 && K_simd >= 4) {
                matmul_8x8_int8(
                    (int8_t*)weight_ptr,
                    (int8_t*)im2col_ptr,
                    output_tile,
                    K_simd,
                    N_padded,
                    M_padded
                );
            } else {
                matmul_scalar_int8(weight_ptr, im2col_ptr, output_tile, M_tile, K_matmul, N_tile);
            }
            
            // Copy to output
            for (int m = 0; m < M_tile; m++) {
                for (int n = 0; n < N_tile; n++) {
                    output[(oc_tile + m) * N_total + sp_tile + n] = output_tile[m * N_padded + n];
                }
            }
        }
    }
}

/* ============================================
 *    Pointwise (1x1) Conv
 * ============================================ */

void pointwise_conv2d_int8(
    const int8_t* input,
    const int8_t* weights,
    int32_t* output,
    int C_in, int C_out,
    int H, int W
) {
    int spatial = H * W;
    int C_in_padded = pad_k_dimension(C_in);
    int C_in_simd = C_in_padded / SIMD_FACTOR;
    
    for (int oc_tile = 0; oc_tile < C_out; oc_tile += TILE_SIZE_M) {
        int M_tile = (oc_tile + TILE_SIZE_M < C_out) ? TILE_SIZE_M : (C_out - oc_tile);
        int M_padded = ((M_tile + 7) / 8) * 8;
        
        for (int sp_tile = 0; sp_tile < spatial; sp_tile += TILE_SIZE_N) {
            int N_tile = (sp_tile + TILE_SIZE_N < spatial) ? TILE_SIZE_N : (spatial - sp_tile);
            int N_padded = ((N_tile + 7) / 8) * 8;
            
            if (M_padded >= 8 && N_padded >= 8 && C_in_simd >= 4) {
                matmul_8x8_int8(
                    (int8_t*)(weights + oc_tile * C_in_padded),
                    (int8_t*)(input + sp_tile),
                    output_tile,
                    C_in_simd,
                    N_padded,
                    M_padded
                );
                
                for (int m = 0; m < M_tile; m++) {
                    for (int n = 0; n < N_tile; n++) {
                        output[(oc_tile + m) * spatial + sp_tile + n] = output_tile[m * N_padded + n];
                    }
                }
            } else {
                for (int m = 0; m < M_tile; m++) {
                    for (int n = 0; n < N_tile; n++) {
                        int32_t acc = 0;
                        for (int k = 0; k < C_in; k++) {
                            acc += (int32_t)weights[(oc_tile + m) * C_in_padded + k] * 
                                   (int32_t)input[k * spatial + sp_tile + n];
                        }
                        output[(oc_tile + m) * spatial + sp_tile + n] = acc;
                    }
                }
            }
        }
    }
}

/* ============================================
 *    Depthwise Conv
 * ============================================ */

void depthwise_conv2d_int8(
    const int8_t* input,
    const int8_t* weights,
    int32_t* output,
    int C, int H_in, int W_in,
    int K,
    int stride,
    int pad
) {
    int H_out = (H_in + 2 * pad - K) / stride + 1;
    int W_out = (W_in + 2 * pad - K) / stride + 1;
    
    for (int c = 0; c < C; c++) {
        const int8_t* in_ch = input + c * H_in * W_in;
        const int8_t* w_ch = weights + c * K * K;
        int32_t* out_ch = output + c * H_out * W_out;
        
        for (int oh = 0; oh < H_out; oh++) {
            for (int ow = 0; ow < W_out; ow++) {
                int32_t acc = 0;
                
                for (int kh = 0; kh < K; kh++) {
                    for (int kw = 0; kw < K; kw++) {
                        int ih = oh * stride - pad + kh;
                        int iw = ow * stride - pad + kw;
                        
                        if (ih >= 0 && ih < H_in && iw >= 0 && iw < W_in) {
                            acc += (int32_t)in_ch[ih * W_in + iw] * (int32_t)w_ch[kh * K + kw];
                        }
                    }
                }
                
                out_ch[oh * W_out + ow] = acc;
            }
        }
    }
}