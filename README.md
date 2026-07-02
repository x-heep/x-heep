# Porting X-HEEP to open-source EDA tools
---
# Usage
## Environment Setup
All the following commands were tested on TCL PC's infrastructure.
It required navigating in the root of the project and run :

`source start_env.sh`

Which sets up the conda environment and define paths, environment variables and Xilinx licence.
This file also contains instruction on downloading RISC-V compiler if needed.
This is more made for potential future X-HEEP users rather than people already set-up.

## Common steps

Make sure to start from fresh state with : 

`make clean-all`

Then generate the configuration (minimal + uart) :

`make mcu-gen X_HEEP_CFG=configs/lattice.hjson`

Create the Hello World app :

`make app PROJECT=hello_world`

## Simulation steps

After common steps, for simulation, you need to build it with : 

`make verilator-build-lattice` 

Then you need to run the simulation with :

`make verilator-run-lattice`

You should have seen the `hello world!` in the terminal. In case you want to look deeper into the signals you can look at the waveforms with :

`make verilator-waves-lattice`

## FPGA steps

After common steps, for FPGA flow, you need to run :

`make lattice-fpga`

When the synthesis and place & route is done (approx. 10 min.), program the board (previously plugged with USB cable to the PC) with :

`make lattice-prog`

You should see a small red LED blink rapidly during the programming, and once it is done the main green LED should start blinking.

From there you need three terminals:

### -- Terminal 1
This one is just to observe UART communication coming from the board (adapt to your picocom location):

`../picocom -b 1250000 -r -l --imap lfcrlf /dev/ttyACM0`

### -- Terminal 2
This one put the board in a state in which it can be accessed with GDB :

`make lattice-load-sw`

### -- Terminal 3
This one will run GDB, load the software and start the program. Start GDB with (adapt to your GDB location) : 

`../tools/risc-v/bin/riscv32-corev-elf-gdb -nx ./sw/build/main.elf`

The in GDB do :

in (gdb) : `set remotetimeout 2000`

in (gdb) : `target remote localhost:3333`

in (gdb) : `load`

in (gdb) : `continue`

After the last command the `hello world!` should appear in the Terminal 1 (with picocom)

---

# Additional details on changes

Here I will add details on some of the work / modifications done for the project. 
I will mention things I think are useful for understanding and not go into details about things that seem trivial.
I will of course stay available in case anything is unclear and needs more details or explanation.
The complete list of modification can be easily seen on the [Pull Request of the project](https://github.com/x-heep/x-heep/pull/976).

## `hw/fpga/xheep_fpga_support/rtl/lattice` folder

The files contained in this folder are based on the ones from the `hw/fpga/xheep_fpga_support/rtl` folder. 
The issue with the original file is that they rely on Xilinx specific primitives that are not compatible with target flow.
The new version of theses files use SystemVerilog behaviourally equivalent code to replace theses primitives.
While some of this code could have been replaced by Lattice compatible primitives, 
plain code was preferred as some primitives require certain hardware cells to be present, 
and issues arise because of the limited hardware of the iCESugar-pro.

The best example of this is the domain clock select cells DCSC (Lattice) which were tried to replace the DCS (Xilinx) ones.
Given the iCESugar-pro only has 2 DCSC cells physically present on the board, the synthesis failed as the design required 3 of them.
Using the SystemVerilog equivalent allowed the synthesis to implement the behaviour into the general purpose FPGA fabric instead, 
allowing the synthesis to work.

## `fpga_core_v_mini_mcu_wrapper.sv`

This new wrapper is based on the `xilinx_core_v_mini_mcu_wrapper.sv` wrapper. 
It adds some `ifdef` conditions to handle the iCESugar-pro board.

It should be able to replace the original file as it retains all the previous functionality, but this has not been tested.
It would be good to replace calls to `xilinx_core_v_mini_mcu_wrapper.sv` by `fpga_core_v_mini_mcu_wrapper.sv` in core files
and test if the Vivado flow for the PYNQ (and others) board(s) still works.

One other thing that could be made better would be to add a proper clock wrapper (similarly to the other boards) 
so that we would not need the `ifdef` around the `clk_i(...)` input signal in the `x_heep_system` instantiation.

## `.core` files

Two new targets have been created in `core-v-mini-mcu.core` : `sim-lattice` and `icesugar`.
The former is used to make a simulation of the design that also includes the FPGA wrapper. 
This was useful in debugging, but now that the flow has been confirmed working, it's relevancy should be questioned.
The latter is the main target of the project and calls on Project Trellis (Yosys/nextpnr) and the correct cells.

While most parameters of theses two targets are self explanatory, two things are worth mentioning:  
 + Some pre-build scripts are used to modify/create files.  
 + A special script is given to Yosys so that it uses the Slang plugin.   

Theses scripts are talk about in more details in the following [scripts](#scripts) section. 

Fileset and scripts are also added or modified to handle the new elements.

`tb/x-heep-tb-utils.core` and `hw/vendor/pulp_platform_tech_cells_generic.core` are modified to accommodate the new simulation target.

`hw/fpga/xheep_fpga_support/core-v-mini-mcu-fpga.core` is also modified to accommodate the new FPGA target.

## Scripts

Multiple scripts have been created to automate some tasks, they are all in the `scripts/icesugar` folder.

### `scripts/icesugar/icesugarpro_fpga.cfg` and `scripts/icesugar/icesugarpro_xheep.cfg`
Theses config files are used so that GDB can connect and program the FPGA/X-HEEP.

### `scripts/icesugar/change_sram_module.sh`
This script modify the `hw/fpga/xheep_fpga_support/rtl/sram_wrapper.sv` file so that it instantiate the correct memory.
Ideally this should be done beforehand by modifying the `sram_wrapper.sv.tpl` file, but given that the target is not
yet specified when the wrapper is generated (during `make mcu-gen`) we can not yet use a parameter to conditionally
change the it. 

This could be circumvented by testing the custom memory module with other FPGA and, if it works, replacing the
xilinx implementation in the `.tpl`, removing the need for this script.

### `scripts/icesugar/add_simulation_parameters.sh` and `scripts/icesugar/remove_simulation_parameters.sh`
Theses script modify the `hw/fpga/fpga_core_v_mini_mcu_wrapper.sv` file by (de)commenting
two parameters given to the X-HEEP system instance. This is so that both the 
simulation (which needs theses parameters) and the synthesis (which needs theses 
parameters to have their default values) can work.

If we remove the simulation which takes the wrapper into account (sim-lattice), 
then theses parameters won't be needed anymore and the scripts can be removed.

### `scripts/icesugar/edalize_yosys_template.tcl`
This script is passed to Yosys and is made so that the Slang plugin is loaded and
used correctly with the `read_slang` calls. Some other commands and settings
assure a working synthesis.

Ideally, Edalize could be modified so that it would generate this script automatically.
The scripts with which they generate those `.tcl` are visible in their repository, 
one could probably be adapted quite easily by taking our script as example.

### `scripts/icesugar/generate_yosys_filelist.sh`
This script generate a filelist in the correct format so that the call to `read_slang`
in the `edalize_yosys_template.tcl` can read it.

Ideally, as above, Edalize could be modified to generate this one automatically.

## `hw/fpga/xheep_fpga_support/board_files/icesugarpro/icesugar_pins.lpf`
This file contains the pin constraint for the iCESugar-pro board.
Most of it is derived from [the examples](https://github.com/wuxx/icesugar-pro/tree/master/src)
project from the official repository.

Given that their is no switch to set `boot_select_i` to `0` as with the PYNQ board,
an alternative was found to use the line :

`IOBUF PORT "boot_select_i" PULLMODE=DOWN;`

Which as far as I could observe mimics setting this input to `0` and allows to
load software on the board correctly.

Ideally the iCESugar-pro would connect the pin to ground physically with the help of an
extension board and/or a wire/switch, and the line above would not be needed.

# Issue with UART baud rate
There is an issue with the baud rate of the UART transmission from the board to 
the PC that I did not have time to investigate. To be able to read the `hello world!`
correctly, when launching `picocom` the baud rate have to be set to `1250000`.
This value was found by looking, with an oscilloscope, at the width of the pulse 
of the UART transmission (directly on a pin of the iCELink chip).

The reason for this issue is still unknown.

# Future work
- Modifications so we can delete the scripts :
  - modify the SRAM template (see if the new memory module can replace the proprietary one in typical flow (Vivado/Xilinx))
  - modify Edalize to generate a correct command template for Yosys + Slang plugin
  - modify Edalize to generate file list compatible with `read_slang`
  - modify simulation so that it does not need parameters for `x_heep_system` instance in FPGA wrapper
  - (alternatively remove simulation with wrapper (`sim-lattice`) altogether)
-  Create a clock wrapper for iCESugar-pro to use in the FPGA wrapper
-  Check if the new FPGA wrapper can replace the Xilinx one in typical flow (Vivado/Xilinx)
-  Verify that theses changes did not break typical FPGA flow (Vivado/Xilinx)
- Find out why the UART transmission baud rate is so high

Finally, the way I had to use three terminals to actually make the software run 
on the board seems all but efficient. I think there might be a better way to do 
this.





















