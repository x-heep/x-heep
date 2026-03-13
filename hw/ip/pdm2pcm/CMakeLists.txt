add_ip_from_fusesoc("./pdm2pcm.core")

ip_link(${IP} ${XHEEP_CFG_IP})

ip_sources(${IP} OPENTITAN_HJSON_TEMPLATE
    ./data/pdm2pcm.hjson.tpl
)

ip_sources(${IP} OPENTITAN_SV_TEMPLATE
    ./rtl/pdm_core.sv.tpl
    ./rtl/pdm2pcm.sv.tpl
)

mcu_gen_template(${IP})

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES OUTDIR "${CMAKE_CURRENT_LIST_DIR}/../../../sw/device/lib/drivers/pdm2pcm/")
regtool(${IP} MARKDOWN)

