# Compile applications

```{warning}
The RISC-V toolchain environment variable name has changed. Use `RISCV_XHEEP` instead of `RISCV` to avoid conflicts with other projects. If you previously exported `RISCV` for X-HEEP, update your shell initialization files (e.g., `~/.bashrc`, `~/.zshrc`) or environment modules to export `RISCV_XHEEP` and remove or adjust any old `RISCV` definitions accordingly.
```

All software applications can be found in `sw/applications`. These can be compiled with the `app` target of the top-level makefile of X-HEEP. To compile the `hello world` application with default parameters, just type:

```
make app
```

This will create the executable file to be loaded in your target system (ASIC, FPGA, Simulation). 
X-HEEP is using CMake to compile and link. Thus, the generated files after having compiled and linked are under `sw\build`.

```{warning}
Don't forget to set the `RISCV_XHEEP` env variable to the compiler folder (without the `/bin` included).
```

You can select the application to run, the target, compiler, etc. by modifying the parameters. The compiler flags explicitely specified by the user will override those already existing (e.g. the default optimization level is `-O2`, passing `COMPILER_FLAGS=-Os` will override the `-O2`). This can be used to pass preprocessor definitions (e.g. pasing `make app COMPILER_FLAGS=-DENABLE_PRINTF` is equivalent to adding `#define ENABLE_PRINTF` on all included files). 
```
app PROJECT=<folder_name_of_the_project_to_be_built> TARGET=sim(default),systemc,pynq-z2,aup-zu3,nexys-a7-100t,zcu104,zcu102 LINKER=on_chip(default),flash_load,flash_exec COMPILER=gcc(default),clang COMPILER_PREFIX=riscv32-corev-(default),riscv32-unknown- ARCH=rv32imc_zicsr(default),<any_RISC-V_ISA_string_supported_by_the_CPU> 

Params:
    - PROJECT (ex: <folder_name_of_the_project_to_be_built>) 
    - TARGET (ex: sim(default),systemc,pynq-z2,aup-zu3,,nexys-a7-100t,zcu104,zcu102) 
    - LINKER (ex: on_chip(default),flash_load,flash_exec) 
    - COMPILER (ex: gcc(default),clang) 
    - COMPILER_PREFIX (ex: riscv32-corev-(default),riscv32-unknown-) 
    - COMPILER_FLAGS (ex: -O0, "-Wall -l<library>")
    - ARCH (ex: rv32imc_zicsr(default),<any_RISC-V_ISA_string_supported_by_the_CPU>)
```

```{note}
You can run `make help` or `make` to see the most up-to-date documentation for the makefile. This includes the parameters available for this command, as well as the documentation for all other commands.
```

For instance, to compile the `hello world` app with the default compiler for the pynq-z2 FPGA, just run:

```
make app PROJECT=hello_world TARGET=pynq-z2
```

## Using the standard GCC or Clang compilers

If you want to use the standard GCC or Clang toolchains, make sure to point the `RISCV_XHEEP` env variable to the corresponding compiler, then just run:

```bash
make app COMPILER=gcc COMPILER_PREFIX=riscv32-unknown- ARCH=rv32imc_zicsr

make app COMPILER=clang COMPILER_PREFIX=riscv32-unknown- ARCH=rv32imc_zicsr
```

## Using the OpenHW Group compiler with PULP extensions

If you want to use the OpenHW Group [GCC](https://www.embecosm.com/resources/tool-chain-downloads/#corev) compiler with CORE_PULP extensions, make sure to point the `RISCV_XHEEP` env variable to the OpenHW Group compiler, then just run:

```
make app COMPILER=gcc COMPILER_PREFIX=riscv32-corev- ARCH=rv32imc_zicsr_zifencei_xcvhwlp_xcvmem_xcvmac_xcvbi_xcvalu_xcvsimd_xcvbitmanip
```

## Using the RVE RISC-V extensions

`RVE` extensions are supported by the standard compiler when using the appropriate ARCH and ABI options (see the [setup](./../GettingStarted/Setup.md) page for details). Ensure that the `RISCV_XHEEP` environment variable points to the compiler configured for the correct ABI, which operates only on registers `x0–x15`.
By default, C code is compiled without using registers `x16–x31`. The X-HEEP `bootrom` and `crt0` have also been implemented in assembly without relying on those registers.
If your application needs to detect whether the `RVE` extensions are in use, the compiler automatically defines the `__riscv_32e` macro. This is used, for example, in the power manager’s HAL for context save/restore operations, ensuring that registers `x16–x31` are ignored when applicable.

```
make app ARCH=rv32emc_zicsr
```

## Compiling FreeRTOS based applications

X-HEEP supports FreeRTOS based applications. Please see `sw\applications\example_freertos_blinky`.

After that, you can run the command to compile and link the FreeRTOS based application. Please also set 'LINKER' and 'TARGET' parameters if needed.

```
make app PROJECT=example_freertos_blinky
```

The main FreeRTOS configuration is allocated under `sw\freertos`, in `FreeRTOSConfig.h`. Please, change this file based on your application requirements.
Moreover, FreeRTOS is being fetched from 'https://github.com/FreeRTOS/FreeRTOS-Kernel.git' by CMake. Specifically, 'V10.5.1' is used. Finally, the fetch repository is located under `sw\build\_deps` after building.
