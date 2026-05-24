xsc -compile ../../../hw/vendor/lowrisc_opentitan/hw/dv/dpi/uartdpi/uartdpi.c -work "." -gcc_compile_options "-fPIC -O2"
xsc -shared -o ../../../hw/vendor/lowrisc_opentitan/hw/dv/dpi/uartdpi/uartdpi.so -work . -gcc_link_options "-lutil" -gcc_link_options "-pthread"
