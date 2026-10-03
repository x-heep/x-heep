#!/bin/bash
# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

PDK_LIB=pdk_lib
ROOT=../../..
TECH_FILE=$ROOT/implementation/postsynth/asic_tech
QUERY="tclsh $ROOT/scripts/asic/tech/query.tcl"

set -e

if [ ! -f "$TECH_FILE" ]; then
  echo "[compile_postsyn_models] ERROR: $TECH_FILE not found: stage a netlist first (make <tool>-<tech>-stage-netlist)." >&2
  exit 1
fi
TECH=$(cat "$TECH_FILE")
echo "[compile_postsyn_models] Staged netlist technology: $TECH"

if ! command -v tclsh >/dev/null 2>&1; then
  echo "[compile_postsyn_models] ERROR: tclsh not found (needed to read scripts/asic/tech/$TECH.tcl)." >&2
  exit 1
fi

MODELS=$($QUERY "$TECH" sim-models)
FLAGS=$($QUERY "$TECH" sim-flags)

echo "[compile_postsyn_models] Compiling into library '$PDK_LIB' (flags: $FLAGS +nospecify +notimingcheck):"
echo "$MODELS" | sed 's/^/  /'

vlib "$PDK_LIB"
vmap "$PDK_LIB" "$PDK_LIB"
# shellcheck disable=SC2086 # FLAGS and MODELS are intentionally word-split
vlog -work "$PDK_LIB" $FLAGS +nospecify +notimingcheck $MODELS
