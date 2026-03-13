add_ip_from_fusesoc("../../vendor/yosyshq_picorv32_spimemio.core")
add_ip_from_fusesoc("./obi_spimemio.core")
ip_link(${IP} 
    x-heep::core::obi_pkg
)

ip_sources(${IP} OPENTITAN_HJSON
    ./data/obi_spimemio.hjson
)

regtool(${IP} RTL FILE_SET rtl)
regtool(${IP} CDEFINES OUTDIR "${CMAKE_CURRENT_LIST_DIR}/../../../sw/device/lib/drivers/spi_memio/")
