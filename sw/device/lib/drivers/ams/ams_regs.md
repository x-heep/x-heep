## Summary

| Name              | Offset   |   Length | Description                                                |
|:------------------|:---------|---------:|:-----------------------------------------------------------|
| ams.[`SEL`](#sel) | 0x0      |        4 | Select the ADC threshold value (20%, 40%, 60%, 80% of VDD) |
| ams.[`GET`](#get) | 0x4      |        4 | Get the ADC output                                         |

## SEL
Select the ADC threshold value (20%, 40%, 60%, 80% of VDD)
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "VALUE", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description                 |
|:------:|:------:|:-------:|:-------|:----------------------------|
|  31:2  |        |         |        | Reserved                    |
|  1:0   |   rw   |    x    | VALUE  | Set the ADC threshold value |

## GET
Get the ADC output
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "VALUE", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description        |
|:------:|:------:|:-------:|:-------|:-------------------|
|  31:1  |        |         |        | Reserved           |
|   0    |   ro   |    x    | VALUE  | Get the ADC output |

