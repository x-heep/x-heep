# I2S example: FPGA capture and simulation

Maintainer: Tommaso Terzano <tommaso.terzano@epfl.ch>

See the [I2S peripheral documentation](../../../../docs/source/Peripherals/I2S.md)
for the hardware interface, driver, DMA, and register reference.

Select tests using the `TEST_ID_*` definitions in `../main.c`:

| Test | FPGA | Simulation |
|---|---|---|
| `TEST_ID_0`: RX-only DMA | 16 batches of 100 left-channel samples | Checks microphone model data |
| `TEST_ID_1`: TX-only DMA | Continuously repeats a known pattern until reset (default) | Checks one transfer with the simulation TX sink |
| `TEST_ID_2`: simultaneous RX/TX DMA | Skipped | Checks RX and TX on separate DMA channels |

Simulation enables all three tests by default. FPGA enables only TX, so no
microphone is needed. The FPGA TX path uses circular DMA on channel 0 and
prefills the FIFO before starting the I2S clocks. It reports startup failures,
TX underflow, or TX overflow over UART. A healthy stream runs indefinitely;
it does not print `Success.`. Reset the board to stop or restart the test.

## Run on PYNQ-Z2

Use a bitstream built from this checkout with I2S TX enabled. To build and
program the FPGA using the repository's usual flow:

```sh
make vivado-fpga FPGA_BOARD=pynq-z2
make vivado-fpga-pgm FPGA_BOARD=pynq-z2
make app PROJECT=example_i2s TARGET=pynq-z2 LINKER=on_chip
```

Load and run `sw/build/main.elf` using your normal JTAG/GDB workflow (see
[Debugging](../../../../docs/source/How_to/Debug.md)). Building the application
alone does not load it onto the board. Open the UART at 115200 baud to see the
stream-start message or errors.

### Logic analyzer wiring

Connect to the **40-pin Raspberry Pi header**. Numbers below are physical
connector positions, not GPIO numbers. Use an analyzer compatible with 3.3 V
logic and connect its ground to board ground.

| Analyzer input | Signal | Header pin | FPGA package pin |
|---|---|---|---|
| Clock | SCK / BCLK | 36 | B19 |
| Word select | WS / LRCLK | 32 | B20 |
| Data | SD TX | 24 | F19 |
| Ground | GND | 34 | — |

Shared application initialization explicitly selects I2S on the SCK, WS, RX,
and TX pad muxes before any test runs, on both FPGA and simulation.
Pin assignments are in
[`pin_assign.xdc`](../../../../hw/fpga/xheep_fpga_support/constraints/pynq-z2/pin_assign.xdc).

Configure the decoder for standard I2S, 32 bits per channel, MSB first,
sampling data on rising BCLK edges, with a one-bit delay after each WS edge.
WS low denotes left and WS high denotes right. Capture both channels and
compare the chronological word stream; capture may begin partway through the
pattern or include startup zeros.

The following hexadecimal words repeat in order:

```text
01234567 89abcdef 0badcafe 13579bdf
2468ace0 fdb97531 a5a55a5a c001d00d
55aa00ff ff00aa55 deadbeef 10203040
```

`I2S_FPGA_CLK_DIV` in `../test_i2s.h` defaults to 8. BCLK is the I2S input
clock divided by 8; the stereo frame rate is BCLK / 64. The current PYNQ-Z2
clock configuration is 15 MHz, giving 1.875 MHz BCLK and a 29.296875 kHz
stereo frame rate. Set the analyzer sample rate to at least 10 times BCLK
(e.g. 20 MS/s for this configuration). Successful UART startup alone
does not verify the physical waveform: check the decoded pattern and clocks.

## RX-only FPGA test

Replace the FPGA `TEST_ID_1` definition with `TEST_ID_0` in `../main.c` and
rebuild. Connect an external I2S source to RX (FPGA W9, Raspberry Pi header
pin 37), using the board-generated SCK and WS. This mode captures left-channel
samples into `rx_only_samples`; inspect that buffer with a debugger.

The existing `i2s_test.py` is a legacy UART audio plotting script. The current
application prints batch markers but does not dump sample values, so that
script is not directly usable with the current RX path. The current 100-sample
batches also do not implement the older multi-second recording demo.

## Simulation regression

```sh
make app PROJECT=example_i2s TARGET=sim LINKER=on_chip
```

Run the resulting ELF with the repository's simulation workflow. TX checking
uses the simulation-only `i2s_tx_sink`; the FPGA TX path never accesses it.
