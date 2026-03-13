function(mcu_gen_structs_periph_gen IP_LIB)
    # Parse keyword arguments
    cmake_parse_arguments(ARG "" "" "ARGS" ${ARGN})
    # Check for any unknown argument
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} passed unrecognized argument "
                "${ARG_UNPARSED_ARGUMENTS}")
    endif()
    # Optimization to not do topological sort of linked IPs on get_ip_...() calls
    flatten_graph_and_disallow_flattening(${IP_LIB})

    alias_dereference(IP_LIB ${IP_LIB})
    get_target_property(BINARY_DIR ${IP_LIB} BINARY_DIR)

    get_ip_sources(cache ${IP_LIB} XHEEP_CACHE)
    get_ip_sources(hjson_deps ${IP_LIB} OPENTITAN_HJSON)

    find_python3()
    find_file(STRUCTS_PERIPH_GEN_EXECUTABLE periph_structs_gen.py REQUIRED
        HINTS "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../util/periph_structs_gen/" )

    set(cmd ${Python3_EXECUTABLE} ${STRUCTS_PERIPH_GEN_EXECUTABLE}
            --cfg_peripherals ${cache}
            ${ARG_ARGS}
        )

    unset(gen_files)

    set(target_name ${IP_LIB}_${CMAKE_CURRENT_FUNCTION})

    set(STAMP_FILE "${BINARY_DIR}/.${target_name}.stamp")
    list(APPEND gen_files "${STAMP_FILE}")
    set(DESCRIPTION "${Green}Run struct periph gen on '${IP_LIB}'${ColourReset}")
    add_custom_command(
        OUTPUT ${gen_files}
        COMMAND ${cmd}
        COMMAND touch ${STAMP_FILE}
        DEPENDS ${cache} ${hjson_deps}
        COMMENT ${DESCRIPTION}
        COMMAND_EXPAND_LISTS
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
    add_custom_target(
        ${target_name}
        DEPENDS ${gen_files}
    )
    set_property(TARGET ${target_name} PROPERTY DESCRIPTION ${DESCRIPTION})
    add_dependencies(${IP_LIB} ${target_name})

    # Allow again topological sort outside the function
    socmake_allow_topological_sort(ON)
endfunction()

