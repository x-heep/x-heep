## Summary

| Name                                           | Offset   |   Length | Description                                                       |
|:-----------------------------------------------|:---------|---------:|:------------------------------------------------------------------|
| im2col_spc.[`SRC_PTR`](#src_ptr)               | 0x0      |        4 | Input data pointer (word aligned)                                 |
| im2col_spc.[`DST_PTR`](#dst_ptr)               | 0x4      |        4 | Output data pointer (word aligned)                                |
| im2col_spc.[`IW`](#iw)                         | 0x8      |        4 | Image width                                                       |
| im2col_spc.[`IH`](#ih)                         | 0xc      |        4 | Image heigth                                                      |
| im2col_spc.[`FW`](#fw)                         | 0x10     |        4 | Filter width                                                      |
| im2col_spc.[`FH`](#fh)                         | 0x14     |        4 | Filter heigth                                                     |
| im2col_spc.[`BATCH`](#batch)                   | 0x18     |        4 | Batch number                                                      |
| im2col_spc.[`NUM_CH`](#num_ch)                 | 0x1c     |        4 | Number of channels. When written, the im2col will start executing |
| im2col_spc.[`CH_COL`](#ch_col)                 | 0x20     |        4 | Number of iterations to perform                                   |
| im2col_spc.[`N_PATCHES_W`](#n_patches_w)       | 0x24     |        4 | Number of patches along W                                         |
| im2col_spc.[`N_PATCHES_H`](#n_patches_h)       | 0x28     |        4 | Number of patches along H                                         |
| im2col_spc.[`LAST_PATCH_H`](#last_patch_h)     | 0x2c     |        4 | Adapted right padded region                                       |
| im2col_spc.[`LAST_PATCH_W`](#last_patch_w)     | 0x30     |        4 | Adapted bottom padded region                                      |
| im2col_spc.[`LOG_STRIDES_D1`](#log_strides_d1) | 0x34     |        4 | Logarithmic number of strides along D1, set to 1 for no stride    |
| im2col_spc.[`LOG_STRIDES_D2`](#log_strides_d2) | 0x38     |        4 | Logarithmic number of strides along D2, set to 1 for no stride    |
| im2col_spc.[`STATUS`](#status)                 | 0x3c     |        4 | Status bit is set to one when the im2col SPC is ready             |
| im2col_spc.[`SLOT`](#slot)                     | 0x40     |        4 | The DMA will wait for the signal                                  |
| im2col_spc.[`DATA_TYPE`](#data_type)           | 0x44     |        4 | Width/type of the data to transfer                                |
| im2col_spc.[`PAD_TOP`](#pad_top)               | 0x48     |        4 | Set the top padding                                               |
| im2col_spc.[`PAD_BOTTOM`](#pad_bottom)         | 0x4c     |        4 | Set the bottom padding                                            |
| im2col_spc.[`PAD_RIGHT`](#pad_right)           | 0x50     |        4 | Set the right padding                                             |
| im2col_spc.[`PAD_LEFT`](#pad_left)             | 0x54     |        4 | Set the left padding                                              |
| im2col_spc.[`INTERRUPT_EN`](#interrupt_en)     | 0x58     |        4 | Interrupt Enable Register                                         |
| im2col_spc.[`SPC_IFR`](#spc_ifr)               | 0x5c     |        4 | Interrupt Flag Register for the SPC operation                     |
| im2col_spc.[`SPC_CH_MASK`](#spc_ch_mask)       | 0x60     |        4 | Mask that defines which DMA channel the SPC can access            |
| im2col_spc.[`SPC_CH_OFFSET`](#spc_ch_offset)   | 0x64     |        4 | Offset of the DMA channel the SPC can access                      |

## SRC_PTR
Input data pointer (word aligned)
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "PTR_IN", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                       |
|:------:|:------:|:-------:|:-------|:----------------------------------|
|  31:0  |   rw   |    x    | PTR_IN | Input data pointer (word aligned) |

## DST_PTR
Output data pointer (word aligned)
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "PTR_OUT", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name    | Description                        |
|:------:|:------:|:-------:|:--------|:-----------------------------------|
|  31:0  |   rw   |    x    | PTR_OUT | Output data pointer (word aligned) |

## IW
Image width
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
| 31:16  |        |         |        | Reserved      |
|  15:0  |   rw   |    x    | SIZE   | Image width   |

## IH
Image heigth
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
| 31:16  |        |         |        | Reserved      |
|  15:0  |   rw   |    x    | SIZE   | Image heigth  |

## FW
Filter width
- Offset: `0x10`
- Reset default: `0x0`
- Reset mask: `0xff`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 8, "attr": ["rw"], "rotate": 0}, {"bits": 24}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:8  |        |         |        | Reserved      |
|  7:0   |   rw   |    x    | SIZE   | Filter width  |

## FH
Filter heigth
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0xff`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 8, "attr": ["rw"], "rotate": 0}, {"bits": 24}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:8  |        |         |        | Reserved      |
|  7:0   |   rw   |    x    | SIZE   | Filter heigth |

## BATCH
Batch number
- Offset: `0x18`
- Reset default: `0x0`
- Reset mask: `0xff`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 8, "attr": ["rw"], "rotate": 0}, {"bits": 24}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:8  |        |         |        | Reserved      |
|  7:0   |   rw   |    x    | SIZE   | Batch size    |

## NUM_CH
Number of channels. When written, the im2col will start executing
- Offset: `0x1c`
- Reset default: `0x0`
- Reset mask: `0xff`

### Fields

```wavejson
{"reg": [{"name": "NUM", "bits": 8, "attr": ["rw"], "rotate": 0}, {"bits": 24}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description        |
|:------:|:------:|:-------:|:-------|:-------------------|
|  31:8  |        |         |        | Reserved           |
|  7:0   |   rw   |    x    | NUM    | Number of channels |

## CH_COL
Number of iterations to perform
- Offset: `0x20`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "NUM", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description          |
|:------:|:------:|:-------:|:-------|:---------------------|
| 31:16  |        |         |        | Reserved             |
|  15:0  |   rw   |    x    | NUM    | Number of iterations |

## N_PATCHES_W
Number of patches along W
- Offset: `0x24`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "NUM", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description       |
|:------:|:------:|:-------:|:-------|:------------------|
| 31:16  |        |         |        | Reserved          |
|  15:0  |   rw   |    x    | NUM    | Number of patches |

## N_PATCHES_H
Number of patches along H
- Offset: `0x28`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "NUM", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description       |
|:------:|:------:|:-------:|:-------|:------------------|
| 31:16  |        |         |        | Reserved          |
|  15:0  |   rw   |    x    | NUM    | Number of patches |

## LAST_PATCH_H
Adapted right padded region
- Offset: `0x2c`
- Reset default: `0x0`
- Reset mask: `0xff`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 8, "attr": ["rw"], "rotate": 0}, {"bits": 24}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                                                                                    |
|:------:|:------:|:-------:|:-------|:-----------------------------------------------------------------------------------------------|
|  31:8  |        |         |        | Reserved                                                                                       |
|  7:0   |   rw   |    x    | SIZE   | Difference between the location of the first element of the last patch along the height and IH |

## LAST_PATCH_W
Adapted bottom padded region
- Offset: `0x30`
- Reset default: `0x0`
- Reset mask: `0xff`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 8, "attr": ["rw"], "rotate": 0}, {"bits": 24}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                                                                                   |
|:------:|:------:|:-------:|:-------|:----------------------------------------------------------------------------------------------|
|  31:8  |        |         |        | Reserved                                                                                      |
|  7:0   |   rw   |    x    | SIZE   | Difference between the location of the first element of the last patch along the width and IW |

## LOG_STRIDES_D1
Logarithmic number of strides along D1, set to 1 for no stride
- Offset: `0x34`
- Reset default: `0x0`
- Reset mask: `0xf`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 4, "attr": ["rw"], "rotate": 0}, {"bits": 28}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:4  |        |         |        | Reserved      |
|  3:0   |   rw   |    x    | SIZE   | Stride size   |

## LOG_STRIDES_D2
Logarithmic number of strides along D2, set to 1 for no stride
- Offset: `0x38`
- Reset default: `0x0`
- Reset mask: `0xf`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 4, "attr": ["rw"], "rotate": 0}, {"bits": 28}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:4  |        |         |        | Reserved      |
|  3:0   |   rw   |    x    | SIZE   | Stride size   |

## STATUS
Status bit is set to one when the im2col SPC is ready
- Offset: `0x3c`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "READY", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:1  |        |         |        | Reserved      |
|   0    |   ro   |   0x1   | READY  | SPC is done   |

## SLOT
The DMA will wait for the signal 
   connected to the selected trigger_slots to be high
   on the read and write side respectivly
- Offset: `0x40`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "RX_TRIGGER_SLOT", "bits": 16, "attr": ["rw"], "rotate": 0}, {"name": "TX_TRIGGER_SLOT", "bits": 16, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name            | Description         |
|:------:|:------:|:-------:|:----------------|:--------------------|
| 31:16  |   rw   |   0x0   | TX_TRIGGER_SLOT | Slot selection mask |
|  15:0  |   rw   |   0x0   | RX_TRIGGER_SLOT | Slot selection mask |

## DATA_TYPE
Width/type of the data to transfer
- Offset: `0x44`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "DATA_TYPE", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 110}}
```

|  Bits  |  Type  |  Reset  | Name                               |
|:------:|:------:|:-------:|:-----------------------------------|
|  31:2  |        |         | Reserved                           |
|  1:0   |   rw   |   0x0   | [DATA_TYPE](#data_type--data_type) |

### DATA_TYPE . DATA_TYPE
Data type

| Value   | Name            | Description       |
|:--------|:----------------|:------------------|
| 0x0     | DMA_32BIT_WORD  | Transfers 32 bits |
| 0x1     | DMA_16BIT_WORD  | Transfers 16 bits |
| 0x2     | DMA_8BIT_WORD   | Transfers  8 bits |
| 0x3     | DMA_8BIT_WORD_2 | Transfers  8 bits |


## PAD_TOP
Set the top padding
- Offset: `0x48`
- Reset default: `0x0`
- Reset mask: `0x3f`

### Fields

```wavejson
{"reg": [{"name": "PAD", "bits": 6, "attr": ["rw"], "rotate": 0}, {"bits": 26}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description             |
|:------:|:------:|:-------:|:-------|:------------------------|
|  31:6  |        |         |        | Reserved                |
|  5:0   |   rw   |   0x0   | PAD    | Top margin padding (2D) |

## PAD_BOTTOM
Set the bottom padding
- Offset: `0x4c`
- Reset default: `0x0`
- Reset mask: `0x3f`

### Fields

```wavejson
{"reg": [{"name": "PAD", "bits": 6, "attr": ["rw"], "rotate": 0}, {"bits": 26}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                |
|:------:|:------:|:-------:|:-------|:---------------------------|
|  31:6  |        |         |        | Reserved                   |
|  5:0   |   rw   |   0x0   | PAD    | Bottom margin padding (2D) |

## PAD_RIGHT
Set the right padding
- Offset: `0x50`
- Reset default: `0x0`
- Reset mask: `0x3f`

### Fields

```wavejson
{"reg": [{"name": "PAD", "bits": 6, "attr": ["rw"], "rotate": 0}, {"bits": 26}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                  |
|:------:|:------:|:-------:|:-------|:-----------------------------|
|  31:6  |        |         |        | Reserved                     |
|  5:0   |   rw   |   0x0   | PAD    | Right margin padding (1D/2D) |

## PAD_LEFT
Set the left padding
- Offset: `0x54`
- Reset default: `0x0`
- Reset mask: `0x3f`

### Fields

```wavejson
{"reg": [{"name": "PAD", "bits": 6, "attr": ["rw"], "rotate": 0}, {"bits": 26}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                 |
|:------:|:------:|:-------:|:-------|:----------------------------|
|  31:6  |        |         |        | Reserved                    |
|  5:0   |   rw   |   0x0   | PAD    | Left margin padding (1D/2D) |

## INTERRUPT_EN
Interrupt Enable Register
- Offset: `0x58`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                      |
|:------:|:------:|:-------:|:-------|:---------------------------------|
|  31:1  |        |         |        | Reserved                         |
|   0    |   rw   |    x    | EN     | Enables operation done interrupt |

## SPC_IFR
Interrupt Flag Register for the SPC operation
- Offset: `0x5c`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "FLAG", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                      |
|:------:|:------:|:-------:|:-------|:---------------------------------|
|  31:1  |        |         |        | Reserved                         |
|   0    |   ro   |   0x0   | FLAG   | Set for operation done interrupt |

## SPC_CH_MASK
Mask that defines which DMA channel the SPC can access
- Offset: `0x60`
- Reset default: `0x1`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "MASK", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description         |
|:------:|:------:|:-------:|:-------|:--------------------|
|  31:0  |   rw   |   0x1   | MASK   | Mask of DMA channel |

## SPC_CH_OFFSET
Offset of the DMA channel the SPC can access
- Offset: `0x64`
- Reset default: `0x1`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "OFF", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description            |
|:------:|:------:|:-------:|:-------|:-----------------------|
|  31:0  |   rw   |   0x1   | OFF    | Offset of DMA channels |

