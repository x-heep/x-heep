# xheep_dma
The configurable X-HEEP DMA

## Quick Start

To genrate the DMA RTL files:
1. Render the Mako templates inside [`data/`](./data/) with X-HEEP's [`mcu_gen.py`](https://github.com/x-heep/xheep_gen) or similar.
2. Make [`x-heep:ip:dma`](./dma.core) a dependency of your project, e.g.:
    ```yaml
    filesets:
      rtl:
        depend:
        - x-heep:ip:dma
        ...
    ```

The configuration registers RTL and the corresponding C header and documentation are automatically generated inside the `rtl`, `sw`, and `docs` directories. If you need these files in different locations in your project, you can `link -sr` those directories there (see X-HEEP for a usage example).

Alternatively, if your project does not rely on FuseSoC, you can use the included [`Makefile`](./Makefile) to generate the same files.
