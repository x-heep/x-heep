# Copyright 2026 EPFL
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
# Author: Thomas Tran 
# Description: Script to generate the serial link xheep wrapper registers

PERIPHERAL_NAME=serial_link_xheep_wrapper
REG_DIR=$(dirname -- $0)
ROOT="$(dirname -- $0)/../../.."
REGTOOL=$ROOT/hw/vendor/pulp_platform/register_interface/vendor/lowrisc_opentitan/util/regtool.py
PERIPH_STRUCTS_GEN=$ROOT/util/periph_structs_gen/periph_structs_gen.py
HJSON_FILE=$REG_DIR/data/$PERIPHERAL_NAME.hjson
TEMPLATE_FILE=$ROOT/util/periph_structs_gen/periph_structs.tpl
RTL_DIR=$REG_DIR/rtl
SW_DIR=$ROOT/sw/device/lib/drivers/serial_link
mkdir -p $RTL_DIR $SW_DIR

printf -- "Generating $PERIPHERAL_NAME registers RTL..."
$REGTOOL -r -t $RTL_DIR $HJSON_FILE
[ $? -eq 0 ] && printf " OK\n" || exit $?

printf -- "Generating $PERIPHERAL_NAME software header..."
$REGTOOL --cdefines -o ${SW_DIR}/${PERIPHERAL_NAME}_regs.h $HJSON_FILE
[ $? -eq 0 ] && printf " OK\n" || exit $?

printf -- "Generating $PERIPHERAL_NAME software header structs..."
python $PERIPH_STRUCTS_GEN --template_filename $TEMPLATE_FILE \
--hjson_filename $HJSON_FILE \
--output_filename ${SW_DIR}/${PERIPHERAL_NAME}_structs.h
[ $? -eq 0 ] && printf " OK\n" || exit $?

printf -- "Generating $PERIPHERAL_NAME documentation..."
$REGTOOL -d $HJSON_FILE > ${SW_DIR}/${PERIPHERAL_NAME}_regs.md
[ $? -eq 0 ] && printf " OK\n" || exit $?
