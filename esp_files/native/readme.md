# Integrating X-HEEP into ESP as a Native Accelerator Tile

## Installation Steps

### 1. Clone X-HEEP Repository

In the ESP repository (https://github.com/sld-columbia/esp), clone X-HEEP into the native accelerator location:


### 2. Prepare ESP Integration

From the top of the cloned X-HEEP root folder run:
```bash
make prepare-xheep-native
```

This copies the native bundle into `accelerators/rtl/xheep_rtl`.

---

## Environment Setup

### Prerequisites

You need the following tools and environments configured:

1. **ESP Environment** (required):
   - ESP RISC-V toolchain
   - ModelSim
   - Vivado (optional, for FPGA synthesis)
   - Setup tutorial: https://www.esp.cs.columbia.edu/docs/setup/setup-guide/

2. **X-HEEP Environment** (required):
   - Export the `RISCV_XHEEP` environment variable as described here:  
     https://x-heep.readthedocs.io/en/latest/GettingStarted/index.html
   - Activate the conda environment:
     ```bash
     conda activate core-v-mini-mcu
     ```

---

## Building and Simulating

### 1. Configure the SoC

Navigate to your target SoC directory (any SoC in the `socs` folder is supported):
```bash
cd $ESP_TOP/socs/xilinx-vc707-xc7vx485t
make esp-xconfig
```

### 2. Add X-HEEP Accelerator Tile

In the GUI configuration tool:

1. **Add an accelerator tile**
2. **Set NoC bitwidths (32 or 64 supported):**
   - Coherence NoC Planes (1,2,3)
   - DMA NoC Planes (4,6)
3. **Select xheep_rtl** from the accelerator dropdown menu
4. **Click "Generate SoC config"** to apply the configuration

### 3. Generate X-HEEP MCU

From the native accelerator root:
```bash
cd $ESP_TOP/accelerators/rtl/xheep_rtl
make xheep        # or: make xheep-vivado for fpga synthesis
```

This will:
- Generate the X-HEEP MCU
- Compile the required software
- Generate the correct hardware filelists

**Configuration Options:**
- **Hardware configuration:** Modify `$ESP_TOP/accelerators/rtl/xheep_rtl/vendor/xheep/configs/esp_heep.hjson`
- **Software application:** Located in `$ESP_TOP/accelerators/rtl/xheep_rtl/vendor/xheep/sw/applications/esp_app_native/`

### 4. ESP Processor Software

The ESP processor will execute the test program located at:
```
socs/xilinx-vc707-xc7vx485t/systest.c
```

This file contains the main software that:
- Initializes X-HEEP
- Loads the firmware into X-HEEP memory
- Configures boot settings
- Communicates with X-HEEP via APB and AXI interfaces

### 5. Run Simulation

Launch ModelSim and simulate:
```bash
# Terminal-based simulation
make sim

# GUI-based simulation
make sim-gui
```

In the ModelSim terminal, run:
```tcl
run -all
```

---

## Reference: Native Example App

The native baremetal test used by ESP lives at `soft/common/apps/baremetal/xheep_native/xheep_native.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include "esp_accelerator.h"
#include "esp_probe.h"
#include "xheep_firmware.h"
#include "xheep_common.h"

#define ACC_COMPAT      "sld,xheep_rtl"
#define ACC_NAME        "xheep_rtl"
#define ACC_VENDOR      VENDOR_SLD
#define ACC_DEVID       0x066
#define CHUNK_SHIFT     20
#define CHUNK_SIZE      (1u << CHUNK_SHIFT)
#define USR_BASE        0x40

/* * CRITICAL FIX: Memory Base Address 
 * Matches 'accelerator_reserved' in Device Tree 
 */
#define ACC_RESERVED_BASE 0x82000000
#define ACC_RESERVED_SIZE 0x01000000

/* Config register indices (match xheep.xml order) */
#define CONF_IDX_CODE_SIZE      0
#define CONF_IDX_FETCH_ADDR     1
#define CONF_IDX_FETCH_TRIGGER  2
#define CONF_IDX_EXIT_TRIGGER   3
#define NUM_CONFIG_REGS         4

static unsigned nchunk_for_size(size_t bytes)
{
    return (bytes + CHUNK_SIZE - 1) >> CHUNK_SHIFT;
}

/* Simple substring check to avoid pulling in libc strstr (not available in baremetal) */
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

static void flatten_firmware(uint8_t *buffer, size_t buffer_size)
{
    for (unsigned s = 0; s < XHEEP_FIRMWARE_NUM_SECTIONS; ++s) {
        const xheep_firmware_fw_section_t *sec = &xheep_firmware_sections[s];
        if (sec->addr + sec->size > buffer_size) {
            printf("  [WARN] Section %u (addr 0x%x size %u) exceeds buffer (size %lu)\n",
                   s, sec->addr, sec->size, buffer_size);
            continue;
        }
        memcpy(buffer + sec->addr, sec->data, sec->size);
    }
}

static void program_conf_regs(struct esp_device *dev, const unsigned *conf_regs)
{
    for (unsigned i = 0; i < NUM_CONFIG_REGS; ++i) {
        iowrite32(dev, (USR_BASE + 4 * i), conf_regs[i]);
    }
}

static bool run_acc(struct esp_device *dev)
{
    const unsigned max_polls = 20; // simple timeout to avoid hanging forever
    unsigned status = ioread32(dev, STATUS_REG);
    printf("  [DBG] run_acc start: STATUS=0x%08x\n", status);
    iowrite32(dev, CMD_REG, CMD_MASK_START);
    unsigned polls = 0;
    while (!(status = ioread32(dev, STATUS_REG)) || !(status & STATUS_MASK_DONE)) {
        printf("[DBG] run_acc polling %u: STATUS=0x%08x\n", polls, status);
        if (++polls >= max_polls) {
            printf("[WARN] Accelerator timeout after %u polls (STATUS=0x%08x)\n",
                   polls, status);
            return false;
        }
    }
    iowrite32(dev, CMD_REG, 0x0);
    printf("  [DBG] run_acc done after %u polls: STATUS=0x%08x\n", polls, status);
    return true;
}

int main(int argc, char **argv)
{
    printf("\n=== X-HEEP Native Accelerator (baremetal - static alloc) ===\n");

    struct esp_device *devs = NULL;
    int ndev = probe(&devs, ACC_VENDOR, ACC_DEVID, ACC_COMPAT);
    printf("[DBG] after probe: ndev=%d\n", ndev);
    if (ndev <= 0) {
        printf("Error: accelerator '%s' not found\n", ACC_COMPAT);
        return 1;
    }
    struct esp_device *dev = &devs[0];
    printf("  Found at addr 0x%llx\n", (unsigned long long)dev->addr);

    unsigned max_chunks = ioread32(dev, PT_NCHUNK_MAX_REG);
    if (max_chunks == 0) {
        printf("Error: scatter-gather DMA disabled for this accelerator\n");
        return 1;
    }

    uintptr_t free_mem_ptr = ACC_RESERVED_BASE;
    uintptr_t mem_end = ACC_RESERVED_BASE + ACC_RESERVED_SIZE;

    size_t fw_buffer_size = 0;
    for (int i = 0; i < XHEEP_FIRMWARE_NUM_SECTIONS; i++) {
        size_t end = xheep_firmware_sections[i].addr + xheep_firmware_sections[i].size;
        if (end > fw_buffer_size) fw_buffer_size = end;
    }
    fw_buffer_size = (fw_buffer_size + 7u) & ~7u; // Align 8
    size_t out_buffer_size = XHEEP_SHARED_STR_ADDR + XHEEP_SHARED_STR_MAX;
    out_buffer_size = (out_buffer_size + 7u) & ~7u; // Align 8

    uint8_t *fw_buffer = (uint8_t *)free_mem_ptr;
    free_mem_ptr += fw_buffer_size;

    free_mem_ptr = (free_mem_ptr + 7u) & ~7u; 
    uint8_t *out_buffer = (uint8_t *)free_mem_ptr;
    free_mem_ptr += out_buffer_size;

    unsigned nchunk = nchunk_for_size(fw_buffer_size);
    if (nchunk > max_chunks) {
        printf("Error: not enough TLB entries (need %u, max %u)\n", nchunk, max_chunks);
        return 1;
    }
    free_mem_ptr = (free_mem_ptr + 7u) & ~7u;
    unsigned **ptable = (unsigned **)free_mem_ptr;
    size_t ptable_size = nchunk * sizeof(unsigned *);
    free_mem_ptr += ptable_size;

    unsigned out_nchunk = nchunk_for_size(out_buffer_size);
    if (out_nchunk > max_chunks) {
        printf("Error: not enough TLB entries for output (need %u, max %u)\n", out_nchunk, max_chunks);
        return 1;
    }
    free_mem_ptr = (free_mem_ptr + 7u) & ~7u;
    unsigned **out_ptable = (unsigned **)free_mem_ptr;
    size_t out_ptable_size = out_nchunk * sizeof(unsigned *);
    free_mem_ptr += out_ptable_size;

    if (free_mem_ptr > mem_end) {
        printf("[FATAL] Memory overflow! Needed 0x%08lx, end is 0x%08lx\n", free_mem_ptr, mem_end);
        return 1;
    }

    out_buffer[XHEEP_SHARED_STR_ADDR] = 0;

    flatten_firmware(fw_buffer, fw_buffer_size);
    printf("[DBG] Firmware flattened.\n");

    for (unsigned i = 0; i < nchunk; ++i) {
        ptable[i] = (unsigned *)(fw_buffer + i * CHUNK_SIZE);
    }

    iowrite32(dev, COHERENCE_REG, ACC_COH_NONE);
    iowrite32(dev, PT_ADDRESS_EXTENDED_REG, 0);
    iowrite32(dev, PT_ADDRESS_REG, (unsigned long)ptable);
    iowrite32(dev, PT_NCHUNK_REG, nchunk);
    iowrite32(dev, PT_SHIFT_REG, CHUNK_SHIFT);
    iowrite32(dev, SRC_OFFSET_REG, 0);
    iowrite32(dev, DST_OFFSET_REG, 0);
    esp_flush(ACC_COH_NONE);

    unsigned conf_regs[NUM_CONFIG_REGS];
    conf_regs[CONF_IDX_CODE_SIZE]     = fw_buffer_size / 4; 
    conf_regs[CONF_IDX_FETCH_ADDR]    = 0;
    conf_regs[CONF_IDX_FETCH_TRIGGER] = 1;
    conf_regs[CONF_IDX_EXIT_TRIGGER]  = 0;
    program_conf_regs(dev, conf_regs);
    
    printf("[DBG] first run_acc starting\n");
    if (!run_acc(dev)) return 1;
    printf("[DBG] first run_acc finished\n");

    conf_regs[CONF_IDX_CODE_SIZE]     = 0;
    conf_regs[CONF_IDX_FETCH_ADDR]    = 0;
    conf_regs[CONF_IDX_FETCH_TRIGGER] = 0;
    conf_regs[CONF_IDX_EXIT_TRIGGER]  = 1;
    program_conf_regs(dev, conf_regs);

    for (unsigned i = 0; i < out_nchunk; ++i) {
        out_ptable[i] = (unsigned *)(out_buffer + i * CHUNK_SIZE);
    }

    iowrite32(dev, PT_ADDRESS_REG, (unsigned long)out_ptable);
    iowrite32(dev, PT_NCHUNK_REG, out_nchunk);
    esp_flush(ACC_COH_NONE);

    printf("[DBG] second run_acc starting\n");
    if (!run_acc(dev)) return 1;
    printf("[DBG] second run_acc finished\n");

    volatile char *shared_str = (char *)out_buffer + XHEEP_SHARED_STR_ADDR;
    printf("X-HEEP message: \"%s\"\n", shared_str);
    int status = contains_str((const char *)shared_str, "Hello from X-Heep Native tile") ? 0 : 1;
    if (status)
        printf("FAIL: Expected string not found\n");
    else
        printf("PASS\n");

    return status;
}
```

---

## Summary

| Step | Command | Description |
|------|---------|-------------|
| 1 | `make prepare-xheep-native` | Prepare ESP integration |
| 2 | `make esp-xconfig` | Configure SoC with GUI |
| 3 | `make xheep` (or `make xheep-vivado`) | Generate X-HEEP MCU and software |
| 4 | `make sim` or `make sim-gui` | Launch simulation |
