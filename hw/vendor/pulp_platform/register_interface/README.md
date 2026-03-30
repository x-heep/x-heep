# Generic Register Interface

This repository contains a simple register interface definition as well as protocol adapters from APB, AXI-Lite, and AXI to said interface. Furthermore, it allows to generate a uniform register interface.

## Read Timing

![Read Timing](docs/timing_read.png)

## Write Timing

![Write Timing](docs/timing_write.png)

## Register File Generator

We re-use lowrisc's register file generator to generate arbitrary configuration registers from an `hjson` description. See the the [tool's description](https://opentitan.org/book/util/reggen/index.html) for further usage details.

We use the [bender import tool](https://github.com/pulp-platform/bender#import-----copy-files-from-dependencies-that-do-not-support-bender) (`>v0.27.0`) to get the sources and apply our custom patches on top.

    curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh -s -- 0.28.1
    ./bender vendor init

to re-vendor.
