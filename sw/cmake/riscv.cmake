# Copyright 2022 Jose Miranda
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

# Author: Jose Miranda (jose.mirandacalero@epfl.ch)

# set(RISCV_XHEEP  /home/$ENV{USER}/tools/riscv)
set(RISCV_GITHUB_GCC_COMPILER  $ENV{RISCV_XHEEP}/bin/$ENV{COMPILER_PREFIX}elf-gcc)
set(RISCV_GITHUB_CLANG_COMPILER  $ENV{RISCV_XHEEP}/bin/clang)
#message("RISC-V GCC cross-compiler is in : ${RISCV_GCC_COMPILER}") 

if (EXISTS ${RISCV_GITHUB_GCC_COMPILER})
     set( RISCV_GCC_COMPILER ${RISCV_GITHUB_GCC_COMPILER})
else()
     message(FATAL_ERROR "RISC-V GCC not found. ${RISCV_GITHUB_GCC_COMPILER}") 
endif()

if ($ENV{COMPILER} MATCHES "clang")
     if (EXISTS ${RISCV_GITHUB_CLANG_COMPILER})
          set( RISCV_CLANG_COMPILER ${RISCV_GITHUB_CLANG_COMPILER})
     else()
          message(FATAL_ERROR "RISC-V clang not found. ${RISCV_GITHUB_CLANG_COMPILER}") 
     endif()
elseif (NOT $ENV{COMPILER} MATCHES "gcc")
     message(FATAL_ERROR "Compiler not supported. $ENV{COMPILER}") 
endif()

#message( "RISC-V GCC found: ${RISCV_GCC_COMPILER}")

get_filename_component(RISCV_TOOLCHAIN_BIN_PATH ${RISCV_GCC_COMPILER} DIRECTORY)
get_filename_component(RISCV_TOOLCHAIN_BIN_GCC ${RISCV_GCC_COMPILER} NAME_WE)
get_filename_component(RISCV_TOOLCHAIN_BIN_EXT ${RISCV_GCC_COMPILER} EXT)

#message( "RISC-V GCC Path: ${RISCV_TOOLCHAIN_BIN_PATH}" )

STRING(REGEX REPLACE "\-gcc$" "-" GCC_CROSS_COMPILE ${RISCV_GCC_COMPILER})
if ($ENV{COMPILER} MATCHES "clang")
     STRING(REGEX REPLACE "clang$" "" CLANG_CROSS_COMPILE ${RISCV_CLANG_COMPILER})
endif()
#message( "RISC-V Cross Compile: ${CROSS_COMPILE}" )

# The Generic system name is used for embedded targets (targets without OS) in
# CMake
set( CMAKE_SYSTEM_NAME          Generic )
set( CMAKE_SYSTEM_PROCESSOR     $ENV{ARCH} 
     CACHE STRING "Generate code for given RISC-V ISA string")
set( CMAKE_EXECUTABLE_SUFFIX    ".elf")

# specify the cross compiler. We force the compiler so that CMake doesn't
# attempt to build a simple test program as this will fail without us using
# the -nostartfiles option on the command line
#CMAKE_FORCE_C_COMPILER( "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILE}gcc${RISCV_TOOLCHAIN_BIN_EXT}" GNU )
#CMAKE_FORCE_CXX_COMPILER( "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILE}g++${RISCV_TOOLCHAIN_BIN_EXT}" GNU )
if ($ENV{COMPILER} MATCHES "gcc")
     set(CMAKE_ASM_COMPILER ${GCC_CROSS_COMPILE}gcc)
     set(CMAKE_AR ${GCC_CROSS_COMPILE}ar)
     set(CMAKE_ASM_COMPILER ${GCC_CROSS_COMPILE}gcc)
     set(CMAKE_C_COMPILER ${GCC_CROSS_COMPILE}gcc)
     set(CMAKE_CXX_COMPILER ${GCC_CROSS_COMPILE}g++)
elseif ($ENV{COMPILER} MATCHES "clang")
     set(CMAKE_ASM_COMPILER ${CLANG_CROSS_COMPILE}clang)
     set(CMAKE_AR ${CLANG_CROSS_COMPILE}llvm-ar)
     set(CMAKE_ASM_COMPILER ${CLANG_CROSS_COMPILE}clang)
     set(CMAKE_C_COMPILER ${CLANG_CROSS_COMPILE}clang)
     set(CMAKE_CXX_COMPILER ${CLANG_CROSS_COMPILE}clang++)
endif()

# We must set the OBJCOPY setting into cache so that it's available to the
# whole project. Otherwise, this does not get set into the CACHE and therefore
# the build doesn't know what the OBJCOPY filepath is
# Even if we compile with clang, this must be GCC's objcopy since we always link with GCC
set( CMAKE_OBJCOPY      ${GCC_CROSS_COMPILE}objcopy
     CACHE FILEPATH "The toolchain objcopy command " FORCE )
#message( "OBJCOPY PATH: ${CMAKE_OBJCOPY}" )

if ($ENV{COMPILER} MATCHES "gcc")
     set( CMAKE_OBJDUMP      ${GCC_CROSS_COMPILE}objdump
          CACHE FILEPATH "The toolchain objdump command " FORCE )
elseif ($ENV{COMPILER} MATCHES "clang")
     set( CMAKE_OBJDUMP      ${CLANG_CROSS_COMPILE}llvm-objdump
          CACHE FILEPATH "The toolchain objdump command " FORCE )
endif()
#message( "OBJDUMP PATH: ${CMAKE_OBJDUMP}" )

# Dealing with GDB into CMake - TBD
#set( CMAKE_C_GDB        ${CROSS_COMPILE}gdb 
#     CACHE FILEPATH "The gdb toolchain command " FORCE )

# Set the common build flags

# Set the CMAKE C flags (which should also be used by the assembler!
# specify the C standard
set( CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g" )
set( CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=${CMAKE_SYSTEM_PROCESSOR} ${COMPILER_FLAGS}" )
if ($ENV{COMPILER} MATCHES "clang")
     set( CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-unused-command-line-argument --target=riscv32 --gcc-toolchain=$ENV{RISCV_XHEEP} --sysroot=$ENV{RISCV_XHEEP}/$ENV{COMPILER_PREFIX}elf" )
endif()

set( CMAKE_C_FLAGS "${CMAKE_C_FLAGS}" CACHE STRING "" )
set( CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS}" CACHE STRING "" )
set( CMAKE_ASM_FLAGS "${CMAKE_C_FLAGS}" CACHE STRING "" )

set( CMAKE_LINKER ${RISCV_GCC_COMPILER})  # We always link with GCC

# Set by deafult Linker flags if needed
#set( CMAKE_EXE_LINKER_FLAGS   "${CMAKE_EXE_LINKER_FLAGS}  -march=${CMAKE_SYSTEM_PROCESSOR}    -nostartfiles   " )
