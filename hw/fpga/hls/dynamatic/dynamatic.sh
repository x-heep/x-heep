#!/usr/bin/env bash
# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Runs a script of Dynamatic shell commands (https://github.com/EPFL-LAP/dynamatic)
# non-interactively:
#
#   hw/fpga/hls/dynamatic/dynamatic.sh <script.dyn>
#
# The script holds one Dynamatic command per line (set-src, compile,
# write-hdl, simulate, ...; see Dynamatic's docs/UserGuide/CommandReference.md)
# and must end with 'exit'. Paths in it must be absolute. The run stops at the
# first failing command and this script then exits non-zero.
#
# By default Dynamatic runs inside a Docker container (see ./Dockerfile), so
# the only host dependency is Docker. The image is built automatically the
# first time (one-off: it builds Dynamatic from source, which takes a while),
# and the container:
#   - sees the X-HEEP checkout and the current directory at the same paths as
#     on the host, so the paths in the script just work;
#   - runs as the calling user, so the generated files are owned by you;
#   - has no network access.
#
# To use a Dynamatic you built on the host instead (it then needs whatever
# Dynamatic itself needs on the host, plus Verilator for co-simulation):
#
#   DYNAMATIC_DIR=/path/to/dynamatic hw/fpga/hls/dynamatic/dynamatic.sh ...
#
# (the top-level directory of the Dynamatic checkout, the one with bin/dynamatic).
#
# Other knobs:
#   DYNAMATIC_DOCKER_IMAGE   image to use/build (default xheep-dynamatic:2fac291)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XHEEP_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

if [ $# -ne 1 ]; then
  echo "usage: $0 <script.dyn>" >&2
  exit 2
fi
DYN_SCRIPT="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

# Dynamatic's frontend finds its own scripts and libraries relative to the
# directory it is started from (unless the script sets set-dynamatic-path),
# so it always runs from Dynamatic's top-level directory.

# --- native installation ---------------------------------------------------
if [ -n "${DYNAMATIC_DIR:-}" ]; then
  if [ ! -x "$DYNAMATIC_DIR/bin/dynamatic" ]; then
    echo "error: DYNAMATIC_DIR='$DYNAMATIC_DIR' has no bin/dynamatic (set it to the top-level directory of a built Dynamatic, or unset it to use Docker)" >&2
    exit 1
  fi
  cd "$DYNAMATIC_DIR"
  exec bin/dynamatic --exit-on-failure --run "$DYN_SCRIPT"
fi

# --- Docker ------------------------------------------------------------------
IMAGE="${DYNAMATIC_DOCKER_IMAGE:-xheep-dynamatic:2fac291}"

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker not found. Install Docker, or build Dynamatic natively and set DYNAMATIC_DIR=/path/to/dynamatic" >&2
  exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Docker image '$IMAGE' not found: building it from $SCRIPT_DIR/Dockerfile" >&2
  echo "(one-off: builds Dynamatic from source against a prebuilt LLVM, ~1 GB download)" >&2
  docker build -t "$IMAGE" "$SCRIPT_DIR" >&2
fi

# Mount the X-HEEP checkout, plus the current directory and the script's
# directory if they live outside of it.
MOUNTS=(-v "$XHEEP_ROOT:$XHEEP_ROOT")
for dir in "$PWD" "$(dirname "$DYN_SCRIPT")"; do
  case "$dir/" in
    "$XHEEP_ROOT"/*) ;;
    *) [[ " ${MOUNTS[*]} " == *" $dir:$dir "* ]] || MOUNTS+=(-v "$dir:$dir") ;;
  esac
done

exec docker run --rm --network none \
  -u "$(id -u):$(id -g)" -e HOME=/tmp \
  "${MOUNTS[@]}" -w /opt/dynamatic \
  "$IMAGE" bin/dynamatic --exit-on-failure --run "$DYN_SCRIPT"
