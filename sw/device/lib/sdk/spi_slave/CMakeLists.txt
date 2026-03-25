add_library(spi_slave_sdk INTERFACE
    ./spi_slave_sdk.c
    )

target_include_directories(spi_slave_sdk INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}
    )


