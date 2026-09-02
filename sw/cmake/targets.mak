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

build : build/Makefile
	@echo Build 
	${MAKE} -s -C build

setup : build/Makefile

build/Makefile : CMakeLists.txt ${CMAKE_DIR}/riscv.cmake
	@if [ ! -d build ] ; then mkdir build ; fi
	@cd build;  \
		${CMAKE} \
		    -G "Unix Makefiles" \
			-DCMAKE_TOOLCHAIN_FILE=../${CMAKE_DIR}/riscv.cmake \
			-DROOT_PROJECT=${ROOT_PROJECT} \
			-DSOURCE_PATH=${SOURCE_PATH} \
			-DTARGET=${TARGET} \
			-DPROJECT:STRING=${PROJECT} \
			-DRISCV_XHEEP:STRING=${RISCV_XHEEP} \
			-DLINK_FOLDER:STRING=${LINK_FOLDER} \
			-DLINKER:STRING=${LINKER} \
			-DCOMPILER:STRING=${COMPILER} \
			-DCOMPILER_PREFIX:STRING=${COMPILER_PREFIX} \
			-DCOMPILER_FLAGS:STRING="${COMPILER_FLAGS}"\
			-DCLANG_LINKER_USE_LD:BOOL=${CLANG_LINKER_USE_LD}\
			-DVERBOSE:STRING=${VERBOSE} \
		    ../ 

clean:
	rm -rf build

.PHONY: setup build
.SUFFIXES:
