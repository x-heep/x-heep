REGTOOL ?= ../../vendor/pulp_platform_register_interface/vendor/lowrisc_opentitan/util/regtool.py
NAME ?= $(notdir $(CURDIR))
CFG = data/$(NAME).hjson 
SW = ../../../sw/device/lib/drivers

RTL_REG_DEFINES = rtl/$(NAME)_reg_pkg.sv rtl/$(NAME)_reg_top.sv
CDEFINES = $(SW)/$(NAME)/$(NAME)_regs.h

.PHONY: reg
reg: $(RTL_REG_DEFINES) $(CDEFINES)

$(RTL_REG_DEFINES): $(CFG)
	$(REGTOOL) -r -t rtl $<

$(CDEFINES): $(CFG)
	$(REGTOOL) --cdefines -o $@ $<

