# Implement on ASIC

This project can be implemented using standard cells based ASIC flow.

## Synthesis with Synopsys Design Compiler

First, you need to provide technology-dependent implementations of some of the cells which require specific instantiation.

Then, please provide a set_libs.tcl and set_constraints.tcl scripts to set link and target libraries, and constraints as the clock.

To generate the `analyze` script for the synthesis scripts with DC, execute:

```
make asic
```

## OpenRoad support for SkyWater 130nm

This relies on a fork of [edalize](https://github.com/davideschiavone/edalize) that contains templates for Design Compiler and OpenRoad.


## Install OpenROAD

First, clone clone `OpenROAD-flow-scripts`

```bash
cd flow
git clone --recursive https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts
cd OpenROAD-flow-scripts
```

Install `OpenRoad` [locally](https://openroad.readthedocs.io/en/latest/user/BuildLocally.html) as,


```bash
sudo ./tools/OpenROAD/etc/DependencyInstaller.sh
sudo ./build_openroad.sh --local
```

Finally, you need to install `KLayout` v0.27.1


Installing OpenRoad and KLayout may not be as straight and forwards, so you may need to install several missing packages
(e.g. Qt for KLayout or libreadline-dev for Yosys, tcl-dev for OpenSTA, etc)

```bash
git clone --depth=1 --branch v0.27.1 https://github.com/KLayout/klayout.git
cd klayout
./build.sh -noruby
```

## Edalize

`x-heep` uses a version of `edalize` + `fusesoc` that supports `sv2v` to convert SystemVerilog to Verilog so that
`OpenRoad` (`yosys`) can compile it.

You need to install `sv2v` as:

```bash
git clone https://github.com/zachjs/sv2v.git
git checkout 36cff4ab0ff3fc64dddb66ef6f3ff4ed80cbd581
cd sv2v
make
```

Follow the instructions at [sv2v](https://github.com/zachjs/sv2v#installation)
and add `sv2v` to the `PATH` variable.

## Run command

```
make openroad-sky130
```
