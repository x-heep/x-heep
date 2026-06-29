## Summary

| Name                               | Offset   |   Length | Description                                                                             |
|:-----------------------------------|:---------|---------:|:----------------------------------------------------------------------------------------|
| iffifo.[`FIFO_OUT`](#fifo_out)     | 0x0      |        4 | Data coming from the FIFO (Fifo Output/Software RX)                                     |
| iffifo.[`FIFO_IN`](#fifo_in)       | 0x4      |        4 | Data sent to the FIFO (Fifo Input/Software TX)                                          |
| iffifo.[`STATUS`](#status)         | 0x8      |        4 | General purpose status register                                                         |
| iffifo.[`OCCUPANCY`](#occupancy)   | 0xc      |        4 | Current number of occupied FIFO slots                                                   |
| iffifo.[`WATERMARK`](#watermark)   | 0x10     |        4 | FIFO occupancy at which the STATUS:REACHED bit is asserted                              |
| iffifo.[`INTERRUPTS`](#interrupts) | 0x14     |        4 | Write any value to assert an interrupt. Write 0 or 1 to disable or enable an interrupt. |

## FIFO_OUT
Data coming from the FIFO (Fifo Output/Software RX)
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "FIFO_OUT", "bits": 32, "attr": ["ro"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:0  |   ro   |    x    | FIFO_OUT |               |

## FIFO_IN
Data sent to the FIFO (Fifo Input/Software TX)
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "FIFO_IN", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name    | Description   |
|:------:|:------:|:-------:|:--------|:--------------|
|  31:0  |   rw   |    x    | FIFO_IN |               |

## STATUS
General purpose status register
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xf`

### Fields

```wavejson
{"reg": [{"name": "EMPTY", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "AVAILABLE", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "REACHED", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "FULL", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 28}], "config": {"lanes": 1, "fontsize": 10, "vspace": 110}}
```

|  Bits  |  Type  |  Reset  | Name      | Description                                                     |
|:------:|:------:|:-------:|:----------|:----------------------------------------------------------------|
|  31:4  |        |         |           | Reserved                                                        |
|   3    |   ro   |    x    | FULL      | Asserted when all FIFO slots are occupied.                      |
|   2    |   ro   |    x    | REACHED   | Asserted when occupied data slots count greater than threshold. |
|   1    |   ro   |    x    | AVAILABLE | Asserted when data is available in FIFO.                        |
|   0    |   ro   |    x    | EMPTY     | Asserted when FIFO empty.                                       |

## OCCUPANCY
Current number of occupied FIFO slots
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "OCCUPANCY", "bits": 32, "attr": ["ro"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name      | Description   |
|:------:|:------:|:-------:|:----------|:--------------|
|  31:0  |   ro   |    x    | OCCUPANCY |               |

## WATERMARK
FIFO occupancy at which the STATUS:REACHED bit is asserted
- Offset: `0x10`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "WATERMARK", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name      | Description   |
|:------:|:------:|:-------:|:----------|:--------------|
|  31:0  |   rw   |    x    | WATERMARK |               |

## INTERRUPTS
Write any value to assert an interrupt. Write 0 or 1 to disable or enable an interrupt.
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "REACHED", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 90}}
```

|  Bits  |  Type  |  Reset  | Name    | Description                 |
|:------:|:------:|:-------:|:--------|:----------------------------|
|  31:1  |        |         |         | Reserved                    |
|   0    |   rw   |    x    | REACHED | Watermark reached interrupt |

