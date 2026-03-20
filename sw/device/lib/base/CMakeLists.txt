add_library(libbase INTERFACE
    ./mmio.c
    ./memory.c
    )
add_library(opentitan::libbase ALIAS libbase)

target_include_directories(libbase INTERFACE ${CMAKE_CURRENT_LIST_DIR})
