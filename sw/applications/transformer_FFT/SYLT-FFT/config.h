// CONFIGURATION FILE
// D. TAYLOR 2014

#ifndef __CONFIG_H__
#define __CONFIG_H__

#include "stdint.h"
#include "stdbool.h"

#ifndef __INLINE
#if defined(__GNUC__)
#define __INLINE __attribute__((always_inline)) inline
#else
#define __INLINE __inline
#endif
#endif


/* == MATH CONFIGURE =============================================== */

#define FPOW2_FBITS        27 // Number of fractional bits (1...28)
#define FPOW2_LIMIT         8 // Limit accuracy to n fractional bits (1...FPOW2_FBITS-1)

#define SINE_BITS           7 // Sine quality (2..14) vs. memory tradeoff
#define SINE_USE_TABLE      1 // Use pre-computed ROM table (vs. generate in RAM)
#define SINE_PRINTOUT       0 // Write sine table to screen (PC only)

/* == FFT CONFIGURE =============================================== */

// Maximum FFT size:          4 << SINE_BITS (complex data points)
// Memory used by sine table: 4 << SINE_BITS (bytes)
// FFT is faster when SINE_USE_TABLE is 0 (located in RAM)

#define FFT_DIT               // Operation mode, FFT_DIT or FFT_DIF (slower)
#define FFT_ROUNDING        0 // Perform rounding when dividing (slower)
#define FFT_SATURATE        0 // Use saturating math where possible (slower)

/* == WAVETABLE CONFIGURE ========================================== */

/* == GLOBAL DATA CONFIGURE ======================================== */

// PI
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// LUT for sine wave, first quadrant only
#if SINE_USE_TABLE
// == PLACE GENERATED SINE TABLE HERE ======================== //
// ROM
#if SINE_BITS != 7
#error "sinetable[] size does not match SINE_BITS"
#endif
const int32_t sinetable[] = {
  0x00000000, 0x01921d1f, 0x03242abe, 0x04b6195d, 0x0647d97c, 0x07d95b9e, 0x096a9049, 0x0afb6805,
  0x0c8bd35e, 0x0e1bc2e3, 0x0fab272b, 0x1139f0ce, 0x12c8106e, 0x145576b1, 0x15e21444, 0x176dd9de,
  0x18f8b83c, 0x1a82a025, 0x1c0b826a, 0x1d934fe5, 0x1f19f97b, 0x209f701c, 0x2223a4c5, 0x23a6887e,
  0x25280c5d, 0x26a82185, 0x2826b928, 0x29a3c484, 0x2b1f34eb, 0x2c98fbba, 0x2e110a61, 0x2f875262,
  0x30fbc54d, 0x326e54c7, 0x33def287, 0x354d9056, 0x36ba2013, 0x382493b0, 0x398cdd32, 0x3af2eeb7,
  0x3c56ba70, 0x3db832a5, 0x3f1749b7, 0x4073f21d, 0x41ce1e64, 0x4325c135, 0x447acd50, 0x45cd358f,
  0x471cece6, 0x4869e664, 0x49b41533, 0x4afb6c97, 0x4c3fdff3, 0x4d8162c4, 0x4ebfe8a4, 0x4ffb654d,
  0x5133cc94, 0x5269126e, 0x539b2aef, 0x54ca0a4a, 0x55f5a4d2, 0x571deef9, 0x5842dd54, 0x59646497,
  0x5a827999, 0x5b9d1153, 0x5cb420df, 0x5dc79d7c, 0x5ed77c89, 0x5fe3b38d, 0x60ec382f, 0x61f1003e,
  0x62f201ac, 0x63ef328f, 0x64e88926, 0x65ddfbd3, 0x66cf811f, 0x67bd0fbc, 0x68a69e81, 0x698c246c,
  0x6a6d98a4, 0x6b4af278, 0x6c242960, 0x6cf934fb, 0x6dca0d14, 0x6e96a99c, 0x6f5f02b1, 0x70231099,
  0x70e2cbc6, 0x719e2cd2, 0x72552c84, 0x7307c3cf, 0x73b5ebd0, 0x745f9dd0, 0x7504d345, 0x75a585cf,
  0x7641af3c, 0x76d94988, 0x776c4edb, 0x77fab988, 0x78848413, 0x7909a92c, 0x798a23b1, 0x7a05eead,
  0x7a7d055b, 0x7aef6323, 0x7b5d039d, 0x7bc5e28f, 0x7c29fbee, 0x7c894bdd, 0x7ce3ceb1, 0x7d3980ec,
  0x7d8a5f3f, 0x7dd6668e, 0x7e1d93e9, 0x7e5fe493, 0x7e9d55fc, 0x7ed5e5c6, 0x7f0991c3, 0x7f3857f5,
  0x7f62368f, 0x7f872bf2, 0x7fa736b4, 0x7fc25596, 0x7fd8878d, 0x7fe9cbbf, 0x7ff62182, 0x7ffd885a,
  0x7fffffff, // <= space potato!
}; // <= sad monkey?
// == END OF GENERATED SINE TABLE ============================ //
#else
// RAM
int32_t sinetable[(1 << SINE_BITS) + 1];
#endif

// LUT for pow(2, fixedpoint)
// Only need to define up to FPOW2_LIMIT
const int32_t fpow2table[] = {
  0x6a09e668, 0x306fe0a3, 0x172b83c8, 0x0b5586d0, 0x059b0d31, 0x02c9a3e7, 0x0163daa0, 0x00b1afa6,
/*0x0058c86e, 0x002c605e, 0x00162f39, 0x000b175f, 0x00058ba0, 0x0002c5cc, 0x000162e5, 0x0000b172,
  0x000058b9, 0x00002c5d, 0x0000162e, 0x00000b17, 0x0000058c, 0x000002c6, 0x00000163, 0x000000b1,
  0x00000059, 0x0000002c, 0x00000016, 0x0000000b, 0x00000006, 0x00000003, 0x00000001, 0x00000001,*/
};

#endif
