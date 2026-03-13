function(regtool IP_LIB)
    # Parse keyword arguments
    cmake_parse_arguments(ARG "RTL;CDEFINES;MARKDOWN" "OUTDIR;FILE_SET" "PARAMETERS;ARGS" ${ARGN})
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

    # Used to overwrite the top level parameters
    set(OVERWRITTEN_PARAMETERS "")
    if(ARG_PARAMETERS)
        foreach(PARAM ${ARG_PARAMETERS})
            set(OVERWRITTEN_PARAMETERS "${OVERWRITTEN_PARAMETERS}" "-p ${PARAM}")
        endforeach()
    endif()

    get_ip_sources(SOURCES ${IP_LIB} OPENTITAN_HJSON NO_DEPS)

    if(NOT SOURCES)
        message(FATAL_ERROR "Library ${IP_LIB} does not have OPENTITAN_HJSON property set,
                unable to run ${CMAKE_CURRENT_FUNCTION}")
    endif()

    find_python3()

    find_program(REGTOOL_EXECUTABLE regtool.py REQUIRED
        HINTS ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../hw/vendor/pulp_platform_register_interface/vendor/lowrisc_opentitan/util/ )
    set(cmd ${Python3_EXECUTABLE} ${REGTOOL_EXECUTABLE}
            ${ARG_ARGS}
            ${OVERWRITTEN_PARAMETERS}
        )

    unset(gen_files)

    ##########################
    ######## SV_GEN ##########
    ##########################

    if(ARG_RTL)
        set(SV_GEN
            ${ARG_OUTDIR}/${MODULE_NAME}_reg_pkg.sv
            ${ARG_OUTDIR}/${MODULE_NAME}_reg_top.sv
            )
        ip_sources(${IP_LIB} SYSTEMVERILOG ${ARG_FILE_SET} PREPEND ${SV_GEN})
        list(APPEND gen_files ${SV_GEN})
        list(APPEND cmd 
            --outdir ${ARG_OUTDIR}
            -r)
        set(target_suffix rtl)
    endif()

    ##########################
    ######## CDEFINES ########
    ##########################

    if(ARG_CDEFINES)
        set(C_GEN
            ${ARG_OUTDIR}/${MODULE_NAME}_regs.h
            )
        target_sources(${IP_LIB} INTERFACE ${C_GEN})
        list(APPEND gen_files ${C_GEN})
        list(APPEND cmd 
            -o ${C_GEN}
            --cdefines)
        set(target_suffix cheader)
        # ip_sources(${IP_LIB} C ${C_GEN})
    endif()

    ##########################
    ######## MARKDOWN ########
    ##########################

    if(ARG_MARKDOWN)
        set(MARKDOWN_GEN
            ${ARG_OUTDIR}/${MODULE_NAME}_regs.md
            )
        ip_sources(${IP_LIB} MARKDOWN ${MARKDOWN_GEN})
        list(APPEND gen_files ${MARKDOWN_GEN})
        list(APPEND cmd 
            -o ${MARKDOWN_GEN}
            -d)
        set(target_suffix markdown)
    endif()


    list(APPEND cmd ${SOURCES})
    set(target_name ${IP_LIB}_regtool_${target_suffix})

    set(STAMP_FILE "${ARG_OUTDIR}/.regtool_${target_suffix}.stamp")
    list(APPEND gen_files "${STAMP_FILE}")
    set(DESCRIPTION "${Green}Run regtool on '${IP_LIB}'${ColourReset}")
    add_custom_command(
        OUTPUT ${gen_files}
        COMMAND ${cmd}
        COMMAND touch ${STAMP_FILE}
        DEPENDS ${SOURCES}
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

