add_ip_from_fusesoc("./cve2_pkg.core")

add_ip_from_fusesoc("./vendor/lowrisc_ip/dv/sv/dv_utils/dv_fcov_macros.core")
add_ip_from_fusesoc("./cve2_core.core")
add_ip_from_fusesoc("../lowrisc_opentitan/hw/ip/prim/prim_secded.core")
add_ip_from_fusesoc("../lowrisc_opentitan/hw/ip/prim/prim_ram_1p_pkg.core")
# add_ip_from_fusesoc("../lowrisc_opentitan/hw/ip/prim/prim_ram_1p.core")
add_ip_from_fusesoc("../lowrisc_opentitan/hw/ip/prim/prim_ram_1p_adv.core")
add_ip_from_fusesoc("../lowrisc_opentitan/hw/ip/prim/prim_lfsr.core")
add_ip_from_fusesoc("../lowrisc_opentitan/hw/ip/prim/prim_ram_1p_scr.core")
add_ip_from_fusesoc("./cve2_clock_gate.core")
add_ip_from_fusesoc("./cve2_top.core")

ip_link(${IP})
