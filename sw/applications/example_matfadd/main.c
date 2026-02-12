// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "matrixAdd32.h"
#include "csr.h"
#include "x-heep.h"

#define FS_INITIAL 0x01

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

void __attribute__ ((noinline)) matrixAdd(float * A, float * B, float * C, int N, int M);
uint32_t check_results(float *  C, int N, int M);

float m_c[HEIGHT*WIDTH];

void putlong(long i)
{
    char int_str[20]; // An array to store the digits
    int len = 0; // The length of the string
    do
    {
        // Get the last digit and store it in the array
        int_str[len] = '0' + i % 10;
        len++;
        // Remove the last digit from i
        i /= 10;
    } while (i > 0);

    // Print the  reversed string of digits
    for (int j = len - 1; j >= 0; j--)
    {
        putchar(int_str[j]);
    }
}

// A function to print a floating point number using putchar
void putfloat(float x, int p)
{
    // Check if x is negative
    if (x < 0)
    {
        // Print a minus sign
        putchar('-');
        // Make x positive
        x = -x;
    }

    float f = x - (long)x; // Get the fractional part of x

    // Get the p most significant digits of the fractional part as the
    // integer part of f.
    // Count the number of initial zeros.
    int initial_zeros = 0;
    // Check if the fraction will overflow to the integer part when
    // rounding up (i.e. if the fraction is 0.999...)
    int fraction_overflow = 1;
    for (int j = 0; j < p; j++)
    {
        f *= 10;
        if (f < 1)
        {
            // exclude the last digit with round up
            if (!(j == p - 1 && f >= 0.5f))
                initial_zeros++;
        }
        if (fraction_overflow && (long)f % 10 < 9)
        {
            fraction_overflow = 0;
        }
    }

    // Round up if necessary
    if ((f - (long)f) >= 0.5f)
    {
        // If the rounding causes a digit to overflow in the fractional
        // part, then we need to print one less zero
        if (fraction_overflow == 0)
        {
            f += 1;
            if (f >= 10 && initial_zeros > 0)
            {
                initial_zeros--;
            }
        }
        // If the overflow is in the integer part, then we need to print
        // one more digit in the integer part, and none in the fractional
        else
        {
            f = 0;
            x += 1;
            initial_zeros = p - 1;
        }
    }

    // Convert the integer part of x into a string of digits
    putlong((long)x);

    // Print a decimal point
    putchar('.');

    // Print the initial zeros
    while (initial_zeros--)
    {
        putchar('0');
    }

    // Convert the fractional part of x into a string of digits
    if (f > 1)
        putlong((long)f);
}

void __attribute__ ((noinline)) printMatrix(float *  C, int N, int M)
{
    for(int i = 0; i < N; i++) {
        for(int j = 0; j < M; j++) {
            putfloat(C[i*N+j], 2);
            if( j != M -1)
                printf(", ");
        }
        printf("\n");
    }
}

int main()
{
    int N = WIDTH;
    int M = HEIGHT;
    uint32_t errors = 0;
    unsigned int instr, cycles;

    //enable FP operations
    CSR_SET_BITS(CSR_REG_MSTATUS, (FS_INITIAL << 13));

    //enable mcycle csr
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);

    CSR_WRITE(CSR_REG_MCYCLE, 0);

    //execute the kernel
    matrixAdd(m_a, m_b, m_c, N, M);

    CSR_READ(CSR_REG_MCYCLE, &cycles) ;

    //stop the HW counter used for monitoring

    errors = check_results(m_c, N, M);

    PRINTF("program finished with %d errors and %d cycles\n\r", errors, cycles);

#ifdef ENABLE_PRINTF
    printMatrix(m_c,N,M);
#endif


    return errors;
}

void __attribute__ ((noinline)) matrixAdd(float *  A, float *  B, float *  C, int N, int M)
{
    for(int i = 0; i < N; i++) {
        for(int j = 0; j < M; j++) {
            C[i*N+j] = A[i*WIDTH+j] + B[i*WIDTH+j];
        }
    }
}

uint32_t check_results(float * C, int N, int M)
{
    // check
    int i, j;
    uint32_t err = 0;

    for(i = 0; i < N; i++) {
        for(j = 0; j < M; j++) {
            if(C[i*N+j] != m_exp[i*WIDTH+j]) {
                err++;
                PRINTF("Error at index %d, %d, expected %d, got %d\n\r", i, j, m_exp[i*WIDTH+j], C[i*N+j]);
            }
        }
    }

    return err;
}
