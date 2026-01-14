# Profiling

The `matrix multiplication` is often used to profile the performance of a CPU and the system.

To get the best performance, first of all configure `X-HEEP` as following:

`make mcu-gen X_HEEP_CFG=configs/benchmark.hjson`

This configuration contains the best settings for `X-HEEP` to compute a fast matrix multiplication.

## Standard RISC-V

To compile the application with a standard `RISC-V` compiler and `ISA`:

`make app PROJECT=example_matmul COMPILER_PREFIX=riscv32-unknown- ARCH=rv32imc`

This will compile the code using 8-bit input data. While if you want to use 32- or 16-bit input data:

`make app PROJECT=example_matmul COMPILER_PREFIX=riscv32-unknown- ARCH=rv32imc COMPILER_FLAGS="-DMATMUL32"` 

or `COMPILER_FLAGS="-DMATMUL16"` or `COMPILER_FLAGS="-DMATMUL8"`.

## CORE-V RISC-V ISA Extensions

To compile the application with the `CORE-V` compiler and using the `CORE-V XPULP extensions`:

`make app PROJECT=example_matmul COMPILER_PREFIX=riscv32-corev- ARCH=rv32imc_zicsr_zifencei_xcvhwlp_xcvmem_xcvmac_xcvbi_xcvalu_xcvsimd_xcvbitmanip COMPILER_FLAGS="-DMATMUL32"` 

or `COMPILER_FLAGS="-DMATMUL16"` or `COMPILER_FLAGS="-DMATMUL8"`.

If you want to execute the hand optmized kernel to take the best out of the `cv32e40p` pipeline, then compile with:

`make app PROJECT=example_matmul COMPILER_PREFIX=riscv32-corev- ARCH=rv32imc_zicsr_zifencei_xcvhwlp_xcvmem_xcvmac_xcvbi_xcvalu_xcvsimd_xcvbitmanip COMPILER_FLAGS="-DMATMUL32 -D__COREV_OPT_ASM"` 

or `COMPILER_FLAGS="-DMATMUL16"` or `COMPILER_FLAGS="-DMATMUL8"`.