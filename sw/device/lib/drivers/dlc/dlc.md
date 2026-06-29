## Summary

| Name                                                | Offset   |   Length | Description                                                 |
|:----------------------------------------------------|:---------|---------:|:------------------------------------------------------------|
| dlc.[`TRANS_SIZE`](#trans_size)                     | 0x0      |        4 | Size of the transaction                                     |
| dlc.[`CURR_LVL`](#curr_lvl)                         | 0x4      |        4 | Current level of the dLC (can be used as initial condition) |
| dlc.[`HYSTERESIS_EN`](#hysteresis_en)               | 0x8      |        4 | Whether or not to have 1-level of hysteresis                |
| dlc.[`DLVL_LOG_LEVEL_WIDTH`](#dlvl_log_level_width) | 0xc      |        4 | Log2 of the level width                                     |
| dlc.[`DISCARD_BITS`](#discard_bits)                 | 0x10     |        4 | Number of LSB to discard                                    |
| dlc.[`DLVL_N_BITS`](#dlvl_n_bits)                   | 0x14     |        4 | Delta level N bits                                          |
| dlc.[`DLVL_MASK`](#dlvl_mask)                       | 0x18     |        4 | Delta level mask                                            |
| dlc.[`DLVL_FORMAT`](#dlvl_format)                   | 0x1c     |        4 | Delta level format                                          |
| dlc.[`DT_MASK`](#dt_mask)                           | 0x20     |        4 | Delta time mask                                             |
| dlc.[`BYPASS`](#bypass)                             | 0x24     |        4 | Bypass input data to output without filter                  |

## TRANS_SIZE
Size of the transaction
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
| 31:16  |        |         |        | Reserved      |
|  15:0  |   rw   |    x    | SIZE   | size          |

## CURR_LVL
Current level of the dLC (can be used as initial condition)
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "LVL", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
| 31:16  |        |         |        | Reserved      |
|  15:0  |   rw   |    x    | LVL    | current level |

## HYSTERESIS_EN
Whether or not to have 1-level of hysteresis
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "HYSTERESIS", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 120}}
```

|  Bits  |  Type  |  Reset  | Name       | Description       |
|:------:|:------:|:-------:|:-----------|:------------------|
|  31:1  |        |         |            | Reserved          |
|   0    |   rw   |    x    | HYSTERESIS | Enable hysteresis |

## DLVL_LOG_LEVEL_WIDTH
Log2 of the level width
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0xf`

### Fields

```wavejson
{"reg": [{"name": "LOG_WL", "bits": 4, "attr": ["rw"], "rotate": 0}, {"bits": 28}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description             |
|:------:|:------:|:-------:|:-------|:------------------------|
|  31:4  |        |         |        | Reserved                |
|  3:0   |   rw   |    x    | LOG_WL | log2 of the level width |

## DISCARD_BITS
Number of LSB to discard
- Offset: `0x10`
- Reset default: `0x0`
- Reset mask: `0xf`

### Fields

```wavejson
{"reg": [{"name": "DISCARD", "bits": 4, "attr": ["rw"], "rotate": -90}, {"bits": 28}], "config": {"lanes": 1, "fontsize": 10, "vspace": 90}}
```

|  Bits  |  Type  |  Reset  | Name    | Description               |
|:------:|:------:|:-------:|:--------|:--------------------------|
|  31:4  |        |         |         | Reserved                  |
|  3:0   |   rw   |    x    | DISCARD | Number of LSBs to discard |

## DLVL_N_BITS
Delta level N bits
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0xf`

### Fields

```wavejson
{"reg": [{"name": "N_BITS", "bits": 4, "attr": ["rw"], "rotate": 0}, {"bits": 28}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                                                           |
|:------:|:------:|:-------:|:-------|:----------------------------------------------------------------------|
|  31:4  |        |         |        | Reserved                                                              |
|  3:0   |   rw   |    x    | N_BITS | number of bits allocated to delta levels within the dlc output packet |

## DLVL_MASK
Delta level mask
- Offset: `0x18`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "MASK", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                                                                                                   |
|:------:|:------:|:-------:|:-------|:--------------------------------------------------------------------------------------------------------------|
| 31:16  |        |         |        | Reserved                                                                                                      |
|  15:0  |   rw   |    x    | MASK   | delta level mask, it has many 1s as the number of bits allocated to delta levels within the dlc output packet |

## DLVL_FORMAT
Delta level format
- Offset: `0x1c`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "TWOSCOMP_N_SGNMOD", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 190}}
```

|  Bits  |  Type  |  Reset  | Name              | Description                                                     |
|:------:|:------:|:-------:|:------------------|:----------------------------------------------------------------|
|  31:1  |        |         |                   | Reserved                                                        |
|   0    |   rw   |    x    | TWOSCOMP_N_SGNMOD | if '1' delta levels are in 2s complement, else sign\\|abs_value |

## DT_MASK
Delta time mask
- Offset: `0x20`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "MASK", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                                                                                                |
|:------:|:------:|:-------:|:-------|:-----------------------------------------------------------------------------------------------------------|
| 31:16  |        |         |        | Reserved                                                                                                   |
|  15:0  |   rw   |    x    | MASK   | delta time mask, it has many 1s as the number of bits allocated to delta time within the dlc output packet |

## BYPASS
Bypass input data to output without filter
- Offset: `0x24`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "BP", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                        |
|:------:|:------:|:-------:|:-------|:-----------------------------------|
|  31:1  |        |         |        | Reserved                           |
|   0    |   rw   |    x    | BP     | if 1, dlc forwards input to output |

