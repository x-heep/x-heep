add_ip_from_fusesoc("./iffifo.core")

ip_sources(${IP} OPENTITAN_HJSON
    ./data/iffifo.hjson
)

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES)


