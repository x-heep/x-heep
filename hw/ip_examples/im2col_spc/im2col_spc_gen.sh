# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

echo "Generating RTL"
${PYTHON} ../../vendor/pulp_platform/register_interface/vendor/lowrisc_opentitan/util/regtool.py -r -t rtl data/im2col_spc.hjson
echo "Generating SW"
${PYTHON} ../../vendor/pulp_platform/register_interface/vendor/lowrisc_opentitan/util/regtool.py --cdefines -o ../../../sw/device/lib/drivers/im2col_spc/im2col_spc_regs.h data/im2col_spc.hjson
