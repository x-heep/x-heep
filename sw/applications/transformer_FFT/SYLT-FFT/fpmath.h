// FIXED POINT MATHS
// D. TAYLOR 2014

#ifndef __FPMATH_H__
#define __FPMATH_H__

#include "config.h"
#include "intrinsics.h"
// #include "fpmath.h"

#define SINE_SIZE  (1 << SINE_BITS)         // Sine table size
#define SINE_FBITS (32 - 2 - SINE_BITS)     // Fractional bits
#define SINE_FMASK ((1 << SINE_FBITS) - 1)  // Fraction mask

// Linear/box interpolation (30 bit precision)
// y1 is first point, y2 second
// mu is interpolation point 00000000-FFFFFFFF
// floating-point equivalent return y2 - y1 * mu + y1;
__INLINE
int32_t linear(int32_t y1, int32_t y2, uint32_t mu) {
  return smmlar((y2 >> 1) - (y1 >> 1), mu >> 1, y1 >> 2) << 2;
}

// Cubic interpolation
// y0...y3 need to be externally limited in range to prevent overflow
// y0...y3 are control points, interpolation is performed between y1 and y2
// mu is interpolation point 00000000-FFFFFFFF
// floating-point equivalent return y1+mu/2*(y2-y0+mu*(2*y0-5*y1+4*y2-y3+mu*(3*(y1-y2)+y3-y0)))
__INLINE
int32_t cubic(int32_t y0, int32_t y1, int32_t y2, int32_t y3, uint32_t mu) {
  mu >>= 1;
  int32_t a = (3 * (y1 - y2) - y0 + y3);
  int32_t b = 2 * y2 + y0 - (5 * y1 + y3) / 2;
  int32_t c = (y2 - y0) / 2;
  return smmlar(smmlar(smmlar(a, mu, b) << 1, mu, c) << 1, mu, y1);
}

// Generate first quadrant (0 to PI/2) of sine wave
// Output table is in Q31 format, with 1 limited to 0x7FFFFFFF
void sine_init() {
#if !SINE_USE_TABLE
  unsigned int n;
#if SINE_PRINTOUT
  printf("// ROM\n");
  printf("#if SINE_BITS != 7\n");
  printf("#error \"sinetable[] size does not match SINE_BITS\"\n");
  printf("#endif\n");
  printf("const int32_t sinetable[] = {");
#endif
  for(n = 0; n <= SINE_SIZE; n++) {
    uint64_t v = (sin(((double)n * M_PI) / (double)(SINE_SIZE * 2)) * 2147483648.0);
    sinetable[n] = v > 2147483647 ? 2147483647 : v;
#if SINE_PRINTOUT
    // Print table
    if((n & 7) == 0) printf("\n  ");
    printf("0x%08x, ", sinetable[n]);
#endif
  }
#if SINE_PRINTOUT
  printf("// <= space potato!\n}; // <= sad monkey?\n");
#endif
#endif
}

// Sin by table lookup with interpolation
// pos = 00000000 to FFFFFFFF, corresponding to 0-2PI(less one)
int32_t sine(uint32_t pos) {
  uint32_t fraction = (pos & SINE_FMASK) << (2 + SINE_BITS);
  uint32_t index = (pos & 0x40000000) ? (0x40000000 + SINE_FMASK - (pos & 0x3FFFFFFF)) : (pos & 0x3FFFFFFF);
  uint32_t indexa = index >> SINE_FBITS;
  uint32_t indexb = pos & 0x40000000 ? indexa - 1 : indexa + 1;
  int32_t sample = linear(sinetable[indexa], sinetable[indexb], fraction);
  return pos & 0x80000000 ? -sample : sample;
}

// Cos by table lookup with interpolation
// See sine
__INLINE
int32_t cosine(uint32_t pos) {
  return sine(pos + 0x40000000);
}

// Fast sin by table lookup
// Same as sine, but no interpolation
__INLINE
int32_t fastsin(uint32_t pos) {
  uint32_t index = (pos & 0x40000000) ? 0x40000000 - (pos & 0x3fffffff) : (pos & 0x3fffffff);
  int32_t sample = sinetable[index >> SINE_FBITS];
  return (pos & 0x80000000 ? -sample : sample);
}

// Fast cos by table lookup
// See fastsin
__INLINE
int32_t fastcos(uint32_t pos) {
  return fastsin(pos + 0x40000000);
}

// Fixed point pow(2, e)
uint64_t fpow2(uint32_t e) {
  uint32_t ipart = e >> FPOW2_FBITS;
#ifdef FPOW2_LIMIT
  uint32_t fpart = (e >> (FPOW2_FBITS - FPOW2_LIMIT)) << (32 - FPOW2_LIMIT);
#else
  uint32_t fpart = e << (32 - FPOW2_FBITS);
#endif
  uint64_t final = 0x100000000;
  if(fpart) {
    uint32_t bit = clz(fpart);
    uint32_t fcalc = fpow2table[bit++] >> 1;
    fpart <<= bit;
    while(fpart) {
      uint32_t lzc = clz(fpart);
      bit += lzc++;
      int32_t fmul = fpow2table[bit++];
      fcalc += smmlar(fcalc, fmul, fmul >> 1);
      fpart <<= lzc;
    }
    final += (uint64_t)fcalc << 1;
  }
  return final << ipart;
}

// Convert binary to gray-code
unsigned bin2gray(unsigned bits) {
  return (bits >> 1) ^ bits;
}

// Convert gray-code to binary
unsigned gray2bin(unsigned bits) {
  bits ^= bits >> 16;
  bits ^= bits >>  8;
  bits ^= bits >>  4;
  bits ^= bits >>  2;
  bits ^= bits >>  1;
  return bits;
}

#endif
