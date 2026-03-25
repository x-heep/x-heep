add_subdirectory("../device/lib/base/" "libbase")
add_subdirectory("../device/lib/base/freestanding/" "freestanding")
add_subdirectory("../device/lib/runtime/" "runtime")
add_subdirectory("../device/bsp/w25q/" "w25q")
add_subdirectory("../device/lib/crt/" "crt0")

add_library(xheep_sdk INTERFACE)

target_include_directories(xheep_sdk INTERFACE
    "${RISCV}/${COMPILER_PREFIX}elf/include"
    "${CMAKE_CURRENT_LIST_DIR}/../"
    "${CMAKE_CURRENT_LIST_DIR}/../device/target/${TARGET}/"
    )

target_compile_options(xheep_sdk INTERFACE
    -march=${CMAKE_SYSTEM_PROCESSOR}
    -nostdlib
    -ffunction-sections
    -DHOST_BUILD
    -DINTERNAL_CRT0 # What is INTERNAL/EXTERNAL CRT0?
    -DportasmHANDLE_INTERRUPT=vSystemIrqHandler
    )

target_link_options(xheep_sdk INTERFACE
    -static 
    -nostartfiles -nostdlib
    -Wl,-Map=mem.map
    -Wl,--gc-sections
    -L ${RISCV}/${COMPILER_PREFIX}elf/lib
    # -lc -lm -lgcc -flto
    -flto
    -fpermissive -fno-rtti -fno-exceptions -fno-threadsafe-statics 
    -ffunction-sections -fdata-sections -specs=nano.specs
)

target_link_libraries(xheep_sdk INTERFACE
    crt0
    opentitan::libbase
    opentitan::freestanding
    runtime
    w25q
    c
    m
    gcc
    )

add_subdirectory("../device/lib/sdk/dma/" "dma_sdk")
add_subdirectory("../device/lib/sdk/spi/" "spi_sdk")
add_subdirectory("../device/lib/sdk/timer/" "timer_sdk")
add_subdirectory("../device/lib/sdk/spi_slave/" "spi_slave_sdk")

target_link_libraries(xheep_sdk INTERFACE
    dma_sdk
    spi_sdk
    timer_sdk
    spi_slave_sdk
    )

add_subdirectory("../device/lib/drivers/" "drivers")

# Driver LIBS is set by the drivers subdirectory
target_link_libraries(xheep_sdk INTERFACE
    ${DRIVER_LIBS}
    )

#######################################################################
#      SET CRT AND LINKER TYPE
#######################################################################

# Get the correct path for the crt files and linker file
if (${LINKER} STREQUAL "on_chip")
  #SET(LIB_CRT_P "${SOURCE_PATH}device/lib/crt/")
  SET(CRT_TYPE "ON_CHIP")
  SET(LINK_FILE "link.ld")
elseif(${LINKER} STREQUAL "flash_load")
  #SET(LIB_CRT_P "${SOURCE_PATH}device/lib/crt_flash_load/")
  SET(CRT_TYPE "FLASH_LOAD")
  SET(LINK_FILE "link_flash_load.ld")
elseif(${LINKER} STREQUAL "flash_exec")
  #SET(LIB_CRT_P	"${SOURCE_PATH}device/lib/crt_flash_exec/")
  SET(CRT_TYPE "FLASH_EXEC")
  SET(LINK_FILE "link_flash_exec.ld")
else()
  message( FATAL_ERROR "Linker specification is not correct" )
endif()
target_compile_options(xheep_sdk INTERFACE -D${CRT_TYPE})

include("${CMAKE_CURRENT_LIST_DIR}/../cmake/utils.cmake")

function(link_application TARGET)
    target_link_libraries(${TARGET} PRIVATE xheep_sdk)

    set_linker_script(${TARGET} "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../linker/link.ld")

    gen_asm(${TARGET})
    gen_hex(${TARGET})
    gen_bin(${TARGET})
    xheep_mem_usage(${TARGET})
endfunction()
