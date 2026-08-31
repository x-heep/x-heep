#!/bin/bash
# Patch the edalize-generated Vivado run script for Versal (VPK180).
# edalize's Vivado backend hardcodes 7-series/UltraScale commands that are
# invalid for Versal devices. This script rewrites those lines in place.

set -eu

RUN_FILE="openhwgroup.org_systems_core-v-mini-mcu_1.0.5_run.tcl"
PROJECT_TCL="openhwgroup.org_systems_core-v-mini-mcu_1.0.5.tcl"
PART_LINE='set_property part xcvp1802-lsvc4072-2MP-e-S [current_project]'
SEGMENTED_LINE='set_property segmented_configuration true [current_project]'

if [ ! -f "$RUN_FILE" ]; then
    echo "ERROR: $RUN_FILE not found in $(pwd)"
    exit 1
fi

if [ ! -f "$PROJECT_TCL" ]; then
    echo "ERROR: $PROJECT_TCL not found in $(pwd)"
    exit 1
fi

# 1. Enable Segmented Configuration for the VPK180 project.
if grep -Fxq "$SEGMENTED_LINE" "$PROJECT_TCL"; then
    echo "INFO: Segmented Configuration already enabled in $PROJECT_TCL."
elif grep -Fxq "$PART_LINE" "$PROJECT_TCL"; then
    sed -i '/^set_property part xcvp1802-lsvc4072-2MP-e-S \[current_project\]$/a set_property segmented_configuration true [current_project]' "$PROJECT_TCL"
else
    echo "ERROR: Could not find VPK180 part line in $PROJECT_TCL"
    exit 1
fi

# 2. WRITE_BITSTREAM.ARGS.BIN_FILE — property does not exist on Versal.
#    Versal uses PDI; the .bin-from-.bit companion is not applicable.
sed -i '/^[[:space:]]*set_property STEPS\.WRITE_BITSTREAM\.ARGS\.BIN_FILE/ s/^/# VERSAL-PATCH: /' "$RUN_FILE"

# 3. Rename the impl step: write_bitstream -> write_device_image.
sed -i 's/-to_step write_bitstream/-to_step write_device_image/g' "$RUN_FILE"

# 4. Output extension: .bit -> .pdi for the backward-compat copy.
#    Word boundary keeps "write_bitstream" (no leading dot) untouched.
sed -i 's/\.bit\b/.pdi/g' "$RUN_FILE"

echo "INFO: Patched $PROJECT_TCL and $RUN_FILE for Versal (VPK180)."
