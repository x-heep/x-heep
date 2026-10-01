# HLS accelerator example: streaming dot product

A small dot-product accelerator, written in C++ and generated with either of two
HLS tools, wired into X-HEEP as a memory-mapped accelerator (simulation with
Verilator, and the `pynq-z2` FPGA). The whole thing is opt-in: pass
`use_hls_example` plus **one** tool flag to FuseSoC.

| HLS tool | Flags | Directory | Host needs |
|----------|-------|-----------|------------|
| Vitis HLS | `--flag use_hls_example --flag use_vitis_hls` | [`vitis/dot_product`](vitis/dot_product) | Vivado + Vitis HLS |
| Bambu HLS (open source) | `--flag use_hls_example --flag use_bambu_hls` | [`bambu/dot_product`](bambu/dot_product) | Docker |

```sh
make mcu-gen
make verilator-build FUSESOC_FLAGS="--flag use_hls_example --flag use_bambu_hls"
make app PROJECT=example_dot_product_hls TARGET=sim
make verilator-run FUSESOC_FLAGS="--flag use_hls_example --flag use_bambu_hls"
```

`common/dot_product` holds what does not depend on the tool (header, C++
testbench, the OBI wrapper with its AXI<->OBI bridges, the `epfl:ip:dot_product`
FuseSoC core that selects the tool); each tool directory holds its kernel, its
generation scripts and a small `dot_product_hls_adapter` module. The software
(`sw/applications/example_dot_product_hls`) is the same for both.

Full guide: [`docs/source/FPGA/HLS_DotProduct_Example.md`](../../../docs/source/FPGA/HLS_DotProduct_Example.md).
