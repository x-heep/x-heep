# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

BENDER 		?= bender
VSIM 		  ?= vsim
REGGEN 		?= $(shell ${BENDER} path register_interface)/vendor/lowrisc_opentitan/util/regtool.py
WORK 		  ?= work

all: compile_questa

clean: clean_bender clean_questa clean_vcs

run: run_questa

# Ensure half-built targets are purged
.DELETE_ON_ERROR:

# --------------
# General
# --------------

.PHONY: clean_bender

Bender.lock:
	$(BENDER) update

clean_bender:
	rm -rf .bender
	rm -rf Bender.lock


# --------------
# Registers
# --------------

.PHONY: update-regs

update-regs: src/regs/*.hjson
	echo $(REGGEN)
	$(REGGEN) src/regs/serial_link.hjson -r -t src/regs
	$(REGGEN) src/regs/serial_link_single_channel.hjson -r -t src/regs

# --------------
# QuestaSim
# --------------

TB_DUT ?= tb_axi_serial_link

BENDER_FLAGS := -t test -t simulation

VLOG_FLAGS += -suppress vlog-2583
VLOG_FLAGS += -suppress vlog-13314
VLOG_FLAGS += -suppress vlog-13233
VLOG_FLAGS += -timescale 1ns/1ps
VLOG_FLAGS += -work $(WORK)

VSIM_FLAGS += $(TB_DUT)
VSIM_FLAGS += -work $(WORK)
VSIM_FLAGS += $(RUN_ARGS)

ifeq ($(GUI), true)
	VSIM_FLAGS += -voptargs=+acc
	VSIM_FLAGS += -do "log -r /*; do util/serial_link_wave.tcl; run -all"
else
	VSIM_FLAGS += -c
	VSIM_FLAGS += -do "run -all; exit"
endif

.PHONY: compile_questa clean_questa run_questa

scripts/compile_vsim.tcl: Bender.lock
	@mkdir -p scripts
	@echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $@
	$(BENDER) script vsim --vlog-arg="$(VLOG_FLAGS)" $(BENDER_FLAGS) | grep -v "set ROOT" >> $@
	@echo >> $@

compile_questa: scripts/compile_vsim.tcl
ifeq ($(SINGLE_CHANNEL),1)
	@sed 's/NumChannels = [0-9]*/NumChannels = 1/' src/serial_link_pkg.sv -i.prev
	$(VSIM) -c -work $(WORK) -do "source $<; quit" | tee $(dir $<)vsim.log
	@mv src/serial_link_pkg.sv.prev src/serial_link_pkg.sv
else
	$(VSIM) -c -work $(WORK) -do "source $<; quit" | tee $(dir $<)vsim.log
endif
	@! grep -P "Errors: [1-9]*," $(dir $<)vsim.log

clean_questa:
	@rm -rf scripts/compile_vsim.tcl
	@rm -rf work*
	@rm -rf vsim.wlf
	@rm -rf transcript
	@rm -rf modelsim.ini
	@rm -rf *.vstf
	@rm -rf scripts/vsim.log

run_questa:
	$(VSIM) $(VSIM_FLAGS)


# --------------
# VCS
# --------------

.PHONY: compile_vcs clean_vcs

VLOGAN_ARGS := -assert svaext
VLOGAN_ARGS += -assert disable_cover
VLOGAN_ARGS += -full64
VLOGAN_ARGS += -sysc=q
VLOGAN_ARGS += -q
VLOGAN_ARGS += -timescale=1ns/1ps

VCS_ARGS    := -full64
VCS_ARGS    += -Mlib=$(WORK)
VCS_ARGS    += -Mdir=$(WORK)
VCS_ARGS    += -debug_access+pp
VCS_ARGS    += -j 8
VCS_ARGS    += -CFLAGS "-Os"

VCS_PARAMS  ?=
TB_DUT 		?= tb_axi_serial_link

VLOGAN  	?= vlogan
VCS		    ?= vcs

VLOGAN_REL_PATHS ?= | grep -v "ROOT=" | sed '3 i ROOT="."'

scripts/compile_vcs.sh: Bender.yml Bender.lock
	@mkdir -p scripts
	$(BENDER) script vcs -t test -t rtl -t simulation --vlog-arg "\$(VLOGAN_ARGS)" --vlogan-bin "$(VLOGAN)" $(VLOGAN_REL_PATHS) > $@
	chmod +x $@

compile_vcs: scripts/compile_vcs.sh
ifeq ($(SINGLE_CHANNEL),1)
	@sed 's/NumChannels = [0-9]*/NumChannels = 1/' src/serial_link_pkg.sv -i.prev
	$< > scripts/compile_vcs.log
	@mv src/serial_link_pkg.sv.prev src/serial_link_pkg.sv
else
	$< > scripts/compile_vcs.log
endif

bin/%.vcs: scripts/compile_vcs.sh compile_vcs
	mkdir -p bin
	$(VCS) $(VCS_ARGS) $(VCS_PARAMS) $(TB_DUT) -o $@

clean_vcs:
	@rm -rf AN.DB
	@rm -f  scripts/compile_vcs.sh
	@rm -rf bin
	@rm -rf work-vcs
	@rm -f  ucli.key
	@rm -f  vc_hdrs.h
	@rm -f  logs/*.vcs.log
	@rm -f  scripts/compile_vcs.log

# --------------
# CI
# --------------

.PHONY: bender

bender:
ifeq (,$(wildcard ./bender))
	curl --proto '=https' --tlsv1.2 -sSf https://pulp-platform.github.io/bender/init \
		| bash -s -- 0.25.3
	touch bender
endif

.PHONY: remove_bender
remove_bender:
	rm -f bender
