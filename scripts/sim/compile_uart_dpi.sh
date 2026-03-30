cd ../../../hw/vendor/lowrisc/opentitan/hw/dv/dpi/uartdpi/
cc -shared -Bsymbolic -fPIC -o uartdpi.so -lutil uartdpi.c
cd -
