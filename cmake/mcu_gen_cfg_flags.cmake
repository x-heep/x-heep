function(mcu_gen_cfg_flags MCU_GEN_FLAGS)
    # Parse keyword arguments
    cmake_parse_arguments(ARG "" "X_HEEP_CFG;X_HEEP_PY_CFG;PADS_CFG;CPU;BUS;MEMORY_BANKS;MEMORY_BANKS_IL;EXTERNAL_DOMAINS" "" ${ARGN})
    # Check for any unknown argument
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} passed unrecognized argument "
                "${ARG_UNPARSED_ARGUMENTS}")
    endif()

    if(ARG_X_HEEP_CFG)
        convert_paths_to_absolute(ARG_X_HEEP_CFG ${ARG_X_HEEP_CFG})
        list(APPEND mcu_gen_flags --config ${ARG_X_HEEP_CFG})
    else()
        message(FATAL "Missing mandatory --config flag for mcu_gen, for X-HEEP general HJSON configuration")
    endif()

    if(ARG_X_HEEP_PY_CFG)
        convert_paths_to_absolute(ARG_X_HEEP_PY_CFG ${ARG_X_HEEP_PY_CFG})
        list(APPEND mcu_gen_flags --python_config ${ARG_X_HEEP_PY_CFG})
    endif()

    if(ARG_PADS_CFG)
        convert_paths_to_absolute(ARG_PADS_CFG ${ARG_PADS_CFG})
        list(APPEND mcu_gen_flags --pads_cfg ${ARG_PADS_CFG})
    else()
        message(FATAL "Missing mandatory --pads_cfg flag for mcu_gen, for Pads HJSON configuration")
    endif()

    if(ARG_CPU)
        list(APPEND mcu_gen_flags --cpu ${ARG_CPU})
    endif()

    if(ARG_BUS)
        list(APPEND mcu_gen_flags --bus ${ARG_BUS})
    endif()

    if(ARG_MEMORY_BANKS)
        list(APPEND mcu_gen_flags --memorybanks ${ARG_MEMORY_BANKS})
    endif()

    if(ARG_MEMORY_BANKS_IL)
        list(APPEND mcu_gen_flags --memorybanks_il ${ARG_MEMORY_BANKS_IL})
    endif()

    if(ARG_EXTERNAL_DOMAINS)
        list(APPEND mcu_gen_flags --external_domains ${ARG_EXTERNAL_DOMAINS})
    endif()

    set(${MCU_GEN_FLAGS} ${mcu_gen_flags} PARENT_SCOPE)

endfunction()
