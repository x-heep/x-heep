macro(find_python3)
    if(NOT DEFINED Python3_EXECUTABLE)
        find_package(Python3 COMPONENTS Interpreter REQUIRED)
        set(Python3_EXECUTABLE "${Python3_EXECUTABLE}" CACHE FILEPATH "Path to Python3 interpreter")
    endif()
endmacro()

function(gen_asm TARGET)
    get_target_property(BINARY_DIR ${TARGET} BINARY_DIR)
    add_custom_command(TARGET ${TARGET} POST_BUILD
            COMMAND ${CMAKE_OBJDUMP} -S  $<TARGET_FILE:${TARGET}> > ${BINARY_DIR}/${TARGET}.S
            COMMENT "Invoking: Disassemble")
endfunction()

function(gen_hex TARGET)
    get_target_property(BINARY_DIR ${TARGET} BINARY_DIR)
    add_custom_command(TARGET ${TARGET} POST_BUILD
            COMMAND ${CMAKE_OBJCOPY} -O verilog  $<TARGET_FILE:${TARGET}> ${BINARY_DIR}/${TARGET}.hex
            COMMENT "Invoking: Hexdump")
    add_custom_command(TARGET ${TARGET} POST_BUILD
            COMMAND ${CMAKE_OBJCOPY} --srec-forceS3 --srec-len 1 -O srec $<TARGET_FILE:${TARGET}> ${BINARY_DIR}/${TARGET}.hex.srec
            COMMENT "Invoking: SREC Hexdump")
endfunction()

function(gen_bin TARGET)
    get_target_property(BINARY_DIR ${TARGET} BINARY_DIR)
    add_custom_command(TARGET ${TARGET} POST_BUILD
            COMMAND ${CMAKE_OBJCOPY} -O binary  $<TARGET_FILE:${TARGET}>  ${BINARY_DIR}/${TARGET}.bin
            COMMENT "Invoking: Binary dump")
endfunction()

function(set_linker_script TARGET LINKER_SCRIPT)
    set_target_properties(${TARGET} PROPERTIES LINK_DEPENDS "${LINKER_SCRIPT}")

    target_link_options(${TARGET} PUBLIC
        -T${LINKER_SCRIPT}
        )
endfunction()

function(xheep_mem_usage TARGET)
    get_target_property(BINARY_DIR ${TARGET} BINARY_DIR)
    find_python3()

    set(mem_usage_executable "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../../scripts/building/mem_usage.py")
    add_custom_command(TARGET ${TARGET} POST_BUILD
        COMMAND ${Python3_EXECUTABLE} ${mem_usage_executable}  
                        --elf-file $<TARGET_FILE:${TARGET}>
                        --map-file ${BINARY_DIR}/mem.map
                        --mcu-pkg-file "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../../hw/core-v-mini-mcu/include/core_v_mini_mcu_pkg.sv"
        COMMENT "Invoking: memory usage analysis")
endfunction()
