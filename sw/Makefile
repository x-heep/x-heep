# Copyright 2019 Clifford Wolf
# Copyright 2019 Robert Balas
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

MAKE     = make

# Path relative from the location of sw/Makefile from which to fetch source files. The directory of that file is the default value.
SOURCE 	?= $(".")

VERBOSE ?= false

# riscv toolchain install path
RISCV_XHEEP			 ?= ~/.riscv
RISCV_EXE_PREFIX	= $(RISCV_XHEEP)/bin/${COMPILER_PREFIX}elf-
RISCV_GDB_PATH		= $(RISCV_EXE_PREFIX)gdb

ifneq ($(filter environment command line override, $(origin RISCV_XHEEP)),)
  $(shell printf '\033[1;32mINFO: Using RISCV_XHEEP from environment or command line: %s\033[0m\n' '$(RISCV_XHEEP)' >&2)
else
  $(shell printf '\033[1;33mWARNING: RISCV_XHEEP not set in environment or command line. Using default: %s\033[0m\n' '$(RISCV_XHEEP)' >&2)
endif

# Get the absolute path
mkfile_path := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

# Get the absolute path of where to fetch sources
source_path := $(realpath $(mkfile_path)/$(SOURCE))

ifeq ($(ARG), value1)
  $(info $$You are executing from: $(mkfile_path))
else ifeq ($(ARG), value2)
  $(info $$You are fetching sources from $(source_path) )
endif

SOURCE_PATH  = $(source_path)/
ROOT_PROJECT = $(mkfile_path)/
INC_FOLDERS  = $(mkfile_path)/device/target/$(TARGET)/
LINK_FOLDER  ?= $(mkfile_path)/linker

# CMake keyword
CMAKE_DIR = cmake

# to distinguish between cmake distros
ifeq (, $(shell which cmake3)) # cmake3 is not defined
CMAKE = cmake
else
CMAKE = cmake3
endif

# Export variables to sub-makefiles
export

# Let's CMake!
include cmake/targets.mak

# GDB connection using RISCV-GDB back-end
gdb_connect:
	  $(RISCV_GDB_PATH) build/main.elf -x gdbInit;
