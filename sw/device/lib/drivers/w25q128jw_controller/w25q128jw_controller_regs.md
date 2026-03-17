## Summary

| Name                                                                   | Offset   |   Length | Description                                                                |
|:-----------------------------------------------------------------------|:---------|---------:|:---------------------------------------------------------------------------|
| w25q128jw_controller.[`CONTROL`](#control)                             | 0x0      |        4 | Control register for flash controller                                      |
| w25q128jw_controller.[`STATUS`](#status)                               | 0x4      |        4 | Status register for flash controller                                       |
| w25q128jw_controller.[`F_ADDRESS`](#f_address)                         | 0x8      |        4 | Address in flash to read from/write to                                     |
| w25q128jw_controller.[`S_ADDRESS`](#s_address)                         | 0xc      |        4 | Address to store read data from SPI_FLASH                                  |
| w25q128jw_controller.[`MD_ADDRESS`](#md_address)                       | 0x10     |        4 | Address where data with which we have to modify the flash is               |
| w25q128jw_controller.[`LENGTH`](#length)                               | 0x14     |        4 | Length of data to W/R                                                      |
| w25q128jw_controller.[`INTR_STATUS`](#intr_status)                     | 0x18     |        4 | Interrupt status register                                                  |
| w25q128jw_controller.[`INTR_ENABLE`](#intr_enable)                     | 0x1c     |        4 | Interrupt enable register                                                  |
| w25q128jw_controller.[`DMA_SLOT_WAIT_COUNTER`](#dma_slot_wait_counter) | 0x20     |        4 | A DMA counter used to wait before submitting the next req when using slots |

## CONTROL
Control register for flash controller
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0x7`

### Fields

```wavejson
{"reg": [{"name": "START", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "RNW", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "QUAD", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 29}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                   |
|:------:|:------:|:-------:|:-------|:------------------------------|
|  31:3  |        |         |        | Reserved                      |
|   2    |   rw   |   0x0   | QUAD   | Quad spi mode                 |
|   1    |   rw   |   0x0   | RNW    | Read Not Write operation mode |
|   0    |   rw   |   0x0   | START  | Start operation               |

## STATUS
Status register for flash controller
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "READY", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description             |
|:------:|:------:|:-------:|:-------|:------------------------|
|  31:1  |        |         |        | Reserved                |
|   0    |   rw   |   0x0   | READY  | Ready for new operation |

## F_ADDRESS
Address in flash to read from/write to
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "F_ADDRESS", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name      | Description                            |
|:------:|:------:|:-------:|:----------|:---------------------------------------|
|  31:0  |   rw   |    x    | F_ADDRESS | Address in flash to read from/write to |

## S_ADDRESS
Address to store read data from SPI_FLASH
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "S_ADDRESS", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name      | Description                               |
|:------:|:------:|:-------:|:----------|:------------------------------------------|
|  31:0  |   rw   |    x    | S_ADDRESS | Address to store read data from SPI_FLASH |

## MD_ADDRESS
Address where data with which we have to modify the flash is
- Offset: `0x10`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "MD_ADDRESS", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name       | Description                                                  |
|:------:|:------:|:-------:|:-----------|:-------------------------------------------------------------|
|  31:0  |   rw   |    x    | MD_ADDRESS | Address where data with which we have to modify the flash is |

## LENGTH
Length of data to W/R
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "LENGTH", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description           |
|:------:|:------:|:-------:|:-------|:----------------------|
|  31:0  |   rw   |    x    | LENGTH | Length of data to W/R |

## INTR_STATUS
Interrupt status register
- Offset: `0x18`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "INTR_STATUS", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 130}}
```

|  Bits  |  Type  |  Reset  | Name        | Description            |
|:------:|:------:|:-------:|:------------|:-----------------------|
|  31:1  |        |         |             | Reserved               |
|   0    |   rw   |    x    | INTR_STATUS | Event interrupt status |

## INTR_ENABLE
Interrupt enable register
- Offset: `0x1c`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "INTR_ENABLE", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 130}}
```

|  Bits  |  Type  |  Reset  | Name        | Description      |
|:------:|:------:|:-------:|:------------|:-----------------|
|  31:1  |        |         |             | Reserved         |
|   0    |   rw   |    x    | INTR_ENABLE | interrupt enable |

## DMA_SLOT_WAIT_COUNTER
A DMA counter used to wait before submitting the next req when using slots
- Offset: `0x20`
- Reset default: `0x0`
- Reset mask: `0xff`

### Fields

```wavejson
{"reg": [{"name": "DMA_SLOT_WAIT_COUNTER", "bits": 8, "attr": ["rw"], "rotate": -90}, {"bits": 24}], "config": {"lanes": 1, "fontsize": 10, "vspace": 230}}
```

|  Bits  |  Type  |  Reset  | Name                  | Description                                                                |
|:------:|:------:|:-------:|:----------------------|:---------------------------------------------------------------------------|
|  31:8  |        |         |                       | Reserved                                                                   |
|  7:0   |   rw   |   0x0   | DMA_SLOT_WAIT_COUNTER | A DMA counter used to wait before submitting the next req when using slots |

