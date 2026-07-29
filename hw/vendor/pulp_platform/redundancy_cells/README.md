# Redundancy Cells

This repository contains various modules used to add redundancy.

## Hybrid Modular Redundancy (HMR)

The HMR unit (contained in `rtl/HMR/hmr_unit.sv`) is designed as a configurable bridge between the system and multiple cores. This bridge allows to configure the cores to run independently, run in a dual/DMR/DCLS mode, or run in a triple/TMR/TCLS mode. These configurations can be switched at runtime (given the availability at design time), or fixed with a parameter at design time.

### System integration

### Instantiation

This module should be placed between all signals connecting the processor cores to the rest of the system. Some additional modules are required to support certain features:
- To allow runtime switching between independent, DMR, and TMR modes, logic should be implemented to signal when the cores are ready to group together and synchronize. If in `DMRFixed` or `TMRFixed` configuration, this is not needed.

#### Parameters

To integrate this module into a system, the following parameters *require* configuration:
- `NumCores`: The number of physical cores within the system
- `all_inputs_t`: A custom struct type containing all inputs required for the implemented core
- `nominal_outputs_t`: A custom struct type containing all normal output signals from the implemented core
- `apb_req_t/apb_resp_t`: APB types (see [apb](https://github.com/pulp-platform/apb)) to access configuration registers

The following parameters are optional for custom configurations:
- `DMRSupported`: Enables support for DMR mode (default: `1'b1`).
- `DMRFixed`: Enforces permanent DMR mode. Cannot be used with `TMRSupported` or `TMRFixed` (default: `1'b0`).
- `TMRSupported`: Enables support for TMR mode (default: `1'b1`).
- `TMRFixed`: Enforces permanent TMR mode. Cannot be used with `DMRSupported` or `DMRFixed` (default: `1'b0`).
- `InterleaveGrps`: Uses interleaved cores for groups instead of sequential cores for groups (e.g., for 6 cores TMR, interleaved groups 0,2,4 and 1,3,5 together vs. sequential groups 0,1,2 and 3,4,5 together) (default: `1'b1`).
- `DefaultNominalOutputs`: Sets a custom default value the core outputs should have towards the system when disabled (i.e., part of a DMR/TMR group) (default: `'{default: '0}`).
- `SeparateData`: Have separate error signalling for data buses, disabling error notification when the bus is disabled (default: `1'b0`). Requires `NumBusVoters` and `bus_outputs_t` to be set.
- `bus_outputs_t`: A custom struct type containing output signals from the implemented core for a separated bus (default: `logic`).
- `DefaultBusOutputs`: Sets a custom default value the bus outptus should have towards the system when disabled (i.e., part of a DMR/TMR group) (default: `'{default: '0}`).
- `RapidRecovery`: Enables the *rapid recovery* feature. Requires `RfAddrWidth`, `SysDataWidth`, `core_backup_t`, and `rapid_recovery_t` to be set. Please check the HMR paper and the code for more information (default: `1'b0`).

When using a non-standard configuration, it may be beneficial to regenerate the configuration registers with the desired values. The `Makefile` sets up a target for this with variables to configure:

```sh
make gen_HMR HMR_NUM_CORES=[12|your desired core number] HMR_DMR_AVAILABLE=[1|your DMRSupported/Fixed config] HMR_TMR_AVAILABLE=[1|your TMRSupported/Fixed config]
```

#### Signals

The following signals are required for baseline functionality:
- `clk_i`: The clock.
- `rst_ni`: The reset.
- `apb_req_i`: An APB request struct input (see [apb](https://github.com/pulp-platform/apb)).
- `apb_resp_o`: An APB response struct output (see [apb](https://github.com/pulp-platform/apb)).

All signals with a `sys_` prefix connect to the system:
- `sys_bootaddress_i`: Default boot address (required for *checkpoint* feature in DMR, otherwise can be tied to `'0`).
- `sys_inputs_i`: All inputs to the cores from the system.
- `sys_nominal_outputs_o`: All normal outputs from the cores to the system.
- `sys_bus_outputs_o`: Bus outputs from the system. Can be left unconnected if `SeparateData` is disabled.
- `sys_fetch_en_i`: Allows configuration switching prior to coer startup.
- `enable_bus_vote_i`: Signals bus outputs are enabled. Can be tied to `'0` if `SeparateData` is disabled.

All signals with a `core_` prefix connect to the core:
- `core_bootaddress_o`: Connect to the cores' boot address input signal (if *checkpoint* feature in DMR is desired, otherwise can be unconnected).
- `core_setback_o`: Reset signal to the processor cores (may need FF if aynchronous reset is used internally).
- `core_inputs_o`: All inputs to the cores.
- `core_nominal_output_i`: All normal outputs from the cores.
- `core_bus_outputs_i`: Bus outputs from the cores. Can be tied to `'0` if `SeparateData` is disabled.

Both DMR and TMR feature some indicator signals:
- `?mr_failure_o`: Indicates an unrecoverable mismatch detected.
- `tmr_error_o`: Indicates a mismatch of a single core.
- `?mr_resynch_req_o`: Interrupt to cores to trigger software resynchronization routine.
- `?mr_sw_synch_req_o`: Interrupt to cores to trigger a software routine to synchronize independent cores. Can be left unconnected for ?MRFixed configurations.
- `?mr_cores_synch_i`: Signal indicating independent cores for a group are synchronized and ready to lock together.
- `redundancy_enable_o`: Signal indicating any redundancy currently is enabled.

To support the *rapid recovery* feature, additional signals are required connecting to a rapid recovery capable core. Please check the HMR paper and the code for more information. If unused, these signals can be left unconnected (outputs) or tied to '0 (inputs).

### Citing

If you are using HMR in your academic work you can cite us:
```BibTeX
@article{10.1145/3635161,
author = {Rogenmoser, Michael and Tortorella, Yvan and Rossi, Davide and Conti, Francesco and Benini, Luca},
title = {Hybrid Modular Redundancy: Exploring Modular Redundancy Approaches in RISC-V Multi-core Computing Clusters for Reliable Processing in Space},
year = {2025},
issue_date = {January 2025},
publisher = {Association for Computing Machinery},
address = {New York, NY, USA},
volume = {9},
number = {1},
issn = {2378-962X},
url = {https://doi.org/10.1145/3635161},
doi = {10.1145/3635161},
abstract = {Space Cyber-Physical Systems such as spacecraft and satellites strongly rely on the reliability of onboard computers to guarantee the success of their missions. Relying solely on radiation-hardened technologies is extremely expensive, and developing inflexible architectural and microarchitectural modifications to introduce modular redundancy within a system leads to significant area increase and performance degradation. To mitigate the overheads of traditional radiation hardening and modular redundancy approaches, we present a novel Hybrid Modular Redundancy approach, a redundancy scheme that features a cluster of RISC-V processors with a flexible on-demand dual-core and triple-core lockstep grouping of computing cores with runtime split-lock capabilities. Further, we propose two recovery approaches, software-based and hardware-based, trading off performance and area overhead. Running at 430 MHz, our fault-tolerant cluster achieves up to 1,160 MOPS on a matrix multiplication benchmark when configured in non-redundant mode and 617 and 414 MOPS in dual and triple mode, respectively. A software-based recovery in triple mode requires 363 clock cycles and occupies 0.612 mm2, representing a 1.3\% area overhead over a non-redundant 12-core RISC-V cluster. As a high-performance alternative, a new hardware-based method provides rapid fault recovery in just 24 clock cycles and occupies 0.660 mm2, namely, ∼9.4\% area overhead over the baseline non-redundant RISC-V cluster. The cluster is also enhanced with split-lock capabilities to enter one of the available redundant modes with minimum performance loss, allowing execution of a mission-critical portion of code when in independent mode, or a performance section when in a reliability mode, with <400 clock cycles overhead for entry and exit. The proposed system is the first to integrate these functionalities on an open-source RISC-V-based compute device, enabling finely tunable reliability versus performance trade-offs.},
journal = {ACM Trans. Cyber-Phys. Syst.},
month = jan,
articleno = {8},
numpages = {29},
keywords = {RISC-V, adaptive fault tolerance, space vehicle computer, reliable computing}
}
```

## On-Demand Redundancy Grouping (ODRG_unit)
> [!NOTE]
> This module has been superceeded by HMR above. ODRG functionality is supported within certain configurations of HMR.

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
