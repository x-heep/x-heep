// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include "im2col.h"
#include "dma.h"

// Use DMA-accelerated im2col for int8 data
// Adapts the pattern from example_im2col

void im2col_int8_dma(
    const int8_t* input,
    int8_t* col_buffer,
    int C_in,
    int H_in, int W_in,
    int K,
    int stride,
    int pad,
    int H_out, int W_out
) {
    int FW = K;
    int FH = K;
    int CH_COL = C_in * FH * FW;
    
    dma_init(NULL);
    
    static dma_target_t tgt_src = {
        .inc_d1_du = 1,  // Will be set to stride
        .type = DMA_DATA_TYPE_BYTE  // int8
    };
    
    static dma_target_t tgt_dst = {
        .inc_d1_du = 1,
        .inc_d2_du = 1,
        .type = DMA_DATA_TYPE_BYTE
    };
    
    static dma_trans_t trans = {
        .src = &tgt_src,
        .dst = &tgt_dst,
        .mode = DMA_TRANS_MODE_SINGLE,
        .dim = DMA_DIM_CONF_2D,
        .end = DMA_TRANS_END_INTR,
        .channel = 0
    };
    
    int8_t* output_ptr = col_buffer;
    
    int w_offset = 0;
    int h_offset = 0;
    int im_c = 0;
    int w_offset_counter = 0;
    int h_offset_counter = 0;
    int im_c_counter = 0;
    
    for (int c = 0; c < CH_COL; c++) {
        // Compute padding regions
        int n_zeros_left = (w_offset >= pad) ? 0 : 1 + (pad - w_offset - 1) / stride;
        int n_zeros_top = (h_offset >= pad) ? 0 : 1 + (pad - h_offset - 1) / stride;
        
        int last_patch_w = (W_out - 1) * stride + w_offset - (W_in - 1 + pad);
        int last_patch_h = (H_out - 1) * stride + h_offset - (H_in - 1 + pad);
        
        int n_zeros_right = (last_patch_w + w_offset + 1 <= 0) ? 0 : 1 + (last_patch_w + w_offset) / stride;
        int n_zeros_bottom = (last_patch_h + h_offset + 1 <= 0) ? 0 : 1 + (last_patch_h + h_offset) / stride;
        
        int size_transfer = W_out - n_zeros_left - n_zeros_right;
        int size_transfer_d2 = H_out - n_zeros_top - n_zeros_bottom;
        
        // Compute source index
        int im_row = h_offset - pad + n_zeros_top * stride;
        int im_col = w_offset - pad + n_zeros_left * stride;
        int src_index = im_c * H_in * W_in + im_row * W_in + im_col;
        
        int src_inc_d2 = stride * W_in - (size_transfer - 1) * stride;
        
        // Configure DMA
        tgt_src.ptr = (uint8_t*)(input + src_index);
        tgt_src.inc_d1_du = stride;
        tgt_src.inc_d2_du = src_inc_d2;
        
        tgt_dst.ptr = (uint8_t*)output_ptr;
        
        trans.size_d1_du = size_transfer;
        trans.size_d2_du = size_transfer_d2;
        trans.pad_top_du = n_zeros_top;
        trans.pad_left_du = n_zeros_left;
        trans.pad_right_du = n_zeros_right;
        trans.pad_bottom_du = n_zeros_bottom;
        
        // Run DMA transfer
        dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
        dma_load_transaction(&trans);
        dma_launch(&trans);
        
        while (!dma_is_ready(0)) {
            CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
            if (!dma_is_ready(0)) {
                asm volatile("wfi");
            }
            CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
        }
        
        output_ptr += W_out * H_out;
        
        // Update counters (avoid modulo)
        if (w_offset == FW - 1) {
            w_offset = 0;
        } else {
            w_offset++;
        }
        
        if (h_offset_counter == FW - 1) {
            h_offset_counter = 0;
            if (h_offset == FH - 1) {
                h_offset = 0;
            } else {
                h_offset++;
            }
        } else {
            h_offset_counter++;
        }
        
        if (im_c_counter == FH * FW - 1) {
            im_c_counter = 0;
            im_c++;
        } else {
            im_c_counter++;
        }
    }
}

// Simple CPU fallback (keep for debugging/comparison)
void im2col_int8_cpu(
    const int8_t* input,
    int8_t* col_buffer,
    int C_in,
    int H_in, int W_in,
    int K,
    int stride,
    int pad,
    int H_out, int W_out
) {
    int N_total = H_out * W_out;
    
    for (int oh = 0; oh < H_out; oh++) {
        for (int ow = 0; ow < W_out; ow++) {
            int col_idx = oh * W_out + ow;
            int row = 0;
            
            for (int c = 0; c < C_in; c++) {
                for (int kh = 0; kh < K; kh++) {
                    for (int kw = 0; kw < K; kw++) {
                        int ih = oh * stride - pad + kh;
                        int iw = ow * stride - pad + kw;
                        
                        int8_t val = 0;
                        if (ih >= 0 && ih < H_in && iw >= 0 && iw < W_in) {
                            val = input[c * H_in * W_in + ih * W_in + iw];
                        }
                        
                        col_buffer[row * N_total + col_idx] = val;
                        row++;
                    }
                }
            }
        }
    }
}