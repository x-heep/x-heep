add_library(runtime INTERFACE)
target_sources(runtime PUBLIC
    ./handler.c
    ./syscalls.c
    ./init.c
    ./core_v_mini_mcu.c
)

target_include_directories(runtime INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}
    )
