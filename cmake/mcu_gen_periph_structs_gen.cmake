function(mcu_gen_periph_structs_gen IP_LIB)
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

    # Get generated hjson files
    get_ip_sources(hjson_files ${IP_LIB} OPENTITAN_HJSON)

    # Get python and the program
    find_python3()
    find_file(PERIPH_STRUCTS_GEN_EXECUTABLE periph_structs_gen.py REQUIRED
        HINTS "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../util/periph_structs_gen/" )

    # Set the template
    find_file(PERIPH_STRUCTS_TEMPLATE periph_structs.tpl REQUIRED
        HINTS "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../util/periph_structs_gen/" )

    unset(gen_files)

    set(target_name ${IP_LIB}_${CMAKE_CURRENT_FUNCTION})
    set(STAMP_FILE "${BINARY_DIR}/.${target_name}.stamp")

    foreach(hjson_filename IN LISTS hjson_files)
        # Derive output filename: replace .hjson suffix with _structs.h
        get_filename_component(base_name ${hjson_filename} NAME_WE)
        get_filename_component(file_dir  ${hjson_filename} DIRECTORY)

        # Specific case where the base name should not be the folder name
        if(base_name STREQUAL "obi_spimemio")
            set(output_dir "spi_memio")
        else()
            set(output_dir "${base_name}")
        endif()

        set(output_filename "${CMAKE_CURRENT_LIST_DIR}/sw/device/lib/drivers/${output_dir}/${base_name}_structs.h")

        set(DESCRIPTION "${Green}Run struct periph gen for '${base_name}'${ColourReset}")

        set(cmd
            ${Python3_EXECUTABLE} ${PERIPH_STRUCTS_GEN_EXECUTABLE}
            --template_filename ${PERIPH_STRUCTS_TEMPLATE}
            --hjson_filename    ${hjson_filename}
            --output_filename   ${output_filename}
        )

        add_custom_command(
            OUTPUT  ${output_filename}
            COMMAND ${cmd}
            DEPENDS ${hjson_filename} ${PERIPH_STRUCTS_TEMPLATE}
            COMMENT ${DESCRIPTION}
            COMMAND_EXPAND_LISTS
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        )

        list(APPEND gen_files ${output_filename})
    endforeach()

    add_custom_command(
        OUTPUT  ${STAMP_FILE}
        COMMAND touch ${STAMP_FILE}
        DEPENDS ${gen_files}
        COMMENT "Stamping ${target_name}"
    )

    add_custom_target(
        ${target_name}
        DEPENDS ${gen_files} ${STAMP_FILE}
    )
    set_property(TARGET ${target_name} PROPERTY DESCRIPTION ${DESCRIPTION})
    add_dependencies(${IP_LIB} ${target_name})

    # Allow again topological sort outside the function
    socmake_allow_topological_sort(ON)
endfunction()
