macro(__mcu_gen_template_file_gen_command generated_files)
    unset(gen_lang_files)
    foreach(source ${sources})
        set(cmd ${Python3_EXECUTABLE} ${MCU_GEN_EXECUTABLE}
                --cached_path "${cache}" --cached --outtpl "${source}")
        cmake_path(REMOVE_EXTENSION source LAST_ONLY OUTPUT_VARIABLE gen_file)
        set(DESCRIPTION "${Green}Generate ${gen_file} for '${IP_LIB}'${ColourReset}")
        add_custom_command(
            OUTPUT ${gen_file}
            COMMAND ${cmd}
            DEPENDS ${sources} ${cache}
            COMMENT ${DESCRIPTION}
            COMMAND_EXPAND_LISTS
        )
        list(APPEND gen_files ${gen_file})
        list(APPEND gen_lang_files ${gen_file})
    endforeach()

    set(${generated_files} ${gen_lang_files})

endmacro()

function(mcu_gen_template IP_LIB)
    # Parse keyword arguments
    cmake_parse_arguments(ARG "" "OUTDIR;FILE_SET" "ARGS" ${ARGN})
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

    if(ARG_FILE_SET)
        set(ARG_FILE_SET FILE_SET ${ARG_FILE_SET})
    endif()

    get_ip_sources(cache ${IP_LIB} XHEEP_CACHE)

    get_ip_links(ips ${IP_LIB})

    find_python3()
    find_program(MCU_GEN_EXECUTABLE mcu_gen.py REQUIRED
        HINTS "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../util/" )

    unset(gen_files)

    get_ip_sources(sources ${IP_LIB} OPENTITAN_HJSON_TEMPLATE NO_DEPS)
    if(sources)
        __mcu_gen_template_file_gen_command(gen_hjson_files)
        ip_sources(${IP_LIB} OPENTITAN_HJSON ${gen_hjson_files})
    endif()

    get_ip_sources(sources ${IP_LIB} OPENTITAN_SVH_TEMPLATE NO_DEPS)
    if(sources)
        __mcu_gen_template_file_gen_command(gen_svh_files)
        ip_sources(${IP_LIB} SYSTEMVERILOG ${ARG_FILE_SET} HEADERS ${gen_svh_files})
    endif()

    get_ip_sources(sources ${IP_LIB} OPENTITAN_SV_TEMPLATE NO_DEPS)
    if(sources)
        __mcu_gen_template_file_gen_command(gen_sv_files)
        ip_sources(${IP_LIB} SYSTEMVERILOG ${ARG_FILE_SET} ${gen_sv_files})
    endif()

    get_ip_sources(sources ${IP_LIB} OPENTITAN_LINKER_TEMPLATE NO_DEPS)
    if(sources)
        __mcu_gen_template_file_gen_command(gen_linker_files)
        ip_sources(${IP_LIB} LINKER ${gen_linker_files})
    endif()

    get_ip_sources(sources ${IP_LIB} OPENTITAN_C_HEADER_TEMPLATE NO_DEPS)
    if(sources)
        __mcu_gen_template_file_gen_command(gen_c_header_files)
        ip_sources(${IP_LIB} C ${gen_c_header_files})
        target_sources(${IP_LIB} INTERFACE ${gen_c_header_files})
    endif()

    get_ip_sources(sources ${IP_LIB} OPENTITAN_ASM_TEMPLATE NO_DEPS)
    if(sources)
        __mcu_gen_template_file_gen_command(gen_asm_files)
        ip_sources(${IP_LIB} ASM ${gen_asm_files})
        target_sources(${IP_LIB} INTERFACE ${gen_asm_files})
    endif()

    set(DESCRIPTION "${Green}Process Opentitan HJSON template files for ${IP_LIB} with mcu_gen${ColourReset}")
    add_custom_target(
        ${IP_LIB}_mcu_gen_template
        DEPENDS ${gen_files}
        COMMENT "${DESCRIPTION}"
    )
    set_property(TARGET ${IP_LIB}_mcu_gen_template PROPERTY DESCRIPTION ${DESCRIPTION})

    # Allow again topological sort outside the function
    socmake_allow_topological_sort(ON)
endfunction()
