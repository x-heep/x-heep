function(xheep_add_cfg_ip IP_LIB)
    # Parse keyword arguments
    cmake_parse_arguments(ARG "" "OUTDIR;X_HEEP_CFG;PADS_CFG;CPU;BUS;MEMORY_BANKS;MEMORY_BANKS_IL" "ARGS" ${ARGN})
    # Check for any unknown argument
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} passed unrecognized argument "
                "${ARG_UNPARSED_ARGUMENTS}")
    endif()

    add_ip(${IP_LIB})
    # alias_dereference(IP_LIB ${IP_LIB})
    get_target_property(BINARY_DIR ${IP_LIB} BINARY_DIR)

    if(NOT DEFINED ARG_OUTDIR)
        set(ARG_OUTDIR ${BINARY_DIR}/${IP_LIB}_${CMAKE_CURRENT_FUNCTION})
    endif()
    make_directory("${ARG_OUTDIR}")

    # get_ip_sources(SOURCES ${IP_LIB} OPENTITAN_HJSON)
    unset(sources)

    find_python3()

    find_program(MCU_GEN_EXECUTABLE mcu_gen.py REQUIRED
        HINTS "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../util/" )

    set(xheep_cfg_pickle "${ARG_OUTDIR}/${IP_LIB}.pickle")
    ip_sources(${IP_LIB} XHEEP_CACHE ${xheep_cfg_pickle})
    set(gen_files ${xheep_cfg_pickle})

    set(cmd ${Python3_EXECUTABLE} ${MCU_GEN_EXECUTABLE}
            --cached_path "${xheep_cfg_pickle}"
            ${ARG_ARGS}
        )

    if(ARG_X_HEEP_CFG)
        convert_paths_to_absolute(ARG_X_HEEP_CFG ${ARG_X_HEEP_CFG})
        list(APPEND cmd --config ${ARG_X_HEEP_CFG})
        list(APPEND sources ${ARG_X_HEEP_CFG})
    endif()

    if(ARG_PADS_CFG)
        convert_paths_to_absolute(ARG_PADS_CFG ${ARG_PADS_CFG})
        list(APPEND cmd --pads_cfg ${ARG_PADS_CFG})
        list(APPEND sources ${ARG_PADS_CFG})
    endif()

    if(ARG_CPU)
        list(APPEND cmd --cpu ${ARG_CPU})
    endif()

    if(ARG_BUS)
        list(APPEND cmd --bus ${ARG_BUS})
    endif()

    if(ARG_MEMORY_BANKS)
        list(APPEND cmd --memorybanks ${ARG_MEMORY_BANKS})
    endif()

    if(ARG_MEMORY_BANKS_IL)
        list(APPEND cmd --memorybanks_il ${ARG_MEMORY_BANKS_IL})
    endif()


    set(target_name ${IP_LIB}_${CMAKE_CURRENT_FUNCTION})

    set(STAMP_FILE "${ARG_OUTDIR}/.${CMAKE_CURRENT_FUNCTION}.stamp")
    list(APPEND gen_files "${STAMP_FILE}")
    set(DESCRIPTION "${Green}Run ${CMAKE_CURRENT_FUNCTION} on '${IP_LIB}'${ColourReset}")
    add_custom_command(
        OUTPUT ${gen_files}
        COMMAND ${cmd}
        COMMAND touch ${STAMP_FILE}
        DEPENDS ${sources}
        COMMENT ${DESCRIPTION}
        COMMAND_EXPAND_LISTS
    )
    add_custom_target(
        ${target_name}
        DEPENDS ${gen_files}
    )
    set_property(TARGET ${target_name} PROPERTY DESCRIPTION ${DESCRIPTION})
    add_dependencies(${IP_LIB} ${target_name})

endfunction()
