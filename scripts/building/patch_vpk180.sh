#!/bin/bash
# Patch the edalize-generated Vivado run script for Versal (VPK180).
# edalize's Vivado backend hardcodes 7-series/UltraScale commands that are
# invalid for Versal devices. This script rewrites those lines in place.

set -eu

FILE="openhwgroup.org_systems_core-v-mini-mcu_1.0.5_run.tcl"

if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE not found in $(pwd)"
    exit 1
fi

# 1. WRITE_BITSTREAM.ARGS.BIN_FILE — property does not exist on Versal.
#    Versal uses PDI; the .bin-from-.bit companion is not applicable.
sed -i '/^[[:space:]]*set_property STEPS\.WRITE_BITSTREAM\.ARGS\.BIN_FILE/ s/^/# VERSAL-PATCH: /' "$FILE"

# 2. Rename the impl step: write_bitstream -> write_device_image.
sed -i 's/-to_step write_bitstream/-to_step write_device_image/g' "$FILE"

# 3. Output extension: .bit -> .pdi for the backward-compat copy.
#    Word boundary keeps "write_bitstream" (no leading dot) untouched.
sed -i 's/\.bit\b/.pdi/g' "$FILE"

echo "INFO: Patched $FILE for Versal (VPK180)."
