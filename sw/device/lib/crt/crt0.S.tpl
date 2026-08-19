/* Copyright (c) 2017  SiFive Inc. All rights reserved.
 * Copyright (c) 2019  ETH Zürich and University of Bologna
 * Copyright (c) 2022 EPFL
 * This copyrighted material is made available to anyone wishing to use,
 * modify, copy, or redistribute it subject to the terms and conditions
 * of the FreeBSD License.   This program is distributed in the hope that
 * it will be useful, but WITHOUT ANY WARRANTY expressed or implied,
 * including the implied warranties of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  A copy of this license is available at
 * http://www.opensource.org/licenses.
 */

#include "x-heep.h"
#include "core_v_mini_mcu.h"
#include "soc_ctrl_regs.h"

#define RAMSIZE_COPIEDBY_BOOTROM 2048

/* Entry point for bare metal programs */
.section .text.start
.global _start
.type _start, @function

_start:
/* initialize global pointer */
.option push
.option norelax
1: auipc gp, %pcrel_hi(__global_pointer$)
   addi  gp, gp, %pcrel_lo(1b)
.option pop

/* initialize stack pointer */
   la sp, _sp

/* set the frequency */
   li a0, SOC_CTRL_START_ADDRESS
   li a2, REFERENCE_CLOCK_Hz
   sw a2, SOC_CTRL_SYSTEM_FREQUENCY_HZ_REG_OFFSET(a0)

#ifdef EXTERNAL_CRTO
   #include "external_crt0.S"
#endif

#ifdef FLASH_LOAD

    call w25q128jw_init_crt0

    // This assumes ram base address is 0x00000000 and the section .text stars from ram0 (in the first RAMSIZE_COPIEDBY_BOOTROM Byte)
    li     s1, RAMSIZE_COPIEDBY_BOOTROM
    li     t0, FLASH_MEM_START_ADDRESS

    // copy the remaining (if any) text and data sections //
    // Setup the in/out pointers and copy size knowing 1KiB as already been copied
    mv     a0, t0 // src ptr (flash)
    add   a0, a0, s1

    la     a1, _etext
    // Skip if everything has already been copied, and copy the data section
    blt    a1, s1, _load_data_section

    // copy size in bytes, i.e. _etext - RAMSIZE_COPIEDBY_BOOTROM
    sub   a2, a1, s1

    // dst ptr (ram)
    mv     a1, s1

    // copy the remaining data --> w25q128jw_read_standard(a0 is src addr, a1 is dest ptr data, a2 is length)

    // this sub is redundat as we could have simply set a0 to RAMSIZE_COPIEDBY_BOOTROM+0x0,
    // but like this is more readable as we set the FLASH address as memory mapped to FLASH_MEM_START_ADDRESS, and then remove the offset
    // as required bz the w25q128jw_read_standard function
    sub    a0,a0,t0
    call w25q128jw_read_standard

% for i, section in enumerate(xheep.memory_ss().iter_linker_sections()):
% if section.name != "code":
_load_${section.name}_section:
    // src ptr
    la     a0, _lma_${section.name}_start
    // dst ptr
    la     a1, __${section.name}_start
    // copy size in bytes
    la     a2, _lma_${section.name}_end
    sub    a2, a2, a0

    bltz   a2, _load_${section.name}_section_end // dont do anything if you do not have something in ${section.name}

    sub    a0,a0,t0
    call w25q128jw_read_standard
_load_${section.name}_section_end:

% endif
% endfor

#endif

/* clear the bss segment */
_init_bss:
    la     a0, __bss_start
    la     a2, __bss_end
    sub    a2, a2, a0
    li     a1, 0
    call   memset


/* set vector table address and vectored mode */
    la a0, __vector_start
    ori a0, a0, 0x1
    csrw mtvec, a0

/* new-style constructors and destructors */
    la a0, __libc_fini_array
    call atexit
    call __libc_init_array

/* call main */
    lw a0, 0(sp)                    /* a0 = argc */
    addi a1, sp, __SIZEOF_POINTER__ /* a1 = argv */
    li a2, 0                        /* a2 = envp = NULL */
    call main
    tail exit

.size  _start, .-_start

.global _init
.type   _init, @function
.global _fini
.type   _fini, @function
_init:
    call init
_fini:
 /* These don't have to do anything since we use init_array/fini_array. Prevent
    missing symbol error */
    ret
.size  _init, .-_init
.size _fini, .-_fini



