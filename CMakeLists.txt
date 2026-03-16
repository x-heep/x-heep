cmake_minimum_required(VERSION 3.27)

# Add SoCMake
include("./cmake/deps.cmake")

# Don't warn on languages added by Fusesoc and custom XHeep languages
socmake_add_languages(OPENTITAN_HJSON OPENTITAN_HJSON_TEMPLATE OPENTITAN_SVH_TEMPLATE OPENTITAN_LINKER_TEMPLATE LINKER MAKEFILE OPENTITAN_SV_TEMPLATE VLT WAIVER TCL VERIBLELINTRULES XHEEP_CACHE MARKDOWN USER CPP C ASM SDC CONFIGFILE VERIBLELINTWAIVER OPENTITAN_C_HEADER_TEMPLATE OPENTITAN_ASM_TEMPLATE)

############################################
##### X-HEEP configuration options #########
############################################

option_enum(XHEEP_CPU "Select CPU" "cv32e20;cv32e40p;cv32e40x;cv32e40px" "cv32e20")
option_enum(XHEEP_BUS "Select BUS architecture" "onetoM;NtoM" "onetoM")
option_integer(XHEEP_MEMORY_BANKS "Select number of memory banks [2(default) - (16-MEMORY_BANKS_IL)]" "2")
option_enum(XHEEP_MEMORY_BANKS_IL "Select number of interleaved memory banks" "0;2;4;8" "0")
option_file(XHEEP_CFG "Path to X-Heep configuration file" "${CMAKE_CURRENT_LIST_DIR}/configs/general.hjson" CHECK_EXISTS)

############################################
##### X-HEEP App firmware options ##########
############################################

option_string(FW_PROJECT "Firmware project to be built" "hello_world")
option_enum(FW_TARGET    "Build firmware project for target" "sim;systemc;pynq-z2;nexys-a7-100t;zcu104" "sim")
option_enum(FW_LINKER    "Which linker script to use" "on_chip;flash_load;flash_exec" "on_chip")
option_enum(FW_COMPILER  "Compiler to use for building firmware" "gcc;clang" "gcc")
option_string(FW_COMPILER_PREFIX "Prefix of the cross-compiler binaries" "riscv32-unknown-")
option_string(FW_ARCH    "Risc-V ISA to build firmware for" "rv32imc")


############################################
##### X-HEEP Simulation options ############
############################################

option_enum(SIM "Which simulator to use" "verilator_cpp;verilator_sv;questasim;modelsim;xcelium;vcs" "verilator_sv")
option_boolean(SIM_TRACE "Generate simulation waveforms" OFF)
option_file(SIM_UART_LOG_FILE "Write log file to a file (for \"-\" write to STDOUT)" "-")

# Assert configuration options ranges
math(EXPR memory_banks_upper_range "16-${XHEEP_MEMORY_BANKS_IL}")
if(${XHEEP_MEMORY_BANKS} LESS 2 OR ${XHEEP_MEMORY_BANKS} GREATER ${memory_banks_upper_range})
    message(FATAL_ERROR "Not supported number of memory banks ${XHEEP_MEMORY_BANKS}, must be in range [2 : ${memory_banks_upper_range}]")
endif()

if(SIM MATCHES "questasim|modelsim")
    modelsim_configure_cxx(LIBRARIES DPI-C)
elseif(SIM MATCHES verilator)
    verilator_configure_cxx(LIBRARIES DPI-C)
elseif(SIM MATCHES xcelium)
    xcelium_configure_cxx(LIBRARIES DPI-C)
elseif(SIM MATCHES vcs)
    vcs_configure_cxx(LIBRARIES DPI-C)
endif()

project(xheep)

# Include X-Heep tools CMake support functions
include("./cmake/regtool.cmake")
include("./cmake/mcu_gen_cfg_flags.cmake")
include("./cmake/mcu_gen_template.cmake")
include("./cmake/primgen.cmake")
include("./cmake/xheep_add_top_target.cmake")
include("./cmake/add_sw.cmake")

# This is the flag generation to follow the X-Heep config.
# It creates a list of flags that will be later given to any call to mcu_gen_template()
mcu_gen_cfg_flags(MCU_GEN_FLAGS
    X_HEEP_CFG ${XHEEP_CFG}
    PADS_CFG ./configs/pad_cfg.py
    CPU ${XHEEP_CPU}
    MEMORY_BANKS ${XHEEP_MEMORY_BANKS}
    MEMORY_BANKS_IL ${XHEEP_MEMORY_BANKS_IL}
    BUS ${XHEEP_BUS}
)

add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/lint/common.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim_subreg.core")
add_ip_from_fusesoc("./hw/vendor/pulp_platform_register_interface.core")
add_ip_from_fusesoc("./hw/vendor/pulp_platform_tech_cells_generic.core")
add_ip_from_fusesoc("./hw/vendor/pulp_platform_common_cells/common_cells.core")
add_ip_from_fusesoc("./hw/vendor/pulp_platform_axi/axi.core")
add_ip_from_fusesoc("./hw/vendor/openhwgroup_axi_slice.core")
add_ip_from_fusesoc("./hw/vendor/pulp_platform_serial_link.core")


add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim_assert.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim_util.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim_diff_decode.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/primgen.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim_pkg.core")

add_subdirectory("./hw/vendor/lowrisc_opentitan/hw/ip/prim_generic")

add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim_arbiter.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim_fifo.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim_alert.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim_cipher_pkg.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim_cipher.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/prim/prim.core")

## SPI HOST
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/top_earlgrey/top_pkg.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/spi_device/spi_device_pkg.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/lint/comportable.core")
add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan_spi_host/spi_host.core")


add_subdirectory("./hw/core-v-mini-mcu/")

add_subdirectory("./hw/ip/")


# CPUs
add_ip_from_fusesoc("./hw/vendor/pulp_platform_fpnew.core")
add_ip_from_fusesoc("./hw/vendor/openhwgroup_cv32e40p.core")
add_ip_from_fusesoc("./hw/vendor/openhwgroup_cv32e40x.core")
add_subdirectory("./hw/vendor/openhwgroup_cv32e20/")
add_ip_from_fusesoc("./hw/vendor/esl_epfl_cv32e40px.core")

add_ip_from_fusesoc("./hw/vendor/pulp_platform_gpio.core")
add_subdirectory("./hw/vendor/pulp_platform_riscv_dbg/")

add_subdirectory("./hw/vendor/lowrisc_opentitan/hw/ip/tlul/")

add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/uart/uart.core")
add_subdirectory("./hw/vendor/lowrisc_opentitan/hw/ip/rv_plic/")

add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/rv_timer/rv_timer.core")

add_ip_from_fusesoc("./hw/vendor/lowrisc_opentitan/hw/ip/i2c/i2c.core")
add_ip_from_fusesoc("./hw/ip/boot_rom/boot_rom.core")
add_ip_from_fusesoc("./hw/vendor/pulp_platform_obi_spi_slave/obi_spi_slave.core")
add_subdirectory("./hw/system/pad_control")

add_subdirectory("./sw/linker/")


add_ip_from_fusesoc("./hw/vendor/waiver/verilator_waiver.core")
add_ip_from_fusesoc("./core-v-mini-mcu.core")
ip_sources(${IP} OPENTITAN_SV_TEMPLATE
    ./hw/core-v-mini-mcu/system_bus.sv.tpl
    ./hw/core-v-mini-mcu/system_xbar.sv.tpl
    ./hw/core-v-mini-mcu/memory_subsystem.sv.tpl
    ./hw/core-v-mini-mcu/peripheral_subsystem.sv.tpl
    ./hw/core-v-mini-mcu/cpu_subsystem.sv.tpl
    ./hw/system/x_heep_system.sv.tpl
    ./hw/system/pad_ring.sv.tpl
)

ip_sources(${IP} OPENTITAN_C_HEADER_TEMPLATE
    ./sw/device/lib/runtime/core_v_mini_mcu.h.tpl
    ./sw/device/lib/runtime/core_v_mini_mcu_memory.h.tpl
)

ip_sources(${IP} OPENTITAN_ASM_TEMPLATE
    ./sw/device/lib/crt/crt0.S.tpl
)

ip_link(${IP}
        xheep_linker
        )

ip_link(pulp-platform.org::tech_cells_generic
    openhwgroup.org::ip::verilator_waiver
)

# Call to mcu-gen
mcu_gen_template(${IP} FILE_SET files_rtl MCU_GEN_FLAGS ${MCU_GEN_FLAGS})

xheep_add_top_target(mcu_gen ${IP})
## SW tests:

# In case the X-Heep was not reused by another project include testbench
if(PROJECT_IS_TOP_LEVEL)
    add_subdirectory("./tb/")
endif() 

help()
