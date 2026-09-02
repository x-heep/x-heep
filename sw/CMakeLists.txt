# Copyright 2022 Jose Miranda
# Copyright 2023 Juan Sapriza
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

# Author: Jose Miranda, Juan Sapriza (jose.mirandacalero / juan.sapriza @epfl.ch)

cmake_minimum_required(VERSION 3.15)

# Include to fetch any vendorised repo (e.g. FreeRTOS)
include(FetchContent)

# Add some colors!
if(NOT WIN32)
  string(ASCII 27 Esc)
  set(ColourReset "${Esc}[m")
  set(ColourBold  "${Esc}[1m")
  set(Red         "${Esc}[31m")
  set(Green       "${Esc}[32m")
  set(Yellow      "${Esc}[33m")
  set(Blue        "${Esc}[34m")
  set(Magenta     "${Esc}[35m")
  set(Cyan        "${Esc}[36m")
  set(White       "${Esc}[37m")
  set(BoldRed     "${Esc}[1;31m")
  set(BoldGreen   "${Esc}[1;32m")
  set(BoldYellow  "${Esc}[1;33m")
  set(BoldBlue    "${Esc}[1;34m")
  set(BoldMagenta "${Esc}[1;35m")
  set(BoldCyan    "${Esc}[1;36m")
  set(BoldWhite   "${Esc}[1;37m")
endif()

# set the project name
project(${PROJECT} ASM C CXX)

# environment check
if(DEFINED ENV{RISCV_XHEEP})
  set(RISCV_XHEEP "$ENV{RISCV_XHEEP}")
else()
  message(WARNING "RISCV_XHEEP not set in the environment. Using the one passed from Makefile: ${RISCV_XHEEP}")
endif()

# set the required CMake standard
set(CMAKE_CXX_STANDARD 14)

# Set MAIN file
SET(MAINFILE "main")


#######################################################################
#      FIND HEADER FILES TO BE INCLUDED
#######################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Preliminary list of header files inside the source path

# Make a list of the header files that need to be included
FILE(GLOB_RECURSE new_list FOLLOW_SYMLINKS ${SOURCE_PATH}*.h)
SET(dir_list_str "")
FOREACH(file_path ${new_list})
  SET(add 0) # This variable is set to 1 if the file_pth needs to be added to the list
  if(${file_path} MATCHES "${SOURCE_PATH}device/")
    if(${file_path} MATCHES "${SOURCE_PATH}device/target/") # Add it if its not in target, or if its in target/${TARGET}
      if(${file_path} MATCHES "${SOURCE_PATH}device/target/${TARGET}")
        SET(add 1)
      endif()
    else()
      SET(add 1)
    endif()
  elseif(${file_path} MATCHES ${SOURCE_PATH}applications/${PROJECT}/)
    SET(add 1)
  elseif( ( ${file_path} MATCHES "${SOURCE_PATH}freertos/" ) AND ( ${PROJECT} MATCHES "freertos" ) )
    SET(add 1)
  elseif( ${file_path} MATCHES "${SOURCE_PATH}external/" )
    SET(add 1)
  endif()

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Prune list

  if( add EQUAL 1 ) # If the file path matched one of the criterion, add it to the list
    # Get the path of the obtained directory
    GET_FILENAME_COMPONENT(dir_path ${file_path} PATH)

    # Add it to the string format list
    SET(dir_list_str ${dir_list_str} "-I ${dir_path} \
    ")
    
    # Add it to the header list
    SET(h_dir_list_ ${h_dir_list_} "${dir_path}")
  endif()

ENDFOREACH()

LIST(REMOVE_DUPLICATES dir_list_str) 
string(REPLACE ";" "" dir_list_str ${dir_list_str}) #This has been moved here to avoid multiple includes of the same path, see: https://github.com/x-heep/x-heep/issues/470
LIST(REMOVE_DUPLICATES h_dir_list_)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Add list to the directories to be included

# Get all the folders to include when linking
SET(INCLUDE_FOLDERS "-I ${RISCV_XHEEP}/${COMPILER_PREFIX}elf/include \
                     -I ${RISCV_XHEEP}/${COMPILER_PREFIX}elf/include/ \
                     -I ${ROOT_PROJECT} \
                     -I ${SOURCE_PATH} \
					           ${dir_list_str}")                                      

#######################################################################
#      FIND SOURCE FILES TO BE INCLUDED
#######################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Preliminary list of source files inside the source path

# Make a list of the .c source files that need to be linked
FILE(GLOB_RECURSE c_files FOLLOW_SYMLINKS ${SOURCE_PATH}*.c)
# Make a list of the .s source files that need to be linked
FILE(GLOB_RECURSE s_files FOLLOW_SYMLINKS ${SOURCE_PATH}*.s)
# Make a list of the .S source files that need to be linked
FILE(GLOB_RECURSE S_files FOLLOW_SYMLINKS ${SOURCE_PATH}*.S)
# Make a list of the .cpp source files that need to be linked
FILE(GLOB_RECURSE cpp_files FOLLOW_SYMLINKS ${SOURCE_PATH}*.cpp)
SET(new_list ${c_files} ${s_files} ${S_files} ${cpp_files})

SET( c_dir_list "" )
SET( app_found 0 )
FOREACH(file_path IN LISTS new_list)
  SET(add 0) # This variable is set to 1 if the file_pth needs to be added to the list
  if(${file_path} MATCHES "${SOURCE_PATH}device/")
    if(NOT ${file_path} MATCHES  ".*/crt/.*") 
      SET(add 1)
    endif()
  elseif( (${file_path} MATCHES "${SOURCE_PATH}external/") AND ( NOT  ${file_path} MATCHES "exclude" ) )
    SET(add 1)
  elseif( ${file_path} MATCHES "${SOURCE_PATH}applications/${PROJECT}/${MAINFILE}\\." ) # look for main.*
    SET(app_found 1)
  elseif( ${file_path} MATCHES "${SOURCE_PATH}applications/${PROJECT}/" ) # other sources
    SET(add 1)
  endif()

  if( add EQUAL 1 ) # If the file path matched one of the criteria, add it to the list
    list(APPEND c_dir_list "${file_path}")
  endif()

ENDFOREACH()

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# If the app was not found, look into the root project
# Before re-setting SOURCE_PATH, save it so we can look later for external defined files

SET(ORIGIN_SRCPATH ${SOURCE_PATH})
if( app_found EQUAL 0 )
  SET(SOURCE_PATH ${ROOT_PROJECT})

  # Make a list of the .c source files that need to be linked
  FILE(GLOB_RECURSE c_files FOLLOW_SYMLINKS ${SOURCE_PATH}*.c)
  # Make a list of the .s source files that need to be linked
  FILE(GLOB_RECURSE s_files FOLLOW_SYMLINKS ${SOURCE_PATH}*.s)
  # Make a list of the .S source files that need to be linked
  FILE(GLOB_RECURSE S_files FOLLOW_SYMLINKS ${SOURCE_PATH}*.S)
  # Make a list of the .cpp source files that need to be linked
  FILE(GLOB_RECURSE cpp_files FOLLOW_SYMLINKS ${SOURCE_PATH}*.cpp)
  SET(new_list ${c_files} ${s_files} ${S_files} ${cpp_files})

  SET(c_dir_list "")
  FOREACH(file_path IN LISTS new_list)
    SET(add 0) # This variable is set to 1 if the file_pth needs to be added to the list
    if(${file_path} MATCHES "${ROOT_PROJECT}device/")
      if(NOT ${file_path} MATCHES ".*/crt/.*")
        SET(add 1)
      endif()
    elseif( ( ${file_path} MATCHES "${ROOT_PROJECT}applications/${PROJECT}/" ) AND ( NOT ${file_path} MATCHES "${ROOT_PROJECT}applications/${PROJECT}/${MAINFILE}\\." ) AND ( NOT  ${file_path} MATCHES "exclude" ) )
      SET(add 1)
    endif()

    if( add EQUAL 1 ) # If the file path matched one of the criteria, add it to the list
      list(APPEND c_dir_list "${file_path}")
    endif()

  ENDFOREACH()
endif()

LIST(REMOVE_DUPLICATES c_dir_list)


#######################################################################
#      DETERMINE IF APP IS EXTERNAL
#######################################################################

# Determine whether the target app is located in the root project or in an external folder
if( ${SOURCE_PATH} STREQUAL ${ROOT_PROJECT} )
  SET( internal_app 1 )
  message( "${Magenta}Internal application${ColourReset}")
else()
  SET( internal_app 0 )
  message( "${Magenta}External application${ColourReset}")
endif()

#######################################################################
#      ADD CUSTOM DEFINITIONS
#######################################################################
add_compile_definitions($ENV{CDEFS})

#######################################################################
#      FIND CRT FILES TO BE INCLUDED
#######################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set the default CRT directories

SET(LIB_CRT_P	  "${ROOT_PROJECT}device/lib/crt/crt0.S")
SET(LIB_VCTR_P  "${ROOT_PROJECT}device/lib/crt/vectors.S")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Look for external CRT files

SET(CRTO "INTERNAL_CRTO")
SET( LIB_CRT_EXT_P  "" )
FILE(GLOB_RECURSE new_list FOLLOW_SYMLINKS "${SOURCE_PATH}/external/lib/crt/*.S")
FOREACH(file_path IN LISTS new_list)
  if(${file_path} MATCHES "external_crt0.S")
    SET( CRTO "EXTERNAL_CRTO" )
    SET( LIB_CRT_EXT_P  "${file_path}" )
    GET_FILENAME_COMPONENT(dir_path ${file_path} PATH)
    SET(INCLUDE_FOLDERS "${INCLUDE_FOLDERS} -I ${dir_path}")
    SET(h_dir_list_ ${h_dir_list_} "${dir_path}")
  endif()
ENDFOREACH()

#In case the application is internal, but there is still an external CRT
if(NOT ${ORIGIN_SRCPATH} MATCHES ${SOURCE_PATH})
 FILE(GLOB_RECURSE new_list FOLLOW_SYMLINKS "${ORIGIN_SRCPATH}external/lib/crt/*.S")
 FOREACH(file_path IN LISTS new_list)
   if(${file_path} MATCHES "external_crt0.S")
     SET( CRTO "EXTERNAL_CRTO" )
     SET( LIB_CRT_EXT_P  "${file_path}" )
     GET_FILENAME_COMPONENT(dir_path ${file_path} PATH)
     SET(INCLUDE_FOLDERS "${INCLUDE_FOLDERS} -I ${dir_path}")
     SET(h_dir_list_ ${h_dir_list_} "${dir_path}")
   endif()
 ENDFOREACH()
endif()

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# In case of a freertos based app

if(${PROJECT} MATCHES "freertos")
  #SET(LIB_CRT_P	"${SOURCE_PATH}device/lib/crt_freertos/")
  SET(LIB_VCTR_P	"${SOURCE_PATH}device/lib/crt/vectors_freertos.S")
endif()


#######################################################################
#      SET CRT AND LINKER TYPE
#######################################################################

# Get the correct path for the crt files and linker file
if (${LINKER} STREQUAL "on_chip")
  #SET(LIB_CRT_P "${SOURCE_PATH}device/lib/crt/")
  SET(CRT_TYPE "ON_CHIP")
  SET(LINK_FILE "link.ld")
elseif(${LINKER} STREQUAL "flash_load")
  #SET(LIB_CRT_P "${SOURCE_PATH}device/lib/crt_flash_load/")
  SET(CRT_TYPE "FLASH_LOAD")
  SET(LINK_FILE "link_flash_load.ld")
else()
  message( FATAL_ERROR "Linker specification is not correct" )
endif()

if (${VERBOSE} MATCHES "true")
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Debug messages to check the paths

message(STATUS "[INFO] ${INCLUDE_FOLDERS}")
message( "${Magenta}Current project: ${PROJECT}${ColourReset}")
message( "${Magenta}Root project: ${ROOT_PROJECT}${ColourReset}")
message( "${Magenta}Source path: ${SOURCE_PATH}${ColourReset}")
message( "${Magenta}LIB_CRT PATH for Cmake: ${LIB_CRT_P}${ColourReset}")
message( "${Magenta}LINKER File for Cmake: ${LINK_FILE}${ColourReset}")
message( "${Magenta}LIB_DRIVERS PATH for Cmake: ${LIB_DRIVERS}${ColourReset}")
message( "${Magenta}Targetting folder: ${INC_FOLDERS}${ColourReset}")
message( "${Magenta}Target: ${TARGET}${ColourReset}")

endif()

# List of CRT files
SET(CRT_FILES
    ${LIB_CRT_P}
    ${LIB_VCTR_P}
    ${LIB_CRT_EXT_P}
)

#######################################################################
#      SET LINKER PROPERTIES
#######################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Free-RTOS configurations

# fetch content from freertos kernel repository
FetchContent_Declare( freertos_kernel
  GIT_REPOSITORY https://github.com/FreeRTOS/FreeRTOS-Kernel.git
  GIT_TAG        99d3d54ac4d17474a81c94ec5bab36f55f470359 #V10.5.1, last commit 16/12/2022
)

# set the freertos version
set(freertos_version "V10.5.1")
add_library(freertos_config  INTERFACE)

# set include dirtectories for freertos
target_include_directories(freertos_config SYSTEM INTERFACE ${h_dir_list_})

# set main compilation options for freertos
target_compile_definitions(freertos_config
  INTERFACE
    projCOVERAGE_TEST=0
)
set(FREERTOS_HEAP "4" CACHE STRING "" FORCE)
set(FREERTOS_PORT "GCC_RISC_V" CACHE STRING "" FORCE)

# fetching freertos content
if(${PROJECT} MATCHES "freertos")
  FetchContent_MakeAvailable(freertos_kernel)
endif()

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set CMAKE flags

# specify the C standard
if(NOT ${PROJECT} MATCHES "coremark")
  set(BASE_COMPILER_FLAGS "\
    -march=${CMAKE_SYSTEM_PROCESSOR} \
    -w -O2 -g \
    -nostartfiles \
    -ffunction-sections \
    -DHOST_BUILD \
    -D${CRT_TYPE} \
    -D${CRTO} \
    -DportasmHANDLE_INTERRUPT=vSystemIrqHandler\
    ${COMPILER_FLAGS}\
  ")
else()
  set(BASE_COMPILER_FLAGS "\
    -march=${CMAKE_SYSTEM_PROCESSOR} \
    -w -O3 -g -falign-functions=16 -funroll-all-loops -falign-jumps=4 -finline-functions -Wall -static -pedantic -DPERFORMANCE_RUN=1 -DITERATIONS=1 -DHAS_STDIO=1 -DHAS_PRINTF=1 \
    -nostartfiles \
    -ffunction-sections \
    -DHOST_BUILD \
    -D${CRT_TYPE} \
    -D${CRTO} \
    -DportasmHANDLE_INTERRUPT=vSystemIrqHandler\
  ")
endif()
set(CMAKE_C_FLAGS ${BASE_COMPILER_FLAGS})
set(CMAKE_CXX_FLAGS ${BASE_COMPILER_FLAGS})
set(CMAKE_ASM_FLAGS ${BASE_COMPILER_FLAGS})

message( "${Yellow}Compiler flags: ${BASE_COMPILER_FLAGS}${ColourReset}")

if (${COMPILER} MATCHES "clang")
     set( CLANG_EXTRA_FLAGS "--target=riscv32 \
                             --gcc-toolchain=${RISCV_XHEEP} \
                             --sysroot=${RISCV_XHEEP}/${COMPILER_PREFIX}elf \
                             -static \
                             -mcmodel=medany \
                             -fvisibility=hidden \
                             -Wall \
                             -Wno-unused-command-line-argument")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CLANG_EXTRA_FLAGS}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CLANG_EXTRA_FLAGS}")
  set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} ${CLANG_EXTRA_FLAGS}")
endif()

# In case of wanting to create a library with those subdirectories
#add_subdirectory(device/lib/base)
#add_subdirectory(device/lib/drivers)
#add_subdirectory(device/lib/runtime)

#######################################################################
#      SET TARGETS
#######################################################################
if ((${COMPILER} MATCHES "gcc") OR (${COMPILER} MATCHES "clang"))
  set(SOURCES ${SOURCE_PATH}applications/${PROJECT}/${MAINFILE}.c)
  if(NOT EXISTS ${SOURCES})
    # If main.c does not exist, set the source file to main.cpp
    set(SOURCES ${SOURCE_PATH}applications/${PROJECT}/${MAINFILE}.cpp)
    message("${Red}cpp SOURCES set")
  endif()
elseif(${COMPILER} MATCHES "g\\+\\+.*$")
  set(SOURCES ${SOURCE_PATH}applications/${PROJECT}/${MAINFILE}.cpp)
endif()

# add the executable
add_executable(${MAINFILE}.elf 
  ${SOURCES}
  ${CRT_FILES}
  ${c_dir_list}
)

# add include directories to compilation
target_include_directories(${MAINFILE}.elf PUBLIC ${h_dir_list_})

# linking the libraries
#target_link_libraries(${MAINFILE}.elf base)
#target_link_libraries(${MAINFILE}.elf drivers)
#target_link_libraries(${MAINFILE}.elf runtime)
if(${PROJECT} MATCHES "freertos")
  target_link_libraries(${MAINFILE}.elf freertos_kernel)
endif()

# Setting-up the linker
SET(LINKER_SCRIPT "${LINK_FOLDER}/${LINK_FILE}")
message( "${Magenta}Linker file: ${LINKER_SCRIPT}${ColourReset}")

# Setting-up the properties, elf is
set_target_properties(${MAINFILE}.elf PROPERTIES LINK_DEPENDS "${LINKER_SCRIPT}")

message(STATUS "${Magenta}CLANG_LINKER_USE_LD = '${CLANG_LINKER_USE_LD}'")

# Linker control (support both GCC and Clang)
if (${COMPILER} MATCHES "clang" AND NOT CLANG_LINKER_USE_LD)
  # Linker flags for Clang
  message(STATUS "${Magenta}Using Clang/lld specific linker flags${ColourReset}")
  SET(CMAKE_EXE_LINKER_FLAGS  "-T ${LINKER_SCRIPT}  \
                              -static \
                              -Wl,-Map=${MAINFILE}.map \
                              -Wl,--gc-sections \
                              -Wl,--allow-multiple-definition \
                              -L ${RISCV_XHEEP}/${COMPILER_PREFIX}elf/lib \
                              -lc -lm -lgcc -flto \
                              -fpermissive -fno-rtti -fno-exceptions -fno-threadsafe-statics \
                              -ffunction-sections -fdata-sections \
                              --target=riscv32 \
                              -fuse-ld=lld")
else()
  # Linker flags for GCC
  message (STATUS "${Magenta}Using GCC specific linker flags${ColourReset}")
  # Linker control
  SET(CMAKE_EXE_LINKER_FLAGS  "-T ${LINKER_SCRIPT}  \
                              -static \
                              -Wl,-Map=${MAINFILE}.map \
                              -Wl,--gc-sections \
                              -L ${RISCV_XHEEP}/${COMPILER_PREFIX}elf/lib \
                              -lc -lm -lgcc -flto \
                              -fpermissive -fno-rtti -fno-exceptions -fno-threadsafe-statics \
                              -ffunction-sections -fdata-sections -specs=nano.specs")
endif()
message( "${Green}RISCV_XHEEP env variable: ${RISCV_XHEEP}")
message( "${Magenta}Lib Folder RISCV-GCC: ${RISCV_XHEEP}/${COMPILER_PREFIX}elf/lib${ColourReset}")

if (${VERBOSE} MATCHES "true")
 SET(CMAKE_VERBOSE_MAKEFILE ON)
else()
 SET(CMAKE_VERBOSE_MAKEFILE OFF)
endif()

# To make sure that .obj files are created and fetched from the same path.
# When setting an inner path to add_executable, .obj files are stored in ${MAINFILE}.elf.dir/<relative path>
# but when an outside directory is provided, they are stored in ${MAINFILE}.elf.dir/<absolute path>.
# To prevent this, if the SOURCE_PATH is the ROOT_PROJECT (X-HEEP source files will be used), no further path is to be added to the fetch directory.
if( ${SOURCE_PATH} STREQUAL ${ROOT_PROJECT} )
    SET(OBJ_PATH "")
else()
    SET(OBJ_PATH ${SOURCE_PATH})
endif()

# Specify that we want to link with GCC even if we are compiling with clang
if (${COMPILER} MATCHES "clang")
  # Call clang here as the flags below are actually meant for a compiler driver, not a linker.
  set(CLANG_LINKER_EXE "ld.lld")
	if( ${PROJECT} MATCHES "freertos" )
		set( CMAKE_C_LINK_EXECUTABLE "${CLANG_LINKER_EXE} ${CMAKE_EXE_LINKER_FLAGS} \
                                ${SOURCE_PATH}build/CMakeFiles/${MAINFILE}.elf.dir/${OBJ_PATH}applications/${PROJECT}/${MAINFILE}.c.obj \
                                -o ${MAINFILE}.elf \
								_deps/freertos_kernel-build/libfreertos_kernel.a \ _deps/freertos_kernel-build/portable/libfreertos_kernel_port.a \ _deps/freertos_kernel-build/libfreertos_kernel.a \ _deps/freertos_kernel-build/portable/libfreertos_kernel_port.a \
								")
	else()
    set( CMAKE_C_LINK_EXECUTABLE "${CLANG_LINKER_EXE} ${CMAKE_EXE_LINKER_FLAGS} \
                                ${SOURCE_PATH}build/CMakeFiles/${MAINFILE}.elf.dir/${OBJ_PATH}applications/${PROJECT}/${MAINFILE}.c.obj \
                                -o ${MAINFILE}.elf")
    endif()
endif()

#######################################################################
#      SET CUSTOM COMMANDS
#######################################################################

# Post processing command to create a disassembly file
add_custom_command(TARGET ${MAINFILE}.elf POST_BUILD
        COMMAND ${CMAKE_OBJDUMP} -S  ${MAINFILE}.elf > ${MAINFILE}.S
        COMMENT "Invoking: Disassemble (${CMAKE_OBJDUMP})")

# Post processing command to create a hex file
if(${LINKER} STREQUAL "flash_load")
    add_custom_command(TARGET ${MAINFILE}.elf POST_BUILD
            COMMAND ${CMAKE_OBJCOPY} -O verilog --adjust-vma=-0x40000000 ${MAINFILE}.elf ${MAINFILE}.hex
            COMMENT "Invoking: Hexdump")
else()
    add_custom_command(TARGET ${MAINFILE}.elf POST_BUILD
            COMMAND ${CMAKE_OBJCOPY} -O verilog  ${MAINFILE}.elf ${MAINFILE}.hex
            COMMENT "Invoking: Hexdump")
    add_custom_command(TARGET ${MAINFILE}.elf POST_BUILD
            COMMAND ${CMAKE_OBJCOPY} --srec-forceS3 --srec-len 1 -O srec ${MAINFILE}.elf ${MAINFILE}.hex.srec
            COMMENT "Invoking: SREC Hexdump")
endif()

add_custom_command(TARGET ${MAINFILE}.elf POST_BUILD
        COMMAND ${CMAKE_OBJCOPY} -O binary  ${MAINFILE}.elf  ${MAINFILE}.bin
        COMMENT "Invoking: Binary dump")

# Pre-processing command to create disassembly for each source file
if ((${COMPILER} MATCHES "gcc") OR (${COMPILER} MATCHES "clang"))
  if(EXISTS ${SOURCE_PATH}applications/${PROJECT}/${MAINFILE}.c)
   foreach (SRC_MODULE ${MAINFILE} )
    add_custom_command(TARGET ${MAINFILE}.elf
                       PRE_LINK
                       COMMAND ${CMAKE_OBJDUMP} -S ${ROOT_PROJECT}build/CMakeFiles/${MAINFILE}.elf.dir/${OBJ_PATH}applications/${PROJECT}/${SRC_MODULE}.c.obj > ${SRC_MODULE}.s
                       COMMENT "Invoking: C Disassemble ( CMakeFiles/${MAINFILE}.dir/${SRC_MODULE}.c.obj)")   
   endforeach()
  else() #main.cpp targets
  foreach (SRC_MODULE ${MAINFILE} )
    add_custom_command(TARGET ${MAINFILE}.elf
                       PRE_LINK
                      COMMAND ${CMAKE_OBJDUMP} -S ${ROOT_PROJECT}build/CMakeFiles/${MAINFILE}.elf.dir/${OBJ_PATH}applications/${PROJECT}/${SRC_MODULE}.cpp.obj > ${SRC_MODULE}.s
                      COMMENT "Invoking: CPP Disassemble ( CMakeFiles/${MAINFILE}.dir/${SRC_MODULE}.cpp.obj)")
    endforeach()
  endif()
elseif(${COMPILER} MATCHES "g\\+\\+.*$")
  foreach (SRC_MODULE ${MAINFILE} )
  add_custom_command(TARGET ${MAINFILE}.elf
                     PRE_LINK
                    COMMAND ${CMAKE_OBJDUMP} -S ${ROOT_PROJECT}build/CMakeFiles/${MAINFILE}.elf.dir/${OBJ_PATH}applications/${PROJECT}/${SRC_MODULE}.cpp.obj > ${SRC_MODULE}.s
                    COMMENT "Invoking: G++ Disassemble ( CMakeFiles/${MAINFILE}.dir/${SRC_MODULE}.cpp.obj)")
  endforeach()
endif()


# Adding gdb command - TBD
#add_custom_target(gdb DEPENDS ${MAINFILE}.elf)
#add_custom_command(TARGET gdb
#    COMMAND ${CMAKE_C_GDB} ${MAINFILE}.elf -x gdbInit &)

# Post-processing to have access to linker script in build folder
add_custom_command(TARGET ${MAINFILE}.elf POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy ${LINKER_SCRIPT} ${MAINFILE}.ld
        COMMENT "Invoking: Linker script copy")

SET(DCMAKE_EXPORT_COMPILE_COMMANDS ON)

#message( FATAL_ERROR "You can not do this at all, CMake will exit." )
