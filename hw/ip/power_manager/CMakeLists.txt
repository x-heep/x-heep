add_ip_from_fusesoc("./power_manager_pkg.core")
add_ip_from_fusesoc("./power_manager.core")

ip_sources(${IP} OPENTITAN_HJSON_TEMPLATE
    ./data/power_manager.hjson.tpl
)
ip_sources(${IP} OPENTITAN_SV_TEMPLATE
    ./rtl/power_manager.sv.tpl
)
ip_sources(${IP} OPENTITAN_C_HEADER_TEMPLATE
    ../../../sw/device/lib/drivers/power_manager/power_manager.h.tpl
)

mcu_gen_template(${IP} MCU_GEN_FLAGS ${MCU_GEN_FLAGS})

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES OUTDIR "${CMAKE_CURRENT_LIST_DIR}/../../../sw/device/lib/drivers/power_manager/")
regtool(${IP} MARKDOWN)
