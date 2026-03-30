# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

echo "Generating RTL"
${PYTHON} ../../vendor/pulp_platform/register_interface/vendor/lowrisc_opentitan/util/regtool.py -r -t rtl data/ams.hjson
echo "Generating SW"
${PYTHON} ../../vendor/pulp_platform/register_interface/vendor/lowrisc_opentitan/util/regtool.py --cdefines -o ../../../sw/device/lib/drivers/ams/ams_regs.h data/ams.hjson
