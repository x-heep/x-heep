<br />
<p align="center"><img src="docs/source/images/x-heep-outline.png" width="500"></p>

# X-HEEP

[![Documentation](https://readthedocs.org/projects/x-heep/badge/?version=latest)](https://x-heep.readthedocs.io/en/latest/)
[![License](https://img.shields.io/badge/License-Apache%202.0%20with%20SHL--2.1-blue.svg)](LICENSE)
[![CI](https://github.com/x-heep/x-heep/actions/workflows/ci.yml/badge.svg)](https://github.com/x-heep/x-heep/actions/workflows/ci.yml)
[![Chat](https://img.shields.io/badge/Matrix-%23x--heep:matrix.org-brightgreen)](https://matrix.to/#/#x-heep:matrix.org)

**X-HEEP** (eXtensible Heterogeneous Energy-Efficient Platform) is an open-source, configurable, and extensible **RISC-V microcontroller** described in SystemVerilog.

Originally designed at the [ESL](https://www.epfl.ch/labs/esl/) lab of EPFL, the project has grown into a collaborative effort, currently maintained by the ESL, the [CEI](https://www.cei.upm.es/) at UPM, and POLITO's [VLSI](https://www.vlsilab.polito.it/) lab.

Built on the foundations of the [PULP-Platform](https://pulp-platform.org/) project from ETHZ and UniBO, and the [OpenTitan](https://opentitan.org/) project, X-HEEP blends energy efficiency with an extensible architecture designed for the future of heterogeneous computing.

---

## Features

- **Configurable RISC-V CPUs**: Supports CV32E2, CV32E40P, CV32E40PX (with CV-X-IF), and CV32E40X cores
- **Extensible architecture**: Add custom accelerators via the CV-X-IF interface or as memory-mapped peripherals on the system bus
- **Comprehensive software stack**: Baremetal and FreeRTOS support with HAL drivers, SDK, and CMake-based build system
- **Multi-tool simulation**: Verilator, QuestaSim, VCS, and Xcelium
- **FPGA support**: Pynq-Z2, ZCU104, ZCU102, Nexys-A7-100t, Genesys2, AUP-ZU3
- **ASIC proven**: Multiple tape-outs in TSMC 65nm, GF 22nm, and TSMC 16nm
- **Docker support**: Ready-to-use Docker image with all dependencies

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/x-heep/x-heep.git
cd x-heep

# 2. Pull the Docker image (recommended) or set up manually
make -C util/docker docker-pull
make -C util/docker docker-run

# 3. Inside the container, generate the MCU and run hello world
make mcu-gen
make app
make verilator-run
```

> See the [Setup Guide](https://x-heep.readthedocs.io/en/latest/GettingStarted/Setup.html) for manual installation instructions.

---

## Documentation

Full documentation is available on [Read the Docs](https://x-heep.readthedocs.io/en/latest/).

| Section | Description |
|---------|-------------|
| [Getting Started](https://x-heep.readthedocs.io/en/latest/GettingStarted/index.html) | Setup, generating the MCU, compiling and running software |
| [How to...](https://x-heep.readthedocs.io/en/latest/How_to/index.html) | Simulation, debugging, compiling apps, FPGA, flash programming, and more |
| [Configuration](https://x-heep.readthedocs.io/en/latest/Configuration/index.html) | CPU, memory, bus, pads, peripherals, and linker configuration |
| [Peripherals](https://x-heep.readthedocs.io/en/latest/Peripherals/index.html) | SPI, I2C, DMA, Timer, Serial Link |
| [FPGA](https://x-heep.readthedocs.io/en/latest/FPGA/index.html) | Running on FPGA boards, bitstream generation, debugging with ILA |
| [ASIC](https://x-heep.readthedocs.io/en/latest/ASIC/index.html) | ASIC implementations (HEEPocrates, HEEPnosis, X-TRELA, and more) |
| [Extending](https://x-heep.readthedocs.io/en/latest/Extending/index.html) | Adding custom hardware accelerators and software |
| [Testing](https://x-heep.readthedocs.io/en/latest/Testing/index.html) | CI workflows, VerifHeep verification library |

---

## Repository Structure

```
x-heep/
├── configs/          # MCU configuration files (HJSON and Python)
├── docs/             # Sphinx documentation source
├── hw/               # Hardware (RTL, IPs, FPGA wrappers)
│   ├── ip/           # X-HEEP core IPs
│   ├── ip_examples/  # Example IPs for reference
│   ├── vendor/       # Vendored third-party IPs
│   ├── fpga/         # FPGA board wrappers and constraints
│   └── asic/         # ASIC implementation files
├── sw/               # Software (applications, drivers, HAL, SDK)
│   ├── applications/ # Example applications
│   ├── device/       # HAL, SDK, drivers, linker scripts
│   ├── build/        # Build output
│   └── freertos/     # FreeRTOS integration
├── tb/               # Testbench files
├── test/             # Test and verification scripts
├── util/             # Utilities (vendor tool, Docker, etc.)
├── scripts/          # Build and simulation scripts
├── Makefile          # Top-level Makefile
└── core-v-mini-mcu.core  # FuseSoC core description
```

---

## Block Diagram

<p align="center"><img src="docs/source/images/xheep_diagram.svg" width="1000"></p>

X-HEEP's architecture is divided into power domains: CPU subsystem, memory banks, peripheral subsystem, and always-on peripheral subsystem. Each domain can be independently clock-gated or power-gated for energy efficiency.

---

## Community

- **Documentation**: [x-heep.readthedocs.io](https://x-heep.readthedocs.io/en/latest/)
- **Matrix Chat**: [#x-heep:matrix.org](https://matrix.to/#/#x-heep:matrix.org)
- **GitHub Issues**: Report bugs and request features
- **Contributions**: Pull requests are welcome! See our [Testing](https://x-heep.readthedocs.io/en/latest/Testing/Testing.html) guide for CI information.

---

## Reference

If you use X-HEEP in your academic work, please cite:

```bibtex
@INPROCEEDINGS{machetti2025xheep,
  author={Machetti, Simone and Schiavone, Pasquale Davide and Ansaloni, Giovanni and Peón-Quirós, Miguel and Atienza, David},
  booktitle={2025 IEEE Computer Society Annual Symposium on VLSI (ISVLSI)},
  title={X-HEEP: An Open-Source, Configurable and Extendible RISC-V Platform for TinyAI Applications},
  year={2025},
  doi={10.1109/ISVLSI65124.2025.11130281}
}
```

---

## License

X-HEEP is licensed under [Apache 2.0 with SHL-2.1](LICENSE), unless otherwise noted in specific subdirectories.
