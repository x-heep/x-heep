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

/*
 * C runtime startup for ROM-resident applications (rom_app and direct_rom modes).
 *
 * Used with link_rom_app.ld and link_direct_rom.ld, where:
 *   - .vectors, .text, .rodata  live in the boot ROM (LMA = VMA = ROM)
 *   - .data, .power_manager     have LMA in ROM, VMA in RAM — copied here
 *   - .bss                      is RAM-only — zeroed here
 *
 * No flash driver is needed. No Mako template is needed: all hardware
 * constants come from the generated headers below, and all section
 * boundaries come from linker symbols provided by the linker script.
 */

#include "x-heep.h"
#include "core_v_mini_mcu.h"
#include "soc_ctrl_regs.h"

.section .text.start
.global _start
.type _start, @function

_start:

/* 1. Initialize global pointer (GP-relative relaxation for small-data) */
.option push
.option norelax
1: auipc gp, %pcrel_hi(__global_pointer$)
   addi  gp, gp, %pcrel_lo(1b)
.option pop

/* 2. Initialize stack pointer */
   la sp, _sp

/* 3. Record the reference clock frequency in SOC_CTRL so peripheral
 *    drivers (UART baud rate, timers, etc.) can read it at runtime
 *    without a board-specific compile-time dependency. */
   li a0, SOC_CTRL_START_ADDRESS
   li a2, REFERENCE_CLOCK_Hz
   sw a2, SOC_CTRL_SYSTEM_FREQUENCY_HZ_REG_OFFSET(a0)

/* 4. Copy .data and .power_manager initializers from ROM (LMA) to RAM (VMA).
 *
 *    _lma_data_start  = LOADADDR(.data)   — source start in ROM
 *    _lma_data_end    = source end in ROM  (covers .data + .power_manager)
 *    __data_start     = VMA of .data       — destination start in RAM
 *
 *    The .power_manager region is included in the ROM image (256 zero bytes)
 *    so this single copy also zeroes the power manager save area, which is
 *    required before any sleep/wakeup call. */
   la   a0, _lma_data_start   /* src: ROM address */
   la   a1, __data_start      /* dst: RAM address */
   la   a2, _lma_data_end     /* src end */
   bgeu a0, a2, _init_bss     /* skip if .data is empty */
_data_copy:
   lw   t0, 0(a0)
   sw   t0, 0(a1)
   addi a0, a0, 4
   addi a1, a1, 4
   bltu a0, a2, _data_copy

/* 5. Zero the BSS segment.
 *    BSS has no ROM image (no initializers to store); crt0 zeroes it directly. */
_init_bss:
   la   a0, __bss_start
   la   a2, __bss_end
   sub  a2, a2, a0
   li   a1, 0
   call memset

/* 6. Set interrupt vector table address and enable vectored mode.
 *    __vector_start points into the ROM window; the table is read-only and
 *    permanent — no patching is possible, which is a feature for space use. */
   la  a0, __vector_start
   ori a0, a0, 0x1            /* bit 0 = 1 → vectored mode */
   csrw mtvec, a0

/* 7. Register global C++ destructors, then call constructors.
 *    Also runs any __attribute__((constructor)) functions. */
   la  a0, __libc_fini_array
   call atexit
   call __libc_init_array

/* 8. Call main */
   lw   a0, 0(sp)                     /* a0 = argc */
   addi a1, sp, __SIZEOF_POINTER__    /* a1 = argv */
   li   a2, 0                         /* a2 = envp = NULL */
   call main
   tail exit

.size _start, .-_start

/* Empty _init/_fini stubs required by newlib to avoid missing-symbol errors.
 * The real work is done through init_array/fini_array registered above. */
.global _init
.type   _init, @function
.global _fini
.type   _fini, @function
_init:
   call init
_fini:
   ret
.size _init, .-_init
.size _fini, .-_fini
