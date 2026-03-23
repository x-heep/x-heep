#!/usr/bin/env zsh
# X-HEEP contributors 2026
# Usage: source util/start_env.zsh

# --- 1. Environment Detection ---
# Determine the absolute path to the directory containing this script
SCRIPT_DIR=$(cd -- "$(dirname -- "${(%):-%N}")" &> /dev/null && pwd)
TOOLS_DIR=$(realpath "$SCRIPT_DIR/../tools")

OS=$(uname -s)

# --- 2. Conda Initialization ---
if [ -z "$CONDA_EXE" ]; then
    CONDA_BASE=$(conda info --base)
else
    CONDA_BASE="${CONDA_EXE%/bin/conda}"
fi
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate core-v-mini-mcu

# --- 3. Dependency Paths ---
if [[ "$OS" == "Darwin" ]]; then
    # macOS: use Homebrew to locate libelf
    if command -v brew >/dev/null; then
        LIBELF_PREFIX=$(brew --prefix libelf)
        export C_INCLUDE_PATH="$LIBELF_PREFIX/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"
        export LIBRARY_PATH="$LIBELF_PREFIX/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
    fi
fi
# On Linux, libelf headers/libs are in standard system paths via apt.

# --- 4. Toolchain Exports ---
export RISCV_XHEEP=$(realpath "$TOOLS_DIR/risc-v")

# OSS CAD Suite Setup
OSS_CAD_PATH="$TOOLS_DIR/oss-cad-suite"
if [[ "$OS" == "Darwin" ]]; then
    # Use the bundled realpath for macOS compatibility
    OSS_BIN_DIR="$("$OSS_CAD_PATH"/libexec/realpath "$OSS_CAD_PATH")/bin"
else
    OSS_BIN_DIR="$(realpath "$OSS_CAD_PATH")/bin"
fi

# Verilator Setup
VERILATOR_BIN=$(realpath "$TOOLS_DIR/verilator/bin")

# Update PATH (Prepend to ensure these versions are used)
export PATH="$VERILATOR_BIN:$OSS_BIN_DIR:$PATH"

# --- 5. Optional/SystemC Placeholder ---
if [[ "$OS" == "Darwin" ]]; then
    # On macOS, SystemC is typically installed via Homebrew
    if command -v brew >/dev/null; then
        _sysc_prefix=$(brew --prefix systemc 2>/dev/null)
        if [[ -n "$_sysc_prefix" && -d "$_sysc_prefix" ]]; then
            export SYSTEMC_INCLUDE="$_sysc_prefix/include"
            export SYSTEMC_LIB="$_sysc_prefix/lib"
        fi
    fi
else
    # On Linux, use user-provided paths if set
    if [ -n "$system_c_dir" ]; then
        export SYSTEMC_INCLUDE="$system_c_dir/include"
        export SYSTEMC_LIB="$system_c_dir/lib"
    fi
fi

if [ -n "$flex_dir" ]; then
    export PATH="$flex_dir/bin:$PATH"
fi

echo "✅ CORE-V Mini-MCU environment activated."
