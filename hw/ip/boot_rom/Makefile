# See LICENSE.SiFive for license details

boot_rom = boot_rom.sv

GCC?=$(RISCV_XHEEP)/bin/$(COMPILER_PREFIX)elf-gcc
OBJCOPY?=$(RISCV_XHEEP)/bin/$(COMPILER_PREFIX)elf-objcopy
OBJDUMP?=$(RISCV_XHEEP)/bin/$(COMPILER_PREFIX)elf-objdump
PYTHON?=python

INC_FOLDERS                 = $(sort $(dir $(wildcard ../../../sw/device/lib/drivers/*/)))
INC_FOLDERS                += $(sort $(dir $(wildcard ../../../sw/device/lib/base/*/)))
INC_FOLDERS                += $(sort $(dir $(wildcard ../../../sw/device/lib/runtime/)))
INC_FOLDERS_GCC             = $(addprefix -I ,$(INC_FOLDERS))

all: $(boot_rom) boot_rom.dump

# APP_BIN must be supplied by the caller (path to the application .bin).
boot_rom_direct.img: $(APP_BIN)
	cp $(APP_BIN) $@
	python3 -c \
	    "import os; n=os.path.getsize('$@'); r=(4-n%4)%4; open('$@','ab').write(b'\x00'*r)"

direct: boot_rom_direct.img
	$(PYTHON) gen_rom.py $<
	sed -i 's/module boot_rom_direct/module boot_rom/' boot_rom_direct.sv
	mv boot_rom_direct.sv boot_rom.sv
	rm -f boot_rom_direct.h
	touch .direct_rom

%.sv: %.img
	$(PYTHON) gen_rom.py $<

%.img: %.bin
	dd if=$< of=$@ bs=1024 count=1

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.elf: $(findstring boot_rom, $(boot_rom)).S link.ld
	$(GCC) $(INC_FOLDERS_GCC) -Tlink.ld $< -nostdlib -fPIC -static -Wl,--no-gc-sections -o $@

%.dump: %.elf
	$(OBJDUMP) -d $< --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.text.init --section=.data  > $@

clean:
	rm -f *.img *.bin *.sv .*dump .direct_rom

.PHONY: direct