include_guard()

#### fifo_pkg
add_ip(x-heep::core::fifo_pkg::0.0.1)
ip_sources(${IP} SYSTEMVERILOG FILE_SET files_rtl
    ./include/fifo_pkg.sv
    )

#### addr_map_rule_pkg
add_ip(x-heep::core::addr_map_rule_pkg::0.0.1)
ip_sources(${IP} SYSTEMVERILOG FILE_SET files_rtl
    ./include/addr_map_rule_pkg.sv
    )

#### power_manager_pkg
add_ip(x-heep::core::power_manager_pkg::0.0.1)
ip_sources(${IP} SYSTEMVERILOG FILE_SET files_rtl
    ./include/power_manager_pkg.sv
    )

#### reg_pkg
add_ip(x-heep::core::reg_pkg::0.0.1)
ip_sources(${IP} SYSTEMVERILOG FILE_SET files_rtl
    ./include/reg_pkg.sv
    )

#### obi_pkg
add_ip(x-heep::core::obi_pkg::0.0.1)
ip_sources(${IP} SYSTEMVERILOG FILE_SET files_rtl
    ./include/obi_pkg.sv
    )

#### xbar_varlat
add_ip_from_fusesoc("../vendor/pulp_platform_cluster_interconnect.core")
add_ip(x-heep::core::xbar_varlat::0.0.1)
ip_sources(${IP} SYSTEMVERILOG
    ./xbar_varlat_n_to_one.sv
    ./xbar_varlat_one_to_n.sv
)
ip_link(${IP}
    pulp-platform.org::cluster_interconnect
    x-heep::core::obi_pkg
    x-heep::core::addr_map_rule_pkg
    )

#### x-heep packages
add_ip_from_fusesoc("./include/x-heep_packages.core")

#### core_v_mini_mcu_pkg
add_ip(x-heep::core::core_v_mini_mcu_pkg::0.0.1)
ip_sources(${IP} OPENTITAN_SV_TEMPLATE
    ./include/core_v_mini_mcu_pkg.sv.tpl
)
ip_link(${IP}
    ${XHEEP_CFG_IP}
    x-heep::core::addr_map_rule_pkg
    x-heep::core::power_manager_pkg
    )
mcu_gen_template(${IP} FILE_SET files_rtl)
