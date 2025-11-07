# Integrating X-HEEP into ESP as a Third-Party Tile

## Installation Steps

### 1. Clone X-HEEP Repository

In the ESP repository (https://github.com/sld-columbia/esp), create a new folder structure:
```bash
mkdir -p accelerators/third-party/xheep/ip
cd accelerators/third-party/xheep/ip
```

Clone X-HEEP (this branch) into the `ip` folder.

### 2. Prepare ESP Integration

From the top of the cloned X-HEEP root folder run:
```bash
make prepare_esp
```

This command will move all necessary files to their correct locations in the ESP directory structure.

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
2. **Set NoC bitwidths:**
   - Coherence NoC Planes (1,2,3) Bitwidth: `32`
   - DMA NoC Planes (4,6) Bitwidth: `32`
3. **Select X-HEEP** from the accelerator dropdown menu
4. **Click "Generate SoC config"** to apply the configuration

### 3. Generate X-HEEP MCU

Close the GUI and generate the X-HEEP MCU files:
```bash
make xheep
```

This command will:
- Generate the X-HEEP MCU
- Compile the required software
- Generate the correct hardware filelists

**Configuration Options:**
- **Hardware configuration:** Modify `$XHEEP_TOP/configs/esp_heep.hjson`
- **Software application:** Located in `$XHEEP_TOP/sw/applications/esp_app/`

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

**See the [complete reference implementation](#reference-esp-processor-test-code) below for an example of full source code working with the current esp_app.**

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

## Reference: ESP Processor Test Code

Below is the reference implementation of `systest.c` that runs on the ESP processor:

```c
// Copyright (c) 2011-2024 Columbia University, System Level Design Group
// SPDX-License-Identifier: Apache-2.0

#include <stdio.h>
#include <stdint.h>
#include "xheep_firmware.h"
#include "core_v_mini_mcu.h"
#include "power_manager_regs.h"
#include "xheep_common.h"

#define XHEEP_BASE_ADDR 0x60400000u
#define MEMORY_BASE_ADDR 0x80000000u

int main(int argc, char **argv)
{
    printf("Hello from ESP!\n");
    printf("[DEBUG] Starting X-HEEP initialization...\n");

    /* 2.5) Initialize shared memory location to prevent X propagation */
    printf("[DEBUG] Initializing shared memory at 0x%x to zero...\n", XHEEP_SHARED_STR_ADDR);
    volatile unsigned *shared_mem = (volatile unsigned *)(uintptr_t)(XHEEP_BASE_ADDR + XHEEP_SHARED_STR_ADDR);
    for (unsigned i = 0; i < XHEEP_SHARED_STR_MAX / 4; ++i) {
        shared_mem[i] = 0;
    }

    /* 2) Load firmware sections to their respective addresses */
    printf("[DEBUG] Loading %u firmware sections...\n", XHEEP_FIRMWARE_NUM_SECTIONS);
    
    for (unsigned s = 0; s < XHEEP_FIRMWARE_NUM_SECTIONS; ++s) {
        const fw_section_t *section = &xheep_firmware_sections[s];
        volatile unsigned *dest = (volatile unsigned *)(uintptr_t)(XHEEP_BASE_ADDR + section->addr);
        const unsigned *src = section->data;
        unsigned words = (section->size + 3) / 4;  // Round up to word
        
        printf("[DEBUG] Section %u: 0x%08x, %u bytes (%u words)\n", 
               s, section->addr, section->size, words);
        
        for (unsigned i = 0; i < words; ++i) {
            dest[i] = src[i];
        }
    }

    printf("[DEBUG] Firmware loaded successfully\n");

    /* 4) Program BOOT control (JTAG/debug path = 0; flash path = 1) */
    printf("[DEBUG] Setting BOOT_SELECT to JTAG/debug path (0) at address 0x%08x\n",
        (unsigned)(XHEEP_BASE_ADDR + XHEEP_BOOT_SELECT_ADDR));
    *(volatile unsigned *)(uintptr_t)(XHEEP_BASE_ADDR + XHEEP_BOOT_SELECT_ADDR) = 0u; // 0=JTAG/debug, 1=FLASH

    /* 5) Set BOOT_ADDRESS register to firmware entry point */
    /* NOTE: This register is NOT reset by CPU reset, so set explicitly */
    printf("[DEBUG] Setting BOOT_ADDRESS register to 0x%x at address 0x%08x\n",
        XHEEP_FW_ENTRY_POINT, (unsigned)(XHEEP_BASE_ADDR + XHEEP_BOOT_ADDRESS_ADDR));
    *(volatile unsigned *)(uintptr_t)(XHEEP_BASE_ADDR + XHEEP_BOOT_ADDRESS_ADDR) = XHEEP_FW_ENTRY_POINT;

    /* 7) Tell boot ROM to exit loop and jump to BOOT_ADDRESS (0x180) */
    printf("[DEBUG] Setting BOOT_EXIT_LOOP=1 at address 0x%08x\n",
        (unsigned)(XHEEP_BASE_ADDR + XHEEP_BOOT_EXIT_LOOP_ADDR));
    *(volatile unsigned *)(uintptr_t)(XHEEP_BASE_ADDR + XHEEP_BOOT_EXIT_LOOP_ADDR) = 1u;
    printf("[DEBUG] Boot ROM should now jump to firmware at 0x%03x (.__boot_address)\n", XHEEP_FW_ENTRY_POINT);

    /* 9) Add delay to let X-HEEP firmware execute before polling */
    printf("[DEBUG] Waiting for X-HEEP to execute...\n");
    for (volatile unsigned delay = 0; delay < 100; delay++) {
        /* busy wait to give X-HEEP time to run */
    }

    /* 10) Read back the string from X-HEEP RAM and print it */
    printf("[DEBUG] Reading string from X-HEEP shared memory at 0x%08x...\n", 
            (unsigned)(XHEEP_BASE_ADDR + XHEEP_SHARED_STR_ADDR));
    volatile const char *p = (volatile const char *)(uintptr_t)(XHEEP_BASE_ADDR + XHEEP_SHARED_STR_ADDR);

    /* Poll until we get a non-zero first character (indicating X-HEEP wrote something) */
    const unsigned max_spin = 2u; 
    unsigned spins = 0;
    while (p[0] == '\0' && spins < max_spin) {
        spins++;
        /* Small delay between polls to give X-HEEP time */
        for (volatile unsigned d = 0; d < 100; d++);
    }
    if (p[0] == '\0') {
        printf("[WARN] Shared string still empty after timeout\n");
    }

    char buf[XHEEP_SHARED_STR_MAX];
    unsigned i = 0;
    for (; i + 1 < XHEEP_SHARED_STR_MAX; ++i) {
        char c = p[i];
        buf[i] = c;
        if (c == '\0') break;
    }
    if (i + 1 >= XHEEP_SHARED_STR_MAX) buf[XHEEP_SHARED_STR_MAX - 1] = '\0';

    printf("[DEBUG] String read complete (%u bytes)\n", i);
    printf("X-HEEP says from APB: %s\n", buf);

    /* 11) Read back the string X-HEEP wrote to external memory via AXI */
    printf("[DEBUG] Reading string from external memory at 0x%08x...\n",
           (unsigned)MEMORY_BASE_ADDR);
    volatile const char *q_8000 = (volatile const char *)(uintptr_t)(MEMORY_BASE_ADDR + XHEEP_SHARED_STR_ADDR);

    char buf_axi[XHEEP_SHARED_STR_MAX];
    unsigned j = 0;
    for (j = 0 ; j + 1 < XHEEP_SHARED_STR_MAX; ++j) {
        char c = q_8000[j];
        buf_axi[j] = c;
        if (c == '\0') break;
    }
    if (j + 1 >= XHEEP_SHARED_STR_MAX) buf_axi[XHEEP_SHARED_STR_MAX - 1] = '\0';

    printf("[DEBUG] AXI string read complete (%u bytes)\n", j);
    printf("X-HEEP says from AXI: %s\n", buf_axi);

}
```

---

## Summary

| Step | Command | Description |
|------|---------|-------------|
| 1 | `make prepare_esp` | Prepare ESP integration |
| 2 | `make esp-xconfig` | Configure SoC with GUI |
| 3 | `make xheep` | Generate X-HEEP MCU and software |
| 4 | `make sim` or `make sim-gui` | Launch simulation |