REGTOOL ?= vendor/pulp_platform_register_interface/vendor/lowrisc_opentitan/util/regtool.py
PERIPH_STRUCTS_GEN ?= util/periph_structs_gen/periph_structs_gen.py
TEMPLATE_FILE ?= util/periph_structs_gen/periph_structs.tpl

RTL_DIR ?= rtl
SW_DIR ?= sw

FUSESOC   := fusesoc
CORE_NAME := x-heep:ip:spi

TB_ARGS ?= --random_data false

SPI_SUBSYS_PERIPH_GEN ?= axi

# w25q128jw_controller
W25Q_NAME := w25q128jw_controller
W25Q_CFG := $(RTL_DIR)/$(W25Q_NAME)/data/$(W25Q_NAME).hjson
W25Q_RTL_OUT := $(RTL_DIR)/$(W25Q_NAME)/rtl
W25Q_SW_OUT := $(SW_DIR)/$(W25Q_NAME)

# spi_subsystem
SPISUBSYS_NAME := spi_subsystem
SPISUBSYS_CFG := data/$(SPISUBSYS_NAME).hjson
SPISUBSYS_RTL_OUT := $(RTL_DIR)
SPISUBSYS_SW_OUT := $(SW_DIR)/$(SPISUBSYS_NAME)

# Generated outputs - # w25q128jw_controller
W25Q_RTL_FILES := $(W25Q_RTL_OUT)/$(W25Q_NAME)_reg_pkg.sv $(W25Q_RTL_OUT)/$(W25Q_NAME)_reg_top.sv
W25Q_SW_FILES := $(W25Q_SW_OUT)/$(W25Q_NAME)_regs.h
W25Q_STRUCTS_FILE := $(W25Q_SW_OUT)/$(W25Q_NAME)_structs.h
W25Q_DOC_FILE := $(W25Q_SW_OUT)/$(W25Q_NAME)_regs.md

# Generated outputs - # spi_subsystem
SPISUBSYS_RTL_FILES := $(SPISUBSYS_RTL_OUT)/$(SPISUBSYS_NAME)_reg_pkg.sv $(SPISUBSYS_RTL_OUT)/$(SPISUBSYS_NAME)_reg_top.sv
SPISUBSYS_SW_FILES := $(SPISUBSYS_SW_OUT)/$(SPISUBSYS_NAME)_regs.h
SPISUBSYS_STRUCTS_FILE := $(SPISUBSYS_SW_OUT)/$(SPISUBSYS_NAME)_structs.h
SPISUBSYS_DOC_FILE := $(SPISUBSYS_SW_OUT)/$(SPISUBSYS_NAME)_regs.md

# output directory
OUT_DIR ?= $(RTL_DIR)

.PHONY: reg
reg: $(W25Q_RTL_FILES) $(W25Q_SW_FILES) $(W25Q_STRUCTS_FILE) $(W25Q_DOC_FILE) \
     $(SPISUBSYS_RTL_FILES) $(SPISUBSYS_SW_FILES) $(SPISUBSYS_STRUCTS_FILE) $(SPISUBSYS_DOC_FILE)
	@echo "All registers for $(W25Q_NAME) and $(SPISUBSYS_NAME) are up to date."

$(W25Q_RTL_FILES): $(W25Q_CFG)
	@printf -- 'Generating $(W25Q_NAME) RTL...\n'
	$(REGTOOL) -r -t $(W25Q_RTL_OUT) $<

$(W25Q_SW_FILES): $(W25Q_CFG)
	@mkdir -p $(W25Q_SW_OUT)
	$(REGTOOL) --cdefines -o $@ $<

$(W25Q_STRUCTS_FILE): $(W25Q_CFG)
	@mkdir -p $(W25Q_SW_OUT)
	python3 $(PERIPH_STRUCTS_GEN) --template_filename $(TEMPLATE_FILE) \
                                  --hjson_filename $< \
                                  --output_filename $@

$(W25Q_DOC_FILE): $(W25Q_CFG)
	@mkdir -p $(W25Q_SW_OUT)
	$(REGTOOL) -d $< > $@

$(SPISUBSYS_RTL_FILES): $(SPISUBSYS_CFG)
	@printf -- 'Generating $(SPISUBSYS_NAME) RTL...\n'
	$(REGTOOL) -r -t $(SPISUBSYS_RTL_OUT) $<

$(SPISUBSYS_SW_FILES): $(SPISUBSYS_CFG)
	@mkdir -p $(SPISUBSYS_SW_OUT)
	$(REGTOOL) --cdefines -o $@ $<

$(SPISUBSYS_STRUCTS_FILE): $(SPISUBSYS_CFG)
	@mkdir -p $(SPISUBSYS_SW_OUT)
	python3 $(PERIPH_STRUCTS_GEN) --template_filename $(TEMPLATE_FILE) \
                                  --hjson_filename $< \
                                  --output_filename $@

$(SPISUBSYS_DOC_FILE): $(SPISUBSYS_CFG)
	@mkdir -p $(SPISUBSYS_SW_OUT)
	$(REGTOOL) -d $< > $@

.PHONY: vendor
vendor:
	python3 util/vendor.py -Uv vendor/lowrisc_opentitan_spi_host.vendor.hjson
	python3 util/vendor.py -Uv vendor/pulp_platform_register_interface.vendor.hjson
	python3 util/vendor.py -Uv vendor/pulp_platform_axi.vendor.hjson
	python3 util/vendor.py -Uv vendor/lowrisc_opentitan.vendor.hjson
	python3 util/vendor.py -Uv vendor/pulp_platform_common_cells.vendor.hjson

.PHONY: clean-sim
clean-sim: clear-prompt clean sim

## Build project for simulation
.PHONY: build
build: lib
	@echo "## Building Simulation Model..."
	$(FUSESOC) run --target=sim --setup --build $(CORE_NAME)

## Run simulation
.PHONY: sim
sim: build
	@echo "## Running Simulation..."
	$(FUSESOC) run --target=sim --run $(CORE_NAME) --run_options="$(TB_ARGS)"

## Search for core file dependencies
.PHONY: lib
lib:
	@echo "## Creating Libraries..."
	$(FUSESOC) library add xspi . || true
	$(FUSESOC) library add vendors vendor || true

## Generate spi_subsystem.sv and spi_subsystem_top_reg.sv
.PHONY: spi-gen
spi-gen: reg periph-gen

## Generate spi_subsystem.sv
.PHONY: periph-gen
periph-gen:
	python3 $(RTL_DIR)/spi_subsystem_gen.py $(RTL_DIR)/spi_subsystem.sv.tpl $(OUT_DIR)/spi_subsystem.sv $(SPI_SUBSYS_PERIPH_GEN)

## Clean files
.PHONY: clean
clean:
	@echo "## Cleaning..."
	rm -rf build
	rm -f fusesoc.conf

## Clear prompt
.PHONY: clear-prompt
clear-prompt:
	@clear
