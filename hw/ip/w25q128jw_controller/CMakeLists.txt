add_ip_from_fusesoc("./w25q128jw_controller.core")

ip_sources(${IP} OPENTITAN_HJSON
    ./data/w25q128jw_controller.hjson
)

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES OUTDIR "${CMAKE_CURRENT_LIST_DIR}/../../../sw/device/lib/drivers/w25q128jw_controller/")
