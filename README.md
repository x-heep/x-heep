<br />
<p align="center"><img src="docs/source/images/x-heep-outline.png" width="500"></p>

# X-HEEP

`X-HEEP` (eXtendable Heterogeneous Energy-Efficient Platform) is a `RISC-V` microcontroller described in `SystemVerilog`
that can be configured to target small and tiny platforms as well as extended to support accelerators.
The cool thing about `X-HEEP` is that we provide a simple customizable MCU, so CPUs, common peripherals, memories, etc.
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
