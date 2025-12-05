# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

MAKE	= make

# Get the absolute path
mkfile_path := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")
$(info $$You are executing from: $(mkfile_path))

# Helper variables for Make string manipulation
empty :=
space := $(empty) $(empty)
comma := ,

# Include the self-documenting tool
export FILE_FOR_HELP=$(mkfile_path)/Makefile

help:
	${mkfile_path}/util/MakefileHelp

# Setup to autogenerate python virtual environment
VENVDIR?=$(WORKDIR)/.venv
REQUIREMENTS_TXT ?= util/python-requirements.txt docs/python-requirements.txt
include Makefile.venv

# FUSESOC and Python values (default)
ifndef CONDA_DEFAULT_ENV
$(info USING VENV)
FUSESOC 	= $(PWD)/$(VENV)/fusesoc
PYTHON  	= $(PWD)/$(VENV)/python
RV_PROFILE 	= $(PWD)/$(VENV)/rv_profile
AREA_PLOT  	= $(PWD)/$(VENV)/area-plot
else
$(info USING MINICONDA $(CONDA_DEFAULT_ENV))
FUSESOC 	:= $(shell which fusesoc)
PYTHON  	:= $(shell which python)
RV_PROFILE  := $(shell which rv_profile)
AREA_PLOT   := $(shell which area-plot)
endif

# Build directories
BUILD_DIR         = build
FUSESOC_BUILD_DIR = $(shell find $(BUILD_DIR) -maxdepth 1 -type d -name 'openhwgroup.org_systems_core-v-mini-mcu_*' 2>/dev/null | sort -V | head -n 1)
VERILATOR_DIR     = $(FUSESOC_BUILD_DIR)/sim-verilator
QUESTASIM_DIR     = $(FUSESOC_BUILD_DIR)/sim-modelsim

# Project options are based on the app to be built (default - hello_world)
PROJECT  ?= hello_world

# Folder where the linker scripts are located
LINK_FOLDER ?= $(mkfile_path)/sw/linker
# Linker options are 'on_chip' (default),'flash_load','flash_exec','freertos'
LINKER   ?= on_chip

# Target options are 'sim' (default) and 'pynq-z2' and 'nexys-a7-100t'
TARGET   	?= sim

# Mcu-gen configuration files
X_HEEP_CFG  ?= configs/general.hjson
PADS_CFG ?= configs/pad_cfg.hjson
PYTHON_X_HEEP_CFG ?=
# Cached mcu-gen xheep configuration
XHEEP_CONFIG_CACHE ?= $(BUILD_DIR)/xheep_config_cache.pickle

# MCU-Gen template files to generate
MCU_GEN_TEMPLATES = \
	hw/core-v-mini-mcu/include/core_v_mini_mcu_pkg.sv.tpl \
	hw/core-v-mini-mcu/core_v_mini_mcu.sv.tpl \
	hw/core-v-mini-mcu/system_bus.sv.tpl \
	hw/core-v-mini-mcu/system_xbar.sv.tpl \
	hw/core-v-mini-mcu/memory_subsystem.sv.tpl \
	hw/core-v-mini-mcu/ao_peripheral_subsystem.sv.tpl \
	hw/core-v-mini-mcu/peripheral_subsystem.sv.tpl \
	hw/core-v-mini-mcu/cpu_subsystem.sv.tpl \
	hw/system/x_heep_system.sv.tpl \
	hw/system/pad_ring.sv.tpl \
	hw/system/pad_control/data/pad_control.hjson.tpl \
	hw/system/pad_control/rtl/pad_control.sv.tpl \
	hw/ip/soc_ctrl/data/soc_ctrl.hjson.tpl \
	hw/ip/power_manager/rtl/power_manager.sv.tpl \
	hw/ip/power_manager/data/power_manager.hjson.tpl \
	hw/ip/pdm2pcm/data/pdm2pcm.hjson.tpl \
	hw/ip/pdm2pcm/rtl/pdm2pcm.sv.tpl \
	hw/ip/pdm2pcm/rtl/pdm_core.sv.tpl \
	hw/ip/dma/data/dma.hjson.tpl \
	hw/ip/dma/data/dma_conf.svh.tpl \
	hw/fpga/sram_wrapper.sv.tpl \
	hw/fpga/scripts/generate_sram.tcl.tpl \
	tb/tb_util.svh.tpl \
	$(LINK_FOLDER)/link.ld.tpl \
	$(LINK_FOLDER)/link_flash_load.ld.tpl \
	$(LINK_FOLDER)/link_flash_exec.ld.tpl \
	sw/device/lib/crt/crt0.S.tpl \
	sw/device/lib/runtime/core_v_mini_mcu.h.tpl \
	sw/device/lib/runtime/core_v_mini_mcu_memory.h.tpl \
	sw/device/lib/drivers/power_manager/power_manager.h.tpl \
	scripts/pnr/core-v-mini-mcu.upf.tpl \
	scripts/pnr/core-v-mini-mcu.dc.upf.tpl \
	util/profile/run_profile.sh.tpl

# Compiler options are 'gcc' (default) and 'clang'
COMPILER 		?= gcc
# Compiler prefix options are 'riscv32-corev-' (default) and 'riscv32-unknown-'
COMPILER_PREFIX ?= $(shell basename $$(ls $(RISCV_XHEEP)/bin/*gcc 2>/dev/null | head -1) | sed 's/elf-gcc$$//')
# Compiler flags to be passed (for both linking and compiling)
COMPILER_FLAGS 	?=
# Arch options are any RISC-V ISA string supported by the CPU. Default 'rv32imc_zicsr'
ARCH     		?= rv32imc_zicsr
# Tell clang to use the gcc link instead of the llvm linker (useful for old clang). Default '0' (set it to 1)
CLANG_LINKER_USE_LD ?= 0

# Path relative from the location of sw/Makefile from which to fetch source files. The directory of that file is the default value.
SOURCE 	 ?= $(".")

# Simulation engines options are verilator (default) and questasim
SIMULATOR ?= verilator
# SIM_ARGS: Additional simulation arguments for run-app-verilator based on input parameters:
# - MAX_SIM_TIME: Maximum simulation time in clock cycles (unlimited if not provided)
SIM_ARGS += $(if $(MAX_SIM_TIME),+max_sim_time=$(MAX_SIM_TIME))

# Testing flags
# Optional TEST_FLAGS options are '--compile-only'
TEST_FLAGS=

# Flash read address for testing, in hexadecimal format 0x0000
FLASHREAD_ADDR ?= 0x0
FLASHREAD_FILE ?= $(mkfile_path)/flashcontent.hex
FLASHREAD_BYTES ?= 256
# Binary to store in flash memory
FLASHWRITE_FILE ?= $(mkfile_path)/sw/build/main.hex
# Max address in the hex file, used to program the flash
ifeq ($(wildcard $(FLASHWRITE_FILE)),)
	MAX_HEX_ADDRESS  := 0
	MAX_HEX_ADDRESS_DEC := 0
	BYTES_AFTER_MAX_HEX_ADDRESS := 0
	FLASHWRITE_BYTES := 0
else
	MAX_HEX_ADDRESS  := $(shell cat $(FLASHWRITE_FILE) | grep "@" | tail -1 | cut -c2-)
	MAX_HEX_ADDRESS_DEC := $(shell printf "%d" 0x$(MAX_HEX_ADDRESS))
	BYTES_AFTER_MAX_HEX_ADDRESS := $(shell tac $(FLASHWRITE_FILE) | awk 'BEGIN {count=0} /@/ {print count; exit} {count++}')
	FLASHWRITE_BYTES := $(shell echo $$(( $(MAX_HEX_ADDRESS_DEC) + $(BYTES_AFTER_MAX_HEX_ADDRESS)*16 )))
endif

# Area plot default configuration
AREA_PLOT_RPT 		?= $(word 1, $(shell [ -d $(BUILD_DIR) ] && find $(BUILD_DIR) -type f -name "*area*.rpt" 2>/dev/null)) # path to the area report file
AREA_PLOT_OUTDIR 	?= $(BUILD_DIR)/area-plot/ # output directory for the area plot
AREA_PLOT_TOP 		?=# top level module to consider for the area plot (automatically infer)

# Export variables to sub-makefiles
export

## @section Conda
conda:
	conda env create -f util/conda_environment.yml

## @section Installation

## Generates mcu files core-v-mini-mcu files and build the design with fusesoc
## @param CPU=[cv32e20(default),cv32e40p,cv32e40x,cv32e40px]
## @param BUS=[onetoM(default),NtoM]
## @param MEMORY_BANKS=[2(default)to(16-MEMORY_BANKS_IL)]
## @param MEMORY_BANKS_IL=[0(default),2,4,8]
## @param X_HEEP_CFG=[configs/general.hjson(default),<path-to-config-file>]
## @param PYTHON_X_HEEP_CFG=[configs/general.py(default),<path-to-config-file>]
mcu-gen:
	$(PYTHON) util/mcu_gen.py --cached_path $(XHEEP_CONFIG_CACHE) --config $(X_HEEP_CFG) --python_config $(PYTHON_X_HEEP_CFG) --pads_cfg $(PADS_CFG) --cpu $(CPU) --bus $(BUS) --memorybanks $(MEMORY_BANKS) --memorybanks_il $(MEMORY_BANKS_IL) --external_domains $(EXTERNAL_DOMAINS)
	$(PYTHON) util/mcu_gen.py --cached_path $(XHEEP_CONFIG_CACHE) --cached --outtpl "$(subst $(space),$(comma),$(MCU_GEN_TEMPLATES))"
	bash -c "cd hw/ip/soc_ctrl; source soc_ctrl_gen.sh; cd ../../../"
	bash -c "cd hw/ip/power_manager; source power_manager_gen.sh; cd ../../../"
	bash -c "cd hw/ip/pdm2pcm; source pdm2pcm_gen.sh; cd ../../../"
	bash -c "cd hw/system/pad_control; source pad_control_gen.sh; cd ../../../"
	bash -c "cd hw/ip/dma; source dma_gen.sh; cd ../../../"
	bash -c "cd hw/ip/boot_rom; make clean; make all; cd ../../../"
	$(MAKE) verible

## Display mcu_gen.py help
mcu-gen-help:
	$(PYTHON) util/mcu_gen.py -h

## Runs verible formating
verible: | .check-verible
	util/format-verible;

## Runs black formating for python xheep generator files
format-python:
	$(PYTHON) -m black util/x_heep_gen
	$(PYTHON) -m black util/periph_structs_gen
	$(PYTHON) -m black util/mcu_gen.py
	$(PYTHON) -m black util/waiver-gen.py
	$(PYTHON) -m black util/c_gen.py
	$(PYTHON) -m black test/test_x_heep_gen

## @section APP FW Build

## Generates the build folder in sw using CMake to build (compile and linking)
## @param PROJECT=<folder_name_of_the_project_to_be_built>
## @param TARGET=sim(default),systemc,pynq-z2,nexys-a7-100t,genesys2,aup-zu3,zcu102,zcu104
## @param LINKER=on_chip(default),flash_load,flash_exec
## @param COMPILER=gcc(default),clang
## @param COMPILER_PREFIX=riscv32-corev-(default),riscv32-unknown-
## @param ARCH=rv32imc(default),<any_RISC-V_ISA_string_supported_by_the_CPU>
app: clean-app
	@$(MAKE) -C sw PROJECT=$(PROJECT) TARGET=$(TARGET) LINKER=$(LINKER) LINK_FOLDER=$(LINK_FOLDER) COMPILER=$(COMPILER) COMPILER_PREFIX=$(COMPILER_PREFIX) COMPILER_FLAGS="$(COMPILER_FLAGS)" ARCH=$(ARCH) SOURCE=$(SOURCE) CLANG_LINKER_USE_LD=$(CLANG_LINKER_USE_LD) \
	|| { \
	echo "\033[0;31mHmmm... seems like the compilation failed...\033[0m"; \
	echo "\033[0;31mIf you do not understand why, it is likely that you either:\033[0m"; \
	echo "\033[0;31m  a) offended the Leprechaun of Electronics\033[0m"; \
	echo "\033[0;31m  b) forgot to run make mcu-gen\033[0m"; \
	echo "\033[0;31m  c) forgot to set the correct compiler parameters (check the docs!)\033[0m"; \
	echo "\033[0;31mI would start by checking b) or c) if I were you!\033[0m"; \
	exit 1; \
	}
	@python scripts/building/mem_usage.py

## Just list the different application names available
app-list:
	@echo "Note: Applications outside the X-HEEP sw/applications directory will not be listed."
	tree sw/applications/

## @section Simulation

## Verilator simulation with C++
verilator-build: | .check-verilator
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) --build openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## Verilator simulation with SystemC
verilator-build-sc: | .check-verilator
	$(FUSESOC) --cores-root . run --no-export --target=sim_sc --tool=verilator $(FUSESOC_FLAGS) --build openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## Questasim simulation
questasim-build:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=modelsim $(FUSESOC_FLAGS) --build openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## Questasim simulation with HDL optimized compilation
questasim-build-opt: questasim-build
	$(MAKE) -C $(QUESTASIM_DIR) opt

## Questasim simulation with HDL optimized compilation and UPF power domain description
## @param FUSESOC_PARAM="--USE_UPF"
questasim-build-opt-upf: questasim-build
	$(MAKE) -C $(QUESTASIM_DIR) opt-upf

## VCS simulation
## @param CPU=cv32e20(default),cv32e40p,cv32e40x,cv32e40px
## @param BUS=onetoM(default),NtoM
vcs-build:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=vcs $(FUSESOC_FLAGS) --build openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## VCS-AMS simulation:
vcs-ams-build:
	$(FUSESOC) --cores-root . run --no-export --target=sim --flag "ams_sim" --tool=vcs $(FUSESOC_FLAGS) --build openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## xcelium simulation
xcelium-build:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=xcelium $(FUSESOC_FLAGS) --build openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## Generates the build output for helloworld application
## Uses verilator to simulate the HW model and run the FW
verilator-run-helloworld: mcu-gen verilator-build
	$(MAKE) -C sw PROJECT=hello_world TARGET=$(TARGET) LINKER=$(LINKER) COMPILER=$(COMPILER) COMPILER_PREFIX=$(COMPILER_PREFIX) ARCH=$(ARCH);
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) --run openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) \
		--run_options="+firmware=../../../sw/build/main.hex $(SIM_ARGS)"

## First builds the app and then uses Verilator to simulate the HW model and run the FW
verilator-run-app: app
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) --run openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) \
		--run_options="+firmware=../../../sw/build/main.hex $(SIM_ARGS)"

## Launches the RTL simulation with the compiled firmware (`app` target) using
## the C++ Verilator model previously built (`verilator-build` target).
verilator-run:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) --run openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) \
		--run_options="+firmware=../../../sw/build/main.hex $(SIM_ARGS)"

## Launches the RTL simulation with the compiled firmware (`app` target) using
## the SystemC Verilator model previously built (`verilator-build-sc` target).
verilator-run-sc:
	$(FUSESOC) --cores-root . run --no-export --target=sim_sc --tool=verilator $(FUSESOC_FLAGS) --run openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) \
		--run_options="+firmware=../../../sw/build/main.hex $(SIM_ARGS)"

## Opens gtkwave to view the waveform generated by the last verilator simulation
verilator-waves: .check-gtkwave
	gtkwave $(VERILATOR_DIR)/waveform.fst

## @section Vivado

## Builds (synthesis and implementation) the bitstream for the FPGA version using Vivado
## @param FPGA_BOARD=pynq-z2,nexys-a7-100t,genesys2,aup-zu3,zcu102,zcu104
## @param FUSESOC_FLAGS=--flag=<flagname>
vivado-fpga:
	$(FUSESOC) --cores-root . run --no-export --target=$(FPGA_BOARD) $(FUSESOC_FLAGS) --build openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee buildvivado.log

vivado-fpga-nobuild:
	$(FUSESOC) --cores-root . run --no-export --target=$(FPGA_BOARD) $(FUSESOC_FLAGS) --setup openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee buildvivado.log

## Loads the generated bitstream into the FPGA
## @param FPGA_BOARD=pynq-z2,nexys-a7-100t,genesys2,aup-zu3,zcu102,zcu104
vivado-fpga-pgm:
	$(FUSESOC) --cores-root . run --no-export --target=$(FPGA_BOARD) $(FUSESOC_FLAGS) --run openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee programfpga.log

## @section ASIC
## Note that for this step you need to provide technology-dependent files (e.g., libs, constraints)
asic:
	$(FUSESOC) --cores-root . run --no-export --target=asic_synthesis $(FUSESOC_FLAGS) --setup openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee builddesigncompiler.log

openroad-sky130:
	git checkout hw/vendor/pulp_platform_common_cells/*
	sed -i 's/(\*[^\n]*\*)//g' hw/vendor/pulp_platform_common_cells/src/*.sv
	$(FUSESOC) --verbose --cores-root . run --target=asic_yosys_synthesis --flag=use_sky130 openhwgroup.org:systems:core-v-mini-mcu $(FUSESOC_PARAM) 2>&1 | tee buildopenroad.log
	git checkout hw/vendor/pulp_platform_common_cells/*

## @section Program, Execute, and Debug w/ EPFL_Programmer

## Read the id from the EPFL_Programmer flash
flash-readid:
	cd sw/vendor/yosyshq_icestorm/iceprog; make; \
	./iceprog -d i:0x0403:0x6011 -I B -t;

## Loads the obtained binary to the EPFL_Programmer flash
flash-prog:
	cd sw/vendor/yosyshq_icestorm/iceprog; make; \
	./iceprog -a $(FLASHWRITE_BYTES) -d i:0x0403:0x6011 -I B $(FLASHWRITE_FILE);

## Read the EPFL_Programmer flash
flash-read:
	cd sw/vendor/yosyshq_icestorm/iceprog; make; \
	./iceprog -d i:0x0403:0x6011 -I B -o $(shell printf "%d" $(FLASHREAD_ADDR)) -R $(FLASHREAD_BYTES) $(FLASHREAD_FILE);

## Erase the EPFL_Programmer flash
flash-erase:
	cd sw/vendor/yosyshq_icestorm/iceprog; make; \
	./iceprog -d i:0x0403:0x6011 -I B -b;

## Run openOCD w/ EPFL_Programmer
openOCD_epflp:
	xterm -e openocd -f ./tb/core-v-mini-mcu-esl-programmer.cfg;

## Run openOCD w/ BSCAN of the Pynq-Z2 board
openOCD_bscan:
	xterm -e openocd -f ./tb/core-v-mini-mcu-pynq-z2-bscan.cfg;

## Start GDB
gdb_connect:
	$(MAKE) -C sw gdb_connect

## @section Testing

## Run the tests for X-HEEP. Cleans and rebuilds all the project.
.PHONY: test
test:
	$(MAKE) mcu-gen X_HEEP_CFG=configs/ci.hjson
	$(RM) test/*.log
	python3 test/test_apps/test_apps.py $(TEST_FLAGS) 2>&1 | tee test/test_apps/test_apps.log
	@echo "You can also find the output in test/test_apps/test_apps.log"
	python3 test/test_x_heep_gen/test_peripherals.py
	@echo "You can also find the peripheral test outputs in test/test_x_heep_gen/outputs"

.PHONY: test_kwargs
test_kwargs:
	$(MAKE) mcu-gen X_HEEP_CFG=configs/ci.hjson PADS_CFG=test/test_x_heep_gen/pads/pad_cfg.hjson
	$(PYTHON) util/mcu_gen.py --cached_path $(XHEEP_CONFIG_CACHE) --cached --outtpl test/test_x_heep_gen/pads/output/kwargs_output.json.tpl
	python3 test/test_x_heep_gen/pad_test.py


## Builds the specified app, loads it into the programmer's flash and then opens picocom to see the output
## @param PROJECT=<folder_name_of_the_project_to_be_built>
run-fpga-flash-load:
	$(MAKE) app LINKER=flash_load TARGET=pynq-z2 PROJECT=$(PROJECT)
	$(MAKE) flash-prog || { \
		echo "\033[0;31mTry holding the RESET button on the FPGA while loading the flash.\033[0m"; \
		exit 1; \
	}
	@echo "\033[0;33mYou can exit Picocom with ctrl+A, ctrl+Q\033[0m";
	@echo "\033[0;33mPress the RESET button on the FPGA to start the program\033[0m";
	picocom -b 9600 -r -l --imap lfcrlf /dev/serial/by-id/usb-FTDI_Quad_RS232-HS-if02-port0;

## @section Profiling
## Run the profiling on a RTL simulation generating a flamegraph.
.PHONY: profile
profile:
	bash util/profile/run_profile.sh $(RV_PROFILE)


## @section Area Plot
## Generate post-synthesis area plot given a synthesis area report
# For additional arguments use area-plot --help
.PHONY: area-plot
area-plot:
	$(AREA_PLOT) --filename $(AREA_PLOT_RPT) --out-dir $(AREA_PLOT_OUTDIR) --top-module $(AREA_PLOT_TOP)

## @section Cleaning commands

## Remove the sw build folder
.PHONY: clean-app
clean-app:
	@rm -rf sw/build

## Remove the build folders
.PHONY: clean
clean: clean-app
	@rm -rf $(BUILD_DIR)

## Leave the repository in a clean state, removing all generated files. For now, it just calls clean.
.PHONY: clean-all
clean-all: clean

## @section Utilities
# Check if a program is available in PATH
define CHECK_PROGRAM
.PHONY: .check-$(1)
.check-$(1):
	@command -v $(2) >/dev/null 2>&1 || { \
		printf "### ERROR: '%s' is not in PATH.\\n" "$(2)" >&2; \
		exit 1; \
	}
endef
$(eval $(call CHECK_PROGRAM,gtkwave,gtkwave))
$(eval $(call CHECK_PROGRAM,verible,verible-verilog-format))
$(eval $(call CHECK_PROGRAM,verilator,verilator))
