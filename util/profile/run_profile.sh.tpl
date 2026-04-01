#!/bin/bash
# Script that runs the rv_profile tool to generate a flamegraph after RTL
# simulation.
# Args:
#  <rv_profile> : Path to the rv_profile tool
RV_PROFILE=$1

# Check if the rv_profile tool is provided
if [ -z "$RV_PROFILE" ]; then
    echo "Usage: $0 <rv_profile>"
    exit 1
fi

# Get the upper root directory
ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || realpath "$(dirname "$0")/../..")

# Get the waveform file
WAVE_FILE=$(find "$ROOT_DIR/build" -name "*.fst" | head -n 1)

# Check if the waveform file was found
if [ -z "$WAVE_FILE" ]; then
    echo "ERROR: No waveform file found in $ROOT_DIR/build" >&2
    exit 1
fi

# Profile report directory
PROFILE_REPORT_DIR=$ROOT_DIR/util/profile

# Config file
PROFILE_CONFIG_FILE=$PROFILE_REPORT_DIR/configs/${xheep.cpu().get_name()}.wal

# Run the profiler
$RV_PROFILE --elf $ROOT_DIR/sw/build/main.elf \
            --fst $WAVE_FILE \
            --cfg $PROFILE_CONFIG_FILE \
            --out $PROFILE_REPORT_DIR/flamegraph.svg