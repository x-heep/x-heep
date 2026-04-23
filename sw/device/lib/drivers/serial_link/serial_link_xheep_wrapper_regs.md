## Summary

| Name                                                                            | Offset   |   Length | Description                                                                                                                                            |
|:--------------------------------------------------------------------------------|:---------|---------:|:-------------------------------------------------------------------------------------------------------------------------------------------------------|
| serial_link_xheep_wrapper.[`RX_MODE`](#rx_mode)                                 | 0x0      |        4 | Receiver mode configuration                                                                                                                            |
| serial_link_xheep_wrapper.[`DIRECT_WRITE_WORD_COUNT`](#direct_write_word_count) | 0x4      |        4 | Expected word count for direct write transfer. Set before arming. Interrupt fires when this many words have been committed to RAM. Write 0 to disable. |

## RX_MODE
Receiver mode configuration
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "DIRECT_WRITE_EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 170}}
```

|  Bits  |  Type  |  Reset  | Name            | Description                                                                                                                     |
|:------:|:------:|:-------:|:----------------|:--------------------------------------------------------------------------------------------------------------------------------|
|  31:1  |        |         |                 | Reserved                                                                                                                        |
|   0    |   rw   |   0x0   | DIRECT_WRITE_EN | Receiver mode select. 0 = FIFO mode (default), 1 = direct write mode (incoming data written directly to memory via OBI master). |

## DIRECT_WRITE_WORD_COUNT
Expected word count for direct write transfer. Set before arming. Interrupt fires when this many words have been committed to RAM. Write 0 to disable.
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "COUNT", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                     |
|:------:|:------:|:-------:|:-------|:--------------------------------|
| 31:16  |        |         |        | Reserved                        |
|  15:0  |   rw   |   0x0   | COUNT  | Expected word count (max 65535) |

