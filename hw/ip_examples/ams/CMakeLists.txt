add_ip_from_fusesoc("./ams.core")

ip_sources(${IP} OPENTITAN_HJSON
    ./data/ams.hjson
)

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES)
