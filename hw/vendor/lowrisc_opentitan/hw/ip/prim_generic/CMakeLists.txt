add_ip_from_fusesoc("../prim/prim_assert.cmake")
add_ip_from_fusesoc("./prim_generic_clock_mux2.core")
primgen(${IP} FILE_SET files_rtl)

add_ip_from_fusesoc("./prim_generic_flop_2sync.core")
primgen(${IP} FILE_SET files_rtl)

add_ip_from_fusesoc("./prim_generic_flop_en.core")
primgen(${IP} FILE_SET files_rtl)

add_ip_from_fusesoc("./prim_generic_flop.core")
primgen(${IP} FILE_SET files_rtl)

add_ip_from_fusesoc("./prim_generic_buf.core")
primgen(${IP} FILE_SET files_rtl)

add_ip_from_fusesoc("../prim/prim_util_memload.core")
add_ip_from_fusesoc("../prim/prim_ram_1p_pkg.core")
add_ip_from_fusesoc("./prim_generic_ram_1p.core")
primgen(${IP} FILE_SET files_rtl)

add_ip_from_fusesoc("./prim_generic_xor2.core")
primgen(${IP} FILE_SET files_rtl)
