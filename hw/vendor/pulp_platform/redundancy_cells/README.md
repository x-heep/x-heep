# Redundancy Cells

This repository contains various modules used to add redundancy.

## On-Demand Redundancy Grouping (ODRG_unit)
The `ODRG_unit` is designed as a configurable bridge between three ibex cores, allowing for independent operation or lock-step operation with majority voting, triggering an interrupt in case a mismatch is detected. It uses lowrisc's reggen tool to generate the required configuration registers.

### Testing
ODRG is integrated in the [PULP cluster](https://github.com/pulp-platform/pulp_cluster/tree/space_pulp) and the [PULP](https://github.com/pulp-platform/pulp/tree/space_pulp) system. To test, please use the `space_pulp` branch.

### Citing
If you are using ODRG in your academic work you can cite us:
```BibTeX
@INPROCEEDINGS{9912026,
  author={Rogenmoser, Michael and Wistoff, Nils and Vogel, Pirmin and Gürkaynak, Frank and Benini, Luca},
  booktitle={2022 IEEE Computer Society Annual Symposium on VLSI (ISVLSI)}, 
  title={On-Demand Redundancy Grouping: Selectable Soft-Error Tolerance for a Multicore Cluster}, 
  year={2022},
  volume={},
  number={},
  pages={398-401},
  doi={10.1109/ISVLSI54635.2022.00089}
}
```

### Maintenance

To re-generate regfile, run following command in the root directory of this repo.
```bash
make gen_ODRG
```
This will generate the register file SV-code, its corresponding C-code and documentation using lowrisc's reggen tool via the pulp register-interface repository.

## ECC encoders and decoders
The hsiao_ecc encoder, decoder, and corrector are based on lowRISC's Hsiao ECC implementation, with an adapted algorithm to deterministically find an appropriate Hsiao matrix. They are implemented in SystemVerilog for efficient parametrization, replacing the generated lowRISC modules.

The lowRISC ECC encoders and decoders are imported using [`bender`'s `vendor` command](https://github.com/pulp-platform/bender#vendor-----copy-files-from-dependencies-that-do-not-support-bender). To re-import and re-generate the `prim_secded_` modules run
```bash
make gen_ECC
```

## ECC wrapper for SRAM
`ecc_sram_wrap.sv` is a wrapper for the tc_sram tech_cell to add ecc in a customizable fashion. It interfaces a modified `TCDM_BANK_MEM_BUS.Slave` defined in pulp_soc with the memory, implementing a load-and-store architecture for writes where not the full word is written. As this requires an additional cycle, a gnt signal is exposed, delaying the subsequent transaction if necessary.

## ECC scrubber
`ecc_scrubber.sv` is a scrubber unit to attach to an ecc-protected memory bank. When triggered, read the next address to detect if a fault has occurred, correcting it if required and logging the number of corrections. It will always give way to other memory accesses and stall to avoid increased latency.

## ECC translators for data bus interfaces
The `BUS_enc_dec` encoders and decoders add or remove ECC to the parametrized `XBAR_TCDM_BUS`, `XBAR_PE_BUS`, and `XBAR_DEMUX_BUS`, defined in [pulp_interfaces.sv](https://github.com/micprog/pulp_soc/blob/ibex_update/rtl/components/pulp_interfaces.sv), as well as [`AXI_BUS`](https://github.com/pulp-platform/axi).

The `DropECC` parameter allows for a faster signal along the decode data path, not correcting the errors but still calculating if an error exists.

## Triple Modular Redundancy majority voters
The `TMR_voter`s are Triple Modular Redundancy majority voters, based on research indicated in the corresponding files. To detect the failing module, additional signals are implemented in higher-level modules.

## Voting Macros
For quickly instantiating voters, the following macros might be useful. They can be used via bender with:
```
`include "redundancy_cells/voters.svh"
```
All Macros use the following naming scheme:
`VOTE{Inputs}{Outputs}{Flags}`

- For size `1` outputs can be arbitrarily sized arrays (denoted as size `[K:0]` below), 
- For size `3` inputs and outputs should be arrays of length 3 at the top level which at lower levels can again be arbitrarily (`K`) sized. 
- The size `X` allows for a parameter to determine how many duplicates are used, which allows to make designs which have compile-time switchable redundancy. 
The parameter should have a value of 1 (no redundancy), 2 (fault detection) or 3 (fault correction).

Available Flags are:
- `F` Fault Detection: Additional 1-bit output signal which is one if voting was not unanimous
- `W` Fault Location: Additional 3-bit output signal which specifies which input was different and 1-bit signal if all bits where different

Voters work with enumerated types, but there is no guarantee when multiple faults occur at once that the output is a valid enum entry.
Enumerated types that consist of a single bit are not supported.

All availabe voters are:

| Macro      | Arguments                                                                         | Description                                      |
|------------|-----------------------------------------------------------------------------------|--------------------------------------------------|
| `VOTE31`   | `input_signal[2:0][K:0], output_signal[K:0]`                                      | 3 -> 1 Voter                                     |
| `VOTE31F`  | `input_signal[2:0][K:0], output_signal[K:0], fault_any`                           | 3 -> 1 Voter with fault detection                |
| `VOTE31W`  | `input_signal[2:0][K:0], output_signal[K:0], fault_210[2:0], fault_multiple`      | 3 -> 1 Voter with fault location                 |
| `VOTE33`   | `input_signal[2:0][K:0], output_signal[2:0][K:0]`                                 | 3 -> 3 Voters                                    |
| `VOTE33F`  | `input_signal[2:0][K:0], output_signal[2:0][K:0], fault_any`                      | 3 -> 3 Voters with fault detection               |
| `VOTE33W`  | `input_signal[2:0][K:0], output_signal[2:0][K:0], fault_210[2:0], fault_multiple` | 3 -> 3 Voters with fault location                |
| `VOTEX1`   | `replicas, input_signal[REP:0][K:0], output_signal[K:0]`                          | replicas -> 1 Voter                              |
| `VOTEX1F`  | `replicas, input_signal[REP:0][K:0], output_signal[K:0], fault_any`               | replicas -> 1 Voter with fault detection         |
| `VOTEXX`   | `replicas, input_signal[REP:0][K:0], output_signal[REP:0][K:0]`                   | replicas -> replicas Voters                      |
| `VOTEXXF`  | `replicas, input_signal[REP:0][K:0], output_signal[REP:0][K:0], fault_any`        | replicas -> replicas Voters with fault detection |

## `rel_*` blocks

The following modules are based on IPs in `common_cells`, but leverage TMR and ECC for reliability.

| Module | Description | Reliability |
|---|---|---|
| `rel_fifo` | FIFO | Optional TMR on control signals, ECC on data, internal TMR and voters |
| `rel_rr_arb_tree` | Round-robin arbiter | Optional TMR on control signals, ECC assumed on data, internal TMR and voters |

## Testing
To run tests, execute the following command:
```bash
./run_tests.sh
```

A bender installation >=v0.27 is required.
