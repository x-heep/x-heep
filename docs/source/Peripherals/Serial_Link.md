# Serial Link Peripheral Documentation

## Overview

The **Serial Link** peripheral ([GitHub Repository](https://github.com/pulp-platform/serial_link)) is integrated into **X-HEEP**. It provides a mechanism to transmit data through a serial interface, either using a FIFO buffer of configurable size or by writing directly into memory.


The serial link wrapper (`serial_link_xheep_wrapper`) extends the base PULP Serial Link IP with two configurable RX modes, selectable at runtime via a software-controlled multiplexer:


- **FIFO mode** (default): Incoming data is stored in a memory-mapped FIFO, which the CPU reads via polling or DMA.
- **Direct write mode**: Incoming AXI transactions are routed through `axi_to_mem` directly into X-HEEP's memory space, bypassing the FIFO entirely.


## Features

- **Memory-mapped peripheral**: The serial link itself is memory-mapped, enabling software access to transmitted data through a standard interface.
- **FIFO buffering**: In FIFO mode, transmitted data is stored in a FIFO of configurable depth before being read by the CPU or DMA.
- **Direct write mode**: Incoming data is written directly to any valid address in the receiver's memory space (RAM, peripherals), enabling zero-copy transfers.
- **Software-controlled RX mux**: A register-based multiplexer selects between FIFO and direct write mode at runtime.
- **Configurable payload**: The data to be transmitted, referred to as the payload, is declared in the `ip/serial_link/minimal_pkg.sv` package.  
  - This ensures that the vendored serial link files remain untouched.
  - Other configurable parameters are also declared in the same package.
- **DMA support**: Both send and receive paths support DMA transfers via `sl_dma_send` and `sl_dma_read`.

## Configuration

1. **FIFO Size**: The depth of the FIFO can be adjusted according to system requirements.
2. **Payload Definition**:  
   - Located in `ip/serial_link/minimal_pkg.sv`.
   - Contains the data to be transmitted and other configuration parameters.
3. **Register Programming**:  
   - To use the serial link, the memory-mapped **registers must be correctly programmed**.  
   - The initialization function `sl_init` provides the required register setup.
4. **RX Mode**: Selected at runtime via `sl_wrapper_set_rx_mode()`.
5. **TX Address Window**: Configured in `configs/general.hjson`:
```
   serial_link: {
       address: 0x50000000
       length:  0x01000000
   }
```
6. **PAD MUX**: On FPGA, DDR pins are muxed with GPIO. The pad mux must be configured in software before use

## Software Application

A software driver for the wrapper has been implemented in `sw/device/lib/drivers/serial_link/serial_link_xheep_wrapper_driver`. All functions are documented in the corresponding `.h` file.


### Usage FIFO Mode
1. Receiver: call `sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO)`
2. Receiver: read from `SL_READ` (blocks until data is available)
3. Sender: call `sl_init`, then write to `SL_WRITE`
4. Data is transferred over DDR Serial Link and appears in the receiver FIFO

### Usage Direct Write Mode
1. Receiver: call `sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE)`
2. Receiver: clear target address, then poll until non-zero
3. Sender: call `sl_wrapper_direct_write(dest_offset, data)`
4. Data is transferred over DDR Serial Link and is written directly to `dest_offset` in the receiver RAM

### Test Applications

| Application | Description |
|-------------|-------------|
| `example_serial_link_direct_write` | Functional test of FIFO (with and without DMA) and direct write modes (test harness simulation + FPGA) |
| `example_serial_link_performance` | Performance evaluation: cycles/word for FIFO and direct write, with bidirectional sync (FPGA)|

---
**Note:** The `SL_READ` address must always be accessed via a `volatile` pointer to prevent compiler optimization of the memory read.

**Note:** In direct write mode, there are no restrictions on the target address. Be careful not to overwrite program data.

**Note:** For multi-test sequences on FPGA (i.e., switching mid-application between FIFO and direct write modes), use bidirectional synchronization (e.g., the receiver signals readiness to the sender via direct write) to avoid timing-dependent desynchronization between boards (see `example_serial_link_direct_write`). This issue arises because `sl_wrapper_set_rx_mode` must be set to the correct mode before receiving data. If you switch modes mid-application and there is a delay on the RX side, incoming data may be missed.

## FPGA

### FPGA Pin Mapping (PYNQ-Z2)

| Signal | Package Pin | 
|--------|-------------|
| `ddr_i_0` | Y8 | 
| `ddr_i_1` | W8 | 
| `ddr_i_2` | Y7 | 
| `ddr_i_3` | W10 | 
| `ddr_o_0` | V10 | 
| `ddr_o_1` | V8 | 
| `ddr_o_2` | U8 |
| `ddr_o_3` | V7 | 
| `ddr_rcv_clk_i` | Y17 |
| `ddr_rcv_clk_o` | F20 |

For two-board testing, cross-connect outputs of board A to inputs of board B and vice versa. Both clock signals must be connected. Also connect the top-right GND pin of the Raspberry Pi header of board A to the corresponding GND pin on board B. 

### How to Run (example: `example_serial_link_direct_write`)

Set the PYNQ-Z2 switches before powering on:
- **SW0** (`boot_select_i`) = **1** (up)
- **SW1** (`execute_from_flash_i`) = **0** (down)

**Step 1 : Program Board A (sender):**


In `sw/applications/example_serial_link_direct_write/main.c`, set:
```c
#define FPGA_RECEIVE 0
```


Connect Board A and its EPFL programmer. Build and flash:
```bash
make app PROJECT=example_serial_link_direct_write TARGET=pynq-z2 LINKER=flash_load
make flash-prog
make vivado-fpga-pgm FPGA_BOARD=pynq-z2
```


Board A must be powered by DC power supply (not Micro USB) so it stays powered when the board is unplugged. Unplug Board A's Micro USB and its EPFL programmer.


**Step 2 : Program Board B (receiver):**


In `sw/applications/example_serial_link_direct_write/main.c`, set:
```c
#define FPGA_RECEIVE 1
```


Connect Board B and its EPFL programmer. Build and flash:
```bash
make app PROJECT=example_serial_link_direct_write TARGET=pynq-z2 LINKER=flash_load
make flash-prog
make vivado-fpga-pgm FPGA_BOARD=pynq-z2
```


**Step 3 : Release the flash programmer:**


After programming Board B, replug the EPFL programmer of board A. Since we unplugged the EPFL programmer of board A the FTDI chip holds the SPI flash pins preventing X-HEEP from reading the flash. Run this command to release them (since two EPFL programmers are connected simultaneously, use index `:0` or `:1` to target the correct one:):
```bash
cd sw/vendor/yosyshq_icestorm/iceprog && ./iceprog -d i:0x0403:0x6011:0 -I B -t  # first programmer
cd sw/vendor/yosyshq_icestorm/iceprog && ./iceprog -d i:0x0403:0x6011:1 -I B -t  # second programmer
```

**Step 4 : Run:**


Open picocom on both Board A and Board B UARTs to see the output:
```bash
picocom -b 9600 -r -l --imap lfcrlf /dev/ttyUSBX  # replace X with correct device
```

Reset **Board B (receiver) first**, then reset **Board A (sender)**. The program will run and you should see the outputs.


> Always reset the receiver before the sender. The receiver must be waiting for data before the sender starts transmitting.

---

**Note:** This documentation describes the minimal configuration and usage of the Serial Link peripheral within X-HEEP. For advanced features and customizations, refer to the original vendor documentation.

**Note:** If you are using `verilator 4.210`, make sure to disable the Serial Link (not include it) because it is not capable of compiling it. Use `verilator 5.040` instead.