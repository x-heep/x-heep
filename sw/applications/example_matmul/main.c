// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include <stdio.h>
#include <stdlib.h>
#include "csr.h"
#include "x-heep.h"

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

#if TARGET_SIM && PRINTF_IN_SIM
        #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

#if defined(MATMUL8)
    #define input_type_t int8_t
    #include "matrixMul8.h"
    #define SIZE_BYTE 1
    #pragma message ( "Compiling for 8bit input data" )
#elif defined(MATMUL16)
    #define input_type_t int16_t
    #include "matrixMul16.h"
    #define SIZE_BYTE 2
    #pragma message ( "Compiling for 16bit input data" )
#elif defined(MATMUL32)
    #define input_type_t int32_t
    #include "matrixMul32.h"
    #define SIZE_BYTE 4
    #pragma message ( "Compiling for 32bit input data" )
#else
    #define input_type_t int8_t
    #define SIZE_BYTE 1
    #include "matrixMul8.h"
    #pragma message ( "Compiling for 8bit input data" )
#endif

void __attribute__ ((noinline)) matrixMul_blocksize(input_type_t *  A, input_type_t *  B, int32_t *  C, int N);

void __attribute__ ((noinline)) matrixMul_tiled(input_type_t *  A, input_type_t *  B, int32_t *  C, int N);

uint32_t check_results(int32_t * C, int N);

int32_t m_c[SIZE*SIZE];

#define BLOCK_SIZE 4

// Define a macro for accessing matrix elements
#define A(i,j) &A[i*SIZE+j]
#define B(i,j) &B[i*SIZE+j]
#define C(i,j) &C[i*SIZE+j]

#define HIGHEST_PERF

int main()
{

    uint32_t errors = 0;
    unsigned int instr, cycles;

    for(int i =0;i<SIZE;i++) {
        for(int j =0;j<SIZE;j++) {
            m_c[i*SIZE+j] = 0;
        }
    }

    //enable mcycle csr
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);

    CSR_WRITE(CSR_REG_MCYCLE, 0);

#ifdef HIGHEST_PERF
    #pragma message ( "single block MatMul is compiled" )
    #if defined(__COREV_OPT_ASM) && (defined(MATMUL8) || defined(MATMUL16))
        #pragma message ( "using hand-optimized XCOREV_PULP kernel with transposed matrix B" )
        matrixMul_blocksize(m_a, m_b_t, m_c, SIZE);
    #else
        #if defined(__COREV_OPT_ASM)
            #pragma message ( "using hand-optimized XCOREV_PULP kernel" )
        #else
            #pragma message ( "using standard matmul kernel" )
        #endif
        matrixMul_blocksize(m_a, m_b, m_c, SIZE);
    #endif
#else
    //execute the kernel
    matrixMul_tiled(m_a, m_b, m_c, SIZE);
#endif

    CSR_READ(CSR_REG_MCYCLE, &cycles);

    errors = check_results(m_c, SIZE);

    PRINTF("program finished with %d errors and %d cycles\n\r", errors, cycles);
    return errors;
}

#ifndef __COREV_OPT_ASM
void __attribute__ ((noinline)) matrixMul_blocksize(input_type_t *  A, input_type_t *  B, int32_t *  C, int N)
{

    for(int i = 0; i < N; i++) {
        for(int j = 0; j < N; j++) {
            int32_t acc = 0;
            for(int k = 0; k < N; k++) {
                acc+= A[i*SIZE+k] * B[k*SIZE+j];
            }
            C[i*SIZE+j] += acc;
        }
    }

}
#else
void __attribute__ ((noinline)) matrixMul_blocksize(input_type_t *  A, input_type_t *  B, int32_t *  C, int N)
{

    for(int i = 0; i < N; i++) {
        //if(i==0) printf("A %x\n", &A[i]);
        for(int j = 0; j < N; j++) {
            int32_t acc = 0;
            //if(j==1 || j==0) printf("B %x\n", &B[j]);
#if defined(MATMUL32)
            input_type_t* b_ptr = &B[j];
#else
            input_type_t* b_ptr = &B[j*SIZE]; //because it's transposed
#endif
            input_type_t* a_ptr = &A[i*SIZE];
            int32_t* c_ptr = &C[i*SIZE+j];
            //for(int k = 0; k < N; k+=2) {
                input_type_t a0;
                input_type_t b0;
                input_type_t a1;
                input_type_t b1;
                // a0 = A[i*SIZE+k];
                // b0 = B[k*SIZE+j];
                // a1 = A[i*SIZE+k+1];
                // b1 = B[(k+1)*SIZE+j];
                // acc = __builtin_riscv_cv_mac_mac(a0, b0, acc);
                // acc = __builtin_riscv_cv_mac_mac(a1, b1, acc);
                // Due to the fact that the two MAC above gets scheduled differently,
                // use the assembly below to implement the code above in the best way
#if defined(MATMUL32)
            asm volatile(
            "cv.setup 1,%10,store_mac \n\t" //for(int k = 0; k < N; k+=2) {
                    "lw	%1,4(%5)\n\t"
                    "lw	%2,%7(%6)\n\t"
                    "cv.lw	%3,(%5),8\n\t"
                    "cv.lw	%4,(%6),%8\n\t"
                    "cv.mac  %0, %1, %2\n\t"
                    "cv.mac  %0, %3, %4\n\t"
            "store_mac: sw %0, 0(%9)\n\t"
                    : "+r"(acc), "=&r"(a0), "=&r"(b0), "=&r"(a1), "=&r"(b1), "+r"(a_ptr),"+r"(b_ptr)
                    : "i"(SIZE*SIZE_BYTE) , "i"(2*SIZE*SIZE_BYTE), "r"(c_ptr), "r"(N>>1)
                );
#elif defined(MATMUL16)
            asm volatile(
            "cv.setup 1,%8,store_mac \n\t" //for(int k = 0; k < N; k+=2) {
                    "lw	%1,4(%5)\n\t"
                    "lw	%2,4(%6)\n\t"
                    "cv.lw	%3,(%5),8\n\t"
                    "cv.lw	%4,(%6),8\n\t"
                    "cv.sdotsp.h  %0, %1, %2\n\t"
                    "cv.sdotsp.h  %0, %3, %4\n\t"
            "store_mac: sw %0, 0(%7)\n\t"
                    : "+r"(acc), "=&r"(a0), "=&r"(b0), "=&r"(a1), "=&r"(b1), "+r"(a_ptr),"+r"(b_ptr)
                    : "r"(c_ptr), "r"(N>>2)
                );
#elif defined(MATMUL8)
            asm volatile(
            "cv.setup 1,%8,store_mac \n\t" //for(int k = 0; k < N; k+=2) {
                    "lw	%1,4(%5)\n\t"
                    "lw	%2,4(%6)\n\t"
                    "cv.lw	%3,(%5),8\n\t"
                    "cv.lw	%4,(%6),8\n\t"
                    "cv.sdotsp.b  %0, %1, %2\n\t"
                    "cv.sdotsp.b  %0, %3, %4\n\t"
            "store_mac: sw %0, 0(%7)\n\t"
                    : "+r"(acc), "=&r"(a0), "=&r"(b0), "=&r"(a1), "=&r"(b1), "+r"(a_ptr),"+r"(b_ptr)
                    : "r"(c_ptr), "r"(N>>3)
                );
#endif

            //}
            //C[i*SIZE+j] += acc;
        }
    }
}
#endif

// Define a recursive function that multiplies two matrices using the tiled algorithm
void __attribute__ ((noinline)) matrixMul_tiled(input_type_t* A, input_type_t* B, int32_t* C, int N) {
    // use the elementary function
    if (N == BLOCK_SIZE) {
        matrixMul_blocksize(A, B, C, N);
    }
    //split the matrices into four blocks each
    else {
        N = N >> 1; // Half the size
        // Multiply the blocks and add them to the corresponding blocks of C
        matrixMul_tiled(A(0, 0), B(0, 0), C(0, 0), N); // C_00 += A_00 * B_00
        matrixMul_tiled(A(0, N), B(N, 0), C(0, 0), N); // C_00 += A_01 * B_10
        matrixMul_tiled(A(0, 0), B(0, N), C(0, N), N); // C_01 += A_00 * B_01
        matrixMul_tiled(A(0, N), B(N, N), C(0, N), N); // C_01 += A_01 * B_11
        matrixMul_tiled(A(N, 0), B(0, 0), C(N, 0), N); // C_10 += A_10 * B_00
        matrixMul_tiled(A(N, N), B(N, 0), C(N, 0), N); // C_10 += A_11 * B_10
        matrixMul_tiled(A(N, 0), B(0, N), C(N, N), N); // C_11 += A_10 * B_01
        matrixMul_tiled(A(N, N), B(N, N), C(N, N), N); // C_11 += A_11 * B_11
    }
}


uint32_t check_results(int32_t * C, int N)
{
    // check
    int i, j;
    uint32_t err = 0;

    for(i = 0; i < N; i++) {
        for(j = 0; j < N; j++) {
            if(C[i*N+j] != m_exp[i*N+j]) {
                err++;
                PRINTF("Error at index %d, %d, expected %d, got %d\n\r", i, j, m_exp[i*N+j], C[i*N+j]);
            }
        }
    }

    return err;
}
