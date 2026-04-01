//
// Created by alireza on 10/6/23.
//

#include <stdio.h>
#include "selfattentionC.h"


void create_SingleHeadSelfAttn(SingleHeadSelfAttn* self_attn, size_t pre_seq_len, size_t input_dim, size_t head_hidden_size, int16_t** weightVector) {
    self_attn->pre_seq_len = pre_seq_len;
    self_attn->head_hidden_size = head_hidden_size;
    createDense(self_attn->query_layer, input_dim, head_hidden_size, weightVector[0], NULL);
    createDense(self_attn->key_layer, input_dim, head_hidden_size, weightVector[1], NULL);
    createDense(self_attn->value_layer, input_dim, head_hidden_size, weightVector[2], NULL);
}

void destroy_SingleHeadSelfAttn(SingleHeadSelfAttn* self_attn) {
    // free(self_attn->query_layer_out);
    // free(self_attn->key_layer_out);
    // free(self_attn->key_transposed_layer_out);
    // free(self_attn->value_layer_out);
    // free(self_attn->attention_scores);

    // destroyDense(self_attn->query_layer);
    // destroyDense(self_attn->key_layer);
    // destroyDense(self_attn->value_layer);

    // free(self_attn);
}

void compute_SingleHeadSelfAttn(SingleHeadSelfAttn* self_attn, int16_t* input, int16_t* output, int16_t* qkv, int16_t* intermediate) {
    self_attn->query_layer_out = qkv;
    self_attn->key_layer_out = qkv + self_attn->pre_seq_len * self_attn->head_hidden_size;
    self_attn->value_layer_out = qkv + 2 * self_attn->pre_seq_len * self_attn->head_hidden_size;
    self_attn->key_transposed_layer_out = qkv + 3 * self_attn->pre_seq_len * self_attn->head_hidden_size;

    // printf("Size query %d\n", self_attn->query_layer->input_size_);
    computeDense(self_attn->query_layer, self_attn->pre_seq_len, input, self_attn->query_layer_out);
    computeDense(self_attn->key_layer, self_attn->pre_seq_len, input, self_attn->key_layer_out);
    computeDense(self_attn->value_layer, self_attn->pre_seq_len, input, self_attn->value_layer_out);

    transpose_quant(self_attn->key_layer_out, self_attn->key_transposed_layer_out, self_attn->pre_seq_len, self_attn->head_hidden_size);
    MatMul_scale(self_attn->key_transposed_layer_out, 1, self_attn->pre_seq_len * self_attn->head_hidden_size);

    MatMul_multiply(self_attn->pre_seq_len, self_attn->query_layer_out, self_attn->key_transposed_layer_out, intermediate, self_attn->head_hidden_size, self_attn->pre_seq_len);

    computeSoftmax(intermediate, self_attn->pre_seq_len);
    MatMul_multiply(self_attn->pre_seq_len, intermediate, self_attn->value_layer_out, output, self_attn->pre_seq_len, self_attn->head_hidden_size);
}
