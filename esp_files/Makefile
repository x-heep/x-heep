.PHONY: hw sw mirror-filelist update-xheep-sverilog update-xheep-verilog mcu-gen questa xheep-vivado xheep-sim-restore

ACCEL_NAME := xheep
VLOG_INCDIRS  += $(ESP_TOP)/accelerators/third-party/xheep/vlog_incdir
VLOG_FILELIST += $(ESP_TOP)/accelerators/third-party/xheep/xheep.sverilog
export VLOG_INCDIRS VLOG_FILELIST
$(info [xheep] VLOG_FILELIST=$(VLOG_FILELIST))
$(info [xheep] VLOG_INCDIRS=$(VLOG_INCDIRS))

# roots
XHEEP_ROOT := $(PWD)
OUT_DIR    := $(XHEEP_ROOT)/out
OBI_ROOT   := $(XHEEP_ROOT)/ip/obi
XH_ROOT    := $(XHEEP_ROOT)/ip/x-heep
FPGA_OUT   := $(OUT_DIR)/fpga

MODELSIM_FILELIST := build/openhwgroup.org_systems_core-v-mini-mcu_0.3.0/sim-modelsim

# 1) run the X-HEEP generator, then 2) mirror filelist into out/
hw: mcu-gen questa update-xheep-sverilog update-xheep-verilog mirror-filelist

mcu-gen:
	$(MAKE) -C $(XH_ROOT) mcu-gen X_HEEP_CFG=configs/esp_heep.hjson

questa:
	$(MAKE) -C $(XH_ROOT) questasim-sim

update-xheep-sverilog:
	@set -e; \
	TCL="$(XH_ROOT)/$(MODELSIM_FILELIST)/edalize_build_rtl.tcl"; \
	SV="$(XHEEP_ROOT)/xheep.sverilog"; \
	[ -f "$$TCL" ] || { echo "[xheep][ERROR] Missing $$TCL"; exit 1; }; \
	t1="$$(mktemp)"; t2="$$(mktemp)"; \
	awk '/-work[ \t]+work/ { for (i=NF; i>0; i--) if ($$i ~ /\.sv$$/) { print $$i; break } }' "$$TCL" > "$$t1"; \
	awk -v genpref="x-heep/$(MODELSIM_FILELIST)/" -v incdir="$(XHEEP_ROOT)/vlog_incdir" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } bn = p; sub(/^.*\//, "", bn); if (system("[ -f \"" incdir "/" bn "\" ]") == 0) { next } print p }' "$$t1" > "$$t2"; \
	{ grep -v '^x-heep' "$$SV" 2>/dev/null || true; } > "$$SV.new"; \
	cat "$$t2" >> "$$SV.new"; \
	mv "$$SV.new" "$$SV"; \
	rm -f "$$t1" "$$t2"; \
	echo "[xheep] Updated $$SV from $$TCL"

update-xheep-verilog:
	@set -e; \
	TCL="$(XH_ROOT)/$(MODELSIM_FILELIST)/edalize_build_rtl.tcl"; \
	VL="$(XHEEP_ROOT)/xheep.verilog"; \
	[ -f "$$TCL" ] || { echo "[xheep][ERROR] Missing $$TCL"; exit 1; }; \
	t1="$$(mktemp)"; t2="$$(mktemp)"; \
	awk '/-work[ \t]+work/ { for (i=NF; i>0; i--) if ($$i ~ /\.v$$/) { print $$i; break } }' "$$TCL" > "$$t1"; \
	awk -v genpref="x-heep/$(MODELSIM_FILELIST)/" -v incdir="$(XHEEP_ROOT)/vlog_incdir" '{ p=$$0; if (p ~ /^generated\//) { p = genpref p } else if (p ~ /^(\.\.\/){3}/) { sub(/^(\.\.\/){3}/, "", p); p = "x-heep/" p } else { p = "x-heep/" p } bn = p; sub(/^.*\//, "", bn); if (system("[ -f \"" incdir "/" bn "\" ]") == 0) { next } print p }' "$$t1" > "$$t2"; \
	{ grep -v '^x-heep' "$$VL" 2>/dev/null || true; } > "$$VL.new"; \
	cat "$$t2" >> "$$VL.new"; \
	mv "$$VL.new" "$$VL"; \
	rm -f "$$t1" "$$t2"; \
	echo "[xheep] Updated $$VL from $$TCL"


# Copy every non-empty, non-comment line from xheep.sverilog AND xheep.verilog into out/<same path>.
# Lines starting with "obi/" are sourced from ip/obi/..., and "x-heep/" from ip/x-heep/...
mirror-filelist:
	@OUT="$(OUT_DIR)"; OBI="$(OBI_ROOT)"; XH="$(XH_ROOT)"; FL="$(VLOG_FILELIST)"; VL="$(XHEEP_ROOT)/xheep.verilog"; \
	echo "[xheep] Mirroring filelist -> $$OUT"; \
	for LIST in "$$FL" "$$VL"; do \
	  [ -f "$$LIST" ] || { echo "[xheep][WARN] Missing list $$LIST, skipping"; continue; }; \
	  while IFS= read -r rel; do \
	    [ -z "$$rel" ] && continue; \
	    case "$$rel" in \#*) continue ;; esac; \
	    prefix=$${rel%%/*}; rest=$${rel#*/}; \
	    if [ "$$prefix" = "obi" ]; then src="$$OBI/$$rest"; \
	    elif [ "$$prefix" = "x-heep" ]; then src="$$XH/$$rest"; \
	    else echo "[xheep][ERROR] Unknown prefix in $$rel (from $$LIST)"; exit 1; fi; \
	    [ -f "$$src" ] || { echo "[xheep][ERROR] Source not found: $$src (from $$rel in $$LIST)"; exit 1; }; \
	    dst="$$OUT/$$rel"; \
	    mkdir -p "$$(dirname "$$dst")"; \
	    if ! cmp -s "$$src" "$$dst" 2>/dev/null; then cp "$$src" "$$dst"; echo "[xheep] COPIED  $$src -> $$dst"; fi; \
	  done < "$$LIST"; \
	done

sw:
	rm -rf $(XH_ROOT)/sw/build
	$(MAKE) -C $(XH_ROOT) RISCV=/home/francesco/tools/riscv  ARCH=rv32imc app PROJECT=esp_app LINKER=on_chip TARGET=sim
	mkdir -p $(XH_ROOT)/sw/generated
	python3 $(ESP_TOP)/accelerators/third-party/xheep/ip/x-heep/util/hex_to_c.py \
		$(XH_ROOT)/sw/generated/xheep_firmware.h \
		$(XH_ROOT)/sw/build/main.hex
	mkdir -p $(ESP_TOP)/soft/common/apps/baremetal/xheep
	mkdir -p $(ESP_TOP)/soft/common/apps/baremetal/xheep/common
	cp $(XH_ROOT)/sw/generated/xheep_firmware.h $(ESP_TOP)/soft/common/apps/baremetal/xheep
	cp $(XH_ROOT)/sw/device/lib/runtime/core_v_mini_mcu.h $(ESP_TOP)/soft/common/apps/baremetal/xheep
	cp $(XH_ROOT)/sw/device/lib/drivers/power_manager/power_manager_regs.h $(ESP_TOP)/soft/common/apps/baremetal/xheep
	cp -r $(XH_ROOT)/sw/applications/esp_app/common/. $(ESP_TOP)/soft/common/apps/baremetal/xheep/common

	cp $(XH_ROOT)/sw/generated/xheep_firmware.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp $(XH_ROOT)/sw/device/lib/runtime/core_v_mini_mcu.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp $(XH_ROOT)/sw/device/lib/drivers/power_manager/power_manager_regs.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp $(XH_ROOT)/sw/device/lib/drivers/soc_ctrl/soc_ctrl_regs.h $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t
	cp -r $(XH_ROOT)/sw/applications/esp_app/common/.  $(ESP_TOP)/socs/xilinx-vc707-xc7vx485t

# Prepare X-HEEP for FPGA synthesis by generating Xilinx Block RAM IP cores
xheep-vivado: mcu-gen
	@echo "[xheep] Preparing X-HEEP for Vivado FPGA synthesis..."
	@mkdir -p $(FPGA_OUT)
	@# Copy FPGA-specific wrapper and supporting files
	@echo "[xheep] Copying FPGA-specific wrappers..."
	@cp $(XH_ROOT)/hw/fpga/sram_wrapper.sv $(FPGA_OUT)/
	@cp $(XH_ROOT)/hw/fpga/prim_xilinx_clk.sv $(FPGA_OUT)/
	@cp $(XH_ROOT)/hw/fpga/*_xilinx_*.sv $(FPGA_OUT)/ 2>/dev/null || true
	@cp $(XH_ROOT)/hw/fpga/pad_cell_*_xilinx.sv $(FPGA_OUT)/ 2>/dev/null || true
	@# Generate BRAM IP generation script
	@echo "[xheep] Generating Xilinx Block RAM IP generation script..."
	@cp $(XH_ROOT)/hw/fpga/scripts/generate_sram.tcl $(FPGA_OUT)/
	@# Create a helper script to run IP generation in Vivado
	@echo "# X-HEEP Xilinx BRAM IP Generation Script" > $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "# This script generates Block RAM IP cores for X-HEEP memory banks" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "# Set output directory for IP" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "set ip_dir [file normalize \"$(FPGA_OUT)/ip_repo\"]" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "file mkdir \$$ip_dir" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "cd \$$ip_dir" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "# Source the BRAM generation script" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "source $(FPGA_OUT)/generate_sram.tcl" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "puts \"X-HEEP Xilinx IP generation completed successfully\"" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@echo "" >> $(FPGA_OUT)/generate_xheep_ips.tcl
	@# Backup and update the xheep.sverilog filelist to use FPGA wrapper instead of simulation wrapper
	@echo "[xheep] Updating xheep.sverilog filelist to use FPGA-specific sram_wrapper..."
	@if [ ! -f $(XHEEP_ROOT)/xheep.sverilog.sim_backup ]; then \
		cp $(XHEEP_ROOT)/xheep.sverilog $(XHEEP_ROOT)/xheep.sverilog.sim_backup; \
	fi
	@sed -i.fpgatmp 's|x-heep/hw/simulation/sram_wrapper.sv|fpga/sram_wrapper.sv|g' $(XHEEP_ROOT)/xheep.sverilog
	@rm -f $(XHEEP_ROOT)/xheep.sverilog.fpgatmp
	@echo "[xheep] FPGA preparation complete. Files generated in: $(FPGA_OUT)"
	@echo "[xheep] Updated xheep.sverilog to use FPGA sram_wrapper (backup saved as xheep.sverilog.sim_backup)"
	@echo "[xheep] To generate Xilinx IPs, the vivado.mk will source: $(FPGA_OUT)/generate_xheep_ips.tcl"
	@echo "[xheep] IMPORTANT: Vivado will automatically set XILINX_FPGA=1 and FPGA_SYNTHESIS=1 defines"
	@echo "[xheep] To restore simulation configuration, run: make xheep-sim-restore"

# Restore X-HEEP configuration for simulation (undo xheep-vivado changes)
xheep-sim-restore:
	@echo "[xheep] Restoring X-HEEP simulation configuration..."
	@if [ -f $(XHEEP_ROOT)/xheep.sverilog.sim_backup ]; then \
		mv $(XHEEP_ROOT)/xheep.sverilog.sim_backup $(XHEEP_ROOT)/xheep.sverilog; \
		echo "[xheep] Restored xheep.sverilog to use simulation sram_wrapper"; \
	else \
		echo "[xheep] No backup found. Run 'make hw' to regenerate simulation files."; \
	fi

vsim:
	$(info CIAOCIAO)
