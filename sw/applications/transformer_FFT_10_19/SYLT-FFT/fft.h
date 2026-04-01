// (I)FFT(R)
// D. TAYLOR 2014

#ifndef __FFT_H__
#define __FFT_H__

#include "config.h"
#include "intrinsics.h"
#include "fpmath.h"

/* == DECLARATIONS ================================================ */

// Fixed-point data type
typedef int32_t fft_t;

// Complex number type
typedef struct {
  fft_t r, i;
} fft_complex_t;

// Readability macros
#define FFT_QCOS(K, SH) sinetable[(1 << SINE_BITS) - (K << SH)]
#define FFT_QSIN(K, SH) sinetable[K << SH]

#if !((defined FFT_DIT) | (defined FFT_DIF))
#error "Must define FFT_DIT or FFT_DIF"
#endif


/* == CODING STYLE DEFINITIONS ==================================== */

// GCC/ARMCC require different coding styles for optimal performance.
// These defines unify the different styles into one syntax.

// # Optimal performance on ARMCC (Keil) #
#if defined(__ARMCC_VERSION)
// Declare complex, assign complex
#define FFT_DECLC(VAR, ASG)  fft_complex_t VAR = ASG;
// Declare complex, assign real, imaginary
#define FFT_DECLR(VAR, R, I) fft_complex_t VAR = (fft_complex_t){ .r = R, .i = I };
// Assign real, imaginary
#define FFT_ASSGN(VAR, R, I) VAR = (fft_complex_t){ .r = R, .i = I };
// Access real, imaginary
#define FFT(VAR, SUB) VAR.SUB
#endif

// # Optimal performance on GCC #
#if defined(__GNUC__)
// Declare complex, assign complex
#define FFT_DECLC(VAR, ASG)  fft_t VAR##r = ASG.r, VAR##i = ASG.i;
// Declare complex, assign real, imaginary
#define FFT_DECLR(VAR, R, I) fft_t VAR##r = R, VAR##i = I;
// Assign real, imaginary
#define FFT_ASSGN(VAR, R, I) VAR.r = R; VAR.i = I;
// Access real, imaginary
#define FFT(VAR, SUB) VAR##SUB
#endif

#if FFT_SATURATE
#define FFT_A(A,B)    qadd(A, B)       // A + B (saturating)
#define FFT_S(A,B)    qsub(A, B)       // A - B (saturating)
#define FFT_M2(W)     qadd(W, W)       // W * 2 (saturating)
#else
#define FFT_A(A,B)    ((A) + (B))      // A + B
#define FFT_S(A,B)    ((A) - (B))      // A - B
#define FFT_M2(W)     ((W) << 1)       // W * 2
#endif
#define FFT_M(A,B)    smmulr(A, B)     // A * B
#define FFT_MA(A,B,C) smmlar(A, B, C)  // C + (A * B)
#define FFT_MS(A,B,C) smmlsr(A, B, C)  // C - (A * B)
#if FFT_ROUNDING
#define FFT_D2(W)     (((W) + 1) >> 1) // W / 2 (rounded)
#else
#define FFT_D2(W)     ((W) >> 1)       // W / 2
#endif

/* == FORWARD AND INVERSE FFT ===================================== */

// Forward FFT transform
// Permutation must be performed prior to (DIT)/after (DIF) call
void fft_forward(fft_complex_t data[], unsigned bits) {
  unsigned size = 1 << bits;
#ifdef FFT_DIT
  unsigned shift = SINE_BITS + 1;
  for(unsigned stride = 2 ; stride <= size; stride <<= 1, shift--) {
#else//FFT_DIF
  unsigned shift = SINE_BITS - (bits - 2);
  for(unsigned stride = size; stride >= 2; stride >>= 1, shift++) {
#endif
    // Twiddle and combine for k = 0, having trivial (0 and 1) twiddle factors
    for(unsigned a = 0; a < size; a += stride) {
      unsigned b = a + (stride >> 1);
/*
      FFT_DECLC(A, data[a]); FFT_DECLC(B, data[b]);
      // # Radix-2 DIT/DIF trivial butterfly #
      FFT_ASSGN(data[a], FFT_D2(FFT_ADD(FFT(A,r), FFT(B,r))), FFT_D2(FFT_ADD(FFT(A,i), FFT(B,i))));
      FFT_ASSGN(data[b], FFT_D2(FFT_SUB(FFT(A,r), FFT(B,r))), FFT_D2(FFT_SUB(FFT(A,i), FFT(B,i))));
*/
      // Special case: GCC optimizes ARMCC style better here
      fft_complex_t A = data[a], B = data[b];
      // # Radix-2 DIT/DIF trivial butterfly #
      data[a] = (fft_complex_t){ .r = FFT_D2(FFT_A(A.r, B.r)), .i = FFT_D2(FFT_A(A.i, B.i)) };
      data[b] = (fft_complex_t){ .r = FFT_D2(FFT_S(A.r, B.r)), .i = FFT_D2(FFT_S(A.i, B.i)) };
    }
    if(!(stride & 2)) {
      for(unsigned a = (stride >> 2); a < (stride >> 2) + size; a += stride) {
        unsigned b = a + (stride >> 1);
        FFT_DECLC(A, data[a]); FFT_DECLC(B, data[b]);
#ifdef FFT_DIT
        // # Radix-2 DIT trivial butterfly #
        FFT_ASSGN(data[a], FFT_D2(FFT_A(FFT(A,r), FFT(B,i))), FFT_D2(FFT_S(FFT(A,i), FFT(B,r))));
        FFT_ASSGN(data[b], FFT_D2(FFT_S(FFT(A,r), FFT(B,i))), FFT_D2(FFT_A(FFT(A,i), FFT(B,r))));
#else//FFT_DIF
        // # Radix-2 DIF trivial butterfly #
        FFT_ASSGN(data[a], FFT_D2(FFT_A(FFT(A,r), FFT(B,r))), FFT_D2(FFT_A(FFT(A,i), FFT(B,i))));
        FFT_ASSGN(data[b], FFT_D2(FFT_S(FFT(A,i), FFT(B,i))), FFT_D2(FFT_S(FFT(B,r), FFT(A,r))));
#endif
      }
    }
    // Twiddle and combine
    for(unsigned k = 1; k < (stride >> 2); k++) {
      FFT_DECLR(W, FFT_QCOS(k, shift), FFT_QSIN(k, shift));
      for(unsigned a = k, b; a < size; a += (stride >> 2) + (stride >> 1)) {
        b = a + (stride >> 1);
        { // These two blocks prevent the compiler from confusing...
          FFT_DECLC(A, data[a]); FFT_DECLC(B, data[b]);
#ifdef FFT_DIT
          // # Radix-2 DIT butterfly #
          FFT_DECLR(BW, FFT_MA(FFT(B,i), FFT(W,i), FFT_M(FFT(B,r), FFT(W,r))),
                        FFT_MS(FFT(B,r), FFT(W,i), FFT_M(FFT(B,i), FFT(W,r))));
          FFT_ASSGN(data[a], FFT_A(FFT_D2(FFT(A,r)), FFT(BW,r)), FFT_A(FFT_D2(FFT(A,i)), FFT(BW,i)));
          FFT_ASSGN(data[b], FFT_S(FFT_D2(FFT(A,r)), FFT(BW,r)), FFT_S(FFT_D2(FFT(A,i)), FFT(BW,i)));
#else//FFT_DIF
          // # Radix-2 DIF butterfly #
          FFT_ASSGN(data[a], FFT_D2(FFT_A(FFT(A,r), FFT(B,r))), FFT_D2(FFT_A(FFT(A,i), FFT(B,i))));
          FFT_DECLR(D, FFT_S(FFT(A,r), FFT(B,r)), FFT_S(FFT(A,i), FFT(B,i)));
          FFT_ASSGN(data[b], FFT_MA(FFT(D,r), FFT(W,r), FFT_M(FFT(D,i), FFT(W,i))),
                             FFT_MS(FFT(D,r), FFT(W,i), FFT_M(FFT(D,i), FFT(W,r))));
#endif
        }
        a += (stride >> 2); b += (stride >> 2);
        { // ...register use resulting in more efficient code
          FFT_DECLC(A, data[a]); FFT_DECLC(B, data[b]);
#ifdef FFT_DIT
          // # Radix-2 DIT butterfly #
          FFT_DECLR(BW, FFT_MS(FFT(B,r), FFT(W,i), FFT_M(FFT(B,i), FFT(W,r))),
                        FFT_MA(FFT(B,i), FFT(W,i), FFT_M(FFT(B,r), FFT(W,r))));
          FFT_ASSGN(data[a], FFT_A(FFT_D2(FFT(A,r)), FFT(BW,r)), FFT_S(FFT_D2(FFT(A,i)), FFT(BW,i)));
          FFT_ASSGN(data[b], FFT_S(FFT_D2(FFT(A,r)), FFT(BW,r)), FFT_A(FFT_D2(FFT(A,i)), FFT(BW,i)));
#else//FFT_DIF
          // # Radix-2 DIF butterfly #
          FFT_ASSGN(data[a], FFT_D2(FFT_A(FFT(A,r), FFT(B,r))), FFT_D2(FFT_A(FFT(A,i), FFT(B,i))));
          FFT_DECLR(D, FFT_S(FFT(B,r), FFT(A,r)), FFT_S(FFT(B,i), FFT(A,i)));
          FFT_ASSGN(data[b], FFT_MS(FFT(D,i), FFT(W,r), FFT_M(FFT(D,r), FFT(W,i))),
                             FFT_MA(FFT(D,i), FFT(W,i), FFT_M(FFT(D,r), FFT(W,r))));
#endif
        }
      }
    }
  }
}

// Inverse FFT transform
// Permutation must be performed prior to (DIT)/after (DIF) call
void fft_inverse(fft_complex_t data[], unsigned bits) {
  unsigned size = 1 << bits;
#ifdef FFT_DIT
  unsigned shift = SINE_BITS + 1;
  for(unsigned stride = 2 ; stride <= size; stride <<= 1, shift--) {
#else//FFT_DIF
  unsigned shift = SINE_BITS - (bits - 2);
  for(unsigned stride = size; stride >= 2; stride >>= 1, shift++) {
#endif
    // Twiddle and combine for k = 0, having trivial (0 and 1) twiddle factors
    for(unsigned a = 0; a < size; a += stride) {
      unsigned b = a + (stride >> 1);
/*
      FFT_DECLC(A, data[a]); FFT_DECLC(B, data[b]);
      // # Radix-2 DIT/DIF trivial butterfly #
      FFT_ASSGN(data[a], FFT_A(FFT(A,r), FFT(B,r)), FFT_A(FFT(A,i), FFT(B,i)));
      FFT_ASSGN(data[b], FFT_S(FFT(A,r), FFT(B,r)), FFT_S(FFT(A,i), FFT(B,i)));
*/
      // Special case: GCC optimizes ARMCC style better here
      fft_complex_t A = data[a], B = data[b];
      // # Radix-2 DIT/DIF trivial butterfly #
      data[a] = (fft_complex_t){ .r = FFT_A(A.r, B.r), .i = FFT_A(A.i, B.i) };
      data[b] = (fft_complex_t){ .r = FFT_S(A.r, B.r), .i = FFT_S(A.i, B.i) };
    }
    if(!(stride & 2)) {
      for(unsigned a = (stride >> 2); a < size; a += stride) {
        unsigned b = a + (stride >> 1);
        FFT_DECLC(A, data[a]); FFT_DECLC(B, data[b]);
#ifdef FFT_DIT
        // # Radix-2 DIT trivial butterfly #
        FFT_ASSGN(data[a], FFT_S(FFT(A,r), FFT(B,i)), FFT_A(FFT(A,i), FFT(B,r)));
        FFT_ASSGN(data[b], FFT_A(FFT(A,r), FFT(B,i)), FFT_S(FFT(A,i), FFT(B,r)));
#else//FFT_DIF
        // # Radix-2 DIF trivial butterfly #
        FFT_ASSGN(data[a], FFT_A(FFT(A,r), FFT(B,r)), FFT_A(FFT(A,i), FFT(B,i)));
        FFT_ASSGN(data[b], FFT_S(FFT(B,i), FFT(A,i)), FFT_S(FFT(A,r), FFT(B,r)));
#endif
      }
    }
    // Twiddle and combine
    for(unsigned k = 1; k < (stride >> 2); k++) {
      FFT_DECLR(W, FFT_QCOS(k, shift), FFT_QSIN(k, shift));
      for(unsigned a = k, b; a < size; a += (stride >> 2) + (stride >> 1)) {
        b = a + (stride >> 1);
        { // These two blocks prevent the compiler from confusing...
          FFT_DECLC(A, data[a]); FFT_DECLC(B, data[b]);
#ifdef FFT_DIT
          // # Radix-2 DIT butterfly #
          FFT_DECLR(BW, FFT_MS(FFT(B,r), FFT(W,r), FFT_M(FFT(B,i), FFT(W,i))),
                        FFT_MA(FFT(B,i), FFT(W,r), FFT_M(FFT(B,r), FFT(W,i))));
          FFT_ASSGN(data[a], FFT_S(FFT(A,r), FFT_M2(FFT(BW,r))), FFT_A(FFT(A,i), FFT_M2(FFT(BW,i))));
          FFT_ASSGN(data[b], FFT_A(FFT(A,r), FFT_M2(FFT(BW,r))), FFT_S(FFT(A,i), FFT_M2(FFT(BW,i))));
#else//FFT_DIF
          // # Radix-2 DIF butterfly #
          FFT_ASSGN(data[a], FFT_A(FFT(A,r), FFT(B,r)), FFT_A(FFT(A,i), FFT(B,i)));
          FFT_DECLR(D, FFT_S(FFT(A,r), FFT(B,r)), FFT_S(FFT(A,i), FFT(B,i)));
          FFT_ASSGN(data[b], FFT_M2(FFT_MS(FFT(D,i), FFT(W,i), FFT_M(FFT(D,r), FFT(W,r)))),
                             FFT_M2(FFT_MA(FFT(D,i), FFT(W,r), FFT_M(FFT(D,r), FFT(W,i)))));
#endif
        }
        a += (stride >> 2); b += (stride >> 2);
        { // ...register use resulting in more efficient code
          FFT_DECLC(A, data[a]); FFT_DECLC(B, data[b]);
#ifdef FFT_DIT
          // # Radix-2 DIT butterfly #
          FFT_DECLR(BW, FFT_MA(FFT(B,i), FFT(W,r), FFT_M(FFT(B,r), FFT(W,i))),
                        FFT_MS(FFT(B,r), FFT(W,r), FFT_M(FFT(B,i), FFT(W,i))));
          FFT_ASSGN(data[a], FFT_S(FFT(A,r), FFT_M2(FFT(BW,r))), FFT_S(FFT(A,i), FFT_M2(FFT(BW,i))));
          FFT_ASSGN(data[b], FFT_A(FFT(A,r), FFT_M2(FFT(BW,r))), FFT_A(FFT(A,i), FFT_M2(FFT(BW,i))));
#else//FFT_DIF
          // # Radix-2 DIF butterfly #
          FFT_ASSGN(data[a], FFT_A(FFT(A,r), FFT(B,r)), FFT_A(FFT(A,i), FFT(B,i)));
          FFT_DECLR(D, FFT_S(FFT(A,r), FFT(B,r)), FFT_S(FFT(B,i), FFT(A,i)));
          FFT_ASSGN(data[b], FFT_M2(FFT_MS(FFT(D,r), FFT(W,i), FFT_M(FFT(D,i), FFT(W,r)))),
                             FFT_M2(FFT_MA(FFT(D,i), FFT(W,i), FFT_M(FFT(D,r), FFT(W,r)))));
#endif
        }
      }
    }
  }
}


/* == DATA SET PROCESSING AND MANIPULATION ======================== */

// Process complex data to produce real-only output
// This allows us to output N*2 point of real data using a N point complex (I)FFT
// Even/odd real data will be found in the real/imaginary parts of every output bin upon completion
void fft_convert(fft_complex_t data[], unsigned bits, bool permutated, bool invert) {
  unsigned size = 1 << --bits;
  unsigned shift = SINE_BITS - bits++;
  unsigned n, z, nc, zc;
  fft_t rsum, rdif, isum, idif;
  fft_t itwiddled, rtwiddled;
  for(nc = zc = size; nc; nc--, zc++) {
    if(permutated) {
      n = RBITS(nc, bits); z = RBITS(zc, bits);
    } else {
      n = nc; z = zc;
    }
    rsum = data[n].r + data[z].r; isum = data[n].i + data[z].i;
    rdif = data[n].r - data[z].r; idif = data[n].i - data[z].i;
    fft_t r =  FFT_QCOS(nc, shift); fft_t i = -FFT_QSIN(nc, shift);
    if(invert) r = -r;
    rtwiddled = FFT_MA(r, isum, FFT_M(i, rdif)) << 1;
    itwiddled = FFT_MS(r, rdif, FFT_M(i, isum)) << 1;
    data[n].r = rsum + rtwiddled; data[n].i = itwiddled + idif;
    data[z].r = rsum - rtwiddled; data[z].i = itwiddled - idif;
  }
  fft_t data_0_tr = data[0].r;
  data[0].r = (data[0].r + data[0].i); data[0].i = (data_0_tr - data[0].i);
  if(!invert) { data[0].r <<= 1; data[0].i <<= 1; }
}

// Perform bit-reversal permutation on data set
// (Reverses address bits for all data points)
void fft_permutate(fft_complex_t data[], unsigned bits) {
  unsigned size  = 1 << bits;
  unsigned shift = 32 - bits;
  for(unsigned i = 1; i < size - 1; i++) {
    unsigned z = rbit(i) >> shift;
    if(z > i) {
      fft_t
      t = data[i].r; data[i].r = data[z].r; data[z].r = t;
      t = data[i].i; data[i].i = data[z].i; data[z].i = t;
    }
  }
}


/* == "HIGH"-LEVEL FUNCTIONS ====================================== */

// Perform forward FFT (including permutation)
__INLINE
void fft_fft(fft_complex_t *complex, unsigned bits) {
#ifdef FFT_DIT
  fft_permutate(complex, bits);
#endif
  fft_forward(complex, bits);
#ifdef FFT_DIF
  fft_permutate(complex, bits);
#endif
}

// Perform inverse FFT (including permutation)
__INLINE
void fft_ifft(fft_complex_t *complex, unsigned bits) {
#ifdef FFT_DIT
  fft_permutate(complex, bits);
#endif
  fft_inverse(complex, bits);
#ifdef FFT_DIF
  fft_permutate(complex, bits);
#endif
}

// Perform forward FFT (including permutation, real output conversion)
__INLINE
void fft_fftr(fft_complex_t *complex, unsigned bits) {
  fft_fft(complex, bits);
  fft_convert(complex, bits, false, false);
}

// Perform inverse FFT (including permutation, real input conversion)
__INLINE
void fft_ifftr(fft_complex_t *complex, unsigned bits) {
  fft_convert(complex, bits, false, true);
  fft_ifft(complex, bits);
}


/* == DATA SET CONSTRUCTION ======================================= */

// Magnitude and phase => complex FFT bin [index]
// A data set built with this method does not require fft_permutate before DIT IFFT
__INLINE
void fft_phase_magnitude(fft_complex_t complex[], unsigned bits, unsigned index, int32_t mag, uint32_t pha) {
#ifdef FFT_DIT
  unsigned n = RBITS(index, bits);
#else//FFT_DIF
  unsigned n = index;
#endif
  complex[n].r = FFT_M(mag, sine(pha));
  complex[n].i = FFT_M(mag, cosine(pha));
}

// Magnitude, phase:0 => complex FFT bin [index]
// A data set built with this method does not require fft_permutate before DIT IFFT
__INLINE
void fft_magnitude(fft_complex_t complex[], unsigned bits, unsigned index, int32_t mag) {
#ifdef FFT_DIT
  unsigned n = RBITS(index, bits);
#else//FFT_DIF
  unsigned n = index;
#endif
  complex[n].r = 0; complex[n].i = mag;
}

// REAL Symmetric DC offset => complex FFT bin [0] (DC)
// A data set built with this method does not require fft_permutate before DIT IFFT
// A data set built with this method does not require fft_convert before IFFT
__INLINE
void fft_real_dc(fft_complex_t data[], fft_t r, fft_t i) {
  data[0].r = r + i;
  data[0].i = r - i;
}

// REAL Symmetric magnitude and phase => complex FFT bins [index], [size-index]
// A data set built with this method does not require fft_permutate before DIT IFFT
// A data set built with this method does not require fft_convert before IFFT
void fft_real_phase_magnitude(fft_complex_t complex[], unsigned bits, unsigned index, int32_t mag_lo, int32_t pha_lo, int32_t mag_hi, int32_t pha_hi) {
  unsigned size = 1 << bits;
  unsigned shift = SINE_BITS - (bits - 1);
#ifdef FFT_DIT
  unsigned n = RBITS(index, bits);
  unsigned z = RBITS(size - index, bits);
#else//FFT_DIF
  unsigned n = index;
  unsigned z = size - index;
#endif
  fft_t rsum, rdif, isum, idif, r, i;
  fft_t itwiddled, rtwiddled;
  r = FFT_M(mag_lo,   sine(pha_lo));
  i = FFT_M(mag_hi,   sine(pha_hi));
  rsum = r + i; rdif = r - i;
  r = FFT_M(mag_lo, cosine(pha_lo));
  i = FFT_M(mag_hi, cosine(pha_hi));
  isum = r + i; idif = r - i;
  r = -FFT_QCOS(index, shift); i = -FFT_QSIN(index, shift);
  rtwiddled = FFT_MA(r, isum, FFT_M(i, rdif)) << 1;
  itwiddled = FFT_MS(r, rdif, FFT_M(i, isum)) << 1;
  complex[n].r = rsum + rtwiddled; complex[n].i = itwiddled + idif;
  complex[z].r = rsum - rtwiddled; complex[z].i = itwiddled - idif;
}

// REAL Symmetric magnitude, phase:0 => complex FFT bins [index], [size-index]
// This method works with permutated (bit-reversed) addressing
// A data set built with this method does not require fft_permutate before DIT IFFT
// A data set built with this method does not require fft_convert before IFFT
void fft_real_magnitude(fft_complex_t complex[], unsigned bits, unsigned index, int32_t mag_lo, int32_t mag_hi) {
  unsigned shift = SINE_BITS - bits + 1;
#ifdef FFT_DIT
  unsigned n = RBITS(index, bits);
  unsigned z = RBITS((1 << bits) - index, bits);
#else//FFT_DIF
  unsigned n = index;
  unsigned z = (1 << bits) - index;
#endif
  fft_t isum, idif, r, i;
  fft_t itwiddled, rtwiddled;
  isum = (mag_lo + mag_hi); idif = mag_lo - mag_hi;
  r = FFT_QCOS(index, shift); i = FFT_QSIN(index, shift);
  rtwiddled = FFT_M(r, isum) << 1;
  itwiddled = FFT_M(i, isum) << 1;
  complex[n].r = -rtwiddled; complex[n].i =  (idif - itwiddled);
  complex[z].r =  rtwiddled; complex[z].i = -(idif + itwiddled);
}

#endif
