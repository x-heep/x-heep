# Copyright 2025 EPFL.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Description: Script to generate the serial link single channel registers

PERIPHERAL_NAME=serial_link

REG_DIR=$(dirname -- $0)
ROOT="$(dirname -- $0)/../../.."
REGTOOL=$ROOT/hw/vendor/pulp_platform_register_interface/vendor/lowrisc_opentitan/util/regtool.py
PERIPH_STRUCTS_GEN=$ROOT/util/periph_structs_gen/periph_structs_gen.py
HJSON_FILE=../../vendor/pulp_platform_serial_link/src/regs/serial_link_single_channel.hjson
TEMPLATE_FILE=$ROOT/util/periph_structs_gen/periph_structs.tpl
RTL_DIR=$REG_DIR/rtl
SW_DIR=$ROOT/sw/device/lib/drivers/$PERIPHERAL_NAME

mkdir -p $RTL_DIR $SW_DIR

printf -- "Generating $PERIPHERAL_NAME software header..."
$REGTOOL --cdefines -o ${SW_DIR}/${PERIPHERAL_NAME}_regs.h $HJSON_FILE
[ $? -eq 0 ] && printf " OK\n" || exit $?


printf -- "Generating $PERIPHERAL_NAME documentation..."
$REGTOOL -d $HJSON_FILE > ${SW_DIR}/${PERIPHERAL_NAME}_regs.md
[ $? -eq 0 ] && printf " OK\n" || exit $?
