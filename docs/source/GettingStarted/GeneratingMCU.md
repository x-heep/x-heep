# Generating the microcontroller

X-HEEP uses a series of Python scripts to generate the desired configuration of the MCU and its related files using [Mako](https://www.makotemplates.org/) `.tpl` templates. For example, `hw/core-v-mini-mcu/core_v_mini_mcu.sv.tpl` will generate `hw/core-v-mini-mcu/core_v_mini_mcu.sv`.

For the default configuration of X-HEEP, you simply have to run:

```bash
make mcu-gen
```

The easiest way of changing the default values is with some arguments. For example, you can change the CPU type (cv32e20), the default bus type (onetoM), the default continuous memory size (2 banks), or the default interleaved memory size (0 banks) with:

```bash
make mcu-gen CPU=cv32e40p BUS=NtoM MEMORY_BANKS=12 MEMORY_BANKS_IL=4
```

This generates X-HEEP with the cv32e40p core, a parallel bus, and 16 memory banks (12 continuous and 4 interleaved), 32KB each, for a total memory of 512KB.

This method has certain limitations, such as the size of the memory banks, which are fixed at 32KB. You can find the full documentation on how to configure X-HEEP in the [Configuration](/Configuration/index) section. This includes using Python scripts for a more detailed and powerful configuration.
