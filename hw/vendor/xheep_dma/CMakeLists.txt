add_ip_from_fusesoc("./dma.core")

ip_link(${IP} 
    x-heep::core::fifo_pkg
)


ip_sources(${IP} OPENTITAN_HJSON_TEMPLATE
    ./data/dma.hjson.tpl
)
ip_sources(${IP} OPENTITAN_SVH_TEMPLATE
    ./data/dma_conf.svh.tpl
)

mcu_gen_template(${IP} FILE_SET files_rtl MCU_GEN_FLAGS ${MCU_GEN_FLAGS})

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES OUTDIR "${CMAKE_CURRENT_LIST_DIR}/../../../sw/device/lib/drivers/xheep_dma/")