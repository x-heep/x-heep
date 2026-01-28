# W25Q128JW CONTROLLER

```{contents} Table of Contents
:depth: 2
```

This IP controls the `SPI Host IP` inside the SPI Subsystem and the `DMA channel 0` to automatically performs read and write operation to the `W25Q128JW` Flash. 

## Preliminary Definitions

### Transaction

It gets as input the `Flash` address and the `SRAM` address, whether it is a read or write operations, and then it starts the transaction. It can be configured to raise an interrupt when done.
