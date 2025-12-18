ACCEL_NAME := xheep

.PHONY: hw sw mcu-gen questa vivado-setup $(ACCEL_NAME)-vivado update-$(ACCEL_NAME)-sverilog update-$(ACCEL_NAME)-verilog update-$(ACCEL_NAME)-sverilog-vivado update-$(ACCEL_NAME)-verilog-vivado

ESP_TOP ?= $(abspath $(CURDIR)/../../..)
ACCEL_PATH := accelerators/rtl/xheep_rtl

# Roots
XHEEP_ROOT := $(ESP_TOP)/$(ACCEL_PATH)
XH_ROOT    := $(XHEEP_ROOT)/vendor/xheep

VLOG_INCDIRS  ?= $(XH_ROOT)/esp_files/third-party/vlog_incdir
VLOG_FILELIST ?= $(XHEEP_ROOT)/$(ACCEL_NAME).sverilog
VLOG_VERILOG  ?= $(XHEEP_ROOT)/$(ACCEL_NAME).verilog
export VLOG_INCDIRS VLOG_FILELIST
$(info [$(ACCEL_NAME)] VLOG_FILELIST=$(VLOG_FILELIST))
$(info [$(ACCEL_NAME)] VLOG_INCDIRS=$(VLOG_INCDIRS))

X_HEEP_CFG ?= configs/esp_heep.hjson
XHEEP_FPGA_BOARD ?= nexys-a7-100t
MODELSIM_FILELIST := build/openhwgroup.org_systems_core-v-mini-mcu_0.3.0/sim-modelsim
VIVADO_FILELIST := build/openhwgroup.org_systems_core-v-mini-mcu_0.3.0/$(XHEEP_FPGA_BOARD)-vivado

OUT_DIR := $(XHEEP_ROOT)/out
FPGA_OUT := $(OUT_DIR)/fpga

RISCV ?= /home/francesco/tools/riscv

ESP_LINUX_APP ?= SeizDetCNN_xheep
XHEEP_APP ?= biomedbench_SeizDetCNN

# Run the X-HEEP generator, then update filelists
hw: mcu-gen questa update-$(ACCEL_NAME)-sverilog update-$(ACCEL_NAME)-verilog

$(ACCEL_NAME)-vivado:
	$(MAKE) mcu-gen
	$(MAKE) vivado-setup
	$(MAKE) update-$(ACCEL_NAME)-sverilog-vivado
	$(MAKE) update-$(ACCEL_NAME)-verilog-vivado
	$(MAKE) sw

mcu-gen:
	$(MAKE) -C $(XH_ROOT) mcu-gen X_HEEP_CFG=$(X_HEEP_CFG)

questa:
	$(MAKE) -C $(XH_ROOT) questasim-sim

vivado-setup:
	$(MAKE) -C $(XH_ROOT) vivado-fpga-nobuild FPGA_BOARD=$(XHEEP_FPGA_BOARD)

update-$(ACCEL_NAME)-sverilog:
	@set -e; \
	TCL="$(XH_ROOT)/$(MODELSIM_FILELIST)/edalize_build_rtl.tcl"; \
	SV="$(VLOG_FILELIST)"; \
	[ -f "$$TCL" ] || { echo "[$(ACCEL_NAME)][ERROR] Missing $$TCL"; exit 1; }; \
	t1="$$(mktemp)"; t2="$$(mktemp)"; \
	awk '/-work[ \t]+work/ { for (i=NF; i>0; i--) if ($$i ~ /\.sv$$/) { print $$i; break } }' "$$TCL" > "$$t1"; \
	awk -v genpref="x-heep/$(MODELSIM_FILELIST)/" -v incdir="$(VLOG_INCDIRS)" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } bn = p; sub(/^.*\//, "", bn); if (system("[ -f \"" incdir "/" bn "\" ]") == 0) { next } print p }' "$$t1" > "$$t2"; \
	{ grep -v '^x-heep' "$$SV" 2>/dev/null || true; } > "$$SV.new"; \
	cat "$$t2" >> "$$SV.new"; \
	mv "$$SV.new" "$$SV"; \
	rm -f "$$t1" "$$t2"; \
	echo "[$(ACCEL_NAME)] Updated $$SV from $$TCL"

update-$(ACCEL_NAME)-verilog:
	@set -e; \
	TCL="$(XH_ROOT)/$(MODELSIM_FILELIST)/edalize_build_rtl.tcl"; \
	VL="$(VLOG_VERILOG)"; \
	[ -f "$$TCL" ] || { echo "[$(ACCEL_NAME)][ERROR] Missing $$TCL"; exit 1; }; \
	t1="$$(mktemp)"; t2="$$(mktemp)"; \
	awk '/-work[ \t]+work/ { for (i=NF; i>0; i--) if ($$i ~ /\.v$$/) { print $$i; break } }' "$$TCL" > "$$t1"; \
	awk -v genpref="x-heep/$(MODELSIM_FILELIST)/" -v incdir="$(VLOG_INCDIRS)" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } bn = p; sub(/^.*\//, "", bn); if (system("[ -f \"" incdir "/" bn "\" ]") == 0) { next } print p }' "$$t1" > "$$t2"; \
	{ grep -v '^x-heep' "$$VL" 2>/dev/null || true; } > "$$VL.new"; \
	cat "$$t2" >> "$$VL.new"; \
	mv "$$VL.new" "$$VL"; \
	rm -f "$$t1" "$$t2"; \
	echo "[$(ACCEL_NAME)] Updated $$VL from $$TCL"

update-$(ACCEL_NAME)-sverilog-vivado:
	@set -e; \
	TCL="$(XH_ROOT)/$(VIVADO_FILELIST)/openhwgroup.org_systems_core-v-mini-mcu_0.3.0.tcl"; \
	SV="$(VLOG_FILELIST)"; \
	[ -f "$$TCL" ] || { echo "[$(ACCEL_NAME)][ERROR] Missing $$TCL"; exit 1; }; \
	t1="$$(mktemp)"; t2="$$(mktemp)"; \
	grep 'read_verilog -sv' "$$TCL" | sed 's/.*{\(.*\)}.*/\1/' | grep '\.sv$$' > "$$t1"; \
	awk -v genpref="x-heep/$(VIVADO_FILELIST)/" -v incdir="$(VLOG_INCDIRS)" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } bn = p; sub(/^.*\//, "", bn); if (system("[ -f \"" incdir "/" bn "\" ]") == 0) { next } print p }' "$$t1" > "$$t2"; \
	{ grep -v '^x-heep' "$$SV" 2>/dev/null || true; } > "$$SV.new"; \
	cat "$$t2" >> "$$SV.new"; \
	mv "$$SV.new" "$$SV"; \
	rm -f "$$t1" "$$t2"; \
	echo "[$(ACCEL_NAME)] Updated $$SV from Vivado $$TCL"

update-$(ACCEL_NAME)-verilog-vivado:
	@set -e; \
	TCL="$(XH_ROOT)/$(VIVADO_FILELIST)/openhwgroup.org_systems_core-v-mini-mcu_0.3.0.tcl"; \
	VL="$(VLOG_VERILOG)"; \
	[ -f "$$TCL" ] || { echo "[$(ACCEL_NAME)][ERROR] Missing $$TCL"; exit 1; }; \
	t1="$$(mktemp)"; t2="$$(mktemp)"; \
	grep 'read_verilog' "$$TCL" | grep -v 'read_verilog -sv' | sed 's/.*{\(.*\)}.*/\1/' | grep '\.v$$' > "$$t1"; \
	awk -v genpref="x-heep/$(VIVADO_FILELIST)/" -v incdir="$(VLOG_INCDIRS)" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } bn = p; sub(/^.*\//, "", bn); if (system("[ -f \"" incdir "/" bn "\" ]") == 0) { next } print p }' "$$t1" > "$$t2"; \
	{ grep -v '^x-heep' "$$VL" 2>/dev/null || true; } > "$$VL.new"; \
	cat "$$t2" >> "$$VL.new"; \
	mv "$$VL.new" "$$VL"; \
	rm -f "$$t1" "$$t2"; \
	echo "[$(ACCEL_NAME)] Updated $$VL from Vivado $$TCL"

sw:
	rm -rf $(XH_ROOT)/sw/build
	$(MAKE) -C $(XH_ROOT) RISCV_XHEEP=$(RISCV_XHEEP) ARCH=rv32imc app PROJECT=$(XHEEP_APP) LINKER=on_chip TARGET=sim
	mkdir -p $(XH_ROOT)/sw/generated
	python3 $(XH_ROOT)/util/hex_to_c.py \
		$(XH_ROOT)/sw/generated/$(ACCEL_NAME)_firmware.h \
		$(XH_ROOT)/sw/build/main.hex
	mkdir -p $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)_native
	mkdir -p $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)_native/common
	cp $(XH_ROOT)/sw/generated/$(ACCEL_NAME)_firmware.h $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)_native
	cp $(XH_ROOT)/sw/device/lib/runtime/core_v_mini_mcu.h $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)_native
	cp $(XH_ROOT)/sw/device/lib/drivers/power_manager/power_manager_regs.h $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)_native
	cp $(XH_ROOT)/sw/device/lib/drivers/soc_ctrl/soc_ctrl_regs.h $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)_native
	cp -r $(XH_ROOT)/sw/applications/$(XHEEP_APP)/common/. $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)_native

	cp $(XH_ROOT)/sw/generated/$(ACCEL_NAME)_firmware.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp $(XH_ROOT)/sw/device/lib/runtime/core_v_mini_mcu.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp $(XH_ROOT)/sw/device/lib/drivers/power_manager/power_manager_regs.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp $(XH_ROOT)/sw/device/lib/drivers/soc_ctrl/soc_ctrl_regs.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp -r $(XH_ROOT)/sw/applications/$(XHEEP_APP)/common/. $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t

	cp $(XH_ROOT)/sw/generated/$(ACCEL_NAME)_firmware.h $(ESP_TOP)/accelerators/rtl/xheep_rtl/sw/linux/app/$(ESP_LINUX_APP)
	cp $(XH_ROOT)/sw/device/lib/runtime/core_v_mini_mcu.h $(ESP_TOP)/accelerators/rtl/xheep_rtl/sw/linux/app/$(ESP_LINUX_APP)
	cp $(XH_ROOT)/sw/device/lib/drivers/power_manager/power_manager_regs.h $(ESP_TOP)/accelerators/rtl/xheep_rtl/sw/linux/app/$(ESP_LINUX_APP)
	cp $(XH_ROOT)/sw/device/lib/drivers/soc_ctrl/soc_ctrl_regs.h $(ESP_TOP)/accelerators/rtl/xheep_rtl/sw/linux/app/$(ESP_LINUX_APP)
	cp -r $(XH_ROOT)/sw/applications/$(XHEEP_APP)/common/. $(ESP_TOP)/accelerators/rtl/xheep_rtl/sw/linux/app/$(ESP_LINUX_APP)
