# SPI slave

The SPI slave peripheral offers external devices read and write access to the memory. Devices can send it commands to control what to read/write. 

## How does it work? 

the Serial Peripheral Interface (SPI) allows to connect a master device to one or more slave devices. They all share a group of three wires, namely Master-Input,Slave-Output (MISO), Master-Output-Slave-Input (MOSI), and SPI-clock (SCK). The master device will control the communication through the wires by sending commands to the slaves through the MOSI and providing a clock signal (SCK) for them to answer. Slaves need to adjust to the timing imposed by the master: the start and end of commands and packets is given by the count of cycles of SCK. To allow for more than one slave, an extra wire per slave called Chip Select (CS) is needed for the master to inform which slave should listen/answer.  

```{warning}
The SPI slave peripheral cannot be commanded from software. It is purely an interface to the outside world. It will only receive instructions from the one master interface that connects to it.  
```

This documentation corresponds to the SPI slave IP of X-HEEP. For the SPI master IP please refer to [the SPI documentation](./SPI.md). 


## Commands

The SPI slave IP has a limited number of commands it can receive. All these commands need to be sent through the `MOSI` pin, with `CS` set to `0` and `SCK` toggling. You should not leave any `SCK` cycle between commands. 
> Typically the SPI host will buffer all commands before sending them to guarantee this condition. On the SPI SDK you can refer to the documentation on `csaat` on [the SPI SDK documentation](./SPI.md).

### Set Wrap-Length
The number of 32-bit words to be read/written is called "wrap length". 

The IP has two registers to store the wrap length L, namely `REG_1` and `REG_2` that will store the 8-LSB and 8-MSB respectively. To write these registers send a word intructing to write on these registers using commands `0x20` and `0x30`. 

| 31:24 | 23:16 | 15:8 | 7:0 |
|----------|----------|----------|----------|
| `L[15:8]` | `0x30` | `L[7:0]` | `0x20` |


### Set dummy cycles

When the SPI salve is commanded to read from memory, before transmitting the data it will wait for a certain number of periods of the SCK. This amount is configurable, and needs to be matched by the SPI master (who also controls the SCK). 

This amount is stored in the `REG_0` of the SPI slave IP and is set by seding a 2-byte command: 

| 15:8 | 7:0 |
|----------|----------|
| `DUMMY_CYCLES` | `0x11` |

```{note}
If this command is not sent, the default value is used: 32 cycles. 
```

### Directionality

A command to define if the SPI slave should read or write from memory. 

`0xB` for READ.

`0x2` for WRITE.

| 7:0|
|----|
| `R/W` |


## Address

The read/write address A in the device's memory, in little endian format (the least-significant byte is sent first in time). 

| 31:24 | 23:16 | 15:8 | 7:0 |
|----------|----------|----------|----------|
| `A[7:0]` | `A[15:8]` | `A[23:16]` | `A[31:24]` |

> The address can be a pointer to an 8-bit word (i.e., can be non-multiple of 4), but the SPI slave will only get 32-bit words, so the whole 32-bit word containing that address (starting at an address multiple of 4) will be fetched. 


## Data

Each data word D needs to be sent in little endian format (the least-significant byte is sent first in time).

 | 31:24 | 23:16 | 15:8 | 7:0 |
|----------|----------|----------|----------|
| `D[7:0]` | `D[15:8]` | `D[23:16]` | `D[31:24]` | 


## Sequence

The commands should be sent in a specific order, and there are hard constraints on what `SCK` and `CS` should do.  

1. Set `CS` to `0`.
1. Start toggling `SCK`. From now all tasks should be done back-to-back without leaving any cycle between them. 
1. (Optional) Send the dummy cycles command. 
1. Send the wrap length command.
1. Send the direction command.
1. Send the address command.
1. If data is to be written, you can stop `SCK` and raise `CS`. Lower it and start toggling `SCK` again to send the data.
1. If the data is to be read, wait for `DUMMY_CYCLES` periods of `SCK`. Then receive the data from MISO.  Receive the data (in read mode), or send the data (in write mode)
1. Raise `CS` and stop `SCK`


## Examples and SDK

An SDK is provided in [spi_sdk](https://github.com/x-heep/x-heep/tree/main/sw/device/lib/sdk/spi_slave), yet... **this is not an SDK for the SPI slave IP!**. This IP is not controlled by software. The SDK provided is a series of functions to control the SPI slave **from the SPI Host IP**.

You can use these functions as in the [example_spi_slave](https://github.com/x-heep/x-heep/tree/main/sw/applications/example_spi_slave/) to command the SPI slave of the X-HEEP system from the SPI Host *of the same system*, i.e., have the system access its own internal memory through the SPI slave port.
Note that this example is a nonsense, there is no point in doing this in real life! 
This is interesting only in simulation to test the behavior of both peripherals. 

A more interesting example is available in [demo_spi_master_slave](https://github.com/x-heep/x-heep/tree/main/sw/applications/demo_spi_master_slave/), where two FPGAs are used to exchange data from the SPI Host of one to the SPI slave of another. 
If you want to read from X-HEEP's memory using the SPI slave, we recommend you follow this demo. 

