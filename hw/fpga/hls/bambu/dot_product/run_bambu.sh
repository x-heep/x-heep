#!/usr/bin/env bash
# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Standalone Bambu HLS build for the dot_product streaming engine -- the
# counterpart of ../../vitis/dot_product/run_hls.tcl. Everything is generated
# in dot_product_proj/ (git-ignored).
#
#   ./run_bambu.sh          # or: ./run_bambu.sh synth
#       Synthesizes dot_product.cpp into dot_product_proj/dot_product.v.
#
#   ./run_bambu.sh sim
#       Same, plus Bambu's RTL co-simulation: the shared C++ testbench
#       (../../common/dot_product/dot_product_tb.cpp) runs against the
#       generated RTL through Verilator, with Bambu's own AXI memory model.
#       This is the Bambu equivalent of Vitis' csim/cosim. It checks the HLS
#       output only -- not the X-HEEP integration (adapter, wrapper, bridges).
#
# Bambu runs through ../bambu.sh: in Docker by default, or natively with
# BAMBU=/path/to/bambu (see that script).
#
# Part / clock period match the pynq-z2 Zynq-7020 target and the 8ns (125MHz)
# sys_clk used in hw/fpga/xheep_fpga_support/constraints/pynq-z2 (same as the
# Vitis flow).

set -euo pipefail

MODE="${1:-synth}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$SCRIPT_DIR/../../common/dot_product"
WORK_DIR="$SCRIPT_DIR/dot_product_proj"

case "$MODE" in
  synth | sim) ;;
  *)
    echo "usage: $0 [synth|sim]" >&2
    exit 2
    ;;
esac

# Flags:
#   --compiler=I386_CLANG16   32-bit target: 32-bit pointers, like X-HEEP's
#                             32-bit address space (the wrapper zero-extends
#                             them to its 64-bit AXI struct addresses).
#   --generate-interface=INFER  honour the '#pragma HLS interface' lines in
#                             dot_product.cpp (m_axi bundles for a/b, plain
#                             ports for size/result).
#   --device-name             Bambu has a timing/area model for xc7z020 with
#                             the clg484 package; the pynq-z2 part is clg400
#                             (same die and speed grade), which Bambu does not
#                             model. Only affects Bambu's estimates -- Vivado
#                             implements the design for the real part.
#   -I / --top-fname          the shared header, and the top function.
BAMBU_FLAGS=(
  --compiler=I386_CLANG16
  -O2
  --generate-interface=INFER
  --clock-period=8
  --device-name=xc7z020,-1,clg484
  --top-fname=dot_product
  -I "$COMMON_DIR"
)

if [ "$MODE" = "sim" ]; then
  BAMBU_FLAGS+=(
    --generate-tb="$COMMON_DIR/dot_product_tb.cpp"
    --simulate
    --simulator=VERILATOR
  )
fi

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Bambu leaves stale results around otherwise.
rm -rf HLS_output ./*.v ./*.sh ./*.xml results.txt

"$SCRIPT_DIR/../bambu.sh" "${BAMBU_FLAGS[@]}" "$SCRIPT_DIR/dot_product.cpp"

if [ ! -f dot_product.v ]; then
  echo "error: Bambu did not produce $WORK_DIR/dot_product.v" >&2
  exit 1
fi

if [ "$MODE" = "sim" ]; then
  LOG=HLS_output/simulation/testbench.log
  echo "----- $LOG"
  cat "$LOG"
  if ! grep -q "TEST PASSED" "$LOG"; then
    echo "error: RTL co-simulation did not report TEST PASSED" >&2
    exit 1
  fi
fi
