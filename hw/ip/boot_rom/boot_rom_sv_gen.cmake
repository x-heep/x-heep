# Function to generate the boot_rom.sv file
function(boot_rom_sv_gen)
    if(NOT DEFINED RISCV_XHEEP OR NOT DEFINED COMPILER_PREFIX)
        message(FATAL_ERROR "[BootRomGen] RISCV_XHEEP and COMPILER_PREFIX must be defined.")
    endif()
 
    set(GCC     ${RISCV_XHEEP}/bin/${COMPILER_PREFIX}elf-gcc)
    set(OBJCOPY ${RISCV_XHEEP}/bin/${COMPILER_PREFIX}elf-objcopy)
    set(OBJDUMP ${RISCV_XHEEP}/bin/${COMPILER_PREFIX}elf-objdump)
 
    find_python3()
 
    set(SRC     "${CMAKE_CURRENT_SOURCE_DIR}/boot_rom.S")
    set(LD      "${CMAKE_CURRENT_SOURCE_DIR}/link.ld")
    set(GENROM  "${CMAKE_CURRENT_SOURCE_DIR}/gen_rom.py")
 
    # Include directories
    file(GLOB _driver_incs LIST_DIRECTORIES true
         "${CMAKE_CURRENT_SOURCE_DIR}/../../../sw/device/lib/drivers/*/")
    file(GLOB _base_incs LIST_DIRECTORIES true
         "${CMAKE_CURRENT_SOURCE_DIR}/../../../sw/device/lib/base/*/")
    set(_runtime_inc "${CMAKE_CURRENT_SOURCE_DIR}/../../../sw/device/lib/runtime")
 
    set(INC_FLAGS "")
    foreach(_dir ${_driver_incs} ${_base_incs} ${_runtime_inc})
        if(IS_DIRECTORY "${_dir}")
            list(APPEND INC_FLAGS "-I${_dir}")
        endif()
    endforeach()
 
    set(ELF  "${CMAKE_CURRENT_SOURCE_DIR}/boot_rom.elf")
    set(BIN  "${CMAKE_CURRENT_SOURCE_DIR}/boot_rom.bin")
    set(IMG  "${CMAKE_CURRENT_SOURCE_DIR}/boot_rom.img")
    set(SV   "${CMAKE_CURRENT_SOURCE_DIR}/boot_rom.sv")
    set(DUMP "${CMAKE_CURRENT_SOURCE_DIR}/boot_rom.dump")


    # Step 1: .S -> .elf
    add_custom_command(
        OUTPUT  "${ELF}"
        COMMAND ${GCC} ${INC_FLAGS} -T "${LD}" "${SRC}"
                -nostdlib -fPIC -static -Wl,--no-gc-sections
                -o "${ELF}"
        DEPENDS "${SRC}" "${LD}"
        COMMENT "[BootRomGen] boot_rom.S -> boot_rom.elf"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        VERBATIM
    )
 

    # Step 2: .elf -> .bin
    # SET A WORKING DIR into CMAKE_CURRENT_SOURCE_DIR
    add_custom_command(
        OUTPUT  "${BIN}"
        COMMAND ${OBJCOPY} -O binary "${ELF}" "${BIN}"
        DEPENDS "${ELF}"
        COMMENT "[BootRomGen] boot_rom.elf -> boot_rom.bin"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        VERBATIM
    )
 

    # Step 3: .bin -> .img
    add_custom_command(
        OUTPUT  "${IMG}"
        COMMAND dd if=${BIN} of=${IMG} bs=1024 count=1
        DEPENDS "${BIN}"
        COMMENT "[BootRomGen] boot_rom.bin -> boot_rom.img"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        VERBATIM
    )
 

    # Step 4: .img -> .sv
    add_custom_command(
        OUTPUT  "${SV}"
        COMMAND ${Python3_EXECUTABLE} "${GENROM}" "${IMG}"
        DEPENDS "${IMG}" "${GENROM}"
        COMMENT "[BootRomGen] boot_rom.img -> boot_rom.sv"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        VERBATIM
    )
 

    # Step 5: .elf -> .dump (mirrors the Makefile)
    add_custom_command(
        OUTPUT  "${DUMP}"
        COMMAND ${OBJDUMP} -d "${ELF}"
                --disassemble-all --disassemble-zeroes
                --section=.text --section=.text.startup
                --section=.text.init --section=.data
                > "${DUMP}"
        DEPENDS "${ELF}"
        COMMENT "[BootRomGen] boot_rom.elf -> boot_rom.dump"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        VERBATIM
    )
 

    # Top target
    add_custom_target(x-heep__ip__boot_rom__sv_gen ALL
        DEPENDS "${SV}" "${DUMP}"
    )
 
endfunction()