add_library(spi_sdk INTERFACE
    ./spi_sdk.c
    )

target_include_directories(spi_sdk INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}
    )


