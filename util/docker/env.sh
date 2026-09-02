#!/bin/bash

# Activate the conda environment
source /opt/conda/etc/profile.d/conda.sh
conda activate x-heep

# Functions to initialize SW build environment
# NOTE: we don't use aliases as they would not be picked up by the non-interactive
#       shell used by GitHub CI.
init_gcc() {
    export COMPILER=gcc
    export COMPILER_PREFIX=riscv32-unknown-
    export ARCH=rv32imc_zicsr
}

init_clang() {
    export COMPILER=clang
    export COMPILER_PREFIX=riscv32-unknown-
    export ARCH=rv32imc_zicsr
}

init_corev() {
    export COMPILER=gcc
    export COMPILER_PREFIX=riscv32-corev-
    export ARCH=rv32imc_zicsr_zifencei_xcvhwlp_xcvmem_xcvmac_xcvbi_xcvalu_xcvsimd_xcvbitmanip
}

# Default to GCC toolchain
init_gcc

# Update PATH to include installed tools
export PATH=$TOOL_PATH:$PATH
