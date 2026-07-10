## Summary

| Name                                                                  | Offset   |   Length | Description                                     |
|:----------------------------------------------------------------------|:---------|---------:|:------------------------------------------------|
| ECC_manager.[`mismatch_count`](#mismatch_count)                       | 0x0      |        4 | Correctable mismatches caught by ecc on access  |
| ECC_manager.[`scrub_interval`](#scrub_interval)                       | 0x4      |        4 | Interval between scrubs                         |
| ECC_manager.[`scrub_fix_count`](#scrub_fix_count)                     | 0x8      |        4 | Correctable mismatches caught by ecc on scrub   |
| ECC_manager.[`scrub_uncorrectable_count`](#scrub_uncorrectable_count) | 0xc      |        4 | Uncorrectable mismatches caught by ecc on scrub |
| ECC_manager.[`write_mask_data_n`](#write_mask_data_n)                 | 0x10     |        4 | Testing: Inverted write mask for data bits      |
| ECC_manager.[`write_mask_ecc_n`](#write_mask_ecc_n)                   | 0x14     |        4 | Testing: Inverted write mask for ECC bits       |

## mismatch_count
Correctable mismatches caught by ecc on access
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "correctable_mismatches", "bits": 32, "attr": ["rw0c"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                   | Description                                    |
|:------:|:------:|:-------:|:-----------------------|:-----------------------------------------------|
|  31:0  |  rw0c  |   0x0   | correctable_mismatches | Correctable mismatches caught by ecc on access |

## scrub_interval
Interval between scrubs
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "scrub_interval", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name           | Description             |
|:------:|:------:|:-------:|:---------------|:------------------------|
|  31:0  |   rw   |    x    | scrub_interval | Interval between scrubs |

## scrub_fix_count
Correctable mismatches caught by ecc on scrub
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "correctable_mismatches", "bits": 32, "attr": ["rw0c"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                   | Description                                   |
|:------:|:------:|:-------:|:-----------------------|:----------------------------------------------|
|  31:0  |  rw0c  |   0x0   | correctable_mismatches | Correctable mismatches caught by ecc on scrub |

## scrub_uncorrectable_count
Uncorrectable mismatches caught by ecc on scrub
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "uncorrectable_mismatches", "bits": 32, "attr": ["rw0c"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                     | Description                                     |
|:------:|:------:|:-------:|:-------------------------|:------------------------------------------------|
|  31:0  |  rw0c  |   0x0   | uncorrectable_mismatches | Uncorrectable mismatches caught by ecc on scrub |

## write_mask_data_n
Testing: Inverted write mask for data bits
- Offset: `0x10`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "write_mask_data_n", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name              | Description                                |
|:------:|:------:|:-------:|:------------------|:-------------------------------------------|
|  31:0  |   rw   |   0x0   | write_mask_data_n | Testing: Inverted write mask for data bits |

## write_mask_ecc_n
Testing: Inverted write mask for ECC bits
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0x7f`

### Fields

```wavejson
{"reg": [{"name": "write_mask_ecc_n", "bits": 7, "attr": ["rw"], "rotate": -90}, {"bits": 25}], "config": {"lanes": 1, "fontsize": 10, "vspace": 180}}
```

|  Bits  |  Type  |  Reset  | Name             | Description                               |
|:------:|:------:|:-------:|:-----------------|:------------------------------------------|
|  31:7  |        |         |                  | Reserved                                  |
|  6:0   |   rw   |   0x0   | write_mask_ecc_n | Testing: Inverted write mask for ECC bits |

