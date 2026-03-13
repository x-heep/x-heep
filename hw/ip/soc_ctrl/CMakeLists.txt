add_ip_from_fusesoc("./openhwgroup_soc_ctrl.core")

ip_sources(${IP} OPENTITAN_HJSON
    ./data/soc_ctrl.hjson
)

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES OUTDIR "${CMAKE_CURRENT_LIST_DIR}/../../../sw/device/lib/drivers/soc_ctrl/")

