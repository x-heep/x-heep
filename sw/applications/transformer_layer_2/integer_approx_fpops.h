#ifndef INTEGER_APPROX_FPOPS_H
#define INTEGER_APPROX_FPOPS_H

#include <stdint.h>
#include <limits.h>

#include "param.h"

// Fixed-point helpers (QNUM_FRACTION_BITS)
static inline int16_t fxp_clamp_i16(int32_t v)
{
    if (v > INT16_MAX) return INT16_MAX;
    if (v < INT16_MIN) return INT16_MIN;
    return (int16_t)v;
}

static inline int16_t fxp_max_i16(int16_t a, int16_t b)
{
    return (a > b) ? a : b;
}

static inline int32_t fxp_abs_i32(int32_t v)
{
    return (v < 0) ? -v : v;
}

static inline int32_t fxp_div_int_round(int32_t num, int32_t den)
{
    if (den == 0) return 0;
    if (num >= 0) return (num + (den / 2)) / den;
    return (num - (den / 2)) / den;
}

static inline int64_t fxp_div_int64_round(int64_t num, int32_t den)
{
    if (den == 0) return 0;
    if (num >= 0) return (num + (den / 2)) / den;
    return (num - (den / 2)) / den;
}

static inline uint32_t fxp_isqrt_u64(uint64_t x)
{
    uint64_t op = x;
    uint64_t res = 0;
    uint64_t one = (uint64_t)1 << 62;
    while (one > op) {
        one >>= 2;
    }
    while (one != 0) {
        if (op >= res + one) {
            op -= res + one;
            res = (res >> 1) + one;
        } else {
            res >>= 1;
        }
        one >>= 2;
    }
    return (uint32_t)res;
}

static inline int32_t fxp_sqrt_qn(int32_t x_qn)
{
    if (x_qn <= 0) return 0;
    uint64_t scaled = ((uint64_t)x_qn) << NUM_FRACTION_BITS;
    return (int32_t)fxp_isqrt_u64(scaled);
}

static inline int32_t fxp_reciprocal_qn(int32_t x_qn)
{
    if (x_qn <= 0) return INT32_MAX;
    int64_t one_qn = (int64_t)1 << NUM_FRACTION_BITS;
    int64_t res = (one_qn * one_qn) / x_qn;
    if (res > INT32_MAX) return INT32_MAX;
    return (int32_t)res;
}

static inline int32_t fxp_exp_qn(int32_t x_qn)
{
    const int32_t clamp_hi = (8 << NUM_FRACTION_BITS);
    const int32_t clamp_lo = (-8 << NUM_FRACTION_BITS);
    if (x_qn <= clamp_lo) return 0;
    if (x_qn > clamp_hi) x_qn = clamp_hi;
    int64_t x2 = ((int64_t)x_qn * x_qn) >> NUM_FRACTION_BITS;
    int64_t res = ((int64_t)1 << NUM_FRACTION_BITS) + x_qn + (x2 >> 1);
    if (res < 0) return 0;
    if (res > INT32_MAX) return INT32_MAX;
    return (int32_t)res;
}

static inline int32_t fxp_tanh_qn(int32_t x_qn)
{
    const int32_t one_qn = (1 << NUM_FRACTION_BITS);
    const int32_t three_qn = (3 << NUM_FRACTION_BITS);
    if (x_qn >= three_qn) return one_qn;
    if (x_qn <= -three_qn) return -one_qn;

    int64_t x2 = ((int64_t)x_qn * x_qn) >> NUM_FRACTION_BITS;
    int32_t c1 = (27 << NUM_FRACTION_BITS);
    int32_t c2 = (9 << NUM_FRACTION_BITS);

    int64_t num = ((int64_t)x_qn * (c1 + (int32_t)x2)) >> NUM_FRACTION_BITS;
    int64_t den = c1 + (((int64_t)c2 * x2) >> NUM_FRACTION_BITS);
    if (den == 0) return 0;

    int64_t res = (num << NUM_FRACTION_BITS) / den;
    if (res > one_qn) return one_qn;
    if (res < -one_qn) return -one_qn;
    return (int32_t)res;
}

#endif // INTEGER_APPROX_FPOPS_H
