add_ip_from_fusesoc("./obi_fifo.core")
ip_link(${IP} 
    x-heep::core::obi_pkg
)
