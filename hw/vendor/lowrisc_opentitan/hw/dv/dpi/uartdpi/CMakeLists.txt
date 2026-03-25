add_ip_from_fusesoc("./uartdpi.core")

add_library(uartdpi SHARED
    ./uartdpi.c
)
target_include_directories(uartdpi PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(uartdpi PRIVATE
    SoCMake::DPI-C
    util
    )

ip_link(${IP} uartdpi)
