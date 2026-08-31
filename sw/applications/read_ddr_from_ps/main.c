// Copyright 2026 Huawei Technologies Co., Ltd.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "core_v_mini_mcu.h"

// PS-side physical DDR base used by the VPK180 NoC remap.
// This must match CONFIG.REMAPS in hw/fpga/xheep_fpga_support/scripts/vpk180/xilinx_generate_ps_wizard.tcl:
//   0xC0000000 -> 0x0000000800000000, size 1 GiB.
#ifndef VPK180_DDR_AXI_REMAP_BASE
#define VPK180_DDR_AXI_REMAP_BASE 0x0000000800000000ULL
#endif

#ifndef VPK180_DDR_AXI_REMAP_SIZE_BYTES
#define VPK180_DDR_AXI_REMAP_SIZE_BYTES 0x40000000ULL
#endif

// Physical DDR address written by PS Linux. Override from the build command.
//
// Example:
//   make app PROJECT=read_ddr_from_ps TARGET=vpk180 \
//     COMPILER_FLAGS="-DPS_DDR_PHYS_ADDR=0x0000000801a90000ULL"
//
#ifndef PS_DDR_PHYS_ADDR
#define PS_DDR_PHYS_ADDR 0x0000000801a90000ULL
#endif

// Number of 32-bit words to read/print. Override with COMPILER_FLAGS if needed.
#ifndef DDR_READ_WORDS
#define DDR_READ_WORDS 16
#endif

#if (PS_DDR_PHYS_ADDR & 0x3ULL) != 0
#error "PS_DDR_PHYS_ADDR must be 32-bit aligned"
#endif

#if PS_DDR_PHYS_ADDR < VPK180_DDR_AXI_REMAP_BASE
#error "PS_DDR_PHYS_ADDR is below the VPK180 DDR remap window"
#endif

#if ((PS_DDR_PHYS_ADDR - VPK180_DDR_AXI_REMAP_BASE) + (DDR_READ_WORDS * 4ULL)) > \
    VPK180_DDR_AXI_REMAP_SIZE_BYTES
#error "DDR read range is outside the VPK180 DDR remap window"
#endif

#define DDR_OFFSET_BYTES ((uint32_t)(PS_DDR_PHYS_ADDR - VPK180_DDR_AXI_REMAP_BASE))
#define XHEEP_DDR_ADDR   ((uint32_t)(EXT_SLAVE_START_ADDRESS + DDR_OFFSET_BYTES))

int main(void)
{
    volatile uint32_t *ddr = (volatile uint32_t *)(uintptr_t)XHEEP_DDR_ADDR;

    printf("X-HEEP DDR read test\n");
    printf("PS DDR remap base     : 0x%08x%08x\n",
           (uint32_t)((uint64_t)VPK180_DDR_AXI_REMAP_BASE >> 32),
           (uint32_t)VPK180_DDR_AXI_REMAP_BASE);
    printf("PS DDR physical addr  : 0x%08x%08x\n",
           (uint32_t)((uint64_t)PS_DDR_PHYS_ADDR >> 32),
           (uint32_t)PS_DDR_PHYS_ADDR);
    printf("DDR offset bytes      : 0x%08x\n", DDR_OFFSET_BYTES);
    printf("X-HEEP read address   : 0x%08x\n", XHEEP_DDR_ADDR);
    printf("Reading %u words:\n", (unsigned)DDR_READ_WORDS);

    for (uint32_t i = 0; i < DDR_READ_WORDS; i++) {
        uint64_t ps_addr = (uint64_t)PS_DDR_PHYS_ADDR + 4u * i;
        uint32_t xheep_addr = XHEEP_DDR_ADDR + 4u * i;
        uint32_t value = ddr[i];
        printf("  PS[0x%08x%08x] X-HEEP[0x%08x] = 0x%08x\n",
               (uint32_t)(ps_addr >> 32), (uint32_t)ps_addr, xheep_addr, value);
    }

    printf("Done.\n");
    return EXIT_SUCCESS;
}
