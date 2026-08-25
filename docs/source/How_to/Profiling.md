# Profiling

## Overview

X-HEEP supports performance profiling using the
[rv-profile](https://github.com/edge-group-polito/rv_profile) Python package. This tool
provides **cycle-accurate profiling** for RISC-V, allowing you to measure how
many cycles each function consumes during RTL simulation. 


The output is an interactive FlameGraph in `.svg` format, which you can open in
any web browser for analysis.

![FlameGraph](https://vincenzo-petrolo.github.io/flamegraph_example/flamegraph.svg)

Currently, all cores supported by X-HEEP are compatible with [rv-profile](https://github.com/edge-group-polito/rv_profile).

## Profiling with rv-profile

```{warning}
Make sure the `mcycle` CSR is enabled; otherwise, profiling will not work.
```
To enable cycle counting in X-HEEP, add the following to your `main.c`:


```c
#include "csr.h"

...

int main(...) {
    // Enable cycle counting
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    // Reset cycle counter
    CSR_WRITE(CSR_REG_MCYCLE, 0);
    ...
}
```

### Steps to profile
1. Compile your target application.
2. Run the RTL simulation.
3. Generate the FlameGgraph with:

```bash
make profile
```

The FlameGraph will be saved at `util/profile/flamegraph.svg`.

### Viewing the FlameGraph
To open the FlameGraph with a web browser (e.g., Firefox), run:

```bash
firefox util/profile/flamegraph.svg
```
