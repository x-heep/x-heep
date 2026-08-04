# Serial Link 

## Overview

The **Serial Link** peripheral ([GitHub Repository](https://github.com/pulp-platform/serial_link)) is integrated into **X-HEEP**. It provides a mechanism to transmit data through a serial interface, either using a FIFO buffer of configurable size or by writing directly into memory.


The serial link wrapper (`serial_link_xheep_wrapper`) extends the base PULP Serial Link IP with two configurable RX modes, selectable at runtime via a software-controlled multiplexer:


- **FIFO mode** (default): Incoming data is stored in a memory-mapped FIFO, which the CPU reads via polling or DMA.
- **Direct write mode**: Incoming bus transactions are routed directly into the receiving X-HEEP's memory space, bypassing the FIFO entirely.

```{note}
This documentation describes the minimal configuration and usage of the Serial Link peripheral within X-HEEP. For advanced features and customizations, refer to the original vendor documentation.
```

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
5. **TX Address Window**: Configured in `configs/general.hjson` or in `configs/python_unsupported.hjson`:.
```
   serial_link: {
       address: 0x50000000
       length:  0x01000000
   }
```
6. **PAD MUX**: On FPGA, DDR pins are muxed with GPIO. The pad mux must be configured in software before use

## Software Application

- A software driver for the wrapper has been implemented in `sw/device/lib/drivers/serial_link/serial_link_xheep_wrapper_driver`. All functions are documented in the corresponding `.h` file.
- Use `sl_init` to initialize the peripheral and program all required registers before transmitting data.

```{warning}
If you are using `verilator 4.210`, make sure to disable the Serial Link (not include it) because it is not capable of compiling it. Use `verilator 5.040` instead.
```

### Usage FIFO Mode
1. Call `sl_init` to program the serial link registers.
2. Receiver: call `sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO)`
3. Receiver: read from `SL_READ` (blocks until data is available)
4. Sender: write to `SL_WRITE`
5. Data is transferred over DDR Serial Link and appears in the receiver FIFO

### Usage Direct Write Mode
1. Call `sl_init` to program the serial link registers.
2. Receiver: call `sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_DIRECT_WRITE)`
3. Receiver: clear target address, then poll until non-zero
4. Sender: call `sl_wrapper_direct_write(dest_offset, data)`
5. Data is transferred over DDR Serial Link and is written directly to `dest_offset` in the receiver RAM

### Test Applications

| Application | Description |
|-------------|-------------|
| `example_serial_link_direct_write` | Functional test of FIFO (with and without DMA) and direct write modes (test harness simulation + FPGA) with bidirectional sync (FPGA) |
| `example_serial_link_performance` | Performance evaluation: cycles/word for FIFO and direct write (FPGA) |

---

```{note}
The `SL_READ` address must always be accessed via a `volatile` pointer to prevent compiler optimization of the memory read.
```

```{note}
In direct write mode, there are no restrictions on the target address. Be careful not to overwrite program data.
```

```{note}
For multi-test sequences on FPGA (i.e., switching mid-application between FIFO and direct write modes), use bidirectional synchronization (e.g., the receiver signals readiness to the sender via direct write) to avoid timing-dependent desynchronization between boards (see `example_serial_link_direct_write`). This issue arises because `sl_wrapper_set_rx_mode` must be set to the correct mode before receiving data. If you switch modes mid-application and there is a delay on the RX side, incoming data may be missed.
```

## FPGA

### FPGA Pin Mapping (PYNQ-Z2)

The pin mapping can be found in `hw/fpga/constraints/pynq-z2/pin_assign.xdc`.

For two-board testing, cross-connect outputs of board A to inputs of board B and vice versa. Both clock signals must be connected. Also connect the top-right GND pin of the Raspberry Pi header of board A to the corresponding GND pin on board B. 

### How to Run (example: `example_serial_link_direct_write`)

Set the PYNQ-Z2 switches before powering on:
- **SW0** (`boot_select_i`) = **1** (up)
- **SW1** (`execute_from_flash_i`) = **0** (down)

**Step 1 : Program Board A (sender):**


In `sw/applications/example_serial_link_direct_write/example_serial_link_direct_write.h`, set:
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


In `sw/applications/example_serial_link_direct_write/example_serial_link_direct_write.h`, set:
```c
#define FPGA_RECEIVE 1
```


Connect Board B and its EPFL programmer. Build and flash:
```bash
make app PROJECT=example_serial_link_direct_write TARGET=pynq-z2 LINKER=flash_load
make flash-prog
make vivado-fpga-pgm FPGA_BOARD=pynq-z2
```


### Step 3: Reconnect Board A's Programmer and Release Both Flash Programmers

After programming Board B, reconnect Board A's EPFL programmer.

Because Board A's EPFL programmer was unplugged, its FTDI chip may hold the SPI flash pins. This can prevent X-HEEP from booting correctly from flash.

With both EPFL programmers connected, release both programmers:

```bash
cd sw/vendor/yosyshq_icestorm/iceprog

./iceprog -d i:0x0403:0x6011:0 -I B -t
./iceprog -d i:0x0403:0x6011:1 -I B -t
```

The programmer index, `:0` or `:1`, selects which EPFL programmer is targeted.

---

### Step 4: Identify the Correct UART Devices

When two EPFL programmers are connected at the same time, do not rely on `/dev/ttyUSBX` or `/dev/serial/by-id/...`, because the two FTDI programmers may have identical IDs.

Instead, use `/dev/serial/by-path/`.

List the available serial devices:

```bash
ls -l /dev/serial/by-path/
```

Then inspect the UART interfaces:

```bash
for d in /dev/ttyUSB*; do
  echo "==== $d ===="
  udevadm info -q property -n "$d" | grep -E 'ID_PATH=|ID_SERIAL=|ID_USB_INTERFACE_NUM=|DEVLINKS='
done
```

For the EPFL programmer UART, look for entries with:

```text
ID_SERIAL=FTDI_Quad_RS232-HS
ID_USB_INTERFACE_NUM=02
```

In one working setup, the two UARTs were:

```text
Receiver / FPGA_RECEIVE = 1:
  /dev/serial/by-path/pci-0000:00:14.0-usb-0:12:1.2-port0

Sender / FPGA_RECEIVE = 0:
  /dev/serial/by-path/pci-0000:00:14.0-usb-0:8:1.2-port0
```

These paths may be different on another machine or when using different USB ports.

---

### Step 5: Open Picocom on Both Boards

Open two terminal windows.

In the first terminal, open the receiver UART:

```bash
picocom -b 9600 -r -l --imap lfcrlf /dev/serial/by-path/<receiver-if02-path>
```

In the second terminal, open the sender UART:

```bash
picocom -b 9600 -r -l --imap lfcrlf /dev/serial/by-path/<sender-if02-path>
```

For example:

```bash
picocom -b 9600 -r -l --imap lfcrlf /dev/serial/by-path/pci-0000:00:14.0-usb-0:12:1.2-port0
```

and:

```bash
picocom -b 9600 -r -l --imap lfcrlf /dev/serial/by-path/pci-0000:00:14.0-usb-0:8:1.2-port0
```

Whenever you are done you can exit the picocom interface with:

```text
Ctrl-a Ctrl-x
```

---

### Step 6: Reset the Boards in the Correct Order

After both picocom terminals are open:

1. Reset **Board B**, the receiver.
2. Then reset **Board A**, the sender.

The receiver should print something similar to:

```text
=== Serial Link MUX Mode Test (FPGA RECEIVE) ===
--- Test 1: FIFO mode ---
```

The sender should print something similar to:

```text
=== Serial Link MUX Mode Test (FPGA SEND) ===
--- Test 1: FIFO mode ---
FIFO sent [0]: 0x11111111
FIFO sent [1]: 0x22222222
FIFO sent [2]: 0x33333333
FIFO sent [3]: 0x44444444
```

```{warning}
Always reset the receiver before the sender. The receiver must be waiting for data before the sender starts transmitting.
```

---

### Troubleshooting

#### Picocom is empty on one board

First check that the correct UART interface is being used. The EPFL programmer UART is usually the FTDI interface with:

```text
ID_USB_INTERFACE_NUM=02
```

Use `/dev/serial/by-path/...` instead of `/dev/serial/by-id/...` when two EPFL programmers are connected.

#### One board does not boot or does not print anything

Exit picocom and release both EPFL programmers again:

```bash
cd sw/vendor/yosyshq_icestorm/iceprog

./iceprog -d i:0x0403:0x6011:0 -I B -t
./iceprog -d i:0x0403:0x6011:1 -I B -t
```

Then reopen picocom and reset the board.

#### The sender prints, but the receiver does not receive data

Check the reset order. The receiver must be reset first, then the sender.

Also check the physical wiring:

- Board A outputs must go to Board B inputs.
- Board B outputs must go to Board A inputs.
- Both clock signals must be connected.
- GND must be connected between the boards.

#### The wrong board is programmed

Program each board separately, and verify the value of `FPGA_RECEIVE` before building:

```c
#define FPGA_RECEIVE 0   // sender
```

or:

```c
#define FPGA_RECEIVE 1   // receiver
```

After changing `FPGA_RECEIVE`, rebuild the application before flashing.
