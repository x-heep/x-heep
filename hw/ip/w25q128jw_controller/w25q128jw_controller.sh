# Author: Michele Caon, David Mallasen
# Description: Script to generate the w25q128jw_controller registers

PERIPHERAL_NAME=w25q128jw_controller

REG_DIR=$(dirname -- $0)
ROOT="$(dirname -- $0)/../../.."
REGTOOL=$ROOT/hw/vendor/pulp_platform_register_interface/vendor/lowrisc_opentitan/util/regtool.py
PERIPH_STRUCTS_GEN=$ROOT/util/periph_structs_gen/periph_structs_gen.py
HJSON_FILE=$REG_DIR/data/$PERIPHERAL_NAME.hjson
TEMPLATE_FILE=$ROOT/util/periph_structs_gen/periph_structs.tpl
RTL_DIR=$REG_DIR/rtl
SW_DIR=$ROOT/sw/device/lib/drivers/$PERIPHERAL_NAME

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
