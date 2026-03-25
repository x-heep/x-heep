add_ip_from_fusesoc("../../../pulp_platform_pulpissimo_remote_bitbang.core")

add_library(remote_bitbang SHARED
    ./remote_bitbang/sim_jtag.c
    ./remote_bitbang/remote_bitbang.c
)
target_include_directories(remote_bitbang PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/remote_bitbang/)

target_link_libraries(remote_bitbang PRIVATE
    SoCMake::DPI-C
    # util
    )

ip_link(${IP} remote_bitbang)

