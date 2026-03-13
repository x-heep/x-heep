add_ip_from_fusesoc("./dma_subsystem.core")

ip_link(${IP} 
    ${XHEEP_CFG_IP}
    x-heep::core::fifo_pkg
    x-heep::core::core_v_mini_mcu_pkg
    x-heep::core::obi_pkg
    x-heep::core::reg_pkg
    x-heep::ip::dma
)
