add_library(w25q INTERFACE
    ./w25q.c
    )

target_include_directories(runtime INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}
    )
