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

// Define token type for firmware data
typedef uint32_t token_t;

static size_t fw_buffer_size;
static size_t out_buffer_size;

static void init_parameters(void)
{
    // Calculate total firmware size from all sections
    fw_buffer_size = 0;
    for (unsigned s = 0; s < XHEEP_FIRMWARE_NUM_SECTIONS; ++s) {
        const xheep_firmware_fw_section_t *section = &xheep_firmware_sections[s];
        size_t section_end = section->addr + section->size;
        if (section_end > fw_buffer_size) {
            fw_buffer_size = section_end;
        }
    }
    
    // Align to 8-byte boundary
    fw_buffer_size = (fw_buffer_size + 7) & ~7;
    
    // Output buffer contains shared memory region
    out_buffer_size = XHEEP_SHARED_STR_ADDR + XHEEP_SHARED_STR_MAX;
    out_buffer_size = (out_buffer_size + 7) & ~7;
    
    printf("[DEBUG] Firmware buffer size: %zu bytes\n", fw_buffer_size);
    printf("[DEBUG] Output buffer size: %zu bytes\n", out_buffer_size);
}

static void flatten_firmware(uint8_t *buffer, size_t buffer_size)
{
    printf("[DEBUG] Loading %u firmware sections into buffer...\n", XHEEP_FIRMWARE_NUM_SECTIONS);
    
    // Zero out the firmware area first
    memset(buffer, 0, buffer_size);
    
    // Load each firmware section
    for (unsigned s = 0; s < XHEEP_FIRMWARE_NUM_SECTIONS; ++s) {
        const xheep_firmware_fw_section_t *section = &xheep_firmware_sections[s];
        if (section->addr + section->size > buffer_size) {
            printf("  [WARN] Section %u (addr 0x%x size %u) exceeds buffer (size %zu)\n",
                   s, section->addr, section->size, buffer_size);
            continue;
        }
        memcpy(buffer + section->addr, section->data, section->size);
        
        printf("[DEBUG]   Section %u: addr=0x%08x, size=%u bytes\n", 
               s, section->addr, section->size);
    }
    
    printf("[DEBUG] Firmware loaded successfully\n");
}

/* Simple substring check */
static bool contains_str(const char *haystack, const char *needle)
{
    if (!*needle) return true;
    for (const char *h = haystack; *h; ++h) {
        if (*h != *needle) continue;
        const char *h_it = h;
        const char *n_it = needle;
        while (*h_it && *n_it && *h_it == *n_it) {
            ++h_it;
            ++n_it;
        }
        if (*n_it == '\0') return true;
    }
    return false;
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
    
    printf("\n=== X-HEEP Native Accelerator (Linux) ===\n\n");
    
    // Initialize parameters
    init_parameters();
    
    // Allocate firmware buffer
    printf("[DEBUG] Allocating %zu bytes for firmware buffer...\n", fw_buffer_size);
    fw_buffer = (uint8_t *)contig_alloc(fw_buffer_size, &fw_contig);
    if (fw_buffer == NULL) {
        fprintf(stderr, "ERROR: Failed to allocate firmware buffer\n");
        return 1;
    }
    printf("[DEBUG] Firmware buffer allocated at %p\n", fw_buffer);
    
    // Allocate output buffer
    printf("[DEBUG] Allocating %zu bytes for output buffer...\n", out_buffer_size);
    out_buffer = (uint8_t *)contig_alloc(out_buffer_size, &out_contig);
    if (out_buffer == NULL) {
        fprintf(stderr, "ERROR: Failed to allocate output buffer\n");
        contig_free(fw_contig);
        return 1;
    }
    printf("[DEBUG] Output buffer allocated at %p\n", out_buffer);
    
    // Clear output buffer
    memset(out_buffer, 0, out_buffer_size);
    out_buffer[XHEEP_SHARED_STR_ADDR] = 0;
    
    // Flatten firmware into fw_buffer
    flatten_firmware(fw_buffer, fw_buffer_size);
    
    // Open X-HEEP device
    printf("[DEBUG] Opening device %s...\n", XHEEP_DEVICE);
    fd = open(XHEEP_DEVICE, O_RDWR, 0);
    if (fd < 0) {
        perror("open");
        contig_free(fw_contig);
        contig_free(out_contig);
        return 1;
    }
    printf("[DEBUG] Device opened successfully\n");
    
    /* ============================================================ */
    /* Phase 1: Fetch code via DMA                                  */
    /* ============================================================ */
    
    memset(&desc, 0, sizeof(desc));
    desc.esp.contig = contig_to_khandle(fw_contig);
    desc.esp.run = true;
    desc.esp.coherence = ACC_COH_NONE;
    desc.esp.p2p_store = 0;
    desc.esp.p2p_nsrcs = 0;
    
    desc.code_size_words = fw_buffer_size / 4;
    desc.boot_fetch_code_addr = 0;
    desc.boot_fetch_code = 1;
    desc.boot_exit_loop = 0;
    desc.src_offset = 0;
    desc.dst_offset = 0;
    
    printf("\n[DEBUG] Phase 1: Fetch Code\n");
    printf("  code_size_words:      %u\n", desc.code_size_words);
    printf("  boot_fetch_code:      %u\n", desc.boot_fetch_code);
    printf("  boot_exit_loop:       %u\n", desc.boot_exit_loop);
    
    printf("[DEBUG] Starting Phase 1 (code fetch)...\n");
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
    printf("[DEBUG] Phase 1 completed in %llu ns\n", hw_ns);
    
    /* ============================================================ */
    /* Phase 2: Boot and execute                                    */
    /* ============================================================ */
    
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
    
    printf("\n[DEBUG] Phase 2: Boot and Execute\n");
    printf("  code_size_words:      %u\n", desc.code_size_words);
    printf("  boot_fetch_code:      %u\n", desc.boot_fetch_code);
    printf("  boot_exit_loop:       %u\n", desc.boot_exit_loop);
    
    printf("[DEBUG] Starting Phase 2 (boot and execute)...\n");
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
    printf("[DEBUG] Phase 2 completed in %llu ns\n", hw_ns);
    
    /* ============================================================ */
    /* Read back results                                            */
    /* ============================================================ */
    
    printf("\n[DEBUG] Reading results from output buffer...\n");
    volatile char *shared_str = (char *)out_buffer + XHEEP_SHARED_STR_ADDR;
    printf("X-HEEP message: \"%s\"\n", shared_str);
    
    // Validate results
    if (!contains_str((const char *)shared_str, "Hello from X-Heep Native tile")) {
        printf("[ERROR] Expected string not found\n");
        errors++;
    }
    
    // Cleanup
    close(fd);
    contig_free(fw_contig);
    contig_free(out_contig);
    
    if (errors == 0) {
        printf("\n+ Test PASSED\n");
    } else {
        printf("\n+ Test FAILED (%d errors)\n", errors);
    }
    
    printf("\n=== X-HEEP Native Accelerator Test Complete ===\n\n");
    
    return errors;
}
