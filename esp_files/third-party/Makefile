ACCEL_NAME := xheep

.PHONY: hw sw mirror-filelist update-$(ACCEL_NAME)-sverilog update-$(ACCEL_NAME)-verilog update-$(ACCEL_NAME)-sverilog-vivado update-$(ACCEL_NAME)-verilog-vivado mcu-gen questa vivado-setup $(ACCEL_NAME)-vivado $(ACCEL_NAME)-sim-restore generate-fpga-ips

ACCEL_PATH := accelerators/third-party/$(ACCEL_NAME)
VLOG_INCDIRS  ?= $(ESP_TOP)/$(ACCEL_PATH)/vlog_incdir
VLOG_FILELIST ?= $(ESP_TOP)/$(ACCEL_PATH)/$(ACCEL_NAME).sverilog
export VLOG_INCDIRS VLOG_FILELIST
$(info [$(ACCEL_NAME)] VLOG_FILELIST=$(VLOG_FILELIST))
$(info [$(ACCEL_NAME)] VLOG_INCDIRS=$(VLOG_INCDIRS))

# roots
XHEEP_ROOT := $(PWD)
OUT_DIR    := $(XHEEP_ROOT)/out
OBI_ROOT   := $(XHEEP_ROOT)/ip/obi
XH_ROOT    := $(XHEEP_ROOT)/ip/x-heep

XHEEP_FPGA_BOARD ?= nexys-a7-100t

MODELSIM_FILELIST := build/openhwgroup.org_systems_core-v-mini-mcu_0.3.0/sim-modelsim
VIVADO_FILELIST := build/openhwgroup.org_systems_core-v-mini-mcu_0.3.0/$(XHEEP_FPGA_BOARD)-vivado
FPGA_OUT := $(OUT_DIR)/fpga

# 1) run the X-HEEP generator, then 2) mirror filelist into out/
hw: mcu-gen questa update-$(ACCEL_NAME)-sverilog update-$(ACCEL_NAME)-verilog mirror-filelist

$(ACCEL_NAME)-vivado:
	$(MAKE) mcu-gen
	$(MAKE) vivado-setup
	$(MAKE) update-$(ACCEL_NAME)-sverilog-vivado
	$(MAKE) update-$(ACCEL_NAME)-verilog-vivado
	$(MAKE) mirror-filelist
	$(MAKE) generate-fpga-ips
	$(MAKE) sw

mcu-gen:
	$(MAKE) -C $(XH_ROOT) mcu-gen X_HEEP_CFG=configs/esp_heep.hjson

questa:
	$(MAKE) -C $(XH_ROOT) questasim-sim

vivado-setup:
	$(MAKE) -C $(XH_ROOT) vivado-fpga-nobuild FPGA_BOARD=$(XHEEP_FPGA_BOARD)

update-$(ACCEL_NAME)-sverilog:
	@set -e; \
	TCL="$(XH_ROOT)/$(MODELSIM_FILELIST)/edalize_build_rtl.tcl"; \
	SV="$(XHEEP_ROOT)/$(ACCEL_NAME).sverilog"; \
	[ -f "$$TCL" ] || { echo "[$(ACCEL_NAME)][ERROR] Missing $$TCL"; exit 1; }; \
	t1="$$(mktemp)"; t2="$$(mktemp)"; \
	awk '/-work[ \t]+work/ { for (i=NF; i>0; i--) if ($$i ~ /\.sv$$/) { print $$i; break } }' "$$TCL" > "$$t1"; \
	awk -v genpref="x-heep/$(MODELSIM_FILELIST)/" -v incdir="$(XHEEP_ROOT)/vlog_incdir" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } bn = p; sub(/^.*\//, "", bn); if (system("[ -f \"" incdir "/" bn "\" ]") == 0) { next } print p }' "$$t1" > "$$t2"; \
	{ grep -v '^x-heep' "$$SV" 2>/dev/null || true; } > "$$SV.new"; \
	cat "$$t2" >> "$$SV.new"; \
	mv "$$SV.new" "$$SV"; \
	rm -f "$$t1" "$$t2"; \
	echo "[$(ACCEL_NAME)] Updated $$SV from $$TCL"

update-$(ACCEL_NAME)-verilog:
	@set -e; \
	TCL="$(XH_ROOT)/$(MODELSIM_FILELIST)/edalize_build_rtl.tcl"; \
	VL="$(XHEEP_ROOT)/$(ACCEL_NAME).verilog"; \
	[ -f "$$TCL" ] || { echo "[$(ACCEL_NAME)][ERROR] Missing $$TCL"; exit 1; }; \
	t1="$$(mktemp)"; t2="$$(mktemp)"; \
	awk '/-work[ \t]+work/ { for (i=NF; i>0; i--) if ($$i ~ /\.v$$/) { print $$i; break } }' "$$TCL" > "$$t1"; \
	awk -v genpref="x-heep/$(MODELSIM_FILELIST)/" -v incdir="$(XHEEP_ROOT)/vlog_incdir" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } bn = p; sub(/^.*\//, "", bn); if (system("[ -f \"" incdir "/" bn "\" ]") == 0) { next } print p }' "$$t1" > "$$t2"; \
	{ grep -v '^x-heep' "$$VL" 2>/dev/null || true; } > "$$VL.new"; \
	cat "$$t2" >> "$$VL.new"; \
	mv "$$VL.new" "$$VL"; \
	rm -f "$$t1" "$$t2"; \
	echo "[$(ACCEL_NAME)] Updated $$VL from $$TCL"

update-$(ACCEL_NAME)-sverilog-vivado:
	@set -e; \
	TCL="$(XH_ROOT)/$(VIVADO_FILELIST)/openhwgroup.org_systems_core-v-mini-mcu_0.3.0.tcl"; \
	SV="$(XHEEP_ROOT)/$(ACCEL_NAME).sverilog"; \
	[ -f "$$TCL" ] || { echo "[$(ACCEL_NAME)][ERROR] Missing $$TCL"; exit 1; }; \
	t1="$$(mktemp)"; t2="$$(mktemp)"; \
	grep 'read_verilog -sv' "$$TCL" | sed 's/.*{\(.*\)}.*/\1/' | grep '\.sv$$' > "$$t1"; \
	awk -v genpref="x-heep/$(VIVADO_FILELIST)/" -v incdir="$(XHEEP_ROOT)/vlog_incdir" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } bn = p; sub(/^.*\//, "", bn); if (system("[ -f \"" incdir "/" bn "\" ]") == 0) { next } print p }' "$$t1" > "$$t2"; \
	{ grep -v '^x-heep' "$$SV" 2>/dev/null || true; } > "$$SV.new"; \
	cat "$$t2" >> "$$SV.new"; \
	mv "$$SV.new" "$$SV"; \
	rm -f "$$t1" "$$t2"; \
	echo "[$(ACCEL_NAME)] Updated $$SV from Vivado $$TCL"

update-$(ACCEL_NAME)-verilog-vivado:
	@set -e; \
	TCL="$(XH_ROOT)/$(VIVADO_FILELIST)/openhwgroup.org_systems_core-v-mini-mcu_0.3.0.tcl"; \
	VL="$(XHEEP_ROOT)/$(ACCEL_NAME).verilog"; \
	[ -f "$$TCL" ] || { echo "[$(ACCEL_NAME)][ERROR] Missing $$TCL"; exit 1; }; \
	t1="$$(mktemp)"; t2="$$(mktemp)"; \
	grep 'read_verilog' "$$TCL" | grep -v 'read_verilog -sv' | sed 's/.*{\(.*\)}.*/\1/' | grep '\.v$$' > "$$t1"; \
	awk -v genpref="x-heep/$(VIVADO_FILELIST)/" -v incdir="$(XHEEP_ROOT)/vlog_incdir" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } bn = p; sub(/^.*\//, "", bn); if (system("[ -f \"" incdir "/" bn "\" ]") == 0) { next } print p }' "$$t1" > "$$t2"; \
	{ grep -v '^x-heep' "$$VL" 2>/dev/null || true; } > "$$VL.new"; \
	cat "$$t2" >> "$$VL.new"; \
	mv "$$VL.new" "$$VL"; \
	rm -f "$$t1" "$$t2"; \
	echo "[$(ACCEL_NAME)] Updated $$VL from Vivado $$TCL"


# Copy every non-empty, non-comment line from $(ACCEL_NAME).sverilog AND $(ACCEL_NAME).verilog into out/<same path>.
# Lines starting with "obi/" are sourced from ip/obi/..., and "x-heep/" from ip/x-heep/...
mirror-filelist:
	@OUT="$(OUT_DIR)"; OBI="$(OBI_ROOT)"; XH="$(XH_ROOT)"; FL="$(VLOG_FILELIST)"; VL="$(XHEEP_ROOT)/$(ACCEL_NAME).verilog"; \
	echo "[$(ACCEL_NAME)] Mirroring filelist -> $$OUT"; \
	for LIST in "$$FL" "$$VL"; do \
	  [ -f "$$LIST" ] || { echo "[$(ACCEL_NAME)][WARN] Missing list $$LIST, skipping"; continue; }; \
	  while IFS= read -r rel; do \
	    [ -z "$$rel" ] && continue; \
	    case "$$rel" in \#*) continue ;; esac; \
	    prefix=$${rel%%/*}; rest=$${rel#*/}; \
	    if [ "$$prefix" = "obi" ]; then src="$$OBI/$$rest"; \
	    elif [ "$$prefix" = "x-heep" ]; then src="$$XH/$$rest"; \
	    else echo "[$(ACCEL_NAME)][ERROR] Unknown prefix in $$rel (from $$LIST)"; exit 1; fi; \
	    [ -f "$$src" ] || { echo "[$(ACCEL_NAME)][ERROR] Source not found: $$src (from $$rel in $$LIST)"; exit 1; }; \
	    dst="$$OUT/$$rel"; \
	    mkdir -p "$$(dirname "$$dst")"; \
	    if ! cmp -s "$$src" "$$dst" 2>/dev/null; then cp "$$src" "$$dst"; echo "[$(ACCEL_NAME)] COPIED  $$src -> $$dst"; fi; \
	  done < "$$LIST"; \
	done

sw:
	rm -rf $(XH_ROOT)/sw/build
	$(MAKE) -C $(XH_ROOT) RISCV=/home/francesco/tools/riscv  ARCH=rv32imc app PROJECT=esp_app LINKER=on_chip TARGET=sim
	mkdir -p $(XH_ROOT)/sw/generated
	python3 $(ESP_TOP)/$(ACCEL_PATH)/ip/x-heep/util/hex_to_c.py \
		$(XH_ROOT)/sw/generated/$(ACCEL_NAME)_firmware.h \
		$(XH_ROOT)/sw/build/main.hex
	mkdir -p $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)
	mkdir -p $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)/common
	cp $(XH_ROOT)/sw/generated/$(ACCEL_NAME)_firmware.h $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)
	cp $(XH_ROOT)/sw/device/lib/runtime/core_v_mini_mcu.h $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)
	cp $(XH_ROOT)/sw/device/lib/drivers/power_manager/power_manager_regs.h $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)
	cp $(XH_ROOT)/sw/device/lib/drivers/soc_ctrl/soc_ctrl_regs.h $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)
	cp -r $(XH_ROOT)/sw/applications/esp_app/common/. $(ESP_TOP)/soft/common/apps/baremetal/$(ACCEL_NAME)

	cp $(XH_ROOT)/sw/generated/$(ACCEL_NAME)_firmware.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp $(XH_ROOT)/sw/device/lib/runtime/core_v_mini_mcu.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp $(XH_ROOT)/sw/device/lib/drivers/power_manager/power_manager_regs.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp $(XH_ROOT)/sw/device/lib/drivers/soc_ctrl/soc_ctrl_regs.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp -r $(XH_ROOT)/sw/applications/esp_app/common/.  $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t

# Generate FPGA-specific Xilinx Block RAM IP cores
generate-fpga-ips:
	@echo "[$(ACCEL_NAME)] Generating Xilinx Block RAM IP cores"
	@mkdir -p $(FPGA_OUT)
	@cp $(XH_ROOT)/hw/fpga/scripts/generate_sram.tcl $(FPGA_OUT)/generate_$(ACCEL_NAME)_ips.tcl
	@echo "[$(ACCEL_NAME)] Generated IP script at $(FPGA_OUT)/generate_$(ACCEL_NAME)_ips.tcl"

vsim:
	$(info CIAOCIAO)
