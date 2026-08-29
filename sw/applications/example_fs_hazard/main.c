#include <stdio.h>
#include <stdlib.h>
#include "csr.h"
#define FS_INITIAL 0x01

int main() {
    int mval1, mval2, mval3;
    int fail = 0;

    //enable FP operations
    CSR_SET_BITS(CSR_REG_MSTATUS, (FS_INITIAL << 13));

    volatile float f = 3.14f;


    asm volatile(
        "li   t0, 0x3000\n\t"
        "csrrc x0, mstatus, t0\n\t"
        "li   t0, 0x1000\n\t"
        "csrrs x0, mstatus, t0\n\t"
        "flw  ft0, %[f]\n\t"
        "csrrs %[val], mstatus, x0\n\t"
        : [val] "=r"(mval1)
        : [f] "m"(f)
        : "t0", "ft0"
    );

    asm volatile(
        "li   t0, 0x3000\n\t"
        "csrrc x0, mstatus, t0\n\t"
        "li   t0, 0x1000\n\t"
        "csrrs x0, mstatus, t0\n\t"
        "flw  ft0, %[f]\n\t"
        "nop\n\t"
        "csrrs %[val], mstatus, x0\n\t"
        : [val] "=r"(mval2)
        : [f] "m"(f)
        : "t0", "ft0"
    );

    asm volatile(
        "li   t0, 0x3000\n\t"
        "csrrc x0, mstatus, t0\n\t"
        "li   t0, 0x1000\n\t"
        "csrrs x0, mstatus, t0\n\t"
        "flw  ft0, %[f]\n\t"
        "flw  ft1, %[f]\n\t"
        "fadd.s ft2, ft0, ft1\n\t"
        "csrrs %[val], mstatus, x0\n\t"
        : [val] "=r"(mval3)
        : [f] "m"(f)
        : "t0", "ft0", "ft1", "ft2"
    );

    int fs1 = (mval1 >> 12) & 3;
    int fs2 = (mval2 >> 12) & 3;
    int fs3 = (mval3 >> 12) & 3;

    printf("Test 1 - flw, no NOP:        FS=%d (expect 3)\n", fs1);
    printf("Test 2 - flw, 1 NOP:         FS=%d (expect 3)\n", fs2);
    printf("Test 3 - flw/flw/fadd.s:     FS=%d (expect 3)\n", fs3);

    if (fs1 != 3) {
        printf("  >>> BUG REPRODUCED: fs1=%d instead of 3 (stale FS after flw)\n", fs1);
        fail = 1;
    }
    if (fs2 != 3) {
        printf("  >>> UNEXPECTED: fs2=%d instead of 3\n", fs2);
        fail = 1;
    }
    if (fs3 != 3) {
        printf("  >>> UNEXPECTED: fs3=%d instead of 3\n", fs3);
        fail = 1;
    }

    if (fail) {
        printf("\n*** FAIL: mstatus.FS pipeline hazard detected ***\n");
        return EXIT_FAILURE;
    }
    printf("\n*** PASS: no mstatus.FS hazard ***\n");
    return EXIT_SUCCESS;
}
