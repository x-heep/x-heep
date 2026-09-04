## Summary

| Name                            | Offset   |   Length | Description                         |
|:--------------------------------|:---------|---------:|:------------------------------------|
| i2s.[`CONTROL`](#control)       | 0x0      |        4 | control register                    |
| i2s.[`STATUS`](#status)         | 0x4      |        4 | Status flags of the I2s peripheral  |
| i2s.[`CLKDIVIDX`](#clkdividx)   | 0x8      |        4 | Control register                    |
| i2s.[`RXDATA`](#rxdata)         | 0xc      |        4 | I2s Receive data                    |
| i2s.[`WATERMARK`](#watermark)   | 0x10     |        4 | Watermark to reach for an interrupt |
| i2s.[`WATERLEVEL`](#waterlevel) | 0x14     |        4 | Watermark counter level             |
| i2s.[`TXDATA`](#txdata)         | 0x18     |        4 | I2s Transmit data                   |

## CONTROL
control register
- Offset: `0x0`
- Reset default: `0x300`
- Reset mask: `0x7fff`

### Fields

```wavejson
{"reg": [{"name": "EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "EN_WS", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "EN_RX", "bits": 2, "attr": ["rw"], "rotate": -90}, {"name": "INTR_EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "EN_WATERMARK", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "RESET_WATERMARK", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "EN_IO", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "DATA_WIDTH", "bits": 2, "attr": ["rw"], "rotate": -90}, {"name": "RX_START_CHANNEL", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "RESET_RX_OVERFLOW", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "EN_TX", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "RESET_TX_UNDERFLOW", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "RESET_TX_OVERFLOW", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 17}], "config": {"lanes": 1, "fontsize": 10, "vspace": 200}}
```

|  Bits  |  Type  |  Reset  | Name                                               |
|:------:|:------:|:-------:|:---------------------------------------------------|
| 31:15  |        |         | Reserved                                           |
|   14   |   rw   |    x    | [RESET_TX_OVERFLOW](#control--reset_tx_overflow)   |
|   13   |   rw   |    x    | [RESET_TX_UNDERFLOW](#control--reset_tx_underflow) |
|   12   |   rw   |    x    | [EN_TX](#control--en_tx)                           |
|   11   |   rw   |    x    | [RESET_RX_OVERFLOW](#control--reset_rx_overflow)   |
|   10   |   rw   |   0x0   | [RX_START_CHANNEL](#control--rx_start_channel)     |
|  9:8   |   rw   |   0x3   | [DATA_WIDTH](#control--data_width)                 |
|   7    |   rw   |    x    | [EN_IO](#control--en_io)                           |
|   6    |   rw   |    x    | [RESET_WATERMARK](#control--reset_watermark)       |
|   5    |   rw   |    x    | [EN_WATERMARK](#control--en_watermark)             |
|   4    |   rw   |    x    | [INTR_EN](#control--intr_en)                       |
|  3:2   |   rw   |   0x0   | [EN_RX](#control--en_rx)                           |
|   1    |   rw   |    x    | [EN_WS](#control--en_ws)                           |
|   0    |   rw   |    x    | [EN](#control--en)                                 |

### CONTROL . RESET_TX_OVERFLOW
reset tx overflow

### CONTROL . RESET_TX_UNDERFLOW
reset tx underflow

### CONTROL . EN_TX
Enable TX channel

### CONTROL . RESET_RX_OVERFLOW
reset rx overflow

### CONTROL . RX_START_CHANNEL
Channel (left/right) of first sample - alternating afterwards.

| Value   | Name        | Description                                 |
|:--------|:------------|:--------------------------------------------|
| 0x0     | LEFT_FIRST  | Start left channel first (default for WAVE) |
| 0x1     | RIGHT_FIRST | Start right channel first                   |


### CONTROL . DATA_WIDTH
Bytes per sample

| Value   | Name    | Description   |
|:--------|:--------|:--------------|
| 0x0     | 8_BITS  | 8 bits        |
| 0x1     | 16_BITS | 16 bits       |
| 0x2     | 24_BITS | 24 bits       |
| 0x3     | 32_BITS | 32 bits       |


### CONTROL . EN_IO
connects the peripheral to the IOs

### CONTROL . RESET_WATERMARK
reset watermark counter

### CONTROL . EN_WATERMARK
en watermark counter

### CONTROL . INTR_EN
enable watermark interrupt

### CONTROL . EN_RX
Enable rx channels

| Value   | Name          | Description          |
|:--------|:--------------|:---------------------|
| 0x0     | DISABLED      | Disable I2s          |
| 0x1     | ONLY_LEFT     | Enable left channel  |
| 0x2     | ONLY_RIGHT    | Enable right channel |
| 0x3     | BOTH_CHANNELS | Enable both channels |


### CONTROL . EN_WS
Enable word select generation

### CONTROL . EN
Enable I2s - CLK Domain

## STATUS
Status flags of the I2s peripheral
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0x3f`

### Fields

```wavejson
{"reg": [{"name": "RUNNING", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "RX_DATA_READY", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "RX_OVERFLOW", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "TX_READY", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "TX_UNDERFLOW", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "TX_OVERFLOW", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 26}], "config": {"lanes": 1, "fontsize": 10, "vspace": 150}}
```

|  Bits  |  Type  |  Reset  | Name          | Description                                                         |
|:------:|:------:|:-------:|:--------------|:--------------------------------------------------------------------|
|  31:6  |        |         |               | Reserved                                                            |
|   5    |   ro   |    x    | TX_OVERFLOW   | 1 to indicate that software wrote TXDATA while the TX FIFO was full |
|   4    |   ro   |    x    | TX_UNDERFLOW  | 1 to indicate that TX needed a sample but the FIFO was empty        |
|   3    |   ro   |    x    | TX_READY      | 1 to indicate that the TX FIFO can accept a sample                  |
|   2    |   ro   |    x    | RX_OVERFLOW   | 1 to indicate that an RX happend - disable rx_channel to clear      |
|   1    |   ro   |    x    | RX_DATA_READY | 1 to indicate that an RX sample is ready                            |
|   0    |   ro   |    x    | RUNNING       | 1 to indicate that SCK is on                                        |

## CLKDIVIDX
Control register
- Offset: `0x8`
- Reset default: `0x4`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "COUNT", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                  |
|:------:|:------:|:-------:|:-------|:-----------------------------|
| 31:16  |        |         |        | Reserved                     |
|  15:0  |   rw   |   0x4   | COUNT  | Index at which clock divide. |

## RXDATA
I2s Receive data
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "RXDATA", "bits": 32, "attr": ["ro"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                              |
|:------:|:------:|:-------:|:-------|:-----------------------------------------|
|  31:0  |   ro   |    x    | RXDATA | latest rx data if DATA_READY flag is set |

## WATERMARK
Watermark to reach for an interrupt
- Offset: `0x10`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "Watermark", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name      | Description                                                             |
|:------:|:------:|:-------:|:----------|:------------------------------------------------------------------------|
| 31:16  |        |         |           | Reserved                                                                |
|  15:0  |   rw   |    x    | Watermark | Count of RX samples written to memory which should trigger an interrupt |

## WATERLEVEL
Watermark counter level
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "Waterlevel", "bits": 16, "attr": ["ro"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name       | Description         |
|:------:|:------:|:-------:|:-----------|:--------------------|
| 31:16  |        |         |            | Reserved            |
|  15:0  |   ro   |    x    | Waterlevel | Count of RX samples |

## TXDATA
I2s Transmit data
- Offset: `0x18`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "TXDATA", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description          |
|:------:|:------:|:-------:|:-------|:---------------------|
|  31:0  |   rw   |    x    | TXDATA | TX sample to enqueue |
