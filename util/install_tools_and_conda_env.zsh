#!/usr/bin/env zsh
# X-HEEP contributors 2026
# Usage: ./util/install_tools_and_conda_env.zsh

# --- Output Helpers ---
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

info()    { print -P "${BOLD}${CYAN}[INFO]${RESET}  $1" }
success() { print -P "${BOLD}${GREEN}[OK]${RESET}    $1" }
warn()    { print -P "${BOLD}${YELLOW}[SKIP]${RESET}  $1" }
error()   { print -P "${BOLD}${RED}[FAIL]${RESET}  $1" }
step()    { print -P "\n${BOLD}━━━ $1 ━━━${RESET}" }
prompt()  { print -Pn "${BOLD}${YELLOW}▸${RESET} $1" }

# --- Helper: run a command quietly, print output only on failure ---
run_quiet() {
    local label="$1"
    shift
    local output
    output=$("$@" 2>&1)
    if [[ $? -ne 0 ]]; then
        error "${label} failed:"
        echo "$output"
        exit 1
    fi
}

# --- Configuration & Versions ---
RISCV_V_DATE="20240530"
OSS_CAD_DATE="2026-02-15"
VERIBLE_HASH="v0.0-4051-g9fdb4057"
VERILATOR_VER="v5.040"

# --- System Detection ---
OS=$(uname -s)
ARCH=$(uname -m)

print -P "\n${BOLD}╔══════════════════════════════════════════════╗${RESET}"
print -P "${BOLD}║   CORE-V Mini-MCU — Environment Setup        ║${RESET}"
print -P "${BOLD}╚══════════════════════════════════════════════╝${RESET}"

info "Platform: ${BOLD}${OS}/${ARCH}${RESET}"

case "${OS}/${ARCH}" in
    Darwin/arm64)
        PLATFORM="macos-arm64"
        ;;
    Darwin/x86_64)
        PLATFORM="macos-x64"
        ;;
    Linux/x86_64)
        PLATFORM="linux-x64"
        ;;
    *)
        error "Unsupported platform ${OS}/${ARCH}. Supported: macOS arm64/x86_64, Linux x86_64."
        exit 1
        ;;
esac

# --- Dependencies ---
step "Step 0/5 — System Dependencies"
if [[ "$OS" == "Darwin" ]]; then
    info "Installing Homebrew packages..."
    run_quiet "Homebrew install" brew install libyaml libelf cmake ninja wget git flex bison systemc help2man autoconf automake meson
    success "Homebrew dependencies installed."
else
    info "Installing APT packages..."
    run_quiet "APT update" sudo apt-get update
    run_quiet "APT install" sudo apt-get install -y --no-install-recommends \
        build-essential make g++ cmake ninja-build wget git curl \
        flex bison autoconf automake help2man \
        libelf1 libelf-dev libyaml-dev libfl-dev libexpat-dev \
        zlib1g-dev libssl-dev libglib2.0-dev \
        python3 python3-dev python3-venv \
        meson
    success "APT dependencies installed."
fi

# --- Tool Download Paths (OS-dependent) ---
if [[ "$PLATFORM" == "macos-arm64" ]]; then
    OSS_CAD_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_DATE}/oss-cad-suite-darwin-arm64-${OSS_CAD_DATE//-/}.tgz"
    VERIBLE_URL="https://github.com/chipsalliance/verible/releases/download/${VERIBLE_HASH}/verible-${VERIBLE_HASH}-macOS.tar.gz"
    RISCV_URL="https://buildbot.embecosm.com/job/corev-gcc-macos-arm64/8/artifact/corev-openhw-gcc-macos-${RISCV_V_DATE}.zip"
    RISCV_ARCHIVE_EXT="zip"
    RISCV_INNER_DIR="corev-openhw-gcc-macos-${RISCV_V_DATE}"
elif [[ "$PLATFORM" == "macos-x64" ]]; then
    OSS_CAD_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_DATE}/oss-cad-suite-darwin-x64-${OSS_CAD_DATE//-/}.tgz"
    VERIBLE_URL="https://github.com/chipsalliance/verible/releases/download/${VERIBLE_HASH}/verible-${VERIBLE_HASH}-macOS.tar.gz"
    RISCV_URL="https://buildbot.embecosm.com/job/corev-gcc-macos/48/artifact/corev-openhw-gcc-macos-${RISCV_V_DATE}.zip"
    RISCV_ARCHIVE_EXT="zip"
    RISCV_INNER_DIR="corev-openhw-gcc-macos-${RISCV_V_DATE}"
else
    OSS_CAD_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_DATE}/oss-cad-suite-linux-x64-${OSS_CAD_DATE//-/}.tgz"
    VERIBLE_URL="https://github.com/chipsalliance/verible/releases/download/${VERIBLE_HASH}/verible-${VERIBLE_HASH}-linux-static-x86_64.tar.gz"
    RISCV_URL="https://buildbot.embecosm.com/job/corev-gcc-ubuntu2204/47/artifact/corev-openhw-gcc-ubuntu2204-${RISCV_V_DATE}.tar.gz"
    RISCV_ARCHIVE_EXT="tar.gz"
    RISCV_INNER_DIR="corev-openhw-gcc-ubuntu2204-${RISCV_V_DATE}"
fi

mkdir -p tools

# --- 1. OSS CAD Suite ---
step "Step 1/5 — OSS CAD Suite"
OSS_CAD_SKIP=false
OSS_CAD_DEFAULT="tools/oss-cad-suite"

if [[ -d "$OSS_CAD_DEFAULT" && -x "$OSS_CAD_DEFAULT/bin/yosys" ]]; then
    success "Already installed at ${DIM}${OSS_CAD_DEFAULT}${RESET}"
    OSS_CAD_SKIP=true
elif command -v yosys &>/dev/null; then
    success "Already in PATH: ${DIM}$(command -v yosys)${RESET}"
    OSS_CAD_SKIP=true
fi

if [[ "$OSS_CAD_SKIP" == false ]]; then
    info "OSS CAD Suite not found."
    echo "  Where should it be installed?"
    echo "    ${BOLD}[1]${RESET} ${OSS_CAD_DEFAULT} ${DIM}(default)${RESET}"
    echo "    ${BOLD}[2]${RESET} Skip"
    echo "    ${BOLD}[3]${RESET} Custom path"
    prompt "Choice [1/2/3]: "
    read -r oss_choice

    OSS_CAD_DEST=""
    case "$oss_choice" in
        2) warn "OSS CAD Suite installation skipped." ;;
        3)
            prompt "Install path: "
            read -r OSS_CAD_DEST
            [[ -z "$OSS_CAD_DEST" ]] && warn "No path provided. Skipping."
            ;;
        *) OSS_CAD_DEST="$OSS_CAD_DEFAULT" ;;
    esac

    if [[ -n "$OSS_CAD_DEST" ]]; then
        info "Downloading OSS CAD Suite to ${DIM}${OSS_CAD_DEST}${RESET}..."
        mkdir -p "$OSS_CAD_DEST"
        wget -q --show-progress "$OSS_CAD_URL" -O oss-cad-suite.tgz
        run_quiet "OSS CAD extract" tar -xzf oss-cad-suite.tgz -C "$(dirname "$OSS_CAD_DEST")"
        rm oss-cad-suite.tgz
        if [[ "$OS" == "Darwin" ]]; then
            info "Removing quarantine (you may be prompted for a password)..."
            zsh "$OSS_CAD_DEST/activate"
        fi
        OSS_CAD_PATH="$OSS_CAD_DEST"
        success "OSS CAD Suite installed."
    fi
fi

# --- 2. Verible ---
step "Step 2/5 — Verible"
VERIBLE_DEFAULT="tools/verible"

if command -v verible-verilog-lint &>/dev/null; then
    success "Already in PATH: ${DIM}$(command -v verible-verilog-lint)${RESET}"
elif [[ -x "$VERIBLE_DEFAULT/bin/verible-verilog-lint" ]]; then
    success "Already installed at ${DIM}${VERIBLE_DEFAULT}${RESET}"
else
    info "Downloading Verible into ${DIM}${VERIBLE_DEFAULT}${RESET}..."
    mkdir -p "$VERIBLE_DEFAULT"
    wget -q --show-progress "$VERIBLE_URL" -O verible.tgz
    run_quiet "Verible extract" tar -xzf verible.tgz -C "$VERIBLE_DEFAULT" --strip-components=1
    rm verible.tgz
    success "Verible installed."
fi

# --- 3. RISC-V Toolchain ---
step "Step 3/5 — RISC-V Toolchain"
RISCV_SKIP=false
RISCV_DEFAULT="tools/risc-v"

if [[ -n "$RISCV_XHEEP" && -d "$RISCV_XHEEP" && -x "$RISCV_XHEEP/bin/riscv32-corev-elf-gcc" ]]; then
    success "Already set via RISCV_XHEEP=${DIM}${RISCV_XHEEP}${RESET}"
    RISCV_SKIP=true
elif command -v riscv32-corev-elf-gcc &>/dev/null; then
    success "Already in PATH: ${DIM}$(command -v riscv32-corev-elf-gcc)${RESET}"
    RISCV_SKIP=true
elif [[ -x "$RISCV_DEFAULT/bin/riscv32-corev-elf-gcc" ]]; then
    success "Already installed at ${DIM}${RISCV_DEFAULT}${RESET}"
    export RISCV_XHEEP=$(realpath "$RISCV_DEFAULT")
    RISCV_SKIP=true
fi

if [[ "$RISCV_SKIP" == false ]]; then
    info "RISC-V toolchain not found."
    echo "  Where should it be installed?"
    echo "    ${BOLD}[1]${RESET} ${RISCV_DEFAULT} ${DIM}(default)${RESET}"
    echo "    ${BOLD}[2]${RESET} Skip"
    echo "    ${BOLD}[3]${RESET} Custom path"
    prompt "Choice [1/2/3]: "
    read -r riscv_choice

    RISCV_DEST=""
    case "$riscv_choice" in
        2) warn "RISC-V toolchain installation skipped." ;;
        3)
            prompt "Install path: "
            read -r RISCV_DEST
            [[ -z "$RISCV_DEST" ]] && warn "No path provided. Skipping."
            ;;
        *) RISCV_DEST="$RISCV_DEFAULT" ;;
    esac

    if [[ -n "$RISCV_DEST" ]]; then
        info "Downloading RISC-V toolchain to ${DIM}${RISCV_DEST}${RESET}..."
        info "This is a large download (~1.3 GB). The server can be slow."
        mkdir -p "$(dirname "$RISCV_DEST")"
        if [[ "$RISCV_ARCHIVE_EXT" == "zip" ]]; then
            wget -q --show-progress "$RISCV_URL" -O riscv.zip
            info "Extracting (this may take a minute)..."
            run_quiet "RISC-V extract" unzip -q riscv.zip -d /tmp/riscv-extract
            mkdir -p "$RISCV_DEST"
            mv /tmp/riscv-extract/${RISCV_INNER_DIR}/* "$RISCV_DEST"/
            rm -rf /tmp/riscv-extract riscv.zip
        else
            mkdir -p "$RISCV_DEST"
            wget -q --show-progress "$RISCV_URL" -O riscv.tar.gz
            run_quiet "RISC-V extract" tar -xzf riscv.tar.gz -C "$RISCV_DEST" --strip-components=1
            rm riscv.tar.gz
        fi
        export RISCV_XHEEP=$(realpath "$RISCV_DEST")
        success "RISC-V toolchain installed."
    fi
fi

# --- 4. Verilator ---
step "Step 4/5 — Verilator ${VERILATOR_VER}"
VERILATOR_DEFAULT="tools/verilator"
VERILATOR_SKIP=false

if [[ -d "$VERILATOR_DEFAULT" && -x "$VERILATOR_DEFAULT/bin/verilator" ]]; then
    success "Already built at ${DIM}${VERILATOR_DEFAULT}${RESET}"
    VERILATOR_SKIP=true
elif command -v verilator &>/dev/null; then
    success "Already in PATH: ${DIM}$(command -v verilator)${RESET}"
    VERILATOR_SKIP=true
fi

if [[ "$VERILATOR_SKIP" == false ]]; then
    info "Verilator not found."
    echo "  Where should it be built?"
    echo "    ${BOLD}[1]${RESET} ${VERILATOR_DEFAULT} ${DIM}(default)${RESET}"
    echo "    ${BOLD}[2]${RESET} Skip"
    echo "    ${BOLD}[3]${RESET} Custom path"
    prompt "Choice [1/2/3]: "
    read -r verilator_choice

    case "$verilator_choice" in
        2)
            warn "Verilator build skipped."
            ;;
        3)
            prompt "Build path: "
            read -r VERILATOR_CUSTOM
            if [[ -z "$VERILATOR_CUSTOM" ]]; then
                warn "No path provided. Skipping."
            else
                VERILATOR_BUILD_DIR="$VERILATOR_CUSTOM"
            fi
            ;;
        *)
            VERILATOR_BUILD_DIR="$VERILATOR_DEFAULT"
            ;;
    esac

    if [[ -n "$VERILATOR_BUILD_DIR" ]]; then
        info "Building Verilator ${VERILATOR_VER} in ${DIM}${VERILATOR_BUILD_DIR}${RESET}..."
        info "This may take several minutes."
        mkdir -p "$(dirname "$VERILATOR_BUILD_DIR")"
        [[ -d "$VERILATOR_BUILD_DIR" ]] || run_quiet "Verilator clone" git clone https://github.com/verilator/verilator.git "$VERILATOR_BUILD_DIR"
        pushd "$VERILATOR_BUILD_DIR"
        run_quiet "Verilator checkout" git checkout "$VERILATOR_VER"

        FLEX_DIR=""
        SYSC_DIR=""

        if [[ "$OS" == "Darwin" ]]; then
            FLEX_DIR=$(brew --prefix flex)
            SYSC_DIR=$(brew --prefix systemc)
            export SYSTEMC_INCLUDE="${SYSC_DIR}/include"
            export SYSTEMC_LIB="${SYSC_DIR}/lib"
            export PATH="${FLEX_DIR}/bin:${PATH}"
        fi

        ADDITIONAL_FLAGS=""
        if [[ "$OS" == "Darwin" && "$VERILATOR_VER" == v5.040* ]]; then
            info "Applying macOS Clang patch for v5.040..."
            ADDITIONAL_FLAGS="-DVL_DEBUG"
            sed -i '' 's|V3Hash{reinterpret_cast<uintptr_t>(val)} {}|V3Hash{static_cast<uint64_t>(reinterpret_cast<uintptr_t>(val))} {}|g' src/V3Hash.h
        fi

        if [[ -n "$FLEX_DIR" ]]; then
            export CXXFLAGS="-I${FLEX_DIR}/include ${ADDITIONAL_FLAGS}"
            export CFLAGS="-I${FLEX_DIR}/include ${ADDITIONAL_FLAGS}"
            export LDFLAGS="-L${FLEX_DIR}/lib"
        elif [[ -n "$ADDITIONAL_FLAGS" ]]; then
            export CXXFLAGS="${ADDITIONAL_FLAGS}"
            export CFLAGS="${ADDITIONAL_FLAGS}"
        fi
        export VERILATOR_ROOT=$(pwd)

        run_quiet "Verilator autoconf" autoconf
        run_quiet "Verilator configure" ./configure --enable-longtests
        if [[ "$OS" == "Darwin" ]]; then
            run_quiet "Verilator build" make -j$(sysctl -n hw.ncpu)
        else
            run_quiet "Verilator build" make -j$(nproc)
        fi

        unset CFLAGS CXXFLAGS LDFLAGS
        popd
        success "Verilator ${VERILATOR_VER} built."
    fi
fi

# --- 5. Environment & Conda Setup ---
step "Step 5/5 — Conda Environment"

CONDA_ENV_FILE="util/conda_environment.yml"

info "Using ${DIM}${CONDA_ENV_FILE}${RESET}"
CONDA_BASE=$(conda info --base)
source "$CONDA_BASE/etc/profile.d/conda.sh"

# pylibfst's CMakeLists.txt uses cmake_minimum_required < 3.5, rejected by CMake >= 4.0
export CMAKE_POLICY_VERSION_MINIMUM=3.5
CONDA_OUTPUT=$(conda env create -f "$CONDA_ENV_FILE" 2>&1) || {
    if echo "$CONDA_OUTPUT" | grep -q "already exists"; then
        success "Conda env already exists."
    else
        error "Conda env creation failed:"
        echo "$CONDA_OUTPUT"
        exit 1
    fi
}
unset CMAKE_POLICY_VERSION_MINIMUM
success "Conda environment ready."

# --- Done ---
print -P "\n"
print -P "${BOLD}${GREEN}╔══════════════════════════════════════════════╗${RESET}"
print -P "${BOLD}${GREEN}║            Setup Complete!                   ║${RESET}"
print -P "${BOLD}${GREEN}╚══════════════════════════════════════════════╝${RESET}"
info "To activate:  ${BOLD}source util/start_env.zsh${RESET}"
echo
