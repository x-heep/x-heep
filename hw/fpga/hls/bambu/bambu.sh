#!/usr/bin/env bash
# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Runs the Bambu HLS tool (https://github.com/ferrandi/PandA-bambu) with the
# given arguments, from the current directory:
#
#   hw/fpga/hls/bambu/bambu.sh <bambu arguments...>
#
# By default Bambu runs inside a Docker container (see ./Dockerfile), so the
# only host dependency is Docker. The image is built automatically the first
# time (it downloads Bambu's ~1.4 GB release AppImage), and the container:
#   - sees the X-HEEP checkout and the current directory at the same paths as
#     on the host, so relative and absolute paths in the arguments just work;
#   - runs as the calling user, so the generated files are owned by you;
#   - has no network access.
#
# To use a Bambu you installed on the host instead (needs the 32-bit
# toolchain, e.g. g++-multilib, and Verilator for co-simulation):
#
#   BAMBU=/path/to/bambu hw/fpga/hls/bambu/bambu.sh ...
#   BAMBU_ENV=/path/to/settings.sh   # optional: sourced first (from-source installs)
#
# Other knobs:
#   BAMBU_DOCKER_IMAGE   image to use/build (default xheep-bambu:2024.10)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XHEEP_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# --- native installation ---------------------------------------------------
if [ -n "${BAMBU:-}" ]; then
  if [ -n "${BAMBU_ENV:-}" ]; then
    # Bambu's settings.sh uses bash arrays, hence bash and not sh.
    # shellcheck disable=SC1090
    source "$BAMBU_ENV"
  fi
  if ! command -v "$BAMBU" >/dev/null 2>&1; then
    echo "error: BAMBU='$BAMBU' is not an executable (set BAMBU to the bambu binary, or unset it to use Docker)" >&2
    exit 1
  fi
  exec "$BAMBU" "$@"
fi

# --- Docker ------------------------------------------------------------------
IMAGE="${BAMBU_DOCKER_IMAGE:-xheep-bambu:2024.10}"

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker not found. Install Docker, or install Bambu natively and set BAMBU=/path/to/bambu" >&2
  exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Docker image '$IMAGE' not found: building it from $SCRIPT_DIR/Dockerfile" >&2
  echo "(one-off, downloads Bambu's release AppImage, ~1.4 GB)" >&2
  docker build -t "$IMAGE" "$SCRIPT_DIR" >&2
fi

# Mount the X-HEEP checkout, plus the current directory if it lives outside of it.
MOUNTS=(-v "$XHEEP_ROOT:$XHEEP_ROOT")
case "$PWD/" in
  "$XHEEP_ROOT"/*) ;;
  *) MOUNTS+=(-v "$PWD:$PWD") ;;
esac

exec docker run --rm --network none \
  -u "$(id -u):$(id -g)" -e HOME=/tmp \
  "${MOUNTS[@]}" -w "$PWD" \
  "$IMAGE" bambu "$@"
