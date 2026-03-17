# Copyright 2025 EPFL contributors
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Michele Caon, David Mallasen, Davide Schiavone
# Description: Script to generate the dma registers

# Variables with command-line overrides
# Usage: ./dma_gen.sh [REGTOOL_PATH] [PERIPH_GEN_PATH] [TEMPLATE_FILE] [SW_DIR_PATH]

PERIPHERAL_NAME=dma

REG_DIR=$(dirname -- $0)
ROOT="$(dirname -- $0)/../../.."
HJSON_FILE=$REG_DIR/data/$PERIPHERAL_NAME.hjson
RTL_DIR=$REG_DIR/rtl


REGTOOL=${1:-$ROOT/hw/vendor/pulp_platform_register_interface/vendor/lowrisc_opentitan/util/regtool.py}
PERIPH_STRUCTS_GEN=${2:-$ROOT/util/periph_structs_gen/periph_structs_gen.py}
TEMPLATE_FILE=${3-$ROOT/util/periph_structs_gen/periph_structs.tpl}
SW_DIR=${4-$ROOT/sw/device/lib/drivers/$PERIPHERAL_NAME}


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
