## Summary

| Name                              | Offset   |   Length | Description                             |
|:----------------------------------|:---------|---------:|:----------------------------------------|
| i2s_tx_sink.[`CONTROL`](#control) | 0x0      |        4 | Sink control. Bit 0 enables TX capture. |
| i2s_tx_sink.[`RXDATA`](#rxdata)   | 0x4      |        4 | Decoded I2S TX sample FIFO output       |
| i2s_tx_sink.[`STATUS`](#status)   | 0x8      |        4 | I2S TX sink status                      |

## CONTROL
Sink control. Bit 0 enables TX capture.
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "CONTROL", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name    | Description   |
|:------:|:------:|:-------:|:--------|:--------------|
|  31:0  |   rw   |   0x0   | CONTROL |               |

## RXDATA
Decoded I2S TX sample FIFO output
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "RXDATA", "bits": 32, "attr": ["ro"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:0  |   ro   |    x    | RXDATA |               |

## STATUS
I2S TX sink status
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0x7`

### Fields

```wavejson
{"reg": [{"name": "EMPTY", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "AVAILABLE", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "OVERFLOW", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 29}], "config": {"lanes": 1, "fontsize": 10, "vspace": 110}}
```

|  Bits  |  Type  |  Reset  | Name      | Description                                       |
|:------:|:------:|:-------:|:----------|:--------------------------------------------------|
|  31:3  |        |         |           | Reserved                                          |
|   2    |   ro   |    x    | OVERFLOW  | Asserted when the decoded-sample FIFO overflowed. |
|   1    |   ro   |    x    | AVAILABLE | Asserted when a decoded sample can be read.       |
|   0    |   ro   |    x    | EMPTY     | Asserted when no decoded sample is available.     |

