//
// Quadrilatero-backed matmul helpers for transformer_layer.
// Active only when HAVE_QUADRILATERO == 1.
//

#ifndef FVLLMONTITRANSFORMER_MATMUL_QUADRILATERO_H
#define FVLLMONTITRANSFORMER_MATMUL_QUADRILATERO_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "param.h"

#if HAVE_QUADRILATERO

#define QMATMUL_TILE_MN 8u
#define QMATMUL_SIMD_FACTOR 2u
#define QMATMUL_SIMD_SHIFT 1u

#define QMATMUL_MAX2(_a, _b) ((_a) > (_b) ? (_a) : (_b))
#define QMATMUL_MAX4(_a, _b, _c, _d) QMATMUL_MAX2(QMATMUL_MAX2((_a), (_b)), QMATMUL_MAX2((_c), (_d)))
#define QMATMUL_ALIGN8(_x) (((_x) + 7u) & ~7u)
#define QMATMUL_MAX_K_ELEMS QMATMUL_ALIGN8((size_t)QMATMUL_MAX4((D_SEQ + 1), D_MODEL, D_Q, D_FF))

#if defined(__riscv)
#define QMATMUL_DATA_INTERLEAVED __attribute__((section(".xheep_data_interleaved"), aligned(16)))
#else
#define QMATMUL_DATA_INTERLEAVED __attribute__((aligned(16)))
#endif

static quant_bit_width QMATMUL_DATA_INTERLEAVED qmatmul_a_tile[QMATMUL_TILE_MN * QMATMUL_MAX_K_ELEMS];
static quant_bit_width QMATMUL_DATA_INTERLEAVED qmatmul_bt_tile[QMATMUL_TILE_MN * QMATMUL_MAX_K_ELEMS];
static int32_t QMATMUL_DATA_INTERLEAVED qmatmul_c_tile[QMATMUL_TILE_MN * QMATMUL_TILE_MN];

static inline size_t qmatmul_round_up8(size_t x)
{
    return (x + 7u) & ~7u;
}

static inline void qmatmul_cpu_fallback(size_t seq_len,
                                        const quant_bit_width *input,
                                        const quant_bit_width *weight,
                                        quant_bit_width *output,
                                        size_t input_size,
                                        size_t output_size)
{
    for (size_t length = 0; length < seq_len; ++length) {
        for (size_t out_idx = 0; out_idx < output_size; ++out_idx) {
            const quant_bit_width *weight_ptr = weight + out_idx;
            const quant_bit_width *input_ptr = input + (length * input_size);
            int32_t sum = 0;

            for (size_t i = 0; i < input_size; ++i) {
                sum += MUL_HQ(*weight_ptr, *input_ptr);
                ++input_ptr;
                weight_ptr += output_size;
            }

            output[(length * output_size) + out_idx] = (quant_bit_width)(sum >> NUM_FRACTION_BITS);
        }
    }
}

#define QMATMUL_HEAD_LINE "mmada.h"
#define QMATMUL_MACC(HEAD,__mat1__, __mat2__, __mat3__) HEAD "  m" #__mat1__", m"#__mat2__", m"#__mat3__

// Int16 kernel copied from example_matmul_quadrilatero (8x8 path).
static __attribute__((noinline)) void qmatmul_kernel_8x8_i16(quant_bit_width *addrA,
                                                              quant_bit_width *addrBT,
                                                              int32_t *addrC,
                                                              int K,
                                                              int N,
                                                              int M,
                                                              int shift)
{
    asm volatile("addi	sp, sp, -0x30           "                            );   //
    asm volatile("sw	s0 , 0x2c(sp)           "                            );   //
    asm volatile("sw	s1 , 0x28(sp)           "                            );   //
    asm volatile("sw	s2 , 0x24(sp)           "                            );   //
    asm volatile("sw	s3 , 0x20(sp)           "                            );   //
    asm volatile("sw	s4 , 0x1c(sp)           "                            );   //
    asm volatile("sw	s5 , 0x18(sp)           "                            );   //
    asm volatile("sw	s6 , 0x14(sp)           "                            );   //
    asm volatile("sw	s7 , 0x10(sp)           "                            );   //
    asm volatile("sw	s8 , 0x0c(sp)           "                            );   //
    asm volatile("sw	s9 , 0x08(sp)           "                            );   //
    asm volatile("sw	s10, 0x04(sp)           "                            );   //
    asm volatile("sw	s11, 0x00(sp)           "                            );   //

    asm volatile("sll     a6,%0,%1              " :: "r" (N),"r" (shift)     );   // a6 = N*2**SIMD_SHIFT
    asm volatile("addi    t0,x0, 0              "                            );   // t0 = m0 = 0
    asm volatile("slli    s3,%0, 2              " :: "r" (K)                 );   // s3 = K*4
    asm volatile("slli    s4,%0, 2              " :: "r" (N)                 );   // s4 = N*4

    asm volatile("loopM_start8x8:               "                            );   // while(m0<M) {
    asm volatile("addi    t1,x0, 0              "                            );   // t1 = n0 = 0
    asm volatile("addi    t3,t0,4               "                            );   // t3 = m0+WIDTH
    asm volatile("mul     s1,s3,t0              "                            );   // s1 = K*4*m0
    asm volatile("mul     s2,s3,t3              "                            );   // s2 = K*4*(m0+WIDTH)
    asm volatile("mul     s0,s4,t0              "                            );   // s0 = N*4*m0
    asm volatile("mul     s10,s4,t3             "                            );   // s10 = N*4*(m0+WIDTH)
    asm volatile("add     s1,%0,s1              " :: "r" (addrA)             );   // s1 = startAddrA0
    asm volatile("add     s2,%0,s2              " :: "r" (addrA)             );   // s2 = startAddrA1
    asm volatile("add     s0,%0,s0              " :: "r" (addrC)             );   // s0 = startAddrC0x
    asm volatile("add     s10,%0,s10            " :: "r" (addrC)             );   // s10 = startAddrC1x

    asm volatile("loopN_start8x8:               "                            );   // while(n0<N) {
    asm volatile("addi    t4,t1,4               "                            );   // t4 = n0+WIDTH
    asm volatile("addi    t2,x0,16              "                            );   // t2 = k0 = 16
    asm volatile("slli    t5,t1, 2              "                            );   // t5 = n0*4
    asm volatile("mld.w   m0, (s1) , s3         "                            );   // m0 = A[s1]
    asm volatile("mzero   m4                    "                            );   // m4 = 0
    asm volatile("mul     s9,s3,t1              "                            );   // s9 = K*4*n0
    asm volatile("add     s9 ,%0,s9             " :: "r" (addrBT)            );   // s9 = startAddrB0
    asm volatile("mld.w   m1, (s9) , a6         "                            );   // m1 = B[s9]
    asm volatile("mzero   m6                    "                            );   // m6 = 0
    asm volatile("mul     s11,s3,t4             "                            );   // s11 = K*4*(n0+WIDTH)
    asm volatile(QMATMUL_MACC(QMATMUL_HEAD_LINE,4,1,0)                        );   // m4 += m1 * m0
    asm volatile("mld.w   m2, (s2) , s3         "                            );   // m2 = A[s2]
    asm volatile("mzero   m5                    "                            );   // m5 = 0
    asm volatile("add     s11,%0,s11            " :: "r" (addrBT)            );   // s11 = startAddrB1
    asm volatile(QMATMUL_MACC(QMATMUL_HEAD_LINE,6,1,2)                        );   // m6 += m1 * m2
    asm volatile("mld.w   m3, (s11), a6         "                            );   // m3 = B[s11]
    asm volatile("mzero   m7                    "                            );   // m7 = 0
    asm volatile("bge     t2, s3, loopK_end8x8 "                            );   // if K*4 <= 16, skip loopK body

    asm volatile("loopK_start8x8:               "                            );   // while(k0*4<K*4) {
    asm volatile("add     s6 ,s1 ,t2            "                            );   // s6 = startAddrA0 + k0*4
    asm volatile(QMATMUL_MACC(QMATMUL_HEAD_LINE,5,3,0)                        );   // m5 += m3 * m0
    asm volatile("mld.w   m0, (s6) , s3         "                            );   // m0 = A[s6]
    asm volatile("add     s7 ,s9 ,t2            "                            );   // s7 = startAddrB0 + k0*4
    asm volatile("add     s5 ,s2 ,t2            "                            );   // s5 = startAddrA1 + k0*4
    asm volatile(QMATMUL_MACC(QMATMUL_HEAD_LINE,7,3,2)                        );   // m7 += m3 * m2
    asm volatile("mld.w   m1, (s7) , a6         "                            );   // m1 = B[s7]
    asm volatile("add     s8,s11,t2             "                            );   // s8 = startAddrB1 + k0*4
    asm volatile("addi    t2,t2,16              "                            );   // t2 += 16
    asm volatile(QMATMUL_MACC(QMATMUL_HEAD_LINE,4,1,0)                        );   // m4 += m1 * m0
    asm volatile("mld.w   m2, (s5) , s3         "                            );   // m2 = A[s5]
    asm volatile("mld.w   m3, (s8) , a6         "                            );   // m3 = B[s8]
    asm volatile(QMATMUL_MACC(QMATMUL_HEAD_LINE,6,1,2)                        );   // m6 += m1 * m2
    asm volatile("blt     t2, s3, loopK_start8x8"                            );   // endwhile

    asm volatile("loopK_end8x8:                 "                            );
    asm volatile("add     s6,t5,s0              "                            );   // s6 = startAddrC00 + n0*4
    asm volatile("mst.w   m4, (s6) , s4         "                            );   // store m4
    asm volatile(QMATMUL_MACC(QMATMUL_HEAD_LINE,5,3,0)                        );   // m5 += m3 * m0
    asm volatile("add     s7,t5,s10             "                            );   // s7 = startAddrC10 + n0*4
    asm volatile("mst.w   m6, (s7) , s4         "                            );   // store m6
    asm volatile(QMATMUL_MACC(QMATMUL_HEAD_LINE,7,3,2)                        );   // m7 += m3 * m2
    asm volatile("slli    t6,t4, 2              "                            );   // t6 = (n0+WIDTH)*4
    asm volatile("add     s5,t6,s0              "                            );   // s5 = startAddrC01 + ...
    asm volatile("mst.w   m5, (s5) , s4         "                            );   // store m5
    asm volatile("addi    t1,t1, 8              "                            );   // t1 += 8
    asm volatile("add     s8,t6,s10             "                            );   // s8 = startAddrC11 + ...
    asm volatile("mst.w   m7, (s8) , s4         "                            );   // store m7
    asm volatile("blt     t1, %0, loopN_start8x8" :: "r" (N)                 );   // endwhile

    asm volatile("add     t0,t0, 8              "                            );   // t0 += 8
    asm volatile("blt     t0, %0, loopM_start8x8" :: "r" (M)                 );   // endwhile

    asm volatile("lw	s0 , 0x2c(sp)           "                            );   //
    asm volatile("lw	s1 , 0x28(sp)           "                            );   //
    asm volatile("lw	s2 , 0x24(sp)           "                            );   //
    asm volatile("lw	s3 , 0x20(sp)           "                            );   //
    asm volatile("lw	s4 , 0x1c(sp)           "                            );   //
    asm volatile("lw	s5 , 0x18(sp)           "                            );   //
    asm volatile("lw	s6 , 0x14(sp)           "                            );   //
    asm volatile("lw	s7 , 0x10(sp)           "                            );   //
    asm volatile("lw	s8 , 0x0c(sp)           "                            );   //
    asm volatile("lw	s9 , 0x08(sp)           "                            );   //
    asm volatile("lw	s10, 0x04(sp)           "                            );   //
    asm volatile("lw	s11, 0x00(sp)           "                            );   //
    asm volatile("addi	sp, sp, 0x30            "                            );   //
}

static inline void qmatmul_base_tile(const quant_bit_width *A,
                                     size_t lda,
                                     const quant_bit_width *B,
                                     size_t ldb,
                                     quant_bit_width *C,
                                     size_t ldc,
                                     size_t m_rows,
                                     size_t k_cols,
                                     size_t n_cols)
{
    int32_t c_acc[QMATMUL_TILE_MN * QMATMUL_TILE_MN];
    memset(c_acc, 0, sizeof(c_acc));

    // Keep kernel usage aligned with example assumptions by using K=8 chunks.
    for (size_t k0 = 0; k0 < k_cols; k0 += QMATMUL_TILE_MN) {
        size_t k_chunk = k_cols - k0;
        if (k_chunk > QMATMUL_TILE_MN) {
            k_chunk = QMATMUL_TILE_MN;
        }

        memset(qmatmul_a_tile, 0, QMATMUL_TILE_MN * QMATMUL_TILE_MN * sizeof(qmatmul_a_tile[0]));
        memset(qmatmul_bt_tile, 0, QMATMUL_TILE_MN * QMATMUL_TILE_MN * sizeof(qmatmul_bt_tile[0]));
        memset(qmatmul_c_tile, 0, sizeof(qmatmul_c_tile));

        for (size_t i = 0; i < m_rows; ++i) {
            quant_bit_width *dst = qmatmul_a_tile + i * QMATMUL_TILE_MN;
            for (size_t kk = 0; kk < k_chunk; ++kk) {
                dst[kk] = A[i * lda + (k0 + kk)];
            }
        }

        for (size_t j = 0; j < n_cols; ++j) {
            quant_bit_width *dst = qmatmul_bt_tile + j * QMATMUL_TILE_MN;
            for (size_t kk = 0; kk < k_chunk; ++kk) {
                dst[kk] = B[(k0 + kk) * ldb + j];
            }
        }

        qmatmul_kernel_8x8_i16(qmatmul_a_tile, qmatmul_bt_tile, qmatmul_c_tile,
                               (int)(QMATMUL_TILE_MN / QMATMUL_SIMD_FACTOR),
                               (int)QMATMUL_TILE_MN, (int)QMATMUL_TILE_MN,
                               (int)QMATMUL_SIMD_SHIFT);

        for (size_t idx = 0; idx < (QMATMUL_TILE_MN * QMATMUL_TILE_MN); ++idx) {
            c_acc[idx] = (int32_t)((uint32_t)c_acc[idx] + (uint32_t)qmatmul_c_tile[idx]);
        }
    }

    for (size_t i = 0; i < m_rows; ++i) {
        for (size_t j = 0; j < n_cols; ++j) {
            int32_t acc = c_acc[i * QMATMUL_TILE_MN + j];
            C[i * ldc + j] = (quant_bit_width)(acc >> NUM_FRACTION_BITS);
        }
    }
}

// Recursive tiling skeleton adapted from example_matmul/matrixMul_tiled.
static inline void qmatmul_recursive(const quant_bit_width *A,
                                     size_t lda,
                                     const quant_bit_width *B,
                                     size_t ldb,
                                     quant_bit_width *C,
                                     size_t ldc,
                                     size_t m_rows,
                                     size_t k_cols,
                                     size_t n_cols)
{
    if (m_rows <= QMATMUL_TILE_MN && n_cols <= QMATMUL_TILE_MN) {
        qmatmul_base_tile(A, lda, B, ldb, C, ldc, m_rows, k_cols, n_cols);
        return;
    }

    if (m_rows >= n_cols && m_rows > QMATMUL_TILE_MN) {
        size_t m0 = m_rows >> 1;
        qmatmul_recursive(A, lda, B, ldb, C, ldc, m0, k_cols, n_cols);
        qmatmul_recursive(A + m0 * lda, lda, B, ldb,
                          C + m0 * ldc, ldc, m_rows - m0, k_cols, n_cols);
    } else {
        size_t n0 = n_cols >> 1;
        qmatmul_recursive(A, lda, B, ldb, C, ldc, m_rows, k_cols, n0);
        qmatmul_recursive(A, lda, B + n0, ldb,
                          C + n0, ldc, m_rows, k_cols, n_cols - n0);
    }
}

static inline void MatMul_multiply_quadrilatero(size_t seq_len,
                                                const quant_bit_width *input,
                                                const quant_bit_width *weight,
                                                quant_bit_width *output,
                                                size_t input_size,
                                                size_t output_size)
{
    if (seq_len == 0 || input_size == 0 || output_size == 0) return;
    if (input_size > QMATMUL_MAX_K_ELEMS) {
        qmatmul_cpu_fallback(seq_len, input, weight, output, input_size, output_size);
        return;
    }

    qmatmul_recursive(input, input_size,
                      weight, output_size,
                      output, output_size,
                      seq_len, input_size, output_size);
}

#endif // HAVE_QUADRILATERO

#endif // FVLLMONTITRANSFORMER_MATMUL_QUADRILATERO_H
