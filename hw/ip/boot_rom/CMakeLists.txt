# Might be a local work around
if(NOT DEFINED RISCV_XHEEP)
    if(DEFINED ENV{RISCV_XHEEP})
        set(RISCV_XHEEP $ENV{RISCV_XHEEP})
    else()
        set(RISCV_XHEEP "~/tools/riscv")
    endif()
endif()

if(NOT DEFINED COMPILER_PREFIX)
    if(DEFINED ENV{COMPILER_PREFIX})
        set(COMPILER_PREFIX $ENV{COMPILER_PREFIX})
    else()
        set(COMPILER_PREFIX "riscv32-unknown-")
    endif()
endif()

include("./boot_rom_sv_gen.cmake")


boot_rom_sv_gen()

add_ip_from_fusesoc("./boot_rom.core")
