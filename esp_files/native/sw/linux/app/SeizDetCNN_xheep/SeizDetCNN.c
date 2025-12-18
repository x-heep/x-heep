// Copyright (c) 2011-2024 Columbia University, System Level Design Group
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>

#include <test/test.h>
#include <test/time.h>
#include <xheep_rtl.h>

// Include firmware binary data
#include "xheep_firmware.h"
#include "xheep_common.h"

#define XHEEP_DEVICE "/dev/xheep_rtl.0"

typedef uint32_t token_t;

static size_t fw_buffer_size;
static size_t out_buffer_size;

static void init_parameters(void)
{
    printf("[DEBUG] init_parameters: Starting...\n");
    fw_buffer_size = 0;
    for (unsigned s = 0; s < XHEEP_FIRMWARE_NUM_SECTIONS; ++s) {
        const xheep_firmware_fw_section_t *section = &xheep_firmware_sections[s];
        size_t section_end = section->addr + section->size;
        printf("[DEBUG]   Section %u: addr=0x%08x, size=%u, end=0x%08zx\n",
               s, section->addr, section->size, section_end);
        if (section_end > fw_buffer_size) {
            fw_buffer_size = section_end;
        }
    }
    fw_buffer_size = (fw_buffer_size + 7) & ~7;

    // Only allocate enough for the result region (SeizDetCNN doesn't use string region)
    out_buffer_size = XHEEP_SHARED_RES_ADDR + XHEEP_SHARED_RES_MAX_BYTES;
    out_buffer_size = (out_buffer_size + 7) & ~7;

    printf("[DEBUG] Firmware buffer size: %zu bytes (0x%zx)\n", fw_buffer_size, fw_buffer_size);
    printf("[DEBUG] Output buffer size: %zu bytes (0x%zx) - optimized for results only\n", out_buffer_size, out_buffer_size);
}

static void flatten_firmware(uint8_t *buffer, size_t buffer_size)
{
    printf("[DEBUG] flatten_firmware: Loading %u firmware sections into buffer...\n", XHEEP_FIRMWARE_NUM_SECTIONS);
    printf("[DEBUG] Buffer address: %p, size: %zu bytes\n", buffer, buffer_size);
    
    memset(buffer, 0, buffer_size);
    printf("[DEBUG] Buffer zeroed\n");

    for (unsigned s = 0; s < XHEEP_FIRMWARE_NUM_SECTIONS; ++s) {
        const xheep_firmware_fw_section_t *section = &xheep_firmware_sections[s];
        printf("[DEBUG] Processing section %u...\n", s);
        printf("[DEBUG]   addr=0x%08x, size=%u bytes, data=%p\n",
               section->addr, section->size, section->data);
        
        if (section->addr + section->size > buffer_size) {
            printf("  [WARN] Section %u (addr 0x%x size %u) exceeds buffer (size %zu)\n",
                   s, section->addr, section->size, buffer_size);
            continue;
        }
        
        printf("[DEBUG]   Copying to buffer offset 0x%08x...\n", section->addr);
        memcpy(buffer + section->addr, section->data, section->size);
        printf("[DEBUG]   Section %u copied successfully\n", s);
    }

    printf("[DEBUG] Firmware loaded successfully\n");
}

int main(int argc, char **argv)
{
    int fd;
    contig_handle_t fw_contig, out_contig;
    uint8_t *fw_buffer, *out_buffer;
    struct xheep_rtl_access desc;
    struct timespec th_start, th_end;
    unsigned long long hw_ns;
    int rc;
    int errors = 0;

    printf("\n=== X-HEEP SeizureDetCNN (Linux) ===\n\n");
    printf("[DEBUG] main: Starting...\n");

    init_parameters();

    printf("\n[DEBUG] main: Allocating %zu bytes for firmware buffer...\n", fw_buffer_size);
    fflush(stdout);
    fw_buffer = (uint8_t *)contig_alloc(fw_buffer_size, &fw_contig);
    if (fw_buffer == NULL) {
        fprintf(stderr, "ERROR: Failed to allocate firmware buffer\n");
        return 1;
    }
    printf("[DEBUG] Firmware buffer allocated at %p\n", fw_buffer);

    printf("[DEBUG] main: Allocating %zu bytes for output buffer...\n", out_buffer_size);
    fflush(stdout);
    out_buffer = (uint8_t *)contig_alloc(out_buffer_size, &out_contig);
    if (out_buffer == NULL) {
        fprintf(stderr, "ERROR: Failed to allocate output buffer\n");
        contig_free(fw_contig);
        return 1;
    }
    printf("[DEBUG] Output buffer allocated at %p\n", out_buffer);

    printf("[DEBUG] main: Zeroing output buffer...\n");
    fflush(stdout);
    memset(out_buffer, 0, out_buffer_size);
    printf("[DEBUG] Output buffer zeroed\n");

    printf("\n[DEBUG] main: Flattening firmware...\n");
    fflush(stdout);
    flatten_firmware(fw_buffer, fw_buffer_size);

    printf("\n[DEBUG] main: Opening device %s...\n", XHEEP_DEVICE);
    fflush(stdout);
    fd = open(XHEEP_DEVICE, O_RDWR, 0);
    if (fd < 0) {
        perror("open");
        contig_free(fw_contig);
        contig_free(out_contig);
        return 1;
    }
    printf("[DEBUG] Device opened successfully (fd=%d)\n", fd);

    // ========== PHASE 1: CODE FETCH ==========
    printf("\n[DEBUG] ========== PHASE 1: CODE FETCH ==========\n");
    fflush(stdout);
    
    memset(&desc, 0, sizeof(desc));
    desc.esp.contig = contig_to_khandle(fw_contig);
    desc.esp.run = true;
    desc.esp.coherence = ACC_COH_NONE;
    desc.esp.p2p_store = 0;
    desc.esp.p2p_nsrcs = 0;

    desc.code_size_words = fw_buffer_size / sizeof(token_t);
    desc.boot_fetch_code_addr = 0;
    desc.boot_fetch_code = 1;
    desc.boot_exit_loop = 0;
    desc.src_offset = 0;
    desc.dst_offset = 0;

    printf("[DEBUG] Phase 1 configuration:\n");
    printf("  code_size_words:      %u (0x%x)\n", desc.code_size_words, desc.code_size_words);
    printf("  boot_fetch_code_addr: 0x%x\n", desc.boot_fetch_code_addr);
    printf("  boot_fetch_code:      %u\n", desc.boot_fetch_code);
    printf("  boot_exit_loop:       %u\n", desc.boot_exit_loop);
    printf("  contig handle:        0x%llx\n", (unsigned long long)desc.esp.contig);
    printf("  src_offset:           0x%x\n", desc.src_offset);
    printf("  dst_offset:           0x%x\n", desc.dst_offset);

    printf("\n[DEBUG] Calling ioctl (XHEEP_RTL_IOC_ACCESS) for Phase 1...\n");
    fflush(stdout);
    gettime(&th_start);
    rc = ioctl(fd, XHEEP_RTL_IOC_ACCESS, &desc);
    gettime(&th_end);

    if (rc < 0) {
        perror("ioctl (phase 1)");
        close(fd);
        contig_free(fw_contig);
        contig_free(out_contig);
        return 1;
    }

    hw_ns = ts_subtract(&th_start, &th_end);
    printf("[DEBUG] Phase 1 ioctl returned: %d\n", rc);
    printf("[DEBUG] Phase 1 completed in %llu ns (%.3f ms)\n", hw_ns, hw_ns / 1000000.0);

    // ========== PHASE 2: BOOT AND EXECUTE ==========
    printf("\n[DEBUG] ========== PHASE 2: BOOT AND EXECUTE ==========\n");
    fflush(stdout);
    
    memset(&desc, 0, sizeof(desc));
    desc.esp.contig = contig_to_khandle(out_contig);
    desc.esp.run = true;
    desc.esp.coherence = ACC_COH_NONE;
    desc.esp.p2p_store = 0;
    desc.esp.p2p_nsrcs = 0;

    desc.code_size_words = 0;
    desc.boot_fetch_code_addr = 0;
    desc.boot_fetch_code = 0;
    desc.boot_exit_loop = 1;
    desc.src_offset = 0;
    desc.dst_offset = 0;

    printf("[DEBUG] Phase 2 configuration:\n");
    printf("  code_size_words:      %u\n", desc.code_size_words);
    printf("  boot_fetch_code_addr: 0x%x\n", desc.boot_fetch_code_addr);
    printf("  boot_fetch_code:      %u\n", desc.boot_fetch_code);
    printf("  boot_exit_loop:       %u\n", desc.boot_exit_loop);
    printf("  contig handle:        0x%llx\n", (unsigned long long)desc.esp.contig);
    printf("  src_offset:           0x%x\n", desc.src_offset);
    printf("  dst_offset:           0x%x\n", desc.dst_offset);

    printf("\n[DEBUG] Calling ioctl (XHEEP_RTL_IOC_ACCESS) for Phase 2...\n");
    fflush(stdout);
    gettime(&th_start);
    rc = ioctl(fd, XHEEP_RTL_IOC_ACCESS, &desc);
    gettime(&th_end);

    if (rc < 0) {
        perror("ioctl (phase 2)");
        close(fd);
        contig_free(fw_contig);
        contig_free(out_contig);
        return 1;
    }

    hw_ns = ts_subtract(&th_start, &th_end);
    printf("[DEBUG] Phase 2 ioctl returned: %d\n", rc);
    printf("[DEBUG] Phase 2 completed in %llu ns (%.3f ms)\n", hw_ns, hw_ns / 1000000.0);

    // ========== READ RESULTS ==========
    printf("\n[DEBUG] ========== READING RESULTS ==========\n");
    printf("[DEBUG] Reading results from output buffer at offset 0x%x...\n", XHEEP_SHARED_RES_ADDR);
    fflush(stdout);
    
    volatile uint32_t *results = (uint32_t *)((uint8_t *)out_buffer + XHEEP_SHARED_RES_ADDR);
    printf("[DEBUG] Results pointer: %p\n", (void*)results);
    
    uint32_t prediction = results[0];
    uint32_t cycles = results[1];
    int32_t fc1_out0 = (int32_t)results[2];
    int32_t fc1_out1 = (int32_t)results[3];
    
    printf("[DEBUG] Raw results[0] (prediction): 0x%08x (%u)\n", prediction, prediction);
    printf("[DEBUG] Raw results[1] (cycles):     0x%08x (%u)\n", cycles, cycles);
    printf("[DEBUG] Raw results[2] (fc1_out[0]): 0x%08x (%d)\n", results[2], fc1_out0);
    printf("[DEBUG] Raw results[3] (fc1_out[1]): 0x%08x (%d)\n", results[3], fc1_out1);

    printf("\n=== RESULTS ===\n");
    printf("X-HEEP prediction: %u (%s)\n", prediction, prediction ? "Seizure" : "Normal");
    printf("Firmware cycles (if provided): %u\n", cycles);
    printf("\nFC1 output:\n");
    printf("  fc1_out[0] = %d\n", fc1_out0);
    printf("  fc1_out[1] = %d\n", fc1_out1);

    if (prediction > 1) {
        printf("[ERROR] Prediction out of expected range [0,1]\n");
        errors++;
    }

    printf("\n[DEBUG] Closing device...\n");
    fflush(stdout);
    close(fd);
    
    printf("[DEBUG] Freeing contiguous buffers...\n");
    fflush(stdout);
    contig_free(fw_contig);
    contig_free(out_contig);

    if (errors == 0) {
        printf("\n+ Test PASSED\n");
    } else {
        printf("\n+ Test FAILED (%d errors)\n", errors);
    }

    printf("\n=== X-HEEP SeizureDetCNN Test Complete ===\n\n");
    return errors;
}