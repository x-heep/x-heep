// INTRINSICS
// D. TAYLOR 2014

#ifndef __INTRINSICS_H__
#define __INTRINSICS_H__
#include "config.h"

// issue warnings when not using full hardware acceleration

#if defined(__ARMCC_VERSION) || (defined(__GNUC__) && defined(__arm__))
#if (__CORTEX_M < 0x03)
#warning "Cortex-M core < M3 detected; hardware acceleration for math operations not supported"
#elif (__CORTEX_M < 0x04)
#warning "Cortex-M core < M4 detected; partial hardware acceleration for math operations supported"
#endif
#endif

// reverse bits (ARM: RBIT)
__INLINE
uint32_t rbit(uint32_t x) {
  uint32_t result;
#if defined(__ARMCC_VERSION) && ((__CORTEX_M >= 0x03) || (__CORTEX_SC >= 300))
  __asm{ rbit result, x }
#elif defined(__GNUC__) && defined(__arm__) && ((__CORTEX_M >= 0x03) || (__CORTEX_SC >= 300))
  __asm("rbit %0, %1":"=r"(result):"r"(x));
#else
  x = (((x & 0xaaaaaaaa) >> 1) | ((x & 0x55555555) << 1));
  x = (((x & 0xcccccccc) >> 2) | ((x & 0x33333333) << 2));
  x = (((x & 0xf0f0f0f0) >> 4) | ((x & 0x0f0f0f0f) << 4));
  x = (((x & 0xff00ff00) >> 8) | ((x & 0x00ff00ff) << 8));
  result = (x >> 16) | (x << 16);
#endif
  return result;
}

#define RBITS(W, BITS) (rbit(W) >> (32 - (BITS)))

// count leading zeroes (ARM: CLZ)
__INLINE
uint32_t clz(uint32_t x) {
  uint32_t result;
#if defined(__ARMCC_VERSION) && ((__CORTEX_M >= 0x03) || (__CORTEX_SC >= 300))
  __asm{ clz result, x }
#elif defined(__GNUC__) && defined(__arm__) && ((__CORTEX_M >= 0x03) || (__CORTEX_SC >= 300))
  __asm("clz %0, %1":"=r"(result):"r"(x));
#else
  x |= x >> 1; x |= x >> 2; x |= x >> 4; x |= x >> 8; x |= x >> 16;
  x -= 0x55555555 & (x >> 1);
  x = (0x33333333 & x) + (0x33333333 & (x >> 2));
  result = 32 - ((0x01010101 * (0x0F0F0F0F & (x + (x >> 4)))) >> 24);
#endif
  return result;
}

// 32-bit signed multiply -> 32-bit result, add 32-bit (ARM: SMMLAR)
// floating point equivalent: return c + a * b
__INLINE
int32_t smmlar(int32_t a, int32_t b, int32_t c) {
  int32_t result;
#if defined(__ARMCC_VERSION) && (__CORTEX_M >= 0x04U)
  __asm{ smmlar result, a, b, c }
#elif defined(__GNUC__) && defined(__arm__) && (__CORTEX_M >= 0x04U)
  __asm("smmlar %0, %1, %2, %3":"=r"(result):"r"(a),"r"(b),"r"(c));
#else
  result = c + ((((int64_t)a * b) + 0x80000000) >> 32);
#endif
  return result;
}

// 32-bit signed multiply -> 32-bit result, subtract 32-bit (ARM: SMMLSR)
// floating point equivalent: return c - a * b
__INLINE
int32_t smmlsr(int32_t a, int32_t b, int32_t c) {
  int32_t result;
#if defined(__ARMCC_VERSION) && (__CORTEX_M >= 0x04U)
  __asm{ smmlsr result, a, b, c }
#elif defined(__GNUC__) && defined(__arm__) && (__CORTEX_M >= 0x04U)
  __asm("smmlsr %0, %1, %2, %3":"=r"(result):"r"(a),"r"(b),"r"(c));
#else
  result = c - ((((int64_t)a * b) + 0x80000000) >> 32);
#endif
  return result;
}

// 32-bit signed multiply -> 32-bit result (ARM: SMMULR)
// floating point equivalent: return a * b
__INLINE
int32_t smmulr(int32_t a, int32_t b) {
  int32_t result;
#if defined(__ARMCC_VERSION) && (__CORTEX_M >= 0x04U)
  __asm{ smmulr result, a, b }
#elif defined(__GNUC__) && defined(__arm__) && (__CORTEX_M >= 0x04U)
  __asm("smmulr %0, %1, %2":"=r"(result):"r"(a),"r"(b));
#else
  result = ((((int64_t)a * b) + 0x80000000) >> 32);
#endif
  return result;
}

// saturating add (ARM: qadd)
// floating point equivalent: return max(min(a + b, 1), -1)
__INLINE
int32_t qadd(int32_t a, int32_t b) {
  uint32_t result;
#if defined(__ARMCC_VERSION)
  __asm{ qadd result, a, b }
#elif defined(__GNUC__) && defined(__arm__)
  __asm("qadd %0, %1, %2":"=r"(result):"r"(a),"r"(b));
#else
  int64_t c = (int64_t)a + b;
  if(c >  2147483647) c =  2147483647;
  if(c < -2147483648) c = -2147483648;
  result = c;
#endif
  return result;
}

// saturating subtract (ARM: qsub)
// floating point equivalent: return max(min(a - b, 1), -1)
__INLINE
int32_t qsub(int32_t a, int32_t b) {
  uint32_t result;
#if defined(__ARMCC_VERSION)
  __asm{ qsub result, a, b }
#elif defined(__GNUC__) && defined(__arm__)
  __asm("qsub %0, %1, %2":"=r"(result):"r"(a),"r"(b));
#else
  int64_t c = (int64_t)a - b;
  if(c >  2147483647) c =  2147483647;
  if(c < -2147483648) c = -2147483648;
  result = c;
#endif
  return result;
}

// 32-bit arithmetic shift right with rounding (ARM: ASRS + ADC)
// floating point equivalent: return v / pow(2, s)
__INLINE
int32_t asrr(int32_t v, int32_t s) {
  int32_t result;
#if defined(__ARMCC_VERSION)
  __asm{ asrs result, v, s };
  __asm{ adc result, result };
#elif defined(__GNUC__) && defined(__arm__)
  __asm("asrs %0, %1, %2":"=r"(result):"r"(v),"r"(s):"cc");
  __asm("adc %0, %1, #0":"=r"(result):"r"(result));
#else
  result = (v + (1 << (s - 1))) >> s;
#endif
  return result;
}

#endif
