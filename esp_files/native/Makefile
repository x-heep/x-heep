ACCEL_NAME := xheep

.PHONY: hw sw mcu-gen questa vivado-setup $(ACCEL_NAME)-vivado update-$(ACCEL_NAME)-filelists clean

ESP_TOP ?= $(abspath $(CURDIR)/../../..)
ACCEL_PATH := accelerators/rtl/$(ACCEL_NAME)_rtl

# Roots
XHEEP_ROOT := $(ESP_TOP)/$(ACCEL_PATH)
XH_ROOT    := $(XHEEP_ROOT)/vendor/x-heep

VLOG_INCDIRS  ?= $(XH_ROOT)/esp_files/third-party/vlog_incdir
VLOG_FILELIST ?= $(XHEEP_ROOT)/$(ACCEL_NAME)_rtl.sverilog
VLOG_VERILOG  ?= $(XHEEP_ROOT)/$(ACCEL_NAME)_rtl.verilog
export VLOG_INCDIRS VLOG_FILELIST
$(info [$(ACCEL_NAME)] VLOG_FILELIST=$(VLOG_FILELIST))
$(info [$(ACCEL_NAME)] VLOG_INCDIRS=$(VLOG_INCDIRS))

X_HEEP_CFG ?= configs/esp_heep.hjson
XHEEP_FPGA_BOARD ?= nexys-a7-100t
MODELSIM_FILELIST := build/openhwgroup.org_systems_core-v-mini-mcu_0.3.0/sim-modelsim
VIVADO_FILELIST := build/openhwgroup.org_systems_core-v-mini-mcu_0.3.0/$(XHEEP_FPGA_BOARD)-vivado
EDA_FILELIST_MODELSIM := $(XH_ROOT)/$(MODELSIM_FILELIST)/openhwgroup.org_systems_core-v-mini-mcu_0.3.0.eda.yml
EDA_FILELIST_VIVADO := $(XH_ROOT)/$(VIVADO_FILELIST)/openhwgroup.org_systems_core-v-mini-mcu_0.3.0.eda.yml

OUT_DIR := $(XHEEP_ROOT)/out
FPGA_OUT := $(OUT_DIR)/fpga

RISCV ?= /home/francesco/tools/riscv

ESP_LINUX_APP ?= 
ESP_BAREMETAL_APP ?= 
XHEEP_APPS ?= 

# Run the X-HEEP generator, then update filelists
hw: mcu-gen questa
	@rm -rf "$(XHEEP_ROOT)/vlog_incdir"/*
	$(MAKE) update-$(ACCEL_NAME)-filelists FLOW=modelsim

$(ACCEL_NAME)-vivado:
	$(MAKE) mcu-gen
	$(MAKE) vivado-setup
	@rm -rf "$(XHEEP_ROOT)/vlog_incdir"/*
	$(MAKE) update-$(ACCEL_NAME)-filelists FLOW=vivado
	$(MAKE) sw

mcu-gen:
	$(MAKE) -C $(XH_ROOT) mcu-gen X_HEEP_CFG=$(X_HEEP_CFG)

questa:
	$(MAKE) -C $(XH_ROOT) questasim-sim

vivado-setup:
	$(MAKE) -C $(XH_ROOT) vivado-fpga-nobuild FPGA_BOARD=$(XHEEP_FPGA_BOARD)

update-$(ACCEL_NAME)-filelists:
	@set -e; \
	FLOW="$(FLOW)"; \
	case "$$FLOW" in \
		""|modelsim) FLOW=modelsim ;; \
		vivado) ;; \
		*) echo "[$(ACCEL_NAME)][ERROR] Unknown FLOW '$$FLOW' (use modelsim or vivado)"; exit 1 ;; \
	esac; \
	if [ "$$FLOW" = "vivado" ]; then \
		FILELIST_DIR="$(VIVADO_FILELIST)"; \
		EDA="$(EDA_FILELIST_VIVADO)"; \
		TCL="$(XH_ROOT)/$(VIVADO_FILELIST)/openhwgroup.org_systems_core-v-mini-mcu_0.3.0.tcl"; \
		[ -f "$$TCL" ] || { echo "[$(ACCEL_NAME)][ERROR] Missing $$TCL"; exit 1; }; \
	else \
		FILELIST_DIR="$(MODELSIM_FILELIST)"; \
		EDA="$(EDA_FILELIST_MODELSIM)"; \
		TCL=""; \
	fi; \
	[ -f "$$EDA" ] || { echo "[$(ACCEL_NAME)][ERROR] Missing $$EDA"; exit 1; }; \
	t_sv="$$(mktemp)"; t_v="$$(mktemp)"; t_sv2="$$(mktemp)"; t_v2="$$(mktemp)"; tinc="$$(mktemp)"; \
	if [ "$$FLOW" = "vivado" ]; then \
		grep 'read_verilog -sv' "$$TCL" | sed 's/.*{\(.*\)}.*/\1/' | grep '\.sv$$' > "$$t_sv"; \
		grep 'read_verilog' "$$TCL" | grep -v 'read_verilog -sv' | sed 's/.*{\(.*\)}.*/\1/' | grep '\.v$$' > "$$t_v"; \
		awk ' \
			/^- / { inc=0; incpath="" } \
			/^[[:space:]]*include_path:[[:space:]]*/ { incpath=$$2 } \
			/^[[:space:]]*is_include_file:[[:space:]]*true/ { inc=1 } \
			/^[[:space:]]*name:[[:space:]]*/ { \
				p=$$2; \
				if (inc && p ~ /\.(sv|svh|v)$$/) { if (incpath == "") incpath="."; print incpath "\t" p >> incout; next } \
			} \
		' incout="$$tinc" "$$EDA"; \
	else \
		awk ' \
			/^- / { inc=0; incpath="" } \
			/^[[:space:]]*include_path:[[:space:]]*/ { incpath=$$2 } \
			/^[[:space:]]*is_include_file:[[:space:]]*true/ { inc=1 } \
			/^[[:space:]]*name:[[:space:]]*/ { \
				p=$$2; \
				if (inc && p ~ /\.(sv|svh|v)$$/) { if (incpath == "") incpath="."; print incpath "\t" p >> incout; next } \
				if (!inc && p ~ /\.sv$$/) print p >> svout; \
				if (!inc && p ~ /\.v$$/) print p >> vout; \
			} \
		' incout="$$tinc" svout="$$t_sv" vout="$$t_v" "$$EDA"; \
	fi; \
	mkdir -p "$(XHEEP_ROOT)/vlog_incdir"; \
	while IFS=$$'\t' read incpath p; do \
		src="$(XH_ROOT)/$$FILELIST_DIR/$$p"; \
		rel="$$(basename "$$p")"; \
		if [ "$$incpath" = "." ]; then incpath=""; fi; \
		if [ -n "$$incpath" ] && [ "$$p" != "$$incpath" ]; then \
			prefix="$$incpath"; \
			case "$$prefix" in */) ;; *) prefix="$$prefix/";; esac; \
			case "$$p" in $$prefix*) rel="$${p#$$prefix}";; esac; \
		fi; \
		dst="$(XHEEP_ROOT)/vlog_incdir/$$rel"; \
		mkdir -p "$$(dirname "$$dst")"; \
		if [ -f "$$src" ]; then cp -f -p "$$src" "$$dst"; fi; \
	done < "$$tinc"; \
	awk -v genpref="x-heep/$$FILELIST_DIR/" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } print p }' "$$t_sv" > "$$t_sv2"; \
	awk -v genpref="x-heep/$$FILELIST_DIR/" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } print p }' "$$t_v" > "$$t_v2"; \
	{ grep -v '^x-heep' "$(VLOG_FILELIST)" 2>/dev/null || true; } > "$(VLOG_FILELIST).new"; \
	cat "$$t_sv2" >> "$(VLOG_FILELIST).new"; \
	mv "$(VLOG_FILELIST).new" "$(VLOG_FILELIST)"; \
	{ grep -v '^x-heep' "$(VLOG_VERILOG)" 2>/dev/null || true; } > "$(VLOG_VERILOG).new"; \
	cat "$$t_v2" >> "$(VLOG_VERILOG).new"; \
	mv "$(VLOG_VERILOG).new" "$(VLOG_VERILOG)"; \
	rm -f "$$t_sv" "$$t_v" "$$t_sv2" "$$t_v2" "$$tinc"; \
	echo "[$(ACCEL_NAME)] Updated $(VLOG_FILELIST) and $(VLOG_VERILOG) for $$FLOW"

sw:
	rm -rf $(XH_ROOT)/sw/build
	@for app_cur in $(XHEEP_APPS); do \
		echo "[$(ACCEL_NAME)] Building X-HEEP app $$app_cur"; \
		$(MAKE) -C $(XH_ROOT) RISCV_XHEEP=$(RISCV_XHEEP) ARCH=rv32imc app PROJECT=$$app_cur LINKER=on_chip TARGET=sim COMPILER_FLAGS+=" -I$(XH_ROOT)/sw/vendor/esp_common" || exit $$?; \
		header="$(ACCEL_NAME)_fw_$${app_cur}.h"; \
		fw_symbol="$(ACCEL_NAME)_fw_$${app_cur}"; \
		mkdir -p $(XH_ROOT)/sw/generated; \
		python3 $(XH_ROOT)/util/hex_to_c.py \
			$(XH_ROOT)/sw/generated/$$header \
			$(XH_ROOT)/sw/build/main.hex \
			--name $$fw_symbol || exit $$?; \
		if [ -n "$(ESP_BAREMETAL_APP)" ]; then \
			mkdir -p $(XHEEP_ROOT)/sw/baremetal/app/$(ESP_BAREMETAL_APP)/common; \
			cp $(XH_ROOT)/sw/generated/$$header $(XHEEP_ROOT)/sw/baremetal/app/$(ESP_BAREMETAL_APP)/common; \
			cp $(XH_ROOT)/sw/device/lib/runtime/core_v_mini_mcu.h $(XHEEP_ROOT)/sw/baremetal/app/$(ESP_BAREMETAL_APP)/common; \
			cp $(XH_ROOT)/sw/device/lib/drivers/power_manager/power_manager_regs.h $(XHEEP_ROOT)/sw/baremetal/app/$(ESP_BAREMETAL_APP)/common; \
			cp $(XH_ROOT)/sw/device/lib/drivers/soc_ctrl/soc_ctrl_regs.h $(XHEEP_ROOT)/sw/baremetal/app/$(ESP_BAREMETAL_APP)/common; \
			cp -r $(XH_ROOT)/sw/applications/$${app_cur}/common/. $(XHEEP_ROOT)/sw/baremetal/app/$(ESP_BAREMETAL_APP)/common; \
			cp -r $(XHEEP_ROOT)/sw/baremetal/app/$(ESP_BAREMETAL_APP) $(ESP_TOP)/soft/common/apps/baremetal; \
			cp -r $(XHEEP_ROOT)/sw/baremetal/include $(ESP_TOP)/soft/common/apps/baremetal/$(ESP_BAREMETAL_APP); \
		fi; \
		if [ -n "$(ESP_LINUX_APP)" ]; then \
			mkdir -p $(XHEEP_ROOT)/sw/linux/app/$(ESP_LINUX_APP)/common; \
			cp $(XH_ROOT)/sw/generated/$$header $(XHEEP_ROOT)/sw/linux/app/$(ESP_LINUX_APP)/common; \
			cp $(XH_ROOT)/sw/device/lib/runtime/core_v_mini_mcu.h $(XHEEP_ROOT)/sw/linux/app/$(ESP_LINUX_APP)/common; \
			cp $(XH_ROOT)/sw/device/lib/drivers/power_manager/power_manager_regs.h $(XHEEP_ROOT)/sw/linux/app/$(ESP_LINUX_APP)/common; \
			cp $(XH_ROOT)/sw/device/lib/drivers/soc_ctrl/soc_ctrl_regs.h $(XHEEP_ROOT)/sw/linux/app/$(ESP_LINUX_APP)/common; \
			cp -r $(XH_ROOT)/sw/applications/$${app_cur}/common/. $(XHEEP_ROOT)/sw/linux/app/$(ESP_LINUX_APP)/common; \
		fi; \
	done

clean:
	$(MAKE) -C $(XH_ROOT) clean
	rm -rf $(XHEEP_ROOT)/vlog_incdir
	rm -rf $(XH_ROOT)/$(ACCEL_NAME).sverilog
	rm -rf $(XH_ROOT)/$(ACCEL_NAME).verilog
