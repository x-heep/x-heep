add_ip_from_fusesoc("./openhwgroup_soc_ctrl.core")

ip_sources(${IP} OPENTITAN_HJSON_TEMPLATE
    ./data/soc_ctrl.hjson.tpl
)

mcu_gen_template(${IP} MCU_GEN_FLAGS ${MCU_GEN_FLAGS})

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES OUTDIR "${CMAKE_CURRENT_LIST_DIR}/../../../sw/device/lib/drivers/soc_ctrl/")

