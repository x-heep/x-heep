# Serial Link Peripheral Documentation

## Overview

The **Serial Link** peripheral ([GitHub Repository](https://github.com/pulp-platform/serial_link)) is integrated into **X-HEEP**. It provides a mechanism to transmit data through a serial interface using a FIFO buffer of configurable size.  

Unlike direct memory access, the serial link does **not write output directly to memory or a specific address**. Instead, data is first stored in a FIFO, which can be accessed as a memory-mapped peripheral. This allows software and hardware to interact with the transmitted data efficiently.

## Features

- **Memory-mapped peripheral**: The serial link itself is memory-mapped, enabling software access to transmitted data through a standard interface.
- **FIFO buffering**: All transmitted data is stored in a FIFO of configurable depth before being sent.
- **Configurable payload**: The data to be transmitted, referred to as the payload, is declared in the `ip/serial_link/minimal_pkg.sv` package.  
  - This ensures that the vendored serial link files remain untouched.
  - Other configurable parameters are also declared in the same package.

## Configuration

1. **FIFO Size**: The depth of the FIFO can be adjusted according to system requirements.
2. **Payload Definition**:  
   - Located in `ip/serial_link/minimal_pkg.sv`.
   - Contains the data to be transmitted and other configuration parameters.
3. **Register Programming**:  
   - To use the serial link, the memory-mapped **registers must be correctly programmed**.  
   - The initialization function `sl_init` provides the required register setup.
4. **Integration**:  
   - The peripheral is memory-mapped in X-HEEP.
   - Only the FIFO is written by the peripheral; memory writes occur through standard memory-mapped access.

## Software Application

- A **test harness simulation** is included to demonstrate the current functionality of the serial link.
- The software interacts with the FIFO to read transmitted data and verify correct operation.
- Use `sl_init` to initialize the peripheral and program all required registers before transmitting data.

## Usage

1. Call `sl_init` to program the serial link registers.
2. Write data to the serial link peripheral.
3. The data is stored in the FIFO.
4. Read data from the FIFO through the memory-mapped interface.
5. The data is transmitted over the serial interface according to the payload configuration.



---

**Note:** This documentation describes the minimal configuration and usage of the Serial Link peripheral within X-HEEP. For advanced features and customizations, refer to the original vendor documentation.
