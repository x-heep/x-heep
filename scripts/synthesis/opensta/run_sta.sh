#!/bin/sh
# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

out=$1

if ! command -v sta >/dev/null 2>&1; then
	echo "WARNING: OpenSTA (sta) not found: no timing, power, ... reports."
	exit 0
fi

echo "Running OpenSTA on $out, log in $out/sta.log"
XHEEP_SYNTH_OUT="$out" sta -no_init -no_splash -exit "$(dirname "$0")/sta_reports.tcl" > "$out/sta.log" 2>&1
if ! grep -q 'OpenSTA reports done' "$out/sta.log"; then
	echo "ERROR: OpenSTA failed, see $out/sta.log"
	tail -n 20 "$out/sta.log"
	exit 1
fi
# Reports in which an OpenSTA command failed (sta_reports.tcl goes on)
if grep '^\[x-heep\] ERROR' "$out/sta.log"; then
	echo "ERROR: some OpenSTA reports are incomplete, see $out/sta.log"
	exit 1
fi
