REGTOOL ?= vendor/pulp_platform/register_interface/vendor/lowrisc_opentitan/util/regtool.py
PERIPH_STRUCTS_GEN ?= util/periph_structs_gen/periph_structs_gen.py
TEMPLATE_FILE ?= util/periph_structs_gen/periph_structs.tpl

RTL_DIR ?= rtl
SW_DIR ?= sw

# w25q128jw_controller
W25Q_NAME := w25q128jw_controller
W25Q_CFG := $(RTL_DIR)/$(W25Q_NAME)/data/$(W25Q_NAME).hjson
W25Q_RTL_OUT := $(RTL_DIR)/$(W25Q_NAME)/rtl
W25Q_SW_OUT := $(SW_DIR)/$(W25Q_NAME)

# Generated outputs
W25Q_RTL_FILES := $(W25Q_RTL_OUT)/$(W25Q_NAME)_reg_pkg.sv $(W25Q_RTL_OUT)/$(W25Q_NAME)_reg_top.sv
W25Q_SW_FILES := $(W25Q_SW_OUT)/$(W25Q_NAME)_regs.h
W25Q_STRUCTS_FILE := $(W25Q_SW_OUT)/$(W25Q_NAME)_structs.h
W25Q_DOC_FILE := $(W25Q_SW_OUT)/$(W25Q_NAME)_regs.md

.PHONY: reg
reg: $(W25Q_RTL_FILES) $(W25Q_SW_FILES) $(W25Q_STRUCTS_FILE) $(W25Q_DOC_FILE)
	@printf -- 'Generating $(W25Q_NAME) registers...\n'

$(W25Q_RTL_FILES): $(W25Q_CFG)
	$(REGTOOL) -r -t $(W25Q_RTL_OUT) $<

$(W25Q_SW_FILES): $(W25Q_CFG)
	mkdir -p $(W25Q_SW_OUT)
	$(REGTOOL) --cdefines -o $@ $<

$(W25Q_STRUCTS_FILE): $(W25Q_CFG)
	mkdir -p $(W25Q_SW_OUT)
	python3 $(PERIPH_STRUCTS_GEN) --template_filename $(TEMPLATE_FILE) \
	                              --hjson_filename $< \
	                              --output_filename $@

$(W25Q_DOC_FILE): $(W25Q_CFG)
	mkdir -p $(W25Q_SW_OUT)
	$(REGTOOL) -d $< > $@

.PHONY: vendor
vendor:
	python3 util/vendor.py -Uv vendor/lowrisc_opentitan_spi_host.vendor.hjson
	python3 util/vendor.py -Uv vendor/yosyshq_picorv32.vendor.hjson
	python3 util/vendor.py -Uv vendor/pulp_platform.vendor.hjson
