## Summary

| Name                                         | Offset   |   Length | Description                    |
|:---------------------------------------------|:---------|---------:|:-------------------------------|
| ODRG_manager.[`SP_store`](#sp_store)         | 0x0      |        4 | Stack Pointer storage register |
| ODRG_manager.[`MODE`](#mode)                 | 0x4      |        4 | Redundancy Mode configuration  |
| ODRG_manager.[`MISMATCHES_0`](#mismatches_0) | 0x8      |        4 | Mismatch counter of core 0     |
| ODRG_manager.[`MISMATCHES_1`](#mismatches_1) | 0xc      |        4 | Mismatch counter of core 1     |
| ODRG_manager.[`MISMATCHES_2`](#mismatches_2) | 0x10     |        4 | Mismatch counter of core 2     |

## SP_store
Stack Pointer storage register
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "SP", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:0  |   rw   |    x    | SP     | Stack Pointer |

## MODE
Redundancy Mode configuration
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0x1f`

### Fields

```wavejson
{"reg": [{"name": "MODE", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "DELAY_RESYNCH", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "SETBACK", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "RELOAD_SETBACK", "bits": 1, "attr": ["rw"], "rotate": -90}, {"name": "FORCE_RESYNCH", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 27}], "config": {"lanes": 1, "fontsize": 10, "vspace": 160}}
```

|  Bits  |  Type  |  Reset  | Name           | Description                                                                               |
|:------:|:------:|:-------:|:---------------|:------------------------------------------------------------------------------------------|
|  31:5  |        |         |                | Reserved                                                                                  |
|   4    |   rw   |    x    | FORCE_RESYNCH  | Forces a resynchronization routine                                                        |
|   3    |   rw   |    x    | RELOAD_SETBACK | Enable setback on mismatch during reload section of re-synch (only possible with SETBACK) |
|   2    |   rw   |    x    | SETBACK        | Enable setback (synchronous reset) during re-synch                                        |
|   1    |   rw   |    x    | DELAY_RESYNCH  | Enable wait-for-restoration                                                               |
|   0    |   rw   |    x    | MODE           | TMR mode enable                                                                           |

## MISMATCHES_0
Mismatch counter of core 0
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "mismatches_0", "bits": 32, "attr": ["rw0c"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name         | Description                |
|:------:|:------:|:-------:|:-------------|:---------------------------|
|  31:0  |  rw0c  |    x    | mismatches_0 | mismatch counter of core 0 |

## MISMATCHES_1
Mismatch counter of core 1
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "mismatches_1", "bits": 32, "attr": ["rw0c"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name         | Description                |
|:------:|:------:|:-------:|:-------------|:---------------------------|
|  31:0  |  rw0c  |    x    | mismatches_1 | mismatch counter of core 1 |

## MISMATCHES_2
Mismatch counter of core 2
- Offset: `0x10`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "mismatches_2", "bits": 32, "attr": ["rw0c"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name         | Description                |
|:------:|:------:|:-------:|:-------------|:---------------------------|
|  31:0  |  rw0c  |    x    | mismatches_2 | mismatch counter of core 2 |

