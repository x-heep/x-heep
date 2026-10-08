# HLS Accelerator Example: Streaming Dot Product

This guide documents a worked example of integrating an HLS-generated accelerator into X-HEEP, both in Verilator simulation and on the `pynq-z2` FPGA. It doubles as a template for adding your own HLS-generated IP to the project.

The same accelerator -- a small streaming dot-product engine written in C++, wired into X-HEEP as a memory-mapped accelerator -- can be generated with either of two HLS tools, selected with a FuseSoC flag:

| HLS tool | Flag | Directory | Needs on the host |
|----------|------|-----------|-------------------|
| [Vitis HLS](https://www.xilinx.com/products/design-tools/vitis/vitis-hls.html) (commercial) | `use_vitis_hls` | `hw/fpga/hls/vitis/dot_product/` | Vivado + Vitis HLS (`settings64.sh` sourced) |
| [Bambu HLS](https://github.com/ferrandi/PandA-bambu) (open source) | `use_bambu_hls` | `hw/fpga/hls/bambu/dot_product/` | Docker only |

Everything else -- the OBI wrapper, the AXI&harr;OBI bridges, the testbench and FPGA hookup, and the **software** -- is shared, so `example_dot_product_hls` runs unchanged with either tool.

```{note}
This whole example is opt-in and gated behind FuseSoC flags: `use_hls_example` plus one tool flag (`use_vitis_hls` or `use_bambu_hls`). Without them, X-HEEP never depends on any HLS tool being installed -- building and simulating the project works exactly as before. See [Design: opt-in via FuseSoC flags](#design-opt-in-via-fusesoc-flags) below.
```

```{note}
The Vitis flow has been tested with `Vivado 2021.1` and `Vitis HLS 2021.1`. The Bambu flow has been tested with Bambu `2024.10` (in its Docker image, Verilator 4.038 inside the container) and X-HEEP's Verilator 5 system simulation, with the very same firmware as the Vitis flow.
```

## Repository layout

```
hw/fpga/hls/
├── common/dot_product/          shared by every HLS flow
│   ├── dot_product.h            C++ interface (types, prototype)
│   ├── dot_product_tb.cpp       C++ testbench (used by both tools)
│   ├── dot_product_xheep_wrapper.sv   OBI wrapper + AXI<->OBI bridges
│   ├── dot_product.core         FuseSoC core epfl:ip:dot_product (selects the tool)
│   └── dot_product.vlt          Verilator waivers for the shared part
├── vitis/dot_product/           Vitis HLS flow
│   ├── dot_product.cpp          the kernel, with Vitis pragmas
│   ├── run_hls.tcl              vitis_hls script (synthesis)
│   ├── generate_core.sh         runs it, copies the RTL, writes dot_product_vitis.core
│   ├── dot_product_vitis.core   FuseSoC core (committed; lists the generated RTL)
│   ├── dot_product.vlt          Verilator waivers for Vitis' generated RTL
│   └── rtl/dot_product_hls_adapter.sv   Vitis core <-> AXI structs
└── bambu/                       Bambu HLS flow
    ├── Dockerfile, bambu.sh     runs Bambu (in Docker by default)
    └── dot_product/
        ├── dot_product.cpp      the kernel, with Bambu pragmas
        ├── run_bambu.sh         synthesis (and standalone RTL co-simulation)
        ├── generate_core.sh     runs it, copies the RTL, writes dot_product_bambu.core
        ├── dot_product_bambu.core   FuseSoC core (committed; lists the generated RTL)
        ├── dot_product.vlt      Verilator waivers for Bambu's generated RTL
        ├── data/dot_product_ctrl.hjson   CTRL register map (input of regtool)
        ├── dot_product_bambu_ctrl.core   FuseSoC core of the register file (runs regtool)
        ├── dot_product_ctrl.vlt          Verilator waivers for the regtool output
        ├── rtl/
        │   ├── dot_product_hls_adapter.sv   Bambu core <-> AXI structs
        │   └── dot_product_ctrl_regs.sv     AXI-Lite -> regbus -> regtool reg_top + core handshake
        └── tb/
            ├── dot_product_ctrl_regs_tb.sv  self-checking unit test of the register file
            └── run.sh                       runs it with Verilator
```

Generated files (`dot_product_proj/`, `rtl/hls/`) are gitignored in both flows.

## What the accelerator does

`dot_product` computes the dot product of two `int32_t` vectors `a` and `b` of a given `size`, accumulating into a 64-bit result. The kernel is written in C++ (`dot_product.h` is shared; each flow has its own `dot_product.cpp`, identical except for the interface pragmas) and seen from X-HEEP it has two kinds of AXI ports:

- **`gmem_a` / `gmem_b`** -- two independent AXI4 master (read) ports. The core fetches both vectors from memory on its own; no data ever passes through software.
- **`CTRL`** -- one AXI4-Lite slave port bundling the two base addresses, `size`, the 64-bit `result`, and the standard Vitis HLS `ap_ctrl_hs` handshake (`ap_start`/`ap_done`/`ap_idle`/`ap_ready`). Vitis HLS generates this register file itself; Bambu cannot, so the Bambu flow provides an equivalent one, generated with [regtool](../How_to/RegGenerator.md) from `data/dot_product_ctrl.hjson` like the other X-HEEP peripherals' register files, **with the same register map and (nearly all) bit semantics**, which is what keeps the software unchanged.

| Offset | Register | Description |
|--------|----------|-------------|
| `0x00` | `AP_CTRL` | bit 0 `ap_start` (write 1 to start), bit 1 `ap_done` (clear on read), bit 2 `ap_idle`, bit 3 `ap_ready` (clear on read), bit 7 `auto_restart` |
| `0x10` | `a` | base address of vector `a` |
| `0x1c` | `b` | base address of vector `b` |
| `0x28` | `size` | number of elements |
| `0x30` / `0x34` | `result` (lo/hi) | 64-bit accumulated dot product |
| `0x38` | `result_ctrl` | bit 0: result valid (clear on read) |

The Bambu flow's register file also implements the interrupt registers of the Vitis-generated block (`GIER` at `0x04`, `IER` at `0x08`, `ISR` at `0x0c`) and an interrupt output, which -- as in the Vitis flow -- is not connected to anything in X-HEEP. `ISR` is write-1-to-clear here, where the Vitis block toggles the bit on write; the two are identical for the normal use (clearing a bit that is set).

Two behaviours follow from the register file being a regtool one, as for every other X-HEEP peripheral (and differ from the Vitis-generated block, which is more permissive): accessing an unmapped offset (`0x18`, `0x24`, `0x2c`, `0x3c`) returns a bus error, and a write whose byte strobes do not cover the whole register is rejected with a bus error (use 32-bit accesses; the byte-wide control registers only need byte 0).

One more regtool property is handled inside the register file: if software clears a bit (clear-on-read `ap_done`/`ap_ready`/result-valid, or write-1-to-clear `ISR`) in the very same clock cycle in which the hardware sets it, software wins and the hardware set is lost. The core pulses `done` only once, so a poll of `AP_CTRL` landing in that exact cycle would have made `ap_done` vanish and left the caller polling forever (this happened in the first system simulation). `dot_product_ctrl_regs.sv` therefore repeats every such hardware set until the bit reads back as set; it stops the cycle the bit is seen, so an event can be repeated but never doubled.

```{note}
**Why are `a`/`b` only 32 bits from software's side, if HLS ports are 64-bit?** (Vitis flow)
Vitis HLS derives the `gmem_a`/`gmem_b` AXI address width from the size of the C++ pointer type in `dot_product.cpp` (`const int32_t *`). Since `vitis_hls` runs as a 64-bit host process, it synthesizes 64-bit `m_axi` address ports (`a`/`b` are each a pair of 32-bit registers in hardware, at `0x10`/`0x14` and `0x1c`/`0x20`) -- this is inherent to how Vitis HLS compiles native pointers, not an X-HEEP design choice. X-HEEP only has a 32-bit address space, so `xheep_axi_to_obi_bridge` truncates the AXI address down to 32 bits before it reaches the OBI bus.

The upper 32-bit half of each pointer register (`0x14`, `0x20`) resets to `0` in the HLS-generated CTRL block and nothing else ever writes it, so it stays `0` without software ever touching it -- the 64-bit-pointer detail is entirely internal to the accelerator and invisible from X-HEEP's/software's point of view. `example_dot_product_hls/main.c` only ever writes the low word.

Bambu is invoked with `--compiler=I386_CLANG16`, i.e. it targets a 32-bit address space like X-HEEP's, so its `gmem_a`/`gmem_b` addresses are natively 32 bits. Its register file keeps the `0x14`/`0x20` words for register-map compatibility, as plain read/write registers that the core does not use.
```

Since X-HEEP's bus is OBI, not AXI, two small reusable bridges do the protocol conversion (both under `hw/ip/`, independent of `dot_product` and reusable for any future AXI-based accelerator):

- **`xheep_obi_to_axi_bridge`** -- OBI master (e.g. the CPU) &rarr; AXI4-Lite slave. Used for the `CTRL` port.
- **`xheep_axi_to_obi_bridge`** -- AXI4 master &rarr; OBI master. Used for `gmem_a` and `gmem_b`, so the accelerator's own memory reads become ordinary OBI transactions into X-HEEP's system bus.

`hw/fpga/hls/common/dot_product/dot_product_xheep_wrapper.sv` ties the generated `dot_product` core and the bridges together into a single clean module exposing three plain OBI ports: one OBI slave (`ctrl_obi_*`) and two OBI masters (`gmem_a_obi_*`, `gmem_b_obi_*`). It is **shared by both HLS flows** -- the testbench and FPGA top instantiate it identically whichever tool is used.

The only tool-specific piece is a small module, `dot_product_hls_adapter`, that each flow provides in its own `rtl/` directory with the same ports: one AXI4-Lite slave (`CTRL`) and two AXI4 read masters, all as PULP AXI structs. It maps whatever flat ports and port names the tool emits onto those structs:

- **Vitis**: connects the generated core (upper-case Xilinx names such as `m_axi_gmem_a_ARVALID`, an `s_axi_CTRL_*` port) and ties off `AWATOP`/`lock`.
- **Bambu**: instantiates the CTRL register file (`dot_product_ctrl_regs`), connects the generated core (lower-case names such as `m_axi_gmem_a_arvalid`, plain `start_port`/`done_port`/`a`/`b`/`size`/`result` ports), adapts the 6-bit ids and 32-bit addresses to the wrapper's structs, and ties off `AWATOP` and `cache_reset`.

## Differences between the two flows

The accelerator's behaviour and register map are the same, but the tools differ in what they can express, which is why the two `dot_product.cpp` files (and the hand-written glue) are not identical:

| | Vitis HLS | Bambu HLS |
|---|---|---|
| Control interface | Generates an AXI4-Lite `s_axilite` register file with `ap_ctrl_hs` | No `s_axilite`: the core only has `clock`/`reset`/`start_port`/`done_port` plus a port per C argument. a regtool-generated register file (`dot_product_ctrl_regs.sv`) provides it |
| Interface pragma | `#pragma HLS INTERFACE m_axi port=a offset=slave bundle=gmem_a ...` | `#pragma HLS interface port=a mode=m_axi offset=direct bundle=gmem_a` (lower-case, case sensitive; only `offset=direct`) |
| `a`, `b` | Base addresses live in generated registers (`offset=slave`) | Plain address input ports, driven by the register file (`offset=direct`) |
| AXI master | Bursts up to 256 beats, 2 outstanding reads (`max_read_burst_length`, `num_read_outstanding`) | Single-beat, in-order transactions (`ARLEN = 0`); no equivalent options |
| Loop pipelining | `#pragma HLS PIPELINE II=1` | No such pragma; the scheduler decides |
| Address width | 64-bit (host pointers) | 32-bit (`--compiler=I386_CLANG16`) |
| Reset | active-low `ap_rst_n` | active-low `reset` |

The single-beat AXI master means the Bambu version fetches operands with lower throughput than the burst-capable Vitis one. As a data point, in the Verilator simulation the whole `example_dot_product_hls` firmware (boot included, `size` = 16) runs in 4802 clock cycles with the Vitis core and 4902 with the Bambu core; that includes the CPU's polling, so it is not a throughput benchmark. Both are functional examples, not tuned accelerators.

## Design: opt-in via FuseSoC flags

Passing `--flag use_hls_example` plus **exactly one** of `--flag use_vitis_hls` / `--flag use_bambu_hls` to any `fusesoc`-driven build (via `FUSESOC_FLAGS`) does the following, all defined in `core-v-mini-mcu.core` and `hw/fpga/hls/common/dot_product/dot_product.core`:

1. `use_hls_example` defines the SystemVerilog macro `` `USE_HLS_EXAMPLE `` (a `vlogdefine` parameter), which gates every instantiation of the accelerator in `tb/testharness.sv.tpl` and `hw/fpga/xilinx_core_v_mini_mcu_wrapper.sv` behind `` `ifdef USE_HLS_EXAMPLE ``.
2. `use_hls_example` also makes `epfl:ip:dot_product` (the shared core: wrapper, bridges) a dependency of the simulation (`tb/x-heep-tb-utils.core`) and FPGA (`rtl-fpga` fileset) builds. Without the flag, FuseSoC never even looks for this core or any generated RTL.
3. The tool flag makes `epfl:ip:dot_product` depend on that tool's core -- `epfl:ip:dot_product_vitis` (`use_vitis_hls`) or `epfl:ip:dot_product_bambu` (`use_bambu_hls`), which provide the `dot_product_hls_adapter` module and the generated RTL.
4. The tool flag also registers a `pre_build` hook, `generate_hls_dot_product_vitis` or `generate_hls_dot_product_bambu`, which runs that flow's `generate_core.sh` (i.e. the HLS tool) automatically before the build -- so passing the flags is enough; you never have to run the HLS step yourself.

Without the flags, no generated Verilog needs to exist on disk, and nothing in X-HEEP requires any HLS tool to be installed.

```{warning}
Pass exactly one tool flag together with `use_hls_example`. With `use_hls_example` alone, no adapter is pulled in and the build fails on the unresolved module `dot_product_hls_adapter`.
```

## Simulating with Verilator

Generate the MCU, then build and run as usual, adding the flags. With **Vitis HLS**:

```sh
source <vivado-installation-path>/settings64.sh
source <vitis_hls-installation-path>/settings64.sh

make mcu-gen
make verilator-build FUSESOC_FLAGS="--flag use_hls_example --flag use_vitis_hls"
make app PROJECT=example_dot_product_hls TARGET=sim
make verilator-run FUSESOC_FLAGS="--flag use_hls_example --flag use_vitis_hls"
```

With **Bambu HLS** (no Xilinx tools needed, only Docker -- see [Running Bambu](#running-bambu)):

```sh
make mcu-gen
make verilator-build FUSESOC_FLAGS="--flag use_hls_example --flag use_bambu_hls"
make app PROJECT=example_dot_product_hls TARGET=sim
make verilator-run FUSESOC_FLAGS="--flag use_hls_example --flag use_bambu_hls"
```

`example_dot_product_hls` (`sw/applications/example_dot_product_hls/main.c`) writes the two vector addresses and `size` into the `CTRL` registers, pulses `ap_start`, polls `ap_done`, and checks the result against a CPU-computed reference:

```
Dot Product Accelerator Successful: 0x0000000000000330
```

```{note}
Sourcing Vivado's and Vitis HLS's `settings64.sh` is only required for the Vitis flow (`use_vitis_hls` triggers the Vitis HLS synthesis hook). The Bambu flow only needs Docker, and a plain `make verilator-build` (no flags) never needs either.
```

## Building and programming the pynq-z2 bitstream

Follow the same flow as any other FPGA build (see [Run on FPGA](./RunOnFPGA.md)), adding the flag:

```sh
source <vivado-installation-path>/settings64.sh
source <vitis_hls-installation-path>/settings64.sh   # Vitis flow only

make vivado-fpga FPGA_BOARD=pynq-z2 FUSESOC_FLAGS="--flag use_hls_example --flag use_vitis_hls"
# or, with the open-source Bambu HLS (Vivado is still needed for the bitstream itself):
make vivado-fpga FPGA_BOARD=pynq-z2 FUSESOC_FLAGS="--flag use_hls_example --flag use_bambu_hls"

make vivado-fpga-pgm FPGA_BOARD=pynq-z2
```

Without the flags, `make vivado-fpga FPGA_BOARD=pynq-z2` builds the exact same bitstream as before this example existed -- no accelerator, no extra logic, no HLS-tool dependency.

### How the accelerator is wired on FPGA

Unlike the testbench (which uses a small dedicated crossbar for external masters/slaves), `core_v_mini_mcu` on FPGA is normally built "unextended" (`EXT_XBAR_NMASTER=0`, no external masters at all). Adding the accelerator without pulling in a full crossbar uses two different mechanisms, both only active under `` `ifdef USE_HLS_EXAMPLE ``:

- **`gmem_a` / `gmem_b`** (the accelerator's own two memory-read masters) are wired to `x_heep_system`'s `ext_xbar_master_req_i`/`resp_o` ports, with `EXT_XBAR_NMASTER` overridden to `2`. These genuinely go through X-HEEP's real system crossbar, since there are two masters that need arbitration for the shared memory/peripheral space.
- **`CTRL`** (the single OBI slave the CPU configures) is wired directly to `ext_core_data_req_o`/`ext_core_data_resp_i` -- X-HEEP's existing per-master address demux already gives the CPU's data bus a dedicated "external slave" output for the `EXT_SLAVE_START_ADDRESS` region (`0xC000_0000`, the same region the testbench and software already use), completely independent of the internal crossbar. Since there is exactly one master on that path, no arbitration/crossbar is needed at all -- it's a direct point-to-point connection.

This wiring lives in `hw/fpga/xilinx_core_v_mini_mcu_wrapper.sv`, scoped to the non-PS-enabled FPGA boards (pynq-z2 included).

## Running Bambu

The Bambu flow runs Bambu inside a Docker container by default, so **Docker is the only host dependency** (no Xilinx tools, no 32-bit toolchain, no Verilator install). The `use_bambu_hls` pre-build hook takes care of everything; this section describes what happens underneath and how to run the steps by hand.

- **The container.** `hw/fpga/hls/bambu/bambu.sh` runs Bambu in the `xheep-bambu:2024.10` image, building it from `hw/fpga/hls/bambu/Dockerfile` the first time it is needed (one-off: it downloads Bambu's release AppImage, ~1.4 GB, and produces a ~5 GB image). The Bambu version is pinned and the download is checked against a SHA-256, so a changed file fails the build. The container runs as your user (generated files are yours), has no network access, and sees the X-HEEP checkout at the same path as on the host.
- **A native install instead.** Set `BAMBU=/path/to/bambu` (and, for from-source installs, `BAMBU_ENV=/path/to/settings.sh`) to skip Docker. A native Bambu additionally needs a 32-bit toolchain (`g++-multilib`) and Verilator for co-simulation.
- **Generating the RTL.** `hw/fpga/hls/bambu/dot_product/generate_core.sh` (what the hook runs) calls `run_bambu.sh`, copies Bambu's output into `rtl/hls/` and regenerates `dot_product_bambu.core`. Bambu writes the whole design -- the top and every library component it uses -- into a single self-contained `dot_product.v`.
- **Checking the HLS result on its own.** `run_bambu.sh sim` co-simulates the generated RTL against the shared C++ testbench through Bambu's own Verilator flow and AXI memory model, and checks for `TEST PASSED`:

  ```sh
  cd hw/fpga/hls/bambu/dot_product
  ./run_bambu.sh sim
  ```

  ```
  expected = 816, got = 816
  TEST PASSED
  ```

  This validates the HLS output only, not the X-HEEP integration (adapter, register file, wrapper, bridges); that is what the Verilator system simulation above is for. Bambu's co-simulation also prints a one-off `ERROR: MDPI driver: Interface 3: Unknown data required: 4.` line before the test runs; the test still passes and returns 0, and the message is not from X-HEEP's code.

  `run_bambu.sh` with no argument only synthesizes. Everything is generated in `dot_product_proj/` (gitignored).
- **Unit test of the register file.** `dot_product_ctrl_regs.sv` replaces a block that Vitis generates, so it has its own self-checking testbench, which drives it over AXI4-Lite against a small model of the Bambu core and checks the behaviour described by the Vitis-generated register map: reset values, the one-cycle start pulse, clear-on-read of `ap_done`/`ap_ready`/result-valid, `auto_restart`, the interrupt registers, the bus errors above, AW/W arriving in either order, and a sweep of software polls across every cycle alignment with the core's done pulse (the race above). It needs Verilator 5 plus what any X-HEEP FuseSoC build needs (the register file is generated by regtool through FuseSoC, see `util/python-requirements.txt`), but no HLS tool, and prints `dot_product_ctrl_regs_tb: PASS`:

  ```sh
  hw/fpga/hls/bambu/dot_product/tb/run.sh
  ```
- **The testbench.** `common/dot_product/dot_product_tb.cpp` is shared with Vitis. Bambu's co-simulation needs to be told how many bytes each pointer argument points to, so the testbench has a small block guarded by `#ifdef __BAMBU_SIM__` (a macro only Bambu defines) that calls `m_param_alloc()`; Vitis never sees it. Likewise `dot_product.h` gives `dot_product()` C linkage, because Bambu names the generated RTL module after the (mangled) C++ symbol and would otherwise call it `_Z11dot_productPKiS0_jPx`.
- **Target device.** `run_bambu.sh` targets `xc7z020,-1,clg484` at 8 ns, the same clock as the Vitis flow. Bambu has a timing/area model for the `clg484` package, not for the pynq-z2's `clg400` (same die and speed grade), so this only affects Bambu's estimates; Vivado implements the design for the real part.

## Extending: adding your own HLS accelerator

The pieces above are deliberately generic and reusable:

- `xheep_obi_to_axi_bridge` / `xheep_axi_to_obi_bridge` (`hw/ip/`) work for any AXI4 / AXI4-Lite port shape, not just `dot_product`'s.
- **Adding another HLS tool** only takes: a directory `hw/fpga/hls/<tool>/dot_product/` with the kernel in that tool's dialect, a `generate_core.sh` (see below), a generated `dot_product_<tool>.core` providing a `dot_product_hls_adapter` module with the same ports as the existing ones, a new `use_<tool>_hls` flag, a `generate_hls_dot_product_<tool>` hook in `core-v-mini-mcu.core`, and one more `use_<tool>_hls ? (epfl:ip:dot_product_<tool>)` line in `hw/fpga/hls/common/dot_product/dot_product.core`. The wrapper, bridges, testbench/FPGA hookup and software don't change.
- `hw/fpga/hls/<tool>/dot_product/generate_core.sh` is a template for an HLS &rarr; FuseSoC `.core` generation script: it runs the tool (`vitis_hls -f run_hls.tcl` for Vitis, `run_bambu.sh` for Bambu) on `dot_product.cpp`, copies the resulting Verilog into the stable `rtl/hls/` directory, and regenerates `dot_product_<tool>.core` to list it. This is exactly the script the `generate_hls_dot_product_<tool>` pre-build hooks run for you -- you only need to touch it directly if you're modifying `dot_product.cpp`/`dot_product.h` and want to re-synthesize without rebuilding the whole simulation/bitstream.

  The script skips re-running the HLS tool (and doesn't need it installed) if `rtl/hls/` already holds RTL newer than the kernel, the shared header, the run script and the script itself (for Bambu also the Docker environment) -- so repeated flagged builds don't re-synthesize every time. Set `FORCE=1` to regenerate unconditionally.

  To remove the generated artifacts (the HLS project and `rtl/hls/`) and force the next build to fully re-synthesize from scratch:

  ```sh
  hw/fpga/hls/vitis/dot_product/generate_core.sh clean
  hw/fpga/hls/bambu/dot_product/generate_core.sh clean
  ```

  This doesn't need the HLS tool installed. It intentionally leaves `dot_product_<tool>.core` untouched: unlike `rtl/hls/` and `dot_product_proj/`, that file is committed to git, because FuseSoC needs it present to resolve `epfl:ip:dot_product_<tool>` as a dependency *before* any `pre_build` hook runs -- if it didn't exist at all, dependency resolution would fail outright and the hook that regenerates `rtl/hls/` would never get a chance to run.

  `FORCE=1` reaches `generate_core.sh` even though it's invoked indirectly, through the `generate_hls_dot_product_<tool>` pre-build hook, through FuseSoC, through `make`: GNU Make automatically exports a variable set on its command line into the environment of every recipe it runs, `fusesoc run --build` inherits that environment when it spawns the `pre_build` hook's subprocess, and the hook itself is just `['bash', '.../generate_core.sh']`, which sees `FORCE` like any other environment variable. So it's enough to set it on the `make` invocation, no extra plumbing needed:

  ```sh
  FORCE=1 make verilator-build FUSESOC_FLAGS="--flag use_hls_example --flag use_bambu_hls"
  FORCE=1 make vivado-fpga FPGA_BOARD=pynq-z2 FUSESOC_FLAGS="--flag use_hls_example --flag use_vitis_hls"
  ```

  ```{note}
  `pre_build` hooks -- and therefore `FORCE`/`generate_core.sh` -- only run as part of an actual FuseSoC `--build` (what `verilator-build` and `vivado-fpga` do). A `--setup`-only step, such as `make vivado-fpga-nobuild`, generates the project files but never invokes the hook, so it won't pick up `FORCE=1` or re-synthesize anything.
  ```
- `dot_product_proj/` (the HLS project) and `rtl/hls/` (the generated RTL) are both gitignored, like any other tool-generated file in this project -- they don't need to exist until the flags are used.
- The `use_hls_example` / tool flag mechanism in `core-v-mini-mcu.core` shows the places (parameter/`` `define ``, dependency, pre-build hook) a new opt-in HLS example needs to be wired into for both simulation and FPGA builds.
