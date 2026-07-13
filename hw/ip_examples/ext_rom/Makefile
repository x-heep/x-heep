ext_rom = rtl/ext_rom.sv

PYTHON?=python

all: $(ext_rom)

ext_rom_direct.img: $(APP_BIN)
	cp $(APP_BIN) $@
	python3 -c \
	    "import os; n=os.path.getsize('$@'); r=(4-n%4)%4; open('$@','ab').write(b'\x00'*r)"

direct: ext_rom_direct.img
	$(PYTHON) ext_rom_gen.py $<

clean:
	rm -f *.img rtl/ext_rom.sv

.PHONY: all direct clean
