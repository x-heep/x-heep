include("${CMAKE_CURRENT_LIST_DIR}/../sw/cmake/get_source_dirs.cmake")

function(add_sw_tests TESTS SOURCE_DIR)
    cmake_parse_arguments(ARG "" "BINARY_DIR" "" ${ARGN})
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} passed unrecognized argument "
                "${ARG_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT ARG_BINARY_DIR)
        set(ARG_BINARY_DIR "${SOURCE_DIR}/build")
    endif()

    if(NOT RISCV)
        set(RISCV $ENV{RISCV})
    endif()

    include(ExternalProject)

    convert_paths_to_absolute(SOURCE_DIR ${SOURCE_DIR})
    convert_paths_to_absolute(ARG_BINARY_DIR ${ARG_BINARY_DIR})

    get_source_dirs(app_dirs "${SOURCE_DIR}/applications")

    unset(tests)
    foreach(test_dir ${app_dirs})

        set(DONT_COMPILE ON)
        include("${test_dir}/CMakeLists.txt")
        set(fw_name "${PROJECT_NAME}")
        set(test "app_${fw_name}")
        set(test_description "${PROJECT_DESCRIPTION}")
        list(APPEND tests ${test})

        ExternalProject_Add(${test}
            SOURCE_DIR "${test_dir}"
            # BINARY_DIR "${ARG_BINARY_DIR}"

            DOWNLOAD_COMMAND ""
            UPDATE_COMMAND ""
            PATCH_COMMAND ""
            INSTALL_COMMAND ""

            BUILD_ALWAYS TRUE # Make sure file changes in sw dir is tracked

            CMAKE_ARGS
                -DCMAKE_TOOLCHAIN_FILE=${SOURCE_DIR}/cmake/riscv.cmake
                -DTARGET=${FW_TARGET}
                -DPROJECT=${FW_PROJECT}
                -DRISCV=${RISCV}
                -DLINKER=${FW_LINKER}
                -DCOMPILER=${FW_COMPILER}
                -DCOMPILER_PREFIX=${FW_COMPILER_PREFIX}
                -DARCH=${FW_ARCH}

                -DCMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}

                # Dont do compiler checks to save time
                -DCMAKE_C_COMPILER_WORKS=1
                -DCMAKE_CXX_COMPILER_WORKS=1
                -DCMAKE_ASM_COMPILER_WORKS=1
                -DCMAKE_C_COMPILER_FORCED=1
                -DCMAKE_CXX_COMPILER_FORCED=1

            # For Ninja so it prints status live and not delayed
            USES_TERMINAL_CONFIGURE TRUE
            USES_TERMINAL_BUILD TRUE
            DEPENDS mcu_gen
            )
        ExternalProject_Get_Property(${test} BINARY_DIR)
        ExternalProject_Get_Property(${test} STAMP_DIR)

        set_target_properties(${test} PROPERTIES EXCLUDE_FROM_ALL TRUE)
        set_target_properties(${test} PROPERTIES DESCRIPTION "${test_description} ")
        set_target_properties(${test} PROPERTIES HEX_FILE "${BINARY_DIR}/${fw_name}.hex")

        list(APPEND TEST_CLEAN_COMMANDS 
            COMMAND ninja -C ${BINARY_DIR} clean || true
            COMMAND touch ${STAMP_DIR}/${test}-configure
            )
    endforeach()

    add_custom_target(clean-tests
        ${TEST_CLEAN_COMMANDS}
        )

    set(${TESTS} ${tests} PARENT_SCOPE)
endfunction()
