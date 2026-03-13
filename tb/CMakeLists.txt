add_subdirectory("../hw/ip_examples/" "ip_examples")

add_ip_from_fusesoc("../hw/vendor/pulp_platform_pulpissimo_simjtag.core")
add_ip_from_fusesoc("../hw/vendor/pulp_platform_quadrilatero.core")
add_subdirectory("../hw/vendor/lowrisc_opentitan/hw/dv/dpi/uartdpi/" "uartdpi")
add_subdirectory("../hw/vendor/pulp_platform_pulpissimo/rtl/tb/" "remote_bitbang")

add_ip_from_fusesoc("./x-heep-tb-utils.core")


ip_link(${IP}
    ${XHEEP_CFG_IP}
)
ip_sources(${IP} OPENTITAN_SVH_TEMPLATE
    ./tb_util.svh.tpl
)
mcu_gen_template(${IP} FILE_SET files_rtl)

#### Testbench
add_ip(tb_top)

ip_sources(${IP} SYSTEMVERILOG FILE_SET tb-sv
    ./tb_top.sv
)

ip_link(${IP}
    x-heep::tb-utils
    openhwgroup.org::systems::core-v-mini-mcu
    )

#####################################################
#### Compile testbench
#####################################################
set(FILE_SETS rtl_sim files_rtl rtl deprecated sim_jtag files_fpu_div remote_bitbang tb-harness systemverilog_only_uart files_clk_gate ff_regfile files_fcov clock-gate rtl-pkg rtl-tap files_rtl_generic rtl-simulation x_heep_system tb-sv files_lint_verilator files_verilator_waiver files_verilator)

get_ip_property(file_sets ${IP} FILE_SETS)
list(REMOVE_DUPLICATES file_sets)

# Handle the tracing for different simulators
if(SIM_TRACE)
    list(APPEND sim_run_args +vcd)
    if(SIM MATCHES verilator)
        set(verilator_trace_args TRACE_FST)
    elseif(SIM MATCHES questasim)
        set(questasim_trace_args -voptargs=+acc=npr)
    endif()
endif()

if(SIM MATCHES verilator_sv)

    verilator(${IP} MAIN TIMING ${verilator_trace_args}
        VERILATOR_ARGS -Wno-fatal
        NO_RUN_TARGET
        FILE_SETS ${FILE_SETS}
        )

# Verilator simulation the tb_top.cpp
elseif(SIM MATCHES verilator_cpp)
    verilator(${IP} TIMING TRACE_FST # ${verilator_trace_args} it cant be disabled in tb_top.cpp for now
        TOP_MODULE testharness
        VERILATOR_ARGS -Wno-fatal
        NO_RUN_TARGET
        FILE_SETS ${FILE_SETS}
        )
    add_executable(tb-verilator
        ./tb_top.cpp
        ./XHEEP_CmdLineOptions.cpp
        )
    target_include_directories(tb-verilator PUBLIC ${CMAKE_CURRENT_LIST_DIR})
    target_link_libraries(tb-verilator PUBLIC ${IP}__vlt)

    set(SIM_RUN_CMD $<TARGET_FILE:tb-verilator>)

# Questasim or modelsim simulation
elseif(SIM MATCHES "questasim|modelsim")
    modelsim(${IP} LIBRARY work QUIET
        SV_COMPILE_ARGS -suppress GroupWarning -define MODELSIM
        NO_RUN_TARGET
        FILE_SETS ${FILE_SETS}
    )

elseif(SIM MATCHES "xcelium")
    xcelium(${IP} LIBRARY work
        SV_COMPILE_ARGS -define XCELIUM
        ELABORATE_ARGS -vtimescale 1ns/10ps
        RUN_ARGS -vtimescale 1ns/10ps
        FILE_SETS ${FILE_SETS}
        NO_RUN_TARGET
    )
elseif(SIM MATCHES "vcs")
    vcs(${IP} LIBRARY work
        SV_COMPILE_ARGS -assert svaext -assert disable_cover -debug_access+all+dmptf -ntb_opts error
        # ELABORATE_ARGS -fgp -kdb -ntb_opts error -race=all -xlrm uniq_prior_final
        ELABORATE_ARGS -xlrm uniq_prior_final -debug_access+all+dmptf
        FILE_SETS ${FILE_SETS}
        NO_RUN_TARGET
    )
endif()

#####################################################
#### Add software tests
#####################################################
add_sw_tests(tests "${CMAKE_CURRENT_LIST_DIR}/../sw")
set_property(GLOBAL PROPERTY CTEST_TARGETS_ADDED 1) # Remove additional targets
include(CTest)
enable_testing()

#####################################################
#### Setup simulator arguments based on options
#####################################################
foreach(test ${tests})
    get_property(hex_file TARGET ${test} PROPERTY HEX_FILE)
    set(sim_run_args
            +firmware=${hex_file}
            +UARTDPI_LOG_uart0=${SIM_UART_LOG_FILE}
        )

    add_custom_target(run_${test}
        COMMAND ${SOCMAKE_SIM_RUN_CMD} ${sim_run_args}
        COMMENT "Running test ${test} with ${SIM}"
        DEPENDS ${test} ${SOCMAKE_COMPILE_TARGET} ${SOCMAKE_ELABORATE_TARGET} x-heep__tb-utils_mcu_gen_template
        USES_TERMINAL
    )
    add_test(NAME run_${test}
             COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target run_${test}
        )

endforeach()
