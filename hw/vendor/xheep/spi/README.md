# X-HEEP SPI Subsystem

The X-HEEP SPI Subsystem. This module includes the SPI Host (documented [here](https://x-heep.readthedocs.io/en/latest/Peripherals/SPI.html)) and the W25Q128JW flash controller (documented [here](https://x-heep.readthedocs.io/en/latest/Peripherals/W25Q128JW_CONTROLLER.html)).

## Quick Start

To genrate the SPI Subsystem RTL files:
1. Render the top-level Mako template [`spi_subsystem.sv.tpl`](./rtl/spi_subsystem.sv.tpl) with X-HEEP's [`mcu_gen.py`](https://github.com/x-heep/xheep_gen) or equivalent.
2. Make [`x-heep:ip:spi`](./xheep_spi.core) a dependency of your project, e.g.:
    ```yaml
    filesets:
      rtl:
        depend:
        - x-heep:ip:spi
        ...
    ```

The configuration registers RTL and the corresponding C header and documentation are automatically generated inside the `rtl`, `sw`, and `docs` directories. If you need these files in different locations in your project, you can `link -sr` those directories there (see X-HEEP for a usage example).
Alternatively, if your project does not rely on FuseSoC, you can use the included [`Makefile`](./Makefile) to generate the same files.

The X-HEEP DMA depends on `pulp-platform.org::common_cells`, so be sure that they are vendored in your project and FuseSoC detects the `common_cells.core` file.
