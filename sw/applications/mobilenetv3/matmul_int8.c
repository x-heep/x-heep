// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include "matmul_int8.h"
#include "csr.h"

// MACC instruction for int8 (4 elements packed per word)
#define MACC_INT8(HEAD, __mat1__, __mat2__, __mat3__) \
    "mmaqa.b  m" #__mat1__ ", m" #__mat2__ ", m" #__mat3__

/* ============================================
 *    8x8 MatMul for INT8 (mmaqa.b)
 * ============================================ */

void __attribute__ ((noinline)) matmul_8x8_int8(
    int8_t* addrA,
    int8_t* addrB,
    int32_t* addrC,
    int K,
    int N,
    int M
) {
    asm volatile("addi   sp, sp, -0x30           ");
    asm volatile("sw     s0 , 0x2c(sp)           ");
    asm volatile("sw     s1 , 0x28(sp)           ");
    asm volatile("sw     s2 , 0x24(sp)           ");
    asm volatile("sw     s3 , 0x20(sp)           ");
    asm volatile("sw     s4 , 0x1c(sp)           ");
    asm volatile("sw     s5 , 0x18(sp)           ");
    asm volatile("sw     s6 , 0x14(sp)           ");
    asm volatile("sw     s7 , 0x10(sp)           ");
    asm volatile("sw     s8 , 0x0c(sp)           ");
    asm volatile("sw     s9 , 0x08(sp)           ");
    asm volatile("sw     s10, 0x04(sp)           ");
    asm volatile("sw     s11, 0x00(sp)           ");

    asm volatile("sll     a6,%0,%1              " :: "r" (N),"r" (SIMD_SHIFT));
    asm volatile("addi    t0,x0, 0              ");
    asm volatile("slli    s3,%0, 2              " :: "r" (K));
    asm volatile("slli    s4,%0, 2              " :: "r" (N));

    asm volatile("loopM_start_int8:");
    asm volatile("addi    t1,x0, 0              ");
    asm volatile("addi    t3,t0,4               ");
    asm volatile("mul     s1,s3,t0              ");
    asm volatile("mul     s2,s3,t3              ");
    asm volatile("mul     s0,s4,t0              ");
    asm volatile("mul     s10,s4,t3             ");
    asm volatile("add     s1,%0,s1              " :: "r" (addrA));
    asm volatile("add     s2,%0,s2              " :: "r" (addrA));
    asm volatile("add     s0,%0,s0              " :: "r" (addrC));
    asm volatile("add     s10,%0,s10            " :: "r" (addrC));

    asm volatile("loopN_start_int8:");
    asm volatile("addi    t4,t1,4               ");
    asm volatile("addi    t2,x0,16              ");
    asm volatile("slli    t5,t1, 2              ");
    asm volatile("mld.w   m0, (s1) , s3         ");
    asm volatile("mzero   m4                    ");
    asm volatile("mul     s9,s3,t1              ");
    asm volatile("add     s9 ,%0,s9             " :: "r" (addrB));
    asm volatile("mld.w   m1, (s9) , a6         ");
    asm volatile("mzero   m6                    ");
    asm volatile("mul     s11,s3,t4             ");
    asm volatile(MACC_INT8(4,1,0));
    asm volatile("mld.w   m2, (s2) , s3         ");
    asm volatile("mzero   m5                    ");
    asm volatile("add     s11,%0,s11            " :: "r" (addrB));
    asm volatile(MACC_INT8(6,1,2));
    asm volatile("mld.w   m3, (s11), a6         ");
    asm volatile("mzero   m7                    ");

    asm volatile("loopK_start_int8:");
    asm volatile("add     s6 ,s1 ,t2            ");
    asm volatile(MACC_INT8(5,3,0));
    asm volatile("mld.w   m0, (s6) , s3         ");
    asm volatile("add     s7 ,s9 ,t2            ");
    asm volatile("add     s5 ,s2 ,t2            ");
    asm volatile(MACC_INT8(7,3,2));
    asm volatile("mld.w   m1, (s7) , a6         ");
    asm volatile("add     s8,s11,t2             ");
    asm volatile("addi    t2,t2,16              ");
    asm volatile(MACC_INT8(4,1,0));
    asm volatile("mld.w   m2, (s5) , s3         ");
    asm volatile("mld.w   m3, (s8) , a6         ");
    asm volatile(MACC_INT8(6,1,2));
    asm volatile("blt     t2, s3, loopK_start_int8");

    asm volatile("add     s6,t5,s0              ");
    asm volatile("mst.w   m4, (s6) , s4         ");
    asm volatile(MACC_INT8(5,3,0));
    asm volatile("add     s7,t5,s10             ");
    asm volatile("mst.w   m6, (s7) , s4         ");
    asm volatile(MACC_INT8(7,3,2));
    asm volatile("slli    t6,t4, 2              ");
    asm volatile("add     s5,t6,s0              ");
    asm volatile("mst.w   m5, (s5) , s4         ");
    asm volatile("addi    t1,t1, 8              ");
    asm volatile("add     s8,t6,s10             ");
    asm volatile("mst.w   m7, (s8) , s4         ");
    asm volatile("blt     t1, %0, loopN_start_int8" :: "r" (N));
    
    asm volatile("add     t0,t0, 8              ");
    asm volatile("blt     t0, %0, loopM_start_int8" :: "r" (M));

    asm volatile("lw      s0 , 0x2c(sp)         ");
    asm volatile("lw      s1 , 0x28(sp)         ");
    asm volatile("lw      s2 , 0x24(sp)         ");
    asm volatile("lw      s3 , 0x20(sp)         ");
    asm volatile("lw      s4 , 0x1c(sp)         ");
    asm volatile("lw      s5 , 0x18(sp)         ");
    asm volatile("lw      s6 , 0x14(sp)         ");
    asm volatile("lw      s7 , 0x10(sp)         ");
    asm volatile("lw      s8 , 0x0c(sp)         ");
    asm volatile("lw      s9 , 0x08(sp)         ");
    asm volatile("lw      s10, 0x04(sp)         ");
    asm volatile("lw      s11, 0x00(sp)         ");
    asm volatile("addi    sp, sp, 0x30          ");
}

/* ============================================
 *    Scalar Fallback
 * ============================================ */

void matmul_scalar_int8(
    const int8_t* A,
    const int8_t* B,
    int32_t* C,
    int M, int K, int N
) {
    for (int m = 0; m < M; m++) {
        for (int n = 0; n < N; n++) {
            int32_t acc = 0;
            for (int k = 0; k < K; k++) {
                acc += (int32_t)A[m * K + k] * (int32_t)B[k * N + n];
            }
            C[m * N + n] = acc;
        }
    }
}