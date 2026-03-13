add_ip_from_fusesoc("./dlc.core")

ip_sources(${IP} OPENTITAN_HJSON
    ./data/dlc.hjson
)

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES)
