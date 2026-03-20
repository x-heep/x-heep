add_library(timer_sdk INTERFACE
    ./timer_sdk.c
    )

target_include_directories(timer_sdk INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}
    )

