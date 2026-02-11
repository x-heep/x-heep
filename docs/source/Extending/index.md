# eXtending X-HEEP

X-HEEP is meant to be extended with your own custom IPs. X-HEEP itself posseses a hardware-software framework capable of working standalone. If you want to extend it, you will need to merge your hardware and software with X-HEEP's.

For this purpose we support the [CV-X-IF](https://docs.openhwgroup.org/projects/openhw-group-core-v-xif/en/latest/intro.html) interface with the [cv32e40px](https://github.com/x-heep/cv32e40px) or [cv32e40x](https://github.com/openhwgroup/cv32e40x) or [cv32e20](https://github.com/openhwgroup/cve2) RISC-V CPUs, and we expose master and slave ports to/from the bus.

> We recommend using the cv32e40px for pairing with your CV-X-IF compliant coprocessor. If you choose to use the cv32e40x, X-HEEP currently uses the revision [`0.9.0`](https://github.com/openhwgroup/cv32e40x/commit/f17028f2369373d9443e4636f2826218e8d54e0f). It is recommended to use the same revision in peripheral IPs to prevent conflicts during RTL compilation. While the cv32e20 does not support custom memory instructions.

In addition, the X-HEEP testbench has been extended with a DMA, dummy peripherals (including the flash), and two CV-X-IF compatible coprocessor: one implementing the RV32F RISC-V extension and one implementing custom matrix extensions.
This has been done to help us maintaining and verifying the extension interface.

If you want to try the FPU-like coprocessor with a CV-X-IF compatible CPU as the cv32e40px, you can do it in the base X-HEEP by configuring it as the system [CPU](../Configuration/CPUConfiguration.md) and enabling the [CV-X-IF](../Configuration/XIFConfiguration.md) in your `my-config.py` Python configuration file, as follows:

```python
    # ...

    system.set_cpu(cv32e40px())
    system.set_xif(CvXIf(
        x_num_rs    = 3 # R4-type floating-point instructions require 3 source operands
    ))

    # ...
```

Then, generate the RTL with MCU-GEN, compile the simulation model, and run the example application with:

```bash
make mcu-gen PYTHON_X_HEEP_CFG=configs/my-config.py X_HEEP_CFG=configs/python_unsupported.hjson
make verilator-build
make app PROJECT=example_matfadd ARCH=rv32imfc
make verilator-run
```

The program should terminate with value 0.

Also, you can try the FPU-like coprocessor with a CV-X-IF extended `cv32e20` CPU using the Zfinx extensions (i.e. the Floating-Point register-file is actually the same as the General-Purpose register-file).
The reason why you cannot use the RVF without ZFinx is that the cv32e20 core X-IF does not support memory X-operations.

First, you need the OpenHW Group CORE-V Compiler, then configure the [CPU](../Configuration/CPUConfiguration.md), enable the [CV-X-IF](../Configuration/XIFConfiguration.md), and define the `FPU_SS_ZFINX` extension parameter (see [Extension Configuration](../Configuration/ExtensionConfiguration.md)) in your `my-config.py`, similar to what is done in [this example](https://github.com/x-heep/x-heep/blob/main/configs/cv32e20_xif_fpu.py). Then, generate the RTL with MCU-GEN, compile the simulation model, and run the example application with:

```bash
make mcu-gen PYTHON_X_HEEP_CFG=configs/my-config.py X_HEEP_CFG=configs/python_unsupported.hjson
make verilator-build
make app PROJECT=example_matfadd COMPILER_PREFIX=riscv32-corev- ARCH=rv32imc_zicsr_zifencei_zfinx
make verilator-run
```

If you want to try [Quadrilatero](https://github.com/pulp-platform/quadrilatero), the custom matrix ISA extensions, you can use any of the cores supporting the CV-X-IF as the co-processor has its own load/store unit.

First, install the compiler as written [here](https://github.com/esl-epfl/xheep_matrix_spec/blob/main/BUILDING.md), then, configure X-HEEP with the `QUADRILATERO` extension parameter (see [Extension Configuration](../Configuration/ExtensionConfiguration.md)), similarly to what is done in [this example](https://github.com/x-heep/x-heep/blob/main/configs/cv32e20_xif_quadrilatero.py). Then, compile the simulation model and run the example application with:

```bash
make mcu-gen PYTHON_X_HEEP_CFG=configs/my-config.py X_HEEP_CFG=configs/python_unsupported.hjson
make verilator-build
make app PROJECT=example_matmul_quadrilatero ARCH=rv32imc_zicsr_xtheadmatrix0p1 COMPILER_FLAGS=-menable-experimental-extensions COMPILER=clang CLANG_LINKER_USE_LD=1
make verilator-run
```


To learn how to extend X-HEEP you can read the guides in this section.

```{toctree}
:maxdepth: 3
:numbered: 1

eXtendingHW
eXtendingSW
eXamples
