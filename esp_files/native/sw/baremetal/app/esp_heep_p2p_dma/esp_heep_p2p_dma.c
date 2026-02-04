/* Copyright (c) 2011-2024 Columbia University, System Level Design Group */
/* SPDX-License-Identifier: Apache-2.0 */

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#ifndef __riscv
    #include <stdlib.h>
#endif

#include "esp_accelerator.h"
#include "esp_probe.h"
#include "monitors.h"
#include "xheep_rtl_accelerator.h"
#include "xheep_common.h"
#include "xheep_fw_esp_p2p_dma.h"
#include "xheep1_fw_esp_p2p_dma.h"

#define DEBUG_PRINTS 0
#define PROFILE 1

#define ACC_COMPAT_PROD  "sld,xheep1_rtl"
#define ACC_COMPAT_CONS  "sld,xheep_rtl"
#define ACC_VENDOR       VENDOR_SLD
#define ACC_DEVID        0x066

#define CHUNK_SHIFT 20
#define CHUNK_SIZE  (1u << CHUNK_SHIFT)
#define NCHUNK(_sz) ((_sz + CHUNK_SIZE - 1) >> CHUNK_SHIFT)

#define ACC_RESERVED_BASE 0x82000000
#define ACC_RESERVED_SIZE 0x01000000

static void dump_yx_entries(struct esp_device *dev, const char *tag, unsigned entries)
{
    for (unsigned i = 0; i < entries; ++i) {
        unsigned reg = YX_REG + (i / 4) * 4;
        unsigned shift = (i % 4) * 2 * YX_WIDTH;
        uint32_t yx = ioread32(dev, reg);
        unsigned x = (yx >> shift) & YX_MASK_YX;
        unsigned y = (yx >> (shift + YX_WIDTH)) & YX_MASK_YX;
        printf("[YX %s] entry%u reg=0x%03x raw=0x%08x y=%u x=%u\n",
               tag, i, reg, yx, y, x);
    }
}

static unsigned tile_index_from_dev(struct esp_device *dev)
{
    return esp_get_y(dev) * SOC_COLS + esp_get_x(dev);
}

static unsigned read_mon_tile(unsigned tile_index, unsigned mon_index)
{
    esp_monitor_args_t mon_args;
    mon_args.read_mode  = ESP_MON_READ_SINGLE;
    mon_args.tile_index = tile_index;
    mon_args.mon_index  = mon_index;
    return esp_monitor(mon_args, NULL);
}

static esp_acc_stats_t read_acc_stats(struct esp_device *dev)
{
    unsigned tile_index = tile_index_from_dev(dev);
    esp_acc_stats_t stats;

    stats.acc_tlb         = read_mon_tile(tile_index, MON_ACC_TLB_INDEX);
    stats.acc_mem_lo      = read_mon_tile(tile_index, MON_ACC_MEM_LO_INDEX);
    stats.acc_mem_hi      = read_mon_tile(tile_index, MON_ACC_MEM_HI_INDEX);
    stats.acc_tot_lo      = read_mon_tile(tile_index, MON_ACC_TOT_LO_INDEX);
    stats.acc_tot_hi      = read_mon_tile(tile_index, MON_ACC_TOT_HI_INDEX);
    stats.acc_invocations = read_mon_tile(tile_index, MON_ACC_INVOCATIONS);

    return stats;
}

static uint64_t acc_cycles_u64(uint32_t lo, uint32_t hi)
{
    return ((uint64_t)hi << 32) | lo;
}

static uint64_t diff_u64(uint64_t start, uint64_t end)
{
    if (end >= start) return end - start;
    return (UINT64_MAX - start + 1u) + end;
}

typedef struct acc_profile {
    esp_acc_stats_t acc;
    uint32_t noc_injects[NOC_PLANES];
    uint32_t noc_backpressure[NOC_PLANES][NOC_QUEUES];
} acc_profile_t;

static void read_noc_profile(struct esp_device *dev, acc_profile_t *profile)
{
    unsigned tile_index = tile_index_from_dev(dev);
    for (unsigned p = 0; p < NOC_PLANES; ++p) {
        unsigned mon_index = MON_NOC_TILE_INJECT_BASE_INDEX + p;
        profile->noc_injects[p] = read_mon_tile(tile_index, mon_index);
    }
    for (unsigned dir = 0; dir < NOC_QUEUES; ++dir) {
        for (unsigned p = 0; p < NOC_PLANES; ++p) {
            unsigned mon_index = MON_NOC_QUEUES_FULL_BASE_INDEX + dir * NOC_PLANES + p;
            profile->noc_backpressure[p][dir] = read_mon_tile(tile_index, mon_index);
        }
    }
}

static void read_acc_profile(struct esp_device *dev, acc_profile_t *profile)
{
    profile->acc = read_acc_stats(dev);
    read_noc_profile(dev, profile);
}

static void print_acc_profile_diff(const char *label, const char *role,
                                   struct esp_device *dev,
                                   const acc_profile_t *start,
                                   const acc_profile_t *end)
{
    unsigned tile_index = tile_index_from_dev(dev);
    uint64_t mem_start = acc_cycles_u64(start->acc.acc_mem_lo, start->acc.acc_mem_hi);
    uint64_t mem_end   = acc_cycles_u64(end->acc.acc_mem_lo, end->acc.acc_mem_hi);
    uint64_t tot_start = acc_cycles_u64(start->acc.acc_tot_lo, start->acc.acc_tot_hi);
    uint64_t tot_end   = acc_cycles_u64(end->acc.acc_tot_lo, end->acc.acc_tot_hi);

    uint64_t mem_cycles = diff_u64(mem_start, mem_end);
    uint64_t tot_cycles = diff_u64(tot_start, tot_end);
    uint64_t compute_cycles = (tot_cycles >= mem_cycles) ? (tot_cycles - mem_cycles) : 0;
    uint32_t tlb_cycles = sub_monitor_vals(start->acc.acc_tlb, end->acc.acc_tlb);
    uint32_t invocations = sub_monitor_vals(start->acc.acc_invocations, end->acc.acc_invocations);

    uint64_t noc_injects_total = 0;
    uint64_t noc_backpressure_total = 0;
    uint32_t noc_injects_diff[NOC_PLANES];
    uint32_t noc_backpressure_diff[NOC_PLANES][NOC_QUEUES];
    for (unsigned p = 0; p < NOC_PLANES; ++p) {
        noc_injects_diff[p] = sub_monitor_vals(start->noc_injects[p], end->noc_injects[p]);
        noc_injects_total += noc_injects_diff[p];
        for (unsigned q = 0; q < NOC_QUEUES; ++q) {
            noc_backpressure_diff[p][q] =
                sub_monitor_vals(start->noc_backpressure[p][q], end->noc_backpressure[p][q]);
            noc_backpressure_total += noc_backpressure_diff[p][q];
        }
    }

    printf("[MON] %s %s: tile=%u (y=%u x=%u)\n",
           label, role, tile_index, esp_get_y(dev), esp_get_x(dev));
    printf("      acc_cycles: total=%llu mem=%llu compute=%llu tlb=%u invocations=%u\n",
           (unsigned long long)tot_cycles, (unsigned long long)mem_cycles,
           (unsigned long long)compute_cycles, tlb_cycles, invocations);
    printf("      noc: injects_total=%llu backpressure_total=%llu\n",
           (unsigned long long)noc_injects_total,
           (unsigned long long)noc_backpressure_total);
    printf("      noc_injects_by_plane:");
    for (unsigned p = 0; p < NOC_PLANES; ++p) {
        printf(" p%u=%u", p, noc_injects_diff[p]);
    }
    printf("\n");
    printf("      noc_backpressure_by_plane:");
    for (unsigned p = 0; p < NOC_PLANES; ++p) {
        uint32_t plane_total = 0;
        for (unsigned q = 0; q < NOC_QUEUES; ++q) {
            plane_total += noc_backpressure_diff[p][q];
        }
        printf(" p%u=%u", p, plane_total);
    }
    printf("\n");
}

static void dump_p2p_state(struct esp_device *dev, const char *tag)
{
    uint32_t p2p   = ioread32(dev, P2P_REG);
    uint32_t mcast = ioread32(dev, MCAST_REG);

    /* Decode basic bits */
    uint32_t src_is_p2p = (p2p & P2P_MASK_SRC_IS_P2P) ? 1 : 0;
    uint32_t dst_is_p2p = (p2p & P2P_MASK_DST_IS_P2P) ? 1 : 0;
    uint32_t nsrcs      = (p2p & P2P_MASK_NSRCS) + 1; // stored as n-1

    uint32_t ndests     = ((mcast >> MCAST_SHIFT_NDESTS) & MCAST_MASK_NDESTS) + 1;
    uint32_t packet     = (mcast >> MCAST_SHIFT_PACKET) & MCAST_MASK_PACKET;
    uint32_t pkt_size   = (mcast >> MCAST_SHIFT_PACKET_SIZE) & MCAST_MASK_PACKET_SIZE;

    /* Source coordinate table entries: entry 0 (local), entry 1 (user=1), entry 2 (user=2) */
    uint32_t yx0 = ioread32(dev, YX_REG + 0);
    uint32_t yx1 = ioread32(dev, YX_REG + 4);
    uint32_t yx2 = ioread32(dev, YX_REG + 8);

    printf("[P2P %s] P2P=0x%08x SRC=%u DST=%u NSRCS=%u |\n MCAST=0x%08x NDESTS=%u PKT=%u PKTSZ=%u |\n YX0=0x%08x YX1=0x%08x YX2=0x%08x\n",
           tag, p2p, src_is_p2p, dst_is_p2p, nsrcs,
           mcast, ndests, packet, pkt_size,
           yx0, yx1, yx2);

}

static void p2p_setup(struct esp_device *prod, struct esp_device *cons)
{
    esp_p2p_reset(prod);
    esp_p2p_set_mcast_ndests(prod, 1); // expecting one consumer

    esp_p2p_reset(cons);
    esp_p2p_set_nsrcs(cons, 2); // make table entry 1 valid (macro uses n-1)
    
    // Set in P2P_REG (0x24) - used for user=0
    esp_p2p_set_y(cons, 1, esp_get_y(prod)); 
    esp_p2p_set_x(cons, 1, esp_get_x(prod));

    // Explicitly program the YX table entry 1 for user=1
    // Hardware packs 4 entries per register.
    // User 1 is at Offset 0 (Reg 0x180), Index 1.
    esp_yx_reg_set_y(cons, esp_get_y(prod), 0, 1);
    esp_yx_reg_set_x(cons, esp_get_x(prod), 0, 1);
    
    // printf("[DBG] P2P Setup Verify: YX_REG(0x180) = 0x%08x\n", ioread32(cons, 0x180));
    // dump_yx_entries(cons, "CONS", 2);
    // dump_yx_entries(prod, "PROD", 1);
}

/*
Note
Producer: xheep1
Consumer: xheep
*/

int main(int argc, char **argv)
{
    printf("\n=== X-HEEP P2P baremetal (firmware load + P2P) ===\n");

    struct esp_device *devs_prod = NULL;
    struct esp_device *devs_cons = NULL;
    int nprod = probe(&devs_prod, ACC_VENDOR, ACC_DEVID, ACC_COMPAT_PROD);
    int ncons = probe(&devs_cons, ACC_VENDOR, ACC_DEVID, ACC_COMPAT_CONS);
    // printf("[DBG] after probe: nprod=%d, ncons=%d\n", nprod, ncons);
    if (nprod <= 0 || ncons <= 0) {
        printf("Error: producer/consumer accelerators not found\n");
        return 1;
    }
    /* Use only the first instance (.0) of each device type */
    struct esp_device *prod = &devs_prod[0];
    struct esp_device *cons = &devs_cons[0];
    printf("  Using Producer instance 0: addr 0x%llx, number=%u\n", 
           (unsigned long long)prod->addr, prod->number);
    printf("  Using Consumer instance 0: addr 0x%llx, number=%u\n", 
           (unsigned long long)cons->addr, cons->number);
    
    /* Verify we're using device number 0 for each type */
    if (prod->number != 0 || cons->number != 0) {
        printf("[WARN] Expected device number 0 for both, got prod=%u cons=%u\n",
               prod->number, cons->number);
    }

    unsigned max_chunks_prod = ioread32(prod, PT_NCHUNK_MAX_REG);
    unsigned max_chunks_cons = ioread32(cons, PT_NCHUNK_MAX_REG);
    if (max_chunks_prod == 0 || max_chunks_cons == 0) {
        printf("Error: scatter-gather DMA disabled for producer or consumer\n");
        return 1;
    }

    /* ------------------------------------------------------------- */
    /* Manual Memory Management Start                                */
    /* ------------------------------------------------------------- */
    
    // Start of our safe region
    uintptr_t free_mem_ptr = ACC_RESERVED_BASE;
    uintptr_t mem_end = ACC_RESERVED_BASE + ACC_RESERVED_SIZE;

    // 1. Calculate Sizes
    // printf("[DBG] Calculating sizes...\n");
    xheep_fw_section_t prod_secs[XHEEP1_FW_ESP_P2P_DMA_NUM_SECTIONS];
    xheep_fw_section_t cons_secs[XHEEP_FW_ESP_P2P_DMA_NUM_SECTIONS];
    for (unsigned s = 0; s < XHEEP1_FW_ESP_P2P_DMA_NUM_SECTIONS; ++s) {
        prod_secs[s].addr = xheep1_fw_esp_p2p_dma_sections[s].addr;
        prod_secs[s].size = xheep1_fw_esp_p2p_dma_sections[s].size;
        prod_secs[s].data = xheep1_fw_esp_p2p_dma_sections[s].data;
    }
    for (unsigned s = 0; s < XHEEP_FW_ESP_P2P_DMA_NUM_SECTIONS; ++s) {
        cons_secs[s].addr = xheep_fw_esp_p2p_dma_sections[s].addr;
        cons_secs[s].size = xheep_fw_esp_p2p_dma_sections[s].size;
        cons_secs[s].data = xheep_fw_esp_p2p_dma_sections[s].data;
    }
    size_t fw_buffer_size_prod = xheep_fw_size(prod_secs, XHEEP1_FW_ESP_P2P_DMA_NUM_SECTIONS);
    size_t fw_buffer_size_cons = xheep_fw_size(cons_secs, XHEEP_FW_ESP_P2P_DMA_NUM_SECTIONS);
    size_t out_buffer_size = XHEEP_SHARED_STR_OFFSET + XHEEP_SHARED_STR_MAX;
    out_buffer_size = (out_buffer_size + 7u) & ~7u; // Align 8

    // 2. Assign Producer Firmware Buffer
    uint8_t *fw_buffer_prod = (uint8_t *)free_mem_ptr;
    free_mem_ptr += fw_buffer_size_prod;
#if DEBUG_PRINTS
    printf("[DBG] fw_buffer_prod @ 0x%08lx (size %u)\n",
           (unsigned long)fw_buffer_prod, (unsigned)fw_buffer_size_prod);
#endif

    // 3. Assign Consumer Firmware Buffer
    free_mem_ptr = (free_mem_ptr + 7u) & ~7u; // force 8-byte alignment
    uint8_t *fw_buffer_cons = (uint8_t *)free_mem_ptr;
    free_mem_ptr += fw_buffer_size_cons;
#if DEBUG_PRINTS
    printf("[DBG] fw_buffer_cons @ 0x%08lx (size %u)\n",
           (unsigned long)fw_buffer_cons, (unsigned)fw_buffer_size_cons);
#endif

    // 4. Assign Output Buffer
    free_mem_ptr = (free_mem_ptr + 7u) & ~7u; // force 8-byte alignment
    uint8_t *out_buffer = (uint8_t *)free_mem_ptr;
    free_mem_ptr += out_buffer_size;
#if DEBUG_PRINTS
    printf("[DBG] out_buffer @ 0x%08lx (size %u)\n",
           (unsigned long)out_buffer, (unsigned)out_buffer_size);
#endif

    // Declare shared string pointer for later use
    volatile char *shared_str = (char *)out_buffer + XHEEP_SHARED_STR_OFFSET;

    // 5. Assign Page Table 1 (Producer Firmware)
    unsigned nchunk_prod = NCHUNK(fw_buffer_size_prod);
    if (nchunk_prod > max_chunks_prod) {
        printf("Error: not enough TLB entries for producer (need %u, max %u)\n", nchunk_prod, max_chunks_prod);
        return 1;
    }
    free_mem_ptr = (free_mem_ptr + 7u) & ~7u;
    unsigned **ptable_prod = (unsigned **)free_mem_ptr;
    size_t ptable_prod_size = nchunk_prod * sizeof(unsigned *);
    free_mem_ptr += ptable_prod_size;
#if DEBUG_PRINTS
    printf("[DBG] ptable_prod @ 0x%08lx (nchunk=%u)\n",
           (unsigned long)ptable_prod, nchunk_prod);
#endif

    // 6. Assign Page Table 2 (Consumer Firmware)
    unsigned nchunk_cons = NCHUNK(fw_buffer_size_cons);
    if (nchunk_cons > max_chunks_cons) {
        printf("Error: not enough TLB entries for consumer (need %u, max %u)\n", nchunk_cons, max_chunks_cons);
        return 1;
    }
    free_mem_ptr = (free_mem_ptr + 7u) & ~7u;
    unsigned **ptable_cons = (unsigned **)free_mem_ptr;
    size_t ptable_cons_size = nchunk_cons * sizeof(unsigned *);
    free_mem_ptr += ptable_cons_size;
#if DEBUG_PRINTS
    printf("[DBG] ptable_cons @ 0x%08lx (nchunk=%u)\n",
           (unsigned long)ptable_cons, nchunk_cons);
#endif

    // 7. Assign Page Table 3 (Output)
    unsigned out_nchunk = NCHUNK(out_buffer_size);
    if (out_nchunk > max_chunks_prod || out_nchunk > max_chunks_cons) {
        printf("Error: not enough TLB entries for output (need %u, max prod=%u, cons=%u)\n", 
               out_nchunk, max_chunks_prod, max_chunks_cons);
        return 1;
    }
    free_mem_ptr = (free_mem_ptr + 7u) & ~7u;
    unsigned **out_ptable = (unsigned **)free_mem_ptr;
    size_t out_ptable_size = out_nchunk * sizeof(unsigned *);
    free_mem_ptr += out_ptable_size;
#if DEBUG_PRINTS
    printf("[DBG] out_ptable @ 0x%08lx (nchunk=%u)\n",
           (unsigned long)out_ptable, out_nchunk);
#endif

    // Safety check
    if (free_mem_ptr > mem_end) {
        printf("[FATAL] Memory overflow! Needed 0x%08lx, end is 0x%08lx\n", free_mem_ptr, mem_end);
        return 1;
    }

    /* ------------------------------------------------------------- */
    /* Logic Execution                                               */
    /* ------------------------------------------------------------- */

    /* Clear output region */
    memset(out_buffer, 0, out_buffer_size);
    
    /* Explicitly zero the shared string area to ensure no stale data */
    memset((void *)shared_str, 0, XHEEP_SHARED_STR_MAX);
    // printf("[DBG] Shared string area cleared at 0x%08lx\n", (unsigned long)shared_str);

    /* Flatten firmware */
    xheep_fw_flatten(fw_buffer_prod, fw_buffer_size_prod, prod_secs,
                     XHEEP1_FW_ESP_P2P_DMA_NUM_SECTIONS);
    xheep_fw_flatten(fw_buffer_cons, fw_buffer_size_cons, cons_secs,
                     XHEEP_FW_ESP_P2P_DMA_NUM_SECTIONS);
#if DEBUG_PRINTS
    printf("[DBG] Firmware flattened.\n");
#endif

    /* Populate Page Table 1 (Producer) */
    for (unsigned i = 0; i < nchunk_prod; ++i) {
        ptable_prod[i] = (unsigned *)(fw_buffer_prod + i * CHUNK_SIZE);
    }
#if DEBUG_PRINTS
    printf("[DBG] ptable_prod[0]=0x%08lx\n", (unsigned long)ptable_prod[0]);
#endif

    /* Populate Page Table 2 (Consumer) */
    for (unsigned i = 0; i < nchunk_cons; ++i) {
        ptable_cons[i] = (unsigned *)(fw_buffer_cons + i * CHUNK_SIZE);
    }
#if DEBUG_PRINTS
    printf("[DBG] ptable_cons[0]=0x%08lx\n", (unsigned long)ptable_cons[0]);
#endif

    /* Configure DMA + coherence for Phase 1 - Consumer */
    // printf("[DBG] Consumer DMA config:\n");
    // printf("  PT_ADDRESS = 0x%08lx\n", (unsigned long)ptable_cons);
    // printf("  PT_NCHUNK = %u\n", nchunk_cons);
    // printf("  PT_SHIFT = %u\n", CHUNK_SHIFT);
    // printf("  CODE_SIZE = %u words (%u bytes)\n", fw_buffer_size_cons / 4, fw_buffer_size_cons);
    
    iowrite32(cons, COHERENCE_REG, ACC_COH_NONE);
    iowrite32(cons, PT_ADDRESS_EXTENDED_REG, 0);
    iowrite32(cons, PT_ADDRESS_REG, (unsigned long)ptable_cons);
    iowrite32(cons, PT_NCHUNK_REG, nchunk_cons);
    iowrite32(cons, PT_SHIFT_REG, CHUNK_SHIFT);
    iowrite32(cons, SRC_OFFSET_REG, 0);
    iowrite32(cons, DST_OFFSET_REG, 0);
    esp_flush(ACC_COH_NONE);

#if DEBUG_PRINTS
    printf("[DBG] consumer first run_acc starting\n");
#endif
#if PROFILE
    acc_profile_t cons_fetch_start;
    acc_profile_t cons_fetch_end;
    read_acc_profile(cons, &cons_fetch_start);
#endif
    if (!xheep_fetch_firmware(cons, fw_buffer_size_cons / 4, 0, false, 20)) return 1;
#if PROFILE
    read_acc_profile(cons, &cons_fetch_end);
#endif
#if DEBUG_PRINTS
    printf("[DBG] consumer first run_acc finished\n");
#endif
#if PROFILE
    print_acc_profile_diff("Phase 1 (fetch)", "consumer", cons, &cons_fetch_start, &cons_fetch_end);
#endif

    // /* Configure DMA + coherence for Phase 1 - Producer */
    // printf("[DBG] Producer DMA config:\n");
    // printf("  PT_ADDRESS = 0x%08lx\n", (unsigned long)ptable_prod);
    // printf("  PT_NCHUNK = %u\n", nchunk_prod);
    // printf("  PT_SHIFT = %u\n", CHUNK_SHIFT);
    // printf("  CODE_SIZE = %u words (%u bytes)\n", fw_buffer_size_prod / 4, fw_buffer_size_prod);
    
    // /* Sanity check: verify producer can be read */
    // unsigned devid_prod = ioread32(prod, DEVID_REG);
    // unsigned pt_nchunk_max_prod = ioread32(prod, PT_NCHUNK_MAX_REG);
    // printf("[DBG] Producer sanity check: DEVID=0x%08x, PT_NCHUNK_MAX=%u\n", devid_prod, pt_nchunk_max_prod);
    
    iowrite32(prod, COHERENCE_REG, ACC_COH_NONE);
    iowrite32(prod, PT_ADDRESS_EXTENDED_REG, 0);
    iowrite32(prod, PT_ADDRESS_REG, (unsigned long)ptable_prod);
    iowrite32(prod, PT_NCHUNK_REG, nchunk_prod);
    iowrite32(prod, PT_SHIFT_REG, CHUNK_SHIFT);
    iowrite32(prod, SRC_OFFSET_REG, 0);
    iowrite32(prod, DST_OFFSET_REG, 0);
    esp_flush(ACC_COH_NONE);

#if DEBUG_PRINTS
    printf("[DBG] producer first run_acc starting\n");
#endif
#if PROFILE
    acc_profile_t prod_fetch_start;
    acc_profile_t prod_fetch_end;
    read_acc_profile(prod, &prod_fetch_start);
#endif
    if (!xheep_fetch_firmware(prod, fw_buffer_size_prod / 4, 0, true, 20)) return 1;
#if PROFILE
    read_acc_profile(prod, &prod_fetch_end);
#endif
#if DEBUG_PRINTS
    printf("[DBG] producer first run_acc finished\n");
#endif
#if PROFILE
    print_acc_profile_diff("Phase 1 (fetch)", "producer", prod, &prod_fetch_start, &prod_fetch_end);
#endif

    /* Phase 2: boot - Setup P2P */
    // printf("[DBG] Setting up P2P configuration\n");
    p2p_setup(prod, cons);

    // dump_p2p_state(prod, "PROD");
    // dump_p2p_state(cons, "CONS");

    /* Phase 2: boot - Configure for both */
    xheep_program_start(prod, true);
    xheep_program_start(cons, false);

    /* Populate Page Table 3 (Output) */
    for (unsigned i = 0; i < out_nchunk; ++i) {
        out_ptable[i] = (unsigned *)(out_buffer + i * CHUNK_SIZE);
    }

    /* Re-configure DMA for Phase 2 - Producer */
    iowrite32(prod, PT_ADDRESS_REG, (unsigned long)out_ptable);
    iowrite32(prod, PT_NCHUNK_REG, out_nchunk);
    
    /* Re-configure DMA for Phase 2 - Consumer */
    iowrite32(cons, PT_ADDRESS_REG, (unsigned long)out_ptable);
    iowrite32(cons, PT_NCHUNK_REG, out_nchunk);
    
    esp_flush(ACC_COH_NONE);

#if DEBUG_PRINTS
    printf("[DBG] producer & consumer second run_acc starting\n");
#endif
#if PROFILE
    acc_profile_t prod_run_start;
    acc_profile_t cons_run_start;
    acc_profile_t prod_run_end;
    acc_profile_t cons_run_end;
    read_acc_profile(prod, &prod_run_start);
    read_acc_profile(cons, &cons_run_start);
#endif
    xheep_start(prod);
    xheep_start(cons);
    
    // printf("[DBG] waiting for both accelerators to complete\n");
    unsigned done = 0;
    unsigned polls = 0;
    while (!done) {
        unsigned status_prod = ioread32(prod, STATUS_REG);
        unsigned status_cons = ioread32(cons, STATUS_REG);
        
        bool prod_done = status_prod & STATUS_MASK_DONE;
        bool cons_done = status_cons & STATUS_MASK_DONE;
        
        done = prod_done && cons_done;
        polls++;
        if (polls % 1000 == 0) {
#if DEBUG_PRINTS
            printf("[DBG] Waiting... Prod Status: 0x%08x (Done=%d), Cons Status: 0x%08x (Done=%d)\n",
                   status_prod, prod_done, status_cons, cons_done);
#endif
            if(polls > 10000){
                printf("Accelerators timed out!\n");
                // break;
            } 
        }
    }
    iowrite32(prod, CMD_REG, 0);
    iowrite32(cons, CMD_REG, 0);
    // printf("[DBG] both accelerators finished\n");
#if PROFILE
    read_acc_profile(prod, &prod_run_end);
    read_acc_profile(cons, &cons_run_end);
    print_acc_profile_diff("Phase 2 (p2p run)", "producer", prod, &prod_run_start, &prod_run_end);
    print_acc_profile_diff("Phase 2 (p2p run)", "consumer", cons, &cons_run_start, &cons_run_end);
    {
        uint64_t prod_tot_start = acc_cycles_u64(prod_run_start.acc.acc_tot_lo, prod_run_start.acc.acc_tot_hi);
        uint64_t prod_tot_end   = acc_cycles_u64(prod_run_end.acc.acc_tot_lo, prod_run_end.acc.acc_tot_hi);
        uint64_t cons_tot_start = acc_cycles_u64(cons_run_start.acc.acc_tot_lo, cons_run_start.acc.acc_tot_hi);
        uint64_t cons_tot_end   = acc_cycles_u64(cons_run_end.acc.acc_tot_lo, cons_run_end.acc.acc_tot_hi);
        uint64_t prod_tot_diff  = diff_u64(prod_tot_start, prod_tot_end);
        uint64_t cons_tot_diff  = diff_u64(cons_tot_start, cons_tot_end);
        uint64_t combined = (prod_tot_diff > cons_tot_diff) ? prod_tot_diff : cons_tot_diff;
        printf("[MON] Phase 2 (p2p run) combined: total_cycles=max(prod=%llu, cons=%llu) = %llu\n",
               (unsigned long long)prod_tot_diff,
               (unsigned long long)cons_tot_diff,
               (unsigned long long)combined);
    }
#endif

    /* Read back result */
    printf("X-HEEP P2P message: \"%s\"\n", shared_str);

    return 0;
}

/*
═══════════════════════════════════════════════════════════════════════════════
PHASE 1: HOST SETUP (xheep_native.c)
═══════════════════════════════════════════════════════════════════════════════

1. Host loads firmware into both accelerators via DMA
   - Producer gets firmware with XHEEP_PRODUCER defined
   - Consumer gets firmware without XHEEP_PRODUCER defined

2. Host configures P2P relationship:
   
   esp_p2p_enable_src(prod);     // Producer: "My writes are P2P"
   esp_p2p_enable_dst(cons);     // Consumer: "My reads come from P2P"
   esp_p2p_set_y/x(cons, ...)    // Tell consumer where producer is located

3. Both accelerators point to same output buffer:
   - PT_ADDRESS_REG → pt_out (same physical pages)

═══════════════════════════════════════════════════════════════════════════════
PHASE 2: PRODUCER EXECUTION (main.c with XHEEP_PRODUCER)
═══════════════════════════════════════════════════════════════════════════════

4. Producer executes:
   
   p2p_dst = XHEEP_P2P_BASE_ADDR(1) + offset
   p2p_dst[i] = src_words[i];  // Write "I am happy to state that "
   
   These WRITES:
   ┌─────────────┐
   │  Producer   │
   │   (xheep1)  │──write──> "I am happy to state that "
   └─────────────┘            |
                              | (DST_IS_P2P is set)
                              ↓
                       ┌──────────────┐
                       │ NoC intercept│
                       │  & forward   │
                       └──────────────┘
                              |
                              | (Does NOT go to memory!)
                              ↓
                       ┌─────────────┐
                       │  Consumer   │
                       │  (xheep)    │← P2P buffer receives data
                       └─────────────┘

═══════════════════════════════════════════════════════════════════════════════
PHASE 3: CONSUMER EXECUTION (main.c without XHEEP_PRODUCER)
═══════════════════════════════════════════════════════════════════════════════

5. Consumer executes:
   
   p2p_source_ptr = XHEEP_P2P_BASE_ADDR(1) + offset
   dest_words[i] = p2p_source_ptr[i];  // Read!
   
   These READS:
   ┌─────────────┐
   │  Consumer   │
   │   (xheep)   │──read──> XHEEP_P2P_BASE_ADDR(1)
   └─────────────┘            |
                              | (SRC_IS_P2P is set)
                              ↓
                       ┌──────────────┐
                       │Socket detects│
                       │  P2P read    │
                       └──────────────┘
                              |
                              | (Does NOT read from memory!)
                              ↓
                    Returns data from P2P buffer
                    (previously received from producer)
                              ↓
   final_string[] = "I am happy to state that "

6. Consumer appends local data:
   
   strcat(final_string, "the P2P communication is working \n");
   
   Result: "I am happy to state that the P2P communication is working \n"

7. Consumer writes result back to memory:
   
   esp_out = XHEEP_P2P_BASE_ADDR(0) + offset
   esp_out[i] = out_words[i];  // Write final string
   
   This write:
   ┌─────────────┐
   │  Consumer   │
   │   (xheep)   │──write──> "I am happy...working"
   └─────────────┘            |
                              | (Normal DMA write)
                              ↓
                       ┌──────────────┐
                       │    Memory    │← Goes to pt_out buffer
                       │   (pt_out)   │
                       └──────────────┘

═══════════════════════════════════════════════════════════════════════════════
PHASE 4: HOST READS RESULT
═══════════════════════════════════════════════════════════════════════════════

8. Host reads out_buf and prints result
*/
