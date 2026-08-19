#  Execute Code from FLASH

## Boot Procedure

The microcontroller has a boot rom where the RISC-V CPU jumps to
at reset time.
The boot rom contains code for two different booting modes:

1. JTAG
2. SPI Flash Loading

These two modes are mainly controlled by input pin `boot_sel_i`.

| `boot_sel_i` | `boot procedure`     |
| ------------ | -------------------- |
| 0			   | JTAG                 |
| 1			   | SPI Flash Loading    |


On the FPGA, such inputs are mapped to two switch buttons.
Below, a description of the three modes is provided.

### JTAG Boot Procedure

In this boot procedure, when the CPU enters the boot rom,
it loops forever. The JTAG programmer (e.g., openOCD) must
load the memory as described in `Debug.md` and set the
booting address. During this procedure, the CPU runs
in `debug mode` until the JTAG (e.g., GDB) tells it to start
executing the code.

To use this mode, when targeting ASICs or FPGA bitstreams,
make sure you have the `boot_sel_i` input (e.g., a switch) set to 0,
and connect the JTAG cable to the microcontroller.

The `Debug.md` guide gives details about how to program the microcontroller
in this mode.

For simulation targets, by default, the testbench uses this mode.
However, this procedure is very slow. For this reason, we use pre-loading instead.
While the CPU loops in the boot rom, it also checks a memory mapped flag that
the testbench can set to 1 after pre-loading the memories.
Then it loads the `boot_address` from a memory-mapped register that is set to
0x180 at reset time, which is also the boot address specified in the entry point of the
linked scripts.
If you want to simulate the actual JTAG procedure without pre-loading instead,
compile the RTL with the `FUSESOC_PARAM="--JTAG_DPI=1"` flag and follow the `Debug.md` guide.


### SPI Flash Loading Boot Procedure

In this boot procedure, when the CPU enters the boot rom, it uses the OpenTitan SPI (SPI host) to copy the first 1KB content of the FLASH (starting at address 0) to the RAM (starting at address 0). Then, the CPU jumps to the entry point at 0x00000180 (in RAM) and executes the start function of the crt0 file (which is contained inside the 1KB copied in RAM). This function checks if the code is completely copied (i.e., less or equal to 1 KB); in this case, it jumps to the main function, or, if more code needs to be copied, it uses the OpenTitan SPI to copy the remaining bytes of code.

To use this mode, when targeting ASICs or FPGA bitstreams,
make sure you have the `boot_sel_i` input (e.g., a switch) set to 1.

Make sure to compile your SW using the link_flash_load.ld linker script.

In this repository, we provide two examples to try, one for FPGA/ASIC
only, which toggles a GPIO forever (in simulation, this would never finish),
and the hello_world example.

To use the link_flash_load.ld linker script, do:

```
make app LINKER=flash_load
or
make app PROJECT=gpio_pmw LINKER=flash_load
```
Then, when launching the simulation, pass the argument `boot_sel=1`
to set the `boot_sel_i` input to `1`.

```
make run PLUSARGS="c firmware=../../../sw/build/main.hex boot_sel=1"
```

If you are using FPGAs or ASIC, make sure to program the FLASH first (while in simulation, the FLASH model will load the binary by itself).

Still as experimental and in draft mode, we also developed an HW peripheral that can be used to automatically control reading and writing operations from/to the FLASH, avoiding the execution of long software procedures.
Such peripheral is called `w25q128jw_controller`. Once stable and tested further, this peripheral will replace the software functions as well as the `yosys` SPI module. In addition, the two booting modes that use the FLASH will be unified. Such peripheral has been only tested in simulation.
