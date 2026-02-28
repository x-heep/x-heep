## Summary

| Name                                            | Offset   |   Length | Description                 |
|:------------------------------------------------|:---------|---------:|:----------------------------|
| serial_link_xheep_wrapper.[`RX_MODE`](#rx_mode) | 0x0      |        4 | Receiver mode configuration |

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

