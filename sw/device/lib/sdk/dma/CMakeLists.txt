add_library(dma_sdk INTERFACE
    ./dma_sdk.c
    )

target_include_directories(dma_sdk INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}
    )
