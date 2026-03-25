function(primgen IP_LIB)
    # Parse keyword arguments
    cmake_parse_arguments(ARG "PRIM;GENERATE_PRIM_PKG" "OUTDIR;FILE_SET" "ARGS" ${ARGN})
    # Check for any unknown argument
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} passed unrecognized argument "
                "${ARG_UNPARSED_ARGUMENTS}")
    endif()

    alias_dereference(IP_LIB ${IP_LIB})
    get_target_property(BINARY_DIR ${IP_LIB} BINARY_DIR)

    if(NOT DEFINED ARG_OUTDIR)
        set(ARG_OUTDIR ${BINARY_DIR}/${IP_LIB}_${CMAKE_CURRENT_FUNCTION})
    endif()
    make_directory("${ARG_OUTDIR}")

    if(DEFINED ARG_FILE_SET)
        set(ARG_FILE_SET FILE_SET ${ARG_FILE_SET})
    endif()

    get_target_property(IP_NAME ${IP_LIB} IP_NAME)
    set(MODULE_NAME ${IP_NAME})

    get_ip_sources(SOURCES ${IP_LIB} SYSTEMVERILOG NO_DEPS)

    #####################################
    # Prepare the fusesoc vlnv 
    #####################################
    string(REPLACE "__" ":" fusesoc_vlnv "${IP_LIB}")
    get_property(ip_vendor TARGET ${IP_LIB} PROPERTY VENDOR)
    get_property(ip_name TARGET ${IP_LIB} PROPERTY IP_NAME)
    get_property(ip_version TARGET ${IP_LIB} PROPERTY VERSION)
    if(NOT DEFINED ip_version)
        set(fusesoc_vlnv "${fusesoc_vlnv}:0")
    endif()

    #####################################
    # Create the json file for primgen
    #####################################
    set(core_dict "{}")
    string(JSON core_dict SET ${core_dict} "${fusesoc_vlnv}" "{}")
    string(JSON core_dict SET ${core_dict} "${fusesoc_vlnv}" "core_root" \"${CMAKE_CURRENT_SOURCE_DIR}\")
    string(JSON core_dict SET ${core_dict} "${fusesoc_vlnv}" "files" \[\]) # Create array

    set(cnt 0)
    foreach(source ${SOURCES})
        string(JSON core_dict SET ${core_dict} "${fusesoc_vlnv}" "files" ${cnt} \"${source}\") # Create array
        math(EXPR cnt "${cnt} + 1" OUTPUT_FORMAT DECIMAL)
    endforeach()

    set(json_dict "{}")
    string(JSON json_dict SET ${json_dict} "cores" "${core_dict}")

    string(JSON json_dict SET ${json_dict} "parameters" "{}")
    string(JSON json_dict SET ${json_dict} "parameters" "prim_name" \"${ip_name}\")

    set(json_outfile "${ARG_OUTDIR}/${IP_LIB}.json")
    file(WRITE "${json_outfile}" "${json_dict}")

    #####################################
    # Prepare the command
    #####################################

    find_python3()
    find_program(PRIMGEN_EXECUTABLE primgen.py REQUIRED
        HINTS ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../hw/vendor/lowrisc_opentitan/hw/ip/prim/util/)

    set(cmd ${Python3_EXECUTABLE} ${PRIMGEN_EXECUTABLE}
            "${json_outfile}")

    #####################################
    # Create a new IP with the generated files
    #####################################
    add_ip("${ip_vendor}::prim::${ip_name}::0")
    unset(gen_files)
    set(SV_GEN ${ARG_OUTDIR}/prim_${ip_name}.sv)
    ip_sources(${IP} SYSTEMVERILOG ${ARG_FILE_SET} PREPEND ${SV_GEN})
    list(APPEND gen_files ${SV_GEN})
    ip_link(${IP} ${IP_LIB})

    #####################################
    # Create the target and the command
    #####################################
    set(target_name ${IP_LIB}_primgen)
    set(STAMP_FILE "${ARG_OUTDIR}/.${IP_LIB}_primgen.stamp")
    list(APPEND gen_files "${STAMP_FILE}")
    set(DESCRIPTION "${Green}Run primgen for '${IP_LIB}'${ColourReset}")
    add_custom_command(
        OUTPUT ${gen_files}
        COMMAND ${cmd}
        COMMAND touch ${STAMP_FILE}
        DEPENDS ${SOURCES}
        COMMENT ${DESCRIPTION}
        COMMAND_EXPAND_LISTS
        WORKING_DIRECTORY ${ARG_OUTDIR}
    )
    add_custom_target(
        ${target_name}
        DEPENDS ${gen_files}
    )
    set_property(TARGET ${target_name} PROPERTY DESCRIPTION ${DESCRIPTION})
    add_dependencies(${IP_LIB} ${target_name})

    # set_property(TARGET ${target_name} APPEND PROPERTY ADDITIONAL_CLEAN_FILES ${json_outfile})
endfunction()


