function(xheep_add_top_target top_target TOP_MCU)
    # Parse keyword arguments
    cmake_parse_arguments(ARG "" "OUTDIR" "ARGS" ${ARGN})
    # Check for any unknown argument
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} passed unrecognized argument "
                "${ARG_UNPARSED_ARGUMENTS}")
    endif()
    # Optimization to not do topological sort of linked IPs on get_ip_...() calls
    flatten_graph_and_disallow_flattening(${TOP_MCU})

    get_ip_sources(SOURCES ${TOP_MCU} SYSTEMVERILOG LINKER C ASM CPP)
    get_ip_sources(HEADERS ${TOP_MCU} SYSTEMVERILOG HEADERS)

    set(target_name ${top_target})

    set(STAMP_FILE "${CMAKE_BINARY_DIR}/.${target_name}_${CMAKE_CURRENT_FUNCTION}.stamp")
    list(APPEND gen_files "${STAMP_FILE}")
    set(DESCRIPTION "${Green}Generate all ${TOP_MCU} files${ColourReset}")
    # add_custom_command(
    #     OUTPUT ${gen_files}
    #     COMMAND ${cmd}
    #     COMMAND touch ${STAMP_FILE}
    #     DEPENDS ${sources}
    #     COMMENT ${DESCRIPTION}
    #     COMMAND_EXPAND_LISTS
    # )
    add_custom_target(
        ${target_name}
        DEPENDS ${SOURCES} ${HEADERS} ${TOP_MCU}
    )
    set_property(TARGET ${target_name} PROPERTY DESCRIPTION ${DESCRIPTION})
    # add_dependencies(${IP_LIB} ${target_name})

    # Allow again topological sort outside the function
    socmake_allow_topological_sort(ON)
endfunction()
