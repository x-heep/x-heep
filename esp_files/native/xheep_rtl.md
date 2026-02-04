This document describes how the X-Heep RTL accelerator is integrated into ESP and how to build and interface with it.

## Main make targets
These are the make targets for the X-Heep flow:
- `sw`: builds the X-Heep firmware and generates the header/blob that ESP will embed and load at runtime.
- `hw`: builds the RTL wrappers and integrates the accelerator into the ESP build.
- `xheep-vivado`: runs the Vivado flow for the X-Heep-enabled design.

## Folder structure (accelerators/rtl/xheep_rtl)
- `hw/`: RTL wrappers that instantiate X-Heep inside ESP.
  - `hw/src/xheep_rtl_basic_dma64/xheep_rtl_basic_dma64.v`: top wrapper for X-Heep (core-v-mini-mcu) and support modules.
  - `hw/src/xheep_rtl_basic_dma64/obi_to_esp_dma64.sv`: OBI to ESP DMA bridge.
  - `hw/src/xheep_rtl_basic_dma64/xheep_boot_controller_dma64.sv`: boot controller and code fetch logic.
  - same for the 32bit versions.
- `sw/`: software side for X-Heep (headers, build rules, and examples).
- `vendor/x-heep/`: upstream X-Heep repository.
- `create_xheep_instance.py`: helper script to generate a new instance/variant.


## Creating a new X-Heep instance
Use `accelerators/rtl/xheep_rtl/create_xheep_instance.py` to generate a new instance with a different configuration. The script generates the RTL and software scaffolding for a new variant; keep the resulting instance under `accelerators/rtl/xheep_rtl/hw` and its matching software under `accelerators/rtl/xheep_rtl/sw` so the build system can pick it up.

## Interface between X-Heep and ESP
The integration is bidirectional:
- X-Heep acts as a master when issuing transactions through the OBI to ESP DMA bridge.
- ESP controls boot and runtime behavior through X-Heep CSRs.

### X-Heep -> ESP (writes from X-Heep)
X-Heep must write into the ESP external slave window. Use the `EXT_SLAVE_START_ADDRESS` region for all outbound transfers from X-Heep into ESP. This is required by the ESP memory map and by the DMA bridge.

When X-Heep writes to ESP:
- Target addresses must be in the `EXT_SLAVE_START_ADDRESS` range.
- The ESP user fields must be set to identify if the operation is regular, point-to-point or multicast.

#### Point-to-point and multicast (user field encoding)
The OBI-to-ESP bridge encodes the ESP DMA user field from the OBI address: `dma_*_ctrl_data_user = addr[27:22]`. X-Heep must program these bits when accessing the `EXT_SLAVE_START_ADDRESS` region.

- **Read (source selection)**: `addr[27:22] = 0` selects the default source. Non-zero values select a source entry from the software-programmed tile lookup table.
- **Write (P2P vs multicast)**: `addr[27:22] = 1` requests point-to-point (single consumer). Values greater than 1 request multicast with that number of consumers.

In practice, build the outbound address as `EXT_SLAVE_START_ADDRESS + (user << 22) + offset` so the bridge forwards the user field correctly.

### Burst DMA transfers (X-Heep initiated)
X-Heep can initiate burst DMA transfers through a small CSR window at the end of the ESP external slave space. This supports both read bursts (ESP -> X-Heep) and write bursts (X-Heep -> ESP), while keeping single-word accesses unchanged.

CSR window:
- Base: `0xF0FFF000` (last 4KB of `0xF0000000–0xF0FFFFFF`)

Registers (word-aligned):
- `0x00 DMA_CTRL`: `START`, `DIR`, `READ_USER_FIELD`, `WRITE_USER_FIELD`
- `0x04 DMA_STATUS`: `BUSY`, `DONE` (W1C), `ERR` (W1C)
- `0x08 DMA_ADDR`: ESP byte address (same address format used by single-word ops)
- `0x0C DMA_LEN_BYTES`: length in bytes (converted to beats in hardware)
- `0x10 XHEEP_ADDR`: X-Heep byte address (local RAM start for the burst)

Behavior:
- For non-multiple-of-8 lengths, the last beat is zero-padded on write; on read, only the valid bytes are written to X-Heep RAM.
- Boot controller still has highest priority on the OBI master port, so burst transfers may stall while boot is active.

Software helpers are available in `vendor/x-heep/sw/esp_common/esp_heep.h` (see `esp_dma_config_t` and the DMA helper functions).

### ESP -> X-Heep (boot and control)
ESP must load and start X-Heep firmware by writing X-Heep CSRs:
- `code_size_words`: size of the X-Heep code (in words).
- `boot_fetch_code_addr`: address where the X-Heep code is stored.
- `boot_fetch_code`: set to 1 to trigger the fetch into X-Heep memory.
- `boot_exit_loop`: set to 1 to start execution after the fetch completes.

