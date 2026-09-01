## Summary

| Name                           | Offset   |   Length | Description                                                                        |
|:-------------------------------|:---------|---------:|:-----------------------------------------------------------------------------------|
| hdmi.[`CTRL`](#ctrl)           | 0x0      |        4 | Video output control                                                               |
| hdmi.[`COLOR`](#color)         | 0x4      |        4 | Solid colour used when CTRL.PATTERN is 3                                           |
| hdmi.[`STATUS`](#status)       | 0x8      |        4 | Video output status                                                                |
| hdmi.[`FRAME_CNT`](#frame_cnt) | 0xc      |        4 | Frames sent since reset. Counted in the bus clock domain on the rising edge of the |
| hdmi.[`PIXEL`](#pixel)         | 0x10     |        4 | Pixel FIFO push, used when CTRL.PATTERN is 4. Write one 0x00RRGGBB word per        |

## CTRL
Video output control
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0xf`

### Fields

```wavejson
{"reg": [{"name": "EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "PATTERN", "bits": 3, "attr": ["rw"], "rotate": -90}, {"bits": 28}], "config": {"lanes": 1, "fontsize": 10, "vspace": 90}}
```

|  Bits  |  Type  |  Reset  | Name    | Description                                                                                                                                                                                                                           |
|:------:|:------:|:-------:|:--------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|  31:4  |        |         |         | Reserved                                                                                                                                                                                                                              |
|  3:1   |   rw   |   0x0   | PATTERN | Test pattern: 0 = colour bars, 1 = XOR texture,    2 = checkerboard with a red border,    3 = solid colour taken from COLOR,    4 = pixel stream written through the PIXEL window,    one word per screen pixel at native resolution. |
|   0    |   rw   |   0x0   | EN      | Enable the visible image. The link keeps sending sync    even when this is 0, so the monitor stays locked and    simply shows a black screen.                                                                                         |

## COLOR
Solid colour used when CTRL.PATTERN is 3
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0xffffff`

### Fields

```wavejson
{"reg": [{"name": "RGB", "bits": 24, "attr": ["rw"], "rotate": 0}, {"bits": 8}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                                     |
|:------:|:------:|:-------:|:-------|:------------------------------------------------|
| 31:24  |        |         |        | Reserved                                        |
|  23:0  |   rw   |   0x0   | RGB    | Red in [23:16], green in [15:8], blue in [7:0]. |

## STATUS
Video output status
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "VSYNC", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                                                                                     |
|:------:|:------:|:-------:|:-------|:------------------------------------------------------------------------------------------------|
|  31:1  |        |         |        | Reserved                                                                                        |
|   0    |   ro   |    x    | VSYNC  | High while the pixel side is inside vertical sync,    resynchronised into the bus clock domain. |

## FRAME_CNT
Frames sent since reset. Counted in the bus clock domain on the rising edge of the
   resynchronised vertical sync, so a value that keeps changing proves the pixel clock
   is actually running.
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "COUNT", "bits": 32, "attr": ["ro"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:0  |   ro   |    x    | COUNT  | Frame count.  |

## PIXEL
Pixel FIFO push, used when CTRL.PATTERN is 4. Write one 0x00RRGGBB word per
   screen pixel, in raster order (row-major, native resolution, no replication).
   There is no frame buffer behind this window, only a shallow CDC FIFO, so
   software (typically via DMA, possibly straight from another peripheral's own
   window) must re-push the whole frame roughly every 16ms (once per HDMI frame) or
   the picture starts showing stale pixels. A write stalls (bus not ready) while the
   FIFO is full, which is what paces a DMA transfer into this window.
   

- Word Aligned Offset Range: `0x10`to`0x10`
- Size (words): `1`
- Access: `wo`
- Byte writes are *not* supported.

