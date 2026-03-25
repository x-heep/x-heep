add_ip_from_fusesoc("${CMAKE_CURRENT_LIST_DIR}/pad_control.core")

ip_sources(${IP} OPENTITAN_HJSON_TEMPLATE
    ./data/pad_control.hjson.tpl
)

ip_sources(${IP} OPENTITAN_SV_TEMPLATE
    ./rtl/pad_control.sv.tpl
)

mcu_gen_template(${IP} FILE_SET files_rtl MCU_GEN_FLAGS ${MCU_GEN_FLAGS})

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES OUTDIR "${CMAKE_CURRENT_LIST_DIR}/../../../sw/device/lib/drivers/pad_control/")

# verilator(${IP} VERILATOR_ARGS -Wno-fatal)

