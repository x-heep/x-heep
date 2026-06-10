## Summary

| Name                                          | Offset   |   Length | Description                                                                                                             |
|:----------------------------------------------|:---------|---------:|:------------------------------------------------------------------------------------------------------------------------|
| dma.[`SRC_PTR`](#src_ptr)                     | 0x0      |        4 | Input data pointer (word aligned)                                                                                       |
| dma.[`DST_PTR`](#dst_ptr)                     | 0x4      |        4 | Output data pointer (word aligned)                                                                                      |
| dma.[`ADDR_PTR`](#addr_ptr)                   | 0x8      |        4 | Addess data pointer (word aligned)                                                                                      |
| dma.[`SIZE_D1`](#size_d1)                     | 0xc      |        4 | Number of elements to copy from, defined with respect to the first dimension - Once a value is written, the copy starts |
| dma.[`SIZE_D2`](#size_d2)                     | 0x10     |        4 | Number of elements to copy from, defined with respect to the second dimension                                           |
| dma.[`STATUS`](#status)                       | 0x14     |        4 | Status bits are set to one if a given event occurred                                                                    |
| dma.[`SRC_PTR_INC_D1`](#src_ptr_inc_d1)       | 0x18     |        4 | Increment the D1 source pointer every time a word is copied                                                             |
| dma.[`SRC_PTR_INC_D2`](#src_ptr_inc_d2)       | 0x1c     |        4 | Increment the D2 source pointer every time a word is copied                                                             |
| dma.[`DST_PTR_INC_D1`](#dst_ptr_inc_d1)       | 0x20     |        4 | Increment the D1 destination pointer every time a word is copied                                                        |
| dma.[`DST_PTR_INC_D2`](#dst_ptr_inc_d2)       | 0x24     |        4 | Increment the D2 destination pointer every time a word is copied                                                        |
| dma.[`SLOT`](#slot)                           | 0x28     |        4 | The DMA will wait for the signal                                                                                        |
| dma.[`SRC_DATA_TYPE`](#src_data_type)         | 0x2c     |        4 | Width/type of the source data to transfer                                                                               |
| dma.[`DST_DATA_TYPE`](#dst_data_type)         | 0x30     |        4 | Width/type of the destination data to transfer                                                                          |
| dma.[`SIGN_EXT`](#sign_ext)                   | 0x34     |        4 | Is the data to be sign extended? (Checked only if the dst data type is wider than the src data type)                    |
| dma.[`MODE`](#mode)                           | 0x38     |        4 | Set the operational mode of the DMA                                                                                     |
| dma.[`HW_FIFO_EN`](#hw_fifo_en)               | 0x3c     |        4 | Enable the HW FIFO mode                                                                                                 |
| dma.[`DIM_CONFIG`](#dim_config)               | 0x40     |        4 | Set the dimensionality of the DMA                                                                                       |
| dma.[`DIM_INV`](#dim_inv)                     | 0x44     |        4 | DMA dimensionality inversion selector                                                                                   |
| dma.[`PAD_TOP`](#pad_top)                     | 0x48     |        4 | Set the top padding                                                                                                     |
| dma.[`PAD_BOTTOM`](#pad_bottom)               | 0x4c     |        4 | Set the bottom padding                                                                                                  |
| dma.[`PAD_RIGHT`](#pad_right)                 | 0x50     |        4 | Set the right padding                                                                                                   |
| dma.[`PAD_LEFT`](#pad_left)                   | 0x54     |        4 | Set the left padding                                                                                                    |
| dma.[`WINDOW_SIZE`](#window_size)             | 0x58     |        4 | Will trigger a every "WINDOW_SIZE" writes                                                                               |
| dma.[`WINDOW_COUNT`](#window_count)           | 0x5c     |        4 | Number of times the end of the window was reached since the beginning.                                                  |
| dma.[`INTERRUPT_EN`](#interrupt_en)           | 0x60     |        4 | Interrupt Enable Register                                                                                               |
| dma.[`TRANSACTION_IFR`](#transaction_ifr)     | 0x64     |        4 | Interrupt Flag Register for transactions                                                                                |
| dma.[`WINDOW_IFR`](#window_ifr)               | 0x68     |        4 | Interrupt Flag Register for windows                                                                                     |
| dma.[`HW_CONFIG_MODE`](#hw_config_mode)       | 0x6c     |        4 | Hardware configuration mode                                                                                             |
| dma.[`SLOT_WAIT_COUNTER`](#slot_wait_counter) | 0x70     |        4 | A counter to wait before submitting the next req when using slots                                                       |

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

## ADDR_PTR
Addess data pointer (word aligned)
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "PTR_ADDR", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name     | Description                                                     |
|:------:|:------:|:-------:|:---------|:----------------------------------------------------------------|
|  31:0  |   rw   |    x    | PTR_ADDR | Address data pointer (word aligned) - used only in Address mode |

## SIZE_D1
Number of elements to copy from, defined with respect to the first dimension - Once a value is written, the copy starts
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description              |
|:------:|:------:|:-------:|:-------|:-------------------------|
| 31:16  |        |         |        | Reserved                 |
|  15:0  |   rw   |    x    | SIZE   | DMA counter D1 and start |

## SIZE_D2
Number of elements to copy from, defined with respect to the second dimension
- Offset: `0x10`
- Reset default: `0x0`
- Reset mask: `0xffff`

### Fields

```wavejson
{"reg": [{"name": "SIZE", "bits": 16, "attr": ["rw"], "rotate": 0}, {"bits": 16}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description    |
|:------:|:------:|:-------:|:-------|:---------------|
| 31:16  |        |         |        | Reserved       |
|  15:0  |   rw   |    x    | SIZE   | DMA counter D2 |

## STATUS
Status bits are set to one if a given event occurred
- Offset: `0x14`
- Reset default: `0x1`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "READY", "bits": 1, "attr": ["ro"], "rotate": -90}, {"name": "WINDOW_DONE", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 130}}
```

|  Bits  |  Type  |  Reset  | Name        | Description                       |
|:------:|:------:|:-------:|:------------|:----------------------------------|
|  31:2  |        |         |             | Reserved                          |
|   1    |   ro   |   0x0   | WINDOW_DONE | set if DMA is copying second half |
|   0    |   ro   |   0x1   | READY       | Transaction is done               |

## SRC_PTR_INC_D1
Increment the D1 source pointer every time a word is copied
- Offset: `0x18`
- Reset default: `0x4`
- Reset mask: `0x3f`

### Fields

```wavejson
{"reg": [{"name": "INC", "bits": 6, "attr": ["rw"], "rotate": 0}, {"bits": 26}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                 |
|:------:|:------:|:-------:|:-------|:----------------------------|
|  31:6  |        |         |        | Reserved                    |
|  5:0   |   rw   |   0x4   | INC    | Source pointer d1 increment |

## SRC_PTR_INC_D2
Increment the D2 source pointer every time a word is copied
- Offset: `0x1c`
- Reset default: `0x4`
- Reset mask: `0x7fffff`

### Fields

```wavejson
{"reg": [{"name": "INC", "bits": 23, "attr": ["rw"], "rotate": 0}, {"bits": 9}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                 |
|:------:|:------:|:-------:|:-------|:----------------------------|
| 31:23  |        |         |        | Reserved                    |
|  22:0  |   rw   |   0x4   | INC    | Source pointer d2 increment |

## DST_PTR_INC_D1
Increment the D1 destination pointer every time a word is copied
- Offset: `0x20`
- Reset default: `0x4`
- Reset mask: `0x3f`

### Fields

```wavejson
{"reg": [{"name": "INC", "bits": 6, "attr": ["rw"], "rotate": 0}, {"bits": 26}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                      |
|:------:|:------:|:-------:|:-------|:---------------------------------|
|  31:6  |        |         |        | Reserved                         |
|  5:0   |   rw   |   0x4   | INC    | Destination pointer d1 increment |

## DST_PTR_INC_D2
Increment the D2 destination pointer every time a word is copied
- Offset: `0x24`
- Reset default: `0x4`
- Reset mask: `0x7fffff`

### Fields

```wavejson
{"reg": [{"name": "INC", "bits": 23, "attr": ["rw"], "rotate": 0}, {"bits": 9}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                      |
|:------:|:------:|:-------:|:-------|:---------------------------------|
| 31:23  |        |         |        | Reserved                         |
|  22:0  |   rw   |   0x4   | INC    | Destination pointer d2 increment |

## SLOT
The DMA will wait for the signal
   connected to the selected trigger_slots to be high
   on the read and write side respectively
- Offset: `0x28`
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

## SRC_DATA_TYPE
Width/type of the source data to transfer
- Offset: `0x2c`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "DATA_TYPE", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 110}}
```

|  Bits  |  Type  |  Reset  | Name                                   |
|:------:|:------:|:-------:|:---------------------------------------|
|  31:2  |        |         | Reserved                               |
|  1:0   |   rw   |   0x0   | [DATA_TYPE](#src_data_type--data_type) |

### SRC_DATA_TYPE . DATA_TYPE
Data type

| Value   | Name            | Description       |
|:--------|:----------------|:------------------|
| 0x0     | DMA_32BIT_WORD  | Transfers 32 bits |
| 0x1     | DMA_16BIT_WORD  | Transfers 16 bits |
| 0x2     | DMA_8BIT_WORD   | Transfers  8 bits |
| 0x3     | DMA_8BIT_WORD_2 | Transfers  8 bits |


## DST_DATA_TYPE
Width/type of the destination data to transfer
- Offset: `0x30`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "DATA_TYPE", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 110}}
```

|  Bits  |  Type  |  Reset  | Name                                   |
|:------:|:------:|:-------:|:---------------------------------------|
|  31:2  |        |         | Reserved                               |
|  1:0   |   rw   |   0x0   | [DATA_TYPE](#dst_data_type--data_type) |

### DST_DATA_TYPE . DATA_TYPE
Data type

| Value   | Name            | Description       |
|:--------|:----------------|:------------------|
| 0x0     | DMA_32BIT_WORD  | Transfers 32 bits |
| 0x1     | DMA_16BIT_WORD  | Transfers 16 bits |
| 0x2     | DMA_8BIT_WORD   | Transfers  8 bits |
| 0x3     | DMA_8BIT_WORD_2 | Transfers  8 bits |


## SIGN_EXT
Is the data to be sign extended? (Checked only if the dst data type is wider than the src data type)
- Offset: `0x34`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "SIGNED", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                        |
|:------:|:------:|:-------:|:----------------------------|
|  31:1  |        |         | Reserved                    |
|   0    |   rw   |   0x0   | [SIGNED](#sign_ext--signed) |

### SIGN_EXT . SIGNED
Extend the sign to the destination data

| Value   | Name      | Description              |
|:--------|:----------|:-------------------------|
| 0x0     | NO_EXTEND | Does not extend the sign |
| 0x1     | EXTEND    | Extends the sign         |


## MODE
Set the operational mode of the DMA
- Offset: `0x38`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "MODE", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                |
|:------:|:------:|:-------:|:--------------------|
|  31:2  |        |         | Reserved            |
|  1:0   |   rw   |   0x0   | [MODE](#mode--mode) |

### MODE . MODE
DMA operation mode

| Value   | Name            | Description                                                                       |
|:--------|:----------------|:----------------------------------------------------------------------------------|
| 0x0     | LINEAR_MODE     | Transfers data linearly                                                           |
| 0x1     | CIRCULAR_MODE   | Transfers data in circular mode                                                   |
| 0x2     | ADDRESS_MODE    | Transfers data using as destination address the data from ADD_PTR                 |
| 0x3     | SUBADDRESS_MODE | Implements transferring of data when SRC_PTR is fixed and related to a peripheral |


## HW_FIFO_EN
Enable the HW FIFO mode
- Offset: `0x3c`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "HW_FIFO_MODE", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 140}}
```

|  Bits  |  Type  |  Reset  | Name         | Description                                     |
|:------:|:------:|:-------:|:-------------|:------------------------------------------------|
|  31:1  |        |         |              | Reserved                                        |
|   0    |   rw   |   0x0   | HW_FIFO_MODE | Mode for exploting external stream accelerators |

## DIM_CONFIG
Set the dimensionality of the DMA
- Offset: `0x40`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "DMA_DIM", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 90}}
```

|  Bits  |  Type  |  Reset  | Name    | Description                 |
|:------:|:------:|:-------:|:--------|:----------------------------|
|  31:1  |        |         |         | Reserved                    |
|   0    |   rw   |   0x0   | DMA_DIM | DMA transfer dimensionality |

## DIM_INV
DMA dimensionality inversion selector
- Offset: `0x44`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "SEL", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                                                 |
|:------:|:------:|:-------:|:-------|:------------------------------------------------------------|
|  31:1  |        |         |        | Reserved                                                    |
|   0    |   rw   |   0x0   | SEL    | DMA dimensionality inversion, used to perform transposition |

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

## WINDOW_SIZE
Will trigger a every "WINDOW_SIZE" writes
   Set to 0 to disable.
- Offset: `0x58`
- Reset default: `0x0`
- Reset mask: `0x1fff`

### Fields

```wavejson
{"reg": [{"name": "WINDOW_SIZE", "bits": 13, "attr": ["rw"], "rotate": 0}, {"bits": 19}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name        | Description   |
|:------:|:------:|:-------:|:------------|:--------------|
| 31:13  |        |         |             | Reserved      |
|  12:0  |   rw   |   0x0   | WINDOW_SIZE |               |

## WINDOW_COUNT
Number of times the end of the window was reached since the beginning.
   Reset at start
- Offset: `0x5c`
- Reset default: `0x0`
- Reset mask: `0xff`

### Fields

```wavejson
{"reg": [{"name": "WINDOW_COUNT", "bits": 8, "attr": ["ro"], "rotate": 0}, {"bits": 24}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name         | Description                                      |
|:------:|:------:|:-------:|:-------------|:-------------------------------------------------|
|  31:8  |        |         |              | Reserved                                         |
|  7:0   |   ro   |   0x0   | WINDOW_COUNT | Number of windows transferred in the transaction |

## INTERRUPT_EN
Interrupt Enable Register
   (Only the interrupt with the lowest id will be triggered)
- Offset: `0x60`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "TRANSACTION_DONE", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "WINDOW_DONE", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 180}}
```

|  Bits  |  Type  |  Reset  | Name             | Description                        |
|:------:|:------:|:-------:|:-----------------|:-----------------------------------|
|  31:2  |        |         |                  | Reserved                           |
|   1    |   rw   |   0x0   | WINDOW_DONE      | Enables window done interrupt      |
|   0    |   rw   |   0x0   | TRANSACTION_DONE | Enables transaction done interrupt |

## TRANSACTION_IFR
Interrupt Flag Register for transactions
- Offset: `0x64`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "FLAG", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                        |
|:------:|:------:|:-------:|:-------|:-----------------------------------|
|  31:1  |        |         |        | Reserved                           |
|   0    |   ro   |   0x0   | FLAG   | Set for transaction done interrupt |

## WINDOW_IFR
Interrupt Flag Register for windows
- Offset: `0x68`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "FLAG", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                   |
|:------:|:------:|:-------:|:-------|:------------------------------|
|  31:1  |        |         |        | Reserved                      |
|   0    |   ro   |   0x0   | FLAG   | Set for window done interrupt |

## HW_CONFIG_MODE
Hardware configuration mode
- Offset: `0x6c`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "HW_CONFIG_MODE", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 160}}
```

|  Bits  |  Type  |  Reset  | Name           | Description                                                       |
|:------:|:------:|:-------:|:---------------|:------------------------------------------------------------------|
|  31:1  |        |         |                | Reserved                                                          |
|   0    |   rw   |   0x0   | HW_CONFIG_MODE | Whether the registers are configured in HW (1) or SW (0, default) |

## SLOT_WAIT_COUNTER
A counter to wait before submitting the next req when using slots
- Offset: `0x70`
- Reset default: `0x0`
- Reset mask: `0xff`

### Fields

```wavejson
{"reg": [{"name": "SLOT_WAIT_COUNTER", "bits": 8, "attr": ["rw"], "rotate": -90}, {"bits": 24}], "config": {"lanes": 1, "fontsize": 10, "vspace": 190}}
```

|  Bits  |  Type  |  Reset  | Name              | Description                                                       |
|:------:|:------:|:-------:|:------------------|:------------------------------------------------------------------|
|  31:8  |        |         |                   | Reserved                                                          |
|  7:0   |   rw   |   0x0   | SLOT_WAIT_COUNTER | A counter to wait before submitting the next req when using slots |

