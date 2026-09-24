# HLS Accelerator Example: Streaming Dot Product

This guide documents a worked example of integrating a [Vitis HLS](https://www.xilinx.com/products/design-tools/vitis/vitis-hls.html)-generated accelerator into X-HEEP, both in Verilator simulation and on the `pynq-z2` FPGA. It doubles as a template for adding your own HLS-generated IP to the project.

The example lives under `hw/fpga/hls/vitis/dot_product/`: a small streaming dot-product engine, written in C++ and synthesized with Vitis HLS, wired into X-HEEP as a memory-mapped accelerator.

```{note}
This whole example is opt-in and gated behind a single FuseSoC flag, `use_hls_example`. Without it, X-HEEP never depends on Vitis HLS being installed -- building and simulating the project works exactly as before. See [Design: opt-in via a FuseSoC flag](#design-opt-in-via-a-fusesoc-flag) below.
```

```{note}
This flow has been tested with `Vivado 2021.1` and `Vitis HLS 2021.1`.
```

## What the accelerator does

`dot_product` computes the dot product of two `int32_t` vectors `a` and `b` of a given `size`, accumulating into a 64-bit result. It is written once in C++ (`dot_product.cpp`/`.h`) and Vitis HLS synthesizes it into three kinds of AXI ports:

- **`gmem_a` / `gmem_b`** -- two independent AXI4 master (read) ports. The core fetches both vectors from memory on its own; no data ever passes through software.
- **`CTRL`** -- one AXI4-Lite slave port bundling the two base addresses, `size`, the 64-bit `result`, and the standard Vitis HLS `ap_ctrl_hs` handshake (`ap_start`/`ap_done`/`ap_idle`/`ap_ready`).

| Offset | Register | Description |
|--------|----------|-------------|
| `0x00` | `AP_CTRL` | bit 0 `ap_start`, bit 1 `ap_done`, bit 2 `ap_idle`, bit 3 `ap_ready` |
| `0x10` | `a` | base address of vector `a` |
| `0x1c` | `b` | base address of vector `b` |
| `0x28` | `size` | number of elements |
| `0x30` / `0x34` | `result` (lo/hi) | 64-bit accumulated dot product |

```{note}
**Why are `a`/`b` only 32 bits from software's side, if HLS ports are 64-bit?**
Vitis HLS derives the `gmem_a`/`gmem_b` AXI address width from the size of the C++ pointer type in `dot_product.cpp` (`const int32_t *`). Since `vitis_hls` runs as a 64-bit host process, it synthesizes 64-bit `m_axi` address ports (`a`/`b` are each a pair of 32-bit registers in hardware, at `0x10`/`0x14` and `0x1c`/`0x20`) -- this is inherent to how Vitis HLS compiles native pointers, not an X-HEEP design choice. X-HEEP only has a 32-bit address space, so `xheep_axi_to_obi_bridge` truncates the AXI address down to 32 bits before it reaches the OBI bus.

The upper 32-bit half of each pointer register (`0x14`, `0x20`) resets to `0` in the HLS-generated CTRL block and nothing else ever writes it, so it stays `0` without software ever touching it -- the 64-bit-pointer detail is entirely internal to the accelerator and invisible from X-HEEP's/software's point of view. `example_dot_product_hls/main.c` only ever writes the low word.
```

Since X-HEEP's bus is OBI, not AXI, two small reusable bridges do the protocol conversion (both under `hw/ip/`, independent of `dot_product` and reusable for any future AXI-based accelerator):

- **`xheep_obi_to_axi_bridge`** -- OBI master (e.g. the CPU) &rarr; AXI4-Lite slave. Used for the `CTRL` port.
- **`xheep_axi_to_obi_bridge`** -- AXI4 master &rarr; OBI master. Used for `gmem_a` and `gmem_b`, so the accelerator's own memory reads become ordinary OBI transactions into X-HEEP's system bus.

`hw/fpga/hls/vitis/dot_product/rtl/dot_product_xheep_wrapper.sv` ties the generated `dot_product` core and both bridges together into a single clean module exposing three plain OBI ports: one OBI slave (`ctrl_obi_*`) and two OBI masters (`gmem_a_obi_*`, `gmem_b_obi_*`).

## Design: opt-in via a FuseSoC flag

Passing `--flag use_hls_example` to any `fusesoc`-driven build (via `FUSESOC_FLAGS`) does three things, all defined in `core-v-mini-mcu.core`:

1. Defines the SystemVerilog macro `` `USE_HLS_EXAMPLE `` (a `vlogdefine` parameter), which gates every instantiation of the accelerator in `tb/testharness.sv.tpl` and `hw/fpga/xilinx_core_v_mini_mcu_wrapper.sv` behind `` `ifdef USE_HLS_EXAMPLE ``.
2. Makes `epfl:ip:dot_product` (the accelerator's own FuseSoC core, `hw/fpga/hls/vitis/dot_product/dot_product.core`) a dependency of the simulation (`tb/x-heep-tb-utils.core`) and FPGA (`rtl-fpga` fileset) builds. Without the flag, FuseSoC never even looks for this core or its generated RTL.
3. Registers a `pre_build` hook, `generate_hls_dot_product`, which runs `hw/fpga/hls/vitis/dot_product/generate_core.sh` (i.e. Vitis HLS) automatically before the build -- so passing the flag is enough; you never have to run the HLS synthesis step yourself.

Without the flag, `dot_product`'s generated Verilog (which is gitignored, see below) does not need to exist on disk at all, and nothing in X-HEEP requires Vitis HLS to be installed.

## Simulating with Verilator

Generate the MCU, then build and run as usual, adding the flag:

```sh
source <vivado-installation-path>/settings64.sh
source <vitis_hls-installation-path>/settings64.sh

make mcu-gen
make verilator-build FUSESOC_FLAGS="--flag use_hls_example"
make app PROJECT=example_dot_product_hls TARGET=sim
make verilator-run FUSESOC_FLAGS="--flag use_hls_example"
```

`example_dot_product_hls` (`sw/applications/example_dot_product_hls/main.c`) writes the two vector addresses and `size` into the `CTRL` registers, pulses `ap_start`, polls `ap_done`, and checks the result against a CPU-computed reference:

```
Dot Product Accelerator Successful: 0x0000000000000330
```

```{note}
Sourcing Vivado's and Vitis HLS's `settings64.sh` is only required because of the `use_hls_example` flag (it triggers the HLS synthesis hook). A plain `make verilator-build` (no flag) never needs them.
```

## Building and programming the pynq-z2 bitstream

Follow the same flow as any other FPGA build (see [Run on FPGA](./RunOnFPGA.md)), adding the flag:

```sh
source <vivado-installation-path>/settings64.sh
source <vitis_hls-installation-path>/settings64.sh

make vivado-fpga FPGA_BOARD=pynq-z2 FUSESOC_FLAGS="--flag use_hls_example"
make vivado-fpga-pgm FPGA_BOARD=pynq-z2
```

Without the flag, `make vivado-fpga FPGA_BOARD=pynq-z2` builds the exact same bitstream as before this example existed -- no accelerator, no extra logic, no Vitis HLS dependency.

### How the accelerator is wired on FPGA

Unlike the testbench (which uses a small dedicated crossbar for external masters/slaves), `core_v_mini_mcu` on FPGA is normally built "unextended" (`EXT_XBAR_NMASTER=0`, no external masters at all). Adding the accelerator without pulling in a full crossbar uses two different mechanisms, both only active under `` `ifdef USE_HLS_EXAMPLE ``:

- **`gmem_a` / `gmem_b`** (the accelerator's own two memory-read masters) are wired to `x_heep_system`'s `ext_xbar_master_req_i`/`resp_o` ports, with `EXT_XBAR_NMASTER` overridden to `2`. These genuinely go through X-HEEP's real system crossbar, since there are two masters that need arbitration for the shared memory/peripheral space.
- **`CTRL`** (the single OBI slave the CPU configures) is wired directly to `ext_core_data_req_o`/`ext_core_data_resp_i` -- X-HEEP's existing per-master address demux already gives the CPU's data bus a dedicated "external slave" output for the `EXT_SLAVE_START_ADDRESS` region (`0xC000_0000`, the same region the testbench and software already use), completely independent of the internal crossbar. Since there is exactly one master on that path, no arbitration/crossbar is needed at all -- it's a direct point-to-point connection.

This wiring lives in `hw/fpga/xilinx_core_v_mini_mcu_wrapper.sv`, scoped to the non-PS-enabled FPGA boards (pynq-z2 included).

## Extending: adding your own HLS accelerator

The pieces above are deliberately generic and reusable:

- `xheep_obi_to_axi_bridge` / `xheep_axi_to_obi_bridge` (`hw/ip/`) work for any AXI4 / AXI4-Lite port shape, not just `dot_product`'s.
- `hw/fpga/hls/vitis/dot_product/generate_core.sh` is a template for a Vitis HLS &rarr; FuseSoC `.core` generation script: it runs `vitis_hls -f run_hls.tcl` (C-synthesizing `dot_product.cpp`), copies the resulting Verilog into the stable `rtl/hls/` directory, and regenerates `dot_product.core` to list it. This is exactly the script the `generate_hls_dot_product` pre-build hook runs for you -- you only need to touch it directly if you're modifying `dot_product.cpp`/`dot_product.h` and want to re-synthesize without rebuilding the whole simulation/bitstream.

  The script skips re-running Vitis HLS (and doesn't need it installed) if `rtl/hls/` already holds RTL newer than `dot_product.cpp`/`dot_product.h`/`run_hls.tcl`/the script itself -- so repeated `use_hls_example`-flagged builds don't re-synthesize every time. Set `FORCE=1` to regenerate unconditionally.

  To remove the generated artifacts (the Vitis HLS project and `rtl/hls/`) and force the next build to fully re-synthesize from scratch:

  ```sh
  hw/fpga/hls/vitis/dot_product/generate_core.sh clean
  ```

  This doesn't need Vitis HLS installed. It intentionally leaves `dot_product.core` untouched: unlike `rtl/hls/` and `dot_product_proj/`, that file is committed to git, because FuseSoC needs it present to resolve `epfl:ip:dot_product` as a dependency *before* any `pre_build` hook runs -- if it didn't exist at all, dependency resolution would fail outright and the hook that regenerates `rtl/hls/` would never get a chance to run.

  `FORCE=1` reaches `generate_core.sh` even though it's invoked indirectly, through the `generate_hls_dot_product` pre-build hook, through FuseSoC, through `make`: GNU Make automatically exports a variable set on its command line into the environment of every recipe it runs, `fusesoc run --build` inherits that environment when it spawns the `pre_build` hook's subprocess, and the hook itself is just `['bash', '.../generate_core.sh']`, which sees `FORCE` like any other environment variable. So it's enough to set it on the `make` invocation, no extra plumbing needed:

  ```sh
  FORCE=1 make verilator-build FUSESOC_FLAGS="--flag use_hls_example"
  FORCE=1 make vivado-fpga FPGA_BOARD=pynq-z2 FUSESOC_FLAGS="--flag use_hls_example"
  ```

  ```{note}
  `pre_build` hooks -- and therefore `FORCE`/`generate_core.sh` -- only run as part of an actual FuseSoC `--build` (what `verilator-build` and `vivado-fpga` do). A `--setup`-only step, such as `make vivado-fpga-nobuild`, generates the project files but never invokes the hook, so it won't pick up `FORCE=1` or re-synthesize anything.
  ```
- `dot_product_proj/` (the Vitis HLS project) and `rtl/hls/` (the generated RTL) are both gitignored, like any other tool-generated file in this project -- they don't need to exist until the `use_hls_example` flag is used.
- The `use_hls_example` flag mechanism in `core-v-mini-mcu.core` shows the three places (parameter/`` `define ``, dependency, pre-build hook) a new opt-in HLS example needs to be wired into for both simulation and FPGA builds.
