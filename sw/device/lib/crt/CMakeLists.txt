add_library(crt0 INTERFACE)
target_sources(crt0 PUBLIC
    ./crt0.S
    ./vectors.S
)

target_include_directories(crt0 INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}
    )
