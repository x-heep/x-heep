## Summary

| Name                         | Offset   |   Length | Description                           |
|:-----------------------------|:---------|---------:|:--------------------------------------|
| camera.[`CONTROL`](#control) | 0x0      |        4 | Control register for flash controller |
| camera.[`STATUS`](#status)   | 0x4      |        4 | Status register for flash controller  |
| camera.[`DATA`](#data)       | 0x8      |        4 | Camera data window.                   |

## CONTROL
Control register for flash controller
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0x7`

### Fields

```wavejson
{"reg": [{"name": "START", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "PWND", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "RESET", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 29}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                   |
|:------:|:------:|:-------:|:-------|:------------------------------|
|  31:3  |        |         |        | Reserved                      |
|   2    |   rw   |   0x0   | RESET  | Control the camera reset      |
|   1    |   rw   |   0x0   | PWND   | Control the camera power-down |
|   0    |   rw   |   0x0   | START  | Start operation               |

## STATUS
Status register for flash controller
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "RUNNING", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 90}}
```

|  Bits  |  Type  |  Reset  | Name    | Description      |
|:------:|:------:|:-------:|:--------|:-----------------|
|  31:1  |        |         |         | Reserved         |
|   0    |   ro   |   0x0   | RUNNING | Frame is running |

## DATA
Camera data window.
   

- Word Aligned Offset Range: `0x8`to`0x8`
- Size (words): `1`
- Access: `ro`
- Byte writes are *not* supported.

