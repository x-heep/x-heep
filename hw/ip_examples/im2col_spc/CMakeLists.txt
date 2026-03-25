add_ip_from_fusesoc("./im2col_spc.core")

ip_sources(${IP} OPENTITAN_HJSON
    ./data/im2col_spc.hjson
)

regtool(${IP} RTL FILE_SET files_rtl)
regtool(${IP} CDEFINES)
