# W25Q128JW controller

```{contents} Table of Contents
:depth: 2
```

This IP controls the `SPI Host IP` inside the SPI Subsystem and the `DMA channel 0` to automatically performs read and write operation to the `W25Q128JW` Flash.

End-to-end usage examples (register setup, ISR, and verification) can be found under:
- `sw/applications/example_w25q128jw_read/`
- `sw/applications/example_w25q128jw_write/`
- `sw/applications/example_w25q128jw_memio/`

## Preliminary Definitions

### Transaction

It gets as input the `Flash` address and the `SRAM` address (if the cache is not enabled), whether it is a read or write operations, and then it starts the transaction. It can be configured to raise an interrupt when done.

### Registers

| Register | Bits | Access | Description |
|---|---|---|---|
| `STATUS` | `[0]` READY | R | Reads `1` when the controller is idle and ready for a new transaction. Poll before writing a new transaction. |
| `STATUS` | `[1]` CACHE | R | Reads `1` when the cache is enabled |
| `F_ADDRESS` | `[31:0]` | RW | Byte address in flash to read from or write to. |
| `S_ADDRESS` | `[31:0]` | RW | SRAM address used as destination (read) or temporary sector buffer (write). |
| `MD_ADDRESS` | `[31:0]` | RW | SRAM address of the new data to write into flash. Only relevant for write transactions; set to any valid address for reads. |
| `LENGTH` | `[31:0]` | RW | Number of bytes to transfer. |
| `CONTROL` | `[0]` START | RW | Write `1` to start the transaction. The controller clears this bit when done. |
| `CONTROL` | `[1]` RNW | RW | `1` = read (flash → SRAM), `0` = write (SRAM → flash). |
| `CONTROL` | `[2]` QUAD | RW | `1` = Quad SPI mode, `0` = standard single SPI mode. (fallback to standard SPI if not supported) |
| `INTR_ENABLE` | `[0]` | RW | Write `1` to enable the done interrupt. |
| `INTR_STATUS` | `[0]` | RW | Set by hardware when the transaction completes. Write `0` to clear from the ISR. |
| `DMA_SLOT_WAIT_COUNTER` | `[7:0]` | RW | Optional wait counter inserted between DMA slot requests. Set to `0` to disable. |
| `CACHE_DATA` | `[31:0]` | R | Address used to transfer data to/from the cache. (Only available when cache is enabled) |

### Starting a Transaction

Write registers in this order:

1. Write `F_ADDRESS` — flash byte address.
2. Write `S_ADDRESS` — SRAM buffer address.
3. Write `MD_ADDRESS` — SRAM address of source data (required for writes without cache; set to any valid address for reads or with cache).
4. Write `LENGTH` — number of bytes.
5. Write `CONTROL.RNW` and `CONTROL.QUAD` as needed.
6. Set `CONTROL.START = 1` to launch the transaction.

On completion the controller clears `CONTROL.START` and sets `STATUS.READY` (`1` when the top FSM returns to `TOP_IDLE`). Poll `STATUS.READY` to wait for completion. If interrupts are enabled (`INTR_ENABLE = 1`), `INTR_STATUS` is also set on completion; clear it from the ISR by calling `w25q128jw_controller_clear_status_register()` (clears bit 0 of `INTR_STATUS`).

`w25q128jw_controller_read` and `w25q128jw_controller_write` are convenience functions that perform the above sequence in a single call.

## Write-Back Cache

The controller integrates an optional direct-mapped write-back cache to reduce redundant SPI transactions when the same flash sector is accessed repeatedly.

### Motivation

Each uncached flash read requires a full DMA setup and SPI command sequence (~66 500 clock cycles at 100 MHz). A write requires an additional sector erase and 16 page-program operations (~80 000 cycles, or ~1.47 ms). By caching the active sector in on-chip SRAM, subsequent accesses to the same sector are served in a single clock cycle, reducing per-access cost by a factor of 1024 for sector-local workloads.

### Architecture

The cache is parameterised by `N_SETS`. The instantiation is with `N_SETS=4`, giving four independent cache lines of one flash sector (4 KiB) each, 16 KiB total.

Each 24-bit flash byte address is decomposed as:

| Field | Bits | Width | Purpose |
|---|---|---|---|
| Tag | `[23:14]` | 10 bits | Identifies which sector is cached |
| Set index | `[13:12]` | 2 bits | Selects one of the four cache lines |
| Byte offset | `[11:0]` | 12 bits | Position within the 4 KiB sector |

Each cache line holds one metadata entry: a **valid** bit and a **dirty** bit. A **hit** occurs when `valid[set]` is asserted and `tag[set] == addr[23:14]`.

### Operation

**Read hit:** Data is streamed from the SRAM cache line to the destination via DMA. The SPI bus is not used.

**Read miss:** If the victim line is dirty, it is written back to flash first (erase + page-program). The new sector is then fetched from flash into the cache line, and the request is served.

**Write hit:** Data is written directly into the SRAM cache line. The dirty bit is set. Flash is not touched.

**Write miss:** Same eviction check as a read miss, then the sector is fetched, modified in cache, and the dirty bit is set.

**Eviction:** Triggered on any miss when the target set is occupied by a dirty line. The controller reads the victim sector from cache and writes it to the correct flash address before installing the new line.

### Memory-Mapped Access

When the cache is enabled, the controller exposes a memory-mapped interface to the flash memory. Data can be read from or written using the address of the flash memory, and the controller will automatically handle the transfer using the cache. Byte granularity access is supported. The DMA must be configured to accept operation from hardware with `dma_set_hw_configuration_mode(1,0);` to allow the controller to perform the transfer. Warning: `w25q128jw_controller_is_ready_polling` disable DMA write access from HW, so DMA must be re configured to allow HW access after calling this function. 

Example of memory-mapped access can be found in `sw/applications/example_w25q128jw_memio/`.

### Current Limitations

- Currently it hasn't been fully verified, some edge cases may not be handled correctly. Use with caution and report any issues.

