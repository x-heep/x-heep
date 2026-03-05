// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "matfloat.h"
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

void __attribute__ ((noinline)) vector_add(float *  A, float *  B, float *  C, int N);
float __attribute__ ((noinline)) dotp(float * A, float * B, int N);
uint32_t check_results(float * computed, float * expected, int N);

float vec_c[SIZE];

static inline int float32_close(float a, float b, float rtol, float atol) {
    float diff = fabsf(a - b);
    float scale = fmaxf(fabsf(a), fabsf(b));
    return diff <= fmaxf(atol, rtol * scale);
}

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

void __attribute__ ((noinline)) print_vector(float *  C, int N)
{
    for(int i = 0; i < N; i++) {
        putfloat(C[i], 2);
        printf("\n");
    }
}

int main()
{

    uint32_t errors = 0;
    unsigned int instr, cycles;

    //enable FP operations
    CSR_SET_BITS(CSR_REG_MSTATUS, (FS_INITIAL << 13));

    //enable mcycle csr
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);

    CSR_WRITE(CSR_REG_MCYCLE, 0);

    //execute the kernel
    vector_add(vec_a, vec_b, vec_c, SIZE);

    CSR_READ(CSR_REG_MCYCLE, &cycles) ;

    //stop the HW counter used for monitoring

    if(check_results(vec_c, vec_sum, SIZE)) return -1;

    //execute the kernel

    if (dotp(vec_a, vec_b, SIZE) != dot_exp) return -2;

#ifdef ENABLE_PRINTF
    print_vector(vec_c,SIZE);
#endif

    return errors;
}

void __attribute__ ((noinline)) vector_add(float *  A, float *  B, float *  C, int N)
{
    for(int i = 0; i < N; i++) {
        C[i] = A[i] + B[i];
    }
}

float __attribute__ ((noinline)) dotp(float *  A, float *  B, int N)
{
    float res = 0.0f;
    for(int i = 0; i < N; i++) {
            res += A[i] * B[i];
    }
    return res;
}

uint32_t check_results(float * computed, float * expected, int N)
{
    // check
    int i, j;
    uint32_t err = 0;

    for(i = 0; i < N; i++) {
        if( fabs(computed[i] - expected[i]) > 0.0001f ) {
            err++;
            PRINTF("Error at index %d, expected %x, got %x\n\r", i, expected[i], computed[i]);
            break;
        }
    }

    return err;
}
