# X-HEEP quick setup

This is a quick tutorial on how to get started with this tool, more information can be found in the [documentation](https://x-heep.readthedocs.io/en/latest/GettingStarted/Setup.html#manual-setup), this is a manual setup for linux.

### OS requirements: 
For ubuntu:
```
sudo apt install autoconf automake autotools-dev curl python3 python3-pip python3-tomli libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev libslirp-dev help2man perl make g++ libfl2 libfl-dev zlibc zlib1g zlib1g-dev ccache mold libgoogle-perftools-dev numactl libelf-dev
```
For Alma Linux:
```
sudo dnf install -y autoconf automake curl python3 python3-pip libmpc-devel mpfr-devel gmp-devel gawk gcc gcc-c++ bison flex texinfo gperf libtool patchutils bc zlib-devel expat-devel ninja-build git cmake glib2-devel libslirp-devel help2man perl make flex-devel ccache numactl elfutils-libelf-devel
```

### Python:
Create your own python environnement
```
python3 -m venv .venv
source .venv/bin/activate
pip install -r python-requirements.txt
```

### RISC-V toolchain:
Follow the documentation directly if you don't have a `riscv32-unknown` toolchain. \
It can be found [here](https://x-heep.readthedocs.io/en/latest/GettingStarted/Setup.html#install-the-risc-v-compiler)

### Other tool:
Verible and Verilator are needed too.\
After that, all the requirements for x-heep should be satisfied.

# X-HEEP fork with SoCMake Support

This fork adds SoCMake support to x-heep, as a small examples to show SoCMake.

***

<br />
<p align="center"><img src="docs/source/images/x-heep-outline.png" width="500"></p>

# X-HEEP

`X-HEEP` (eXtensible Heterogeneous Energy-Efficient Platform) is a `RISC-V` microcontroller described in `SystemVerilog`.

Originally designed at the [ESL](https://www.epfl.ch/labs/esl/) lab of EPFL, the project has grown into a collaborative effort, currently maintained by the ESL, the [CEI](https://www.cei.upm.es/) at UPM, and POLITO's [VLSI](https://www.vlsilab.polito.it/) lab.

Built on the foundations of the [PULP-Platform](https://pulp-platform.org/) project from ETHZ and UniBO, and the [OpenTitan](https://opentitan.org/) project, `X-HEEP` blends energy efficiency with an extensible architecture designed for the future of heterogeneous computing.

`X-HEEP` can be configured to target small and tiny platforms as well as extended to support multiple and diverse accelerators.
The cool thing about `X-HEEP` is that we provide a simple, customizable MCU, with industry verified CPUs, common peripherals, memories, etc.
so that you can extend it with your own accelerator without modifying the MCU, but just instantiating it in your design.
By doing so, you inherit an IP capable of running baremetal or booting RTOS (such as `freeRTOS`) with the whole FW stack, including `HAL` drivers and `SDK`,
and you can focus on building your special HW or APP supported by the microcontroller.

`X-HEEP` currently supports simulation with Verilator, Questasim, VCS, and Xcelium. Morever, the firmware can be built and linked using `CMake` with either _GCC_ or _Clang_ as backends. It can be implemented on FPGA, and it supports ASIC implementation in silicon, which is its main (but not the only) target for the platform.

The block diagram below shows the `X-HEEP` MCU

<p align="center"><img src="docs/source/images/xheep_diagram.svg" width="1000"></p>

You can access an editable version of this diagram for your use in presentations or publications [here](https://viewer.diagrams.net/?tags=%7B%7D&lightbox=1&highlight=0000FF&edit=_blank&layers=1&nav=1&title=X-HEEP-general-diagram.drawio&dark=auto#Uhttps%3A%2F%2Fdrive.google.com%2Fuc%3Fid%3D1FxAmuywf1zneG0PeiYe_IHTJCv-3kLPI%26export%3Ddownload). 

## :bookmark_tabs: Documentation and Community

You can refer to the documentation in [Read the Docs](https://x-heep.readthedocs.io/en/latest/index.html).

Join the community on Matrix: [#x-heep:matrix.org](https://matrix.to/#/#x-heep:matrix.org).

## Reference

If you use X-HEEP in your academic work you can cite us: [X-HEEP Paper](https://doi.org/10.1109/ISVLSI65124.2025.11130281).

```
@INPROCEEDINGS{machetti2025xheep,
  author={Machetti, Simone and Schiavone, Pasquale Davide and Ansaloni, Giovanni and Peón-Quirós, Miguel and Atienza, David},
  booktitle={2025 IEEE Computer Society Annual Symposium on VLSI (ISVLSI)}, 
  title={X-HEEP: An Open-Source, Configurable and Extendible RISC-V Platform for TinyAI Applications}, 
  year={2025},
  doi={10.1109/ISVLSI65124.2025.11130281}
}
```
