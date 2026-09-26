# I2S

Author: Tommaso Terzano <tommaso.terzano@epfl.ch>

The I2S peripheral transfers serial audio samples using a bit clock (SCK, also
called BCLK), word select (WS, also called LRCLK), and separate receive and
transmit data signals. RX and TX can run independently or simultaneously,
sharing the same clock and word length.

## Hardware and serial format

The current implementation generates SCK and WS: X-HEEP acts as the clock
controller. The external SCK and WS inputs are not used to clock the peripheral;
external-clock operation is not supported by this implementation. There is no
separate master-clock (MCLK) output.

| Signal | Direction in I2S mode | Purpose |
|---|---|---|
| `i2s_sck_io` | Output | Serial bit clock |
| `i2s_ws_io` | Output | Channel selection: low for left, high for right |
| `i2s_sd_rx_io` | Input | Samples received from an external device |
| `i2s_sd_tx_io` | Output | Samples transmitted by X-HEEP |

The supported word lengths are **8, 16, 24, and 32 bits per channel**. Data is
MSB first, with the standard I2S one-bit delay after a WS transition. TX changes
data on falling SCK edges; a receiver samples it on rising edges.

For word length `N` and divider `D >= 2`:

```text
BCLK frequency = peripheral input clock / D
Stereo frame rate = BCLK frequency / (2 * N)
```

Divider values 0 and 1 bypass division. Each stereo frame contains two channel
slots. At 32 bits per channel, this is 64 BCLK cycles per stereo frame.
A 32-bit register access transfers one sample, not a stereo pair. For narrower
TX words, the serializer uses the low `N` bits of the written value. RX samples
are right-aligned and zero-filled above the configured word length.

TX consumes the next FIFO word at each WS transition. Software supplies samples
in chronological channel order; there are no separate left and right TX FIFOs.
RX can select left, right, or both channels.

### TX hardware and reset defaults

The standalone I2S module defaults to `I2sDisableTx = 1`. The current X-HEEP
peripheral subsystem and its generation template override this with
`I2sDisableTx = 0`, including the TX hardware in the design.

This synthesis parameter is separate from the software TX enable. After reset,
TX and clock generation are disabled; the configured word length defaults to
32 bits. Software must enable TX with `i2s_tx_start()` and start clocks with
`i2s_init()`. Enabling a register bit cannot add TX logic to an older bitstream.

## Pad configuration

The I2S pads are shared with GPIO 19 (SCK), 20 (WS), 21 (RX), and 22 (TX).
Mux value **0 selects I2S**; value 1 selects GPIO. Although the mux registers
reset to 0, application initialization should explicitly select the pads it
uses, particularly when another application may have used them as GPIO.

`i2s_init()` configures the peripheral, not the pad mux. For example:

```c
#include "core_v_mini_mcu.h"
#include "pad_control.h"
#include "pad_control_regs.h"

void configure_i2s_pads(void)
{
    pad_control_t pads = {
        .base_addr = mmio_region_from_addr(PAD_CONTROL_START_ADDRESS),
    };
    pad_control_set_mux(&pads, PAD_CONTROL_PAD_MUX_I2S_SCK_REG_OFFSET, 0);
    pad_control_set_mux(&pads, PAD_CONTROL_PAD_MUX_I2S_WS_REG_OFFSET, 0);
    pad_control_set_mux(&pads, PAD_CONTROL_PAD_MUX_I2S_SD_RX_REG_OFFSET, 0);
    pad_control_set_mux(&pads, PAD_CONTROL_PAD_MUX_I2S_SD_TX_REG_OFFSET, 0);
}
```

The example application performs this setup before its tests. Applications
using only RX or TX can leave the unused data pad assigned to another function.

## Driver

The driver is in `sw/device/lib/drivers/i2s/`; include `i2s.h` to use it.
Check the return values of initialization, start, stop, and write operations.

| Operation | Driver API |
|---|---|
| Configure divider and word length; start SCK and WS | `i2s_init(divider, word_length)` |
| Check whether clocks are running | `i2s_is_running()` |
| Start RX | `i2s_rx_start(I2S_LEFT_CH / I2S_RIGHT_CH / I2S_BOTH_CH)` |
| Poll and read RX | `i2s_rx_data_available()`, `i2s_rx_read_data()` |
| Arm TX | `i2s_tx_start()` |
| Poll and enqueue TX | `i2s_tx_ready()`, `i2s_tx_write_data(word)` |
| Check errors | `i2s_rx_overflow()`, `i2s_tx_underflow()`, `i2s_tx_overflow()` |
| Stop a direction | `i2s_rx_stop()`, `i2s_tx_stop()` |
| Stop clocks and disable TX | `i2s_terminate()` |

Word-length constants are `I2S_08_BITS`, `I2S_16_BITS`, `I2S_24_BITS`, and
`I2S_32_BITS`. Stop the peripheral before changing the divider or word length.
Stop RX explicitly before termination; `i2s_terminate()` does not clear RX enable.

### RX sequence

1. Select the pads and prepare the receive buffer and DMA transaction, if used.
2. Call `i2s_init()` to start the clocks.
3. Call `i2s_rx_start()` with the desired channel selection.
4. Drain received samples through DMA or readiness-checked reads.
5. Once DMA is no longer reading RX, call `i2s_rx_stop()`, then terminate the
   peripheral if neither direction is needed.

### TX sequence

1. Select the pads and prepare the transmit samples.
2. Prefill the TX FIFO while clocks are stopped. The current TX FIFO holds four
   words; use readiness checks or the DMA trigger to avoid writing a full FIFO.
3. Call `i2s_tx_start()` to arm TX, then `i2s_init()` to start the clocks.
4. Keep supplying data through DMA or readiness-checked writes.
5. For a finite transfer, allow queued samples and the active serial word to
   finish before stopping TX or its clocks.

**DMA completion means samples reached the peripheral, not that their final
bits have left the pin.** The driver has no TX-drained query. A finite-transfer
application must account for the remaining FIFO and serializer latency. The
FPGA example avoids this shutdown issue by streaming continuously until reset.

TX underflow means the serializer requested a sample from an empty FIFO; that
slot transmits zeros. TX overflow means a write arrived while the FIFO was full.
Stop functions return error status and clear the associated flags when possible;
clearing clock-domain flags requires running clocks. Stopping TX does not flush
its FIFO.

## DMA and watermark interrupts

Use 32-bit DMA transfers for sample register accesses, including when the serial
word length is less than 32 bits. Keep the peripheral address fixed and increment
the memory address for successive samples.

| Direction | Peripheral address macro | Peripheral trigger |
|---|---|---|
| RX: peripheral to memory | `I2S_RX_DATA_ADDRESS` | `DMA_TRIG_SLOT_I2S_RX` |
| TX: memory to peripheral | `I2S_TX_DATA_ADDRESS` | `DMA_TRIG_SLOT_I2S_TX` |

Use separate DMA channels for simultaneous RX and TX. Circular TX DMA repeats a
memory buffer without requiring software to reload each completed transfer.
See [DMA](DMA.md) for transaction configuration.

The RX watermark counts **successful RX data-register reads**, including DMA
reads. It is not a FIFO occupancy threshold. With a nonzero watermark, the
counter wraps to zero and generates an event when the programmed count is
reached. `i2s_rx_enable_watermark(watermark, interrupt_en)` controls this feature;
`i2s_rx_read_waterlevel()` reads the count, and `i2s_rx_reset_waterlevel()` resets
it. Route and enable the I2S interrupt in the interrupt controller as required.
TX underflow and overflow are polled status flags, not this watermark interrupt.

## Register summary

Use the generated `I2S_START_ADDRESS` and definitions in `i2s_regs.h`; addresses
can depend on the system configuration.

| Offset | Register | Purpose |
|---|---|---|
| `0x00` | `CONTROL` | Clock, RX/TX, IO, width, and watermark enables |
| `0x04` | `STATUS` | Running, readiness, and error flags |
| `0x08` | `CLKDIVIDX` | 16-bit clock divider |
| `0x0C` | `RXDATA` | Read the next received sample |
| `0x10` | `WATERMARK` | RX read-count event threshold |
| `0x14` | `WATERLEVEL` | Current RX read count |
| `0x18` | `TXDATA` | Write a sample into the TX FIFO |

`STATUS` bits are: 0 running, 1 RX data ready, 2 RX overflow, 3 TX ready,
4 TX underflow, and 5 TX overflow. `CONTROL.EN_TX` is bit 12.

## PYNQ-Z2 logic analyzer test

The current `example_i2s` application defaults to continuous TX on FPGA. It uses
circular DMA channel 0, 32-bit words, and divider 8. Select tests using the
`TEST_ID_*` definitions in `sw/applications/example_i2s/main.c`:

| Test | FPGA behavior | Simulation behavior |
|---|---|---|
| `TEST_ID_0` | RX-only batches from an external source | Checks the microphone model pattern |
| `TEST_ID_1` | Repeating TX pattern until reset (default) | Checks TX through the simulation sink |
| `TEST_ID_2` | Skipped | Simultaneous RX/TX on separate DMA channels |

Simulation enables all three tests by default. The FPGA TX test needs no
microphone. Build it with:

```sh
make app PROJECT=example_i2s TARGET=pynq-z2 LINKER=on_chip
```

Load and run `sw/build/main.elf` using the [FPGA debugging workflow](../How_to/Debug.md).
A subsequent simulation application build overwrites this same ELF, so rebuild
for `pynq-z2` before loading it on the board. A healthy FPGA TX test prints
`I2S TX: repeating 12 words, 32-bit I2S, divider 8. Reset to stop.` and remains in
its error-monitoring loop. It does not print a completion message.

### Connections and decoder settings

Use the **40-pin Raspberry Pi header**, with a common analyzer ground and
3.3 V-compatible inputs. These are physical connector positions, not GPIO IDs.

| Analyzer connection | Physical header pin | FPGA package pin |
|---|---|---|
| BCLK | **36** | B19 |
| WS | **32** | B20 |
| TX data | **24** | F19 |
| Ground | **34** | GND |
| Optional RX source data | 37 | W9 |

Configure standard I2S decoding: **32 bits per channel, MSB first, rising-edge
sampling, one-bit delay after WS transitions, both channels enabled**.
The current 15 MHz PYNQ-Z2 peripheral clock gives 1.875 MHz BCLK and
29.296875 kHz stereo frames at divider 8. An analyzer sample rate of 20 MS/s or
higher is suitable for this configuration.

The twelve words below repeat in chronological order:

```text
01234567 89ABCDEF 0BADCAFE 13579BDF
2468ACE0 FDB97531 A5A55A5A C001D00D
55AA00FF FF00AA55 DEADBEEF 10203040
```

Each word is 32 bits; the complete pattern occupies six 64-bit stereo frames.
A capture can start midway through the pattern. Display unsigned hexadecimal
values to compare them with the buffer.

If the decoder shows only six values, it may be displaying one channel:

| Alternating word group | Values |
|---|---|
| First, third, fifth, etc. | `01234567 0BADCAFE 2468ACE0 A5A55A5A 55AA00FF DEADBEEF` |
| Second, fourth, sixth, etc. | `89ABCDEF 13579BDF FDB97531 C001D00D FF00AA55 10203040` |

Use WS to identify left and right; do not infer channel identity solely from
where the capture starts. Press **BTN3** to reset X-HEEP. After a reset, an
application loaded through JTAG may need to be launched again.

### Clocks work but TX is flat

Check the implemented pin assignment, not only the source template. Older
PYNQ-Z2 constraints assigned TX to **L14**, an onboard RGB LED connection.
The current assignment is **F19**, physical header pin 24.

Git tracks `hw/fpga/xheep_fpga_support/constraints/pynq-z2/pin_assign.xdc.tpl`;
Vivado consumes the generated `pin_assign.xdc`. On the FPGA build machine:

```sh
rg -n 'i2s_sd_tx' hw/fpga/xheep_fpga_support/constraints/pynq-z2/pin_assign.xdc*
```

Both must specify F19. If generation is stale, run `make mcu-gen` with your
system's configuration, rebuild implementation and the bitstream, and program
that bitstream. Updating the ELF does not change pin routing. In Vivado's
implemented design, confirm with:

```tcl
get_property PACKAGE_PIN [get_ports i2s_sd_tx_io]
report_io -file i2s_io.rpt
```

If the mapping is correct, inspect the TX pad mux, `CONTROL`, and `STATUS` using
GDB. For the current example's address map:

```text
x/1wx 0x20080044
x/2wx 0x30070000
```

During healthy TX-only operation, the mux is `0`, control is `0x1383`, and
status has running set with no underflow or overflow (`0x01` or `0x09`, depending
on FIFO readiness). These values verify configuration and status, not the
physical waveform. A UART startup message is likewise not a measurement of TX.
