#!/usr/bin/env bash
# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Standalone Dynamatic build for the dot_product engine -- the counterpart of
# ../../vitis/dot_product/run_hls.tcl and ../../bambu/dot_product/run_bambu.sh.
# Everything is generated in dot_product_proj/ (git-ignored).
#
#   ./run_dynamatic.sh          # or: ./run_dynamatic.sh synth
#       Compiles dot_product.c into a dataflow circuit and writes it as
#       Verilog into dot_product_proj/out/hdl/.
#
#   ./run_dynamatic.sh sim
#       Same, plus Dynamatic's RTL co-simulation with Verilator: the shared C++
#       testbench (../../common/dot_product/dot_product_tb.cpp) runs in C to
#       record the kernel's inputs and outputs, then Dynamatic's testbench
#       replays the inputs on the generated RTL and compares its outputs with
#       the C ones. It checks the HLS output only -- not the X-HEEP integration
#       (adapter, wrapper, bridges).
#
# Dynamatic runs through ../dynamatic.sh: in Docker by default, or natively
# with DYNAMATIC_DIR=/path/to/dynamatic (see that script).
#
# The clock period matches the 8ns target of the other two flows.

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

# Dynamatic's frontend only looks for includes next to the kernel, names the
# kernel after its file, and writes its output in an 'out' directory next to
# it, so the kernel and the shared header and testbench are staged together
# in the work directory.
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp "$SCRIPT_DIR/dot_product.c" "$COMMON_DIR/dot_product.h" "$COMMON_DIR/dot_product_tb.cpp" "$WORK_DIR/"

# Commands:
#   set-clock-period   target clock period (ns), for buffer placement
#   compile            C -> dataflow circuit (default buffer placement: no
#                      MILP solver, so no Gurobi needed)
#   write-hdl          circuit -> Verilog (Dynamatic's default is VHDL;
#                      X-HEEP's simulation is Verilator, which only reads
#                      Verilog/SystemVerilog)
{
  echo "set-src $WORK_DIR/dot_product.c"
  echo "set-clock-period 8"
  echo "compile"
  echo "write-hdl --hdl verilog"
  if [ "$MODE" = "sim" ]; then
    echo "simulate --simulator verilator"
  fi
  echo "exit"
} >"$WORK_DIR/run.dyn"

cd "$WORK_DIR"
"$SCRIPT_DIR/../dynamatic.sh" "$WORK_DIR/run.dyn"

if [ ! -f out/hdl/dot_product_wrapper.v ]; then
  echo "error: Dynamatic did not produce $WORK_DIR/out/hdl/dot_product_wrapper.v" >&2
  exit 1
fi

if [ "$MODE" = "sim" ]; then
  REPORT=out/sim/report.txt
  echo "----- $REPORT (tail)"
  tail -n 5 "$REPORT"
  # The co-simulation's own pass/fail is the frontend's exit status (checked
  # above through set -e); this makes sure the comparison actually ran.
  if ! grep -q "C and VHDL outputs match\|C and RTL outputs match\|outputs match" "$REPORT"; then
    echo "error: Dynamatic's co-simulation did not report matching outputs" >&2
    exit 1
  fi
fi
