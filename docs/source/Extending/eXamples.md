# X-HEEP-based eXamples

Here you can find a list of `X-HEEP` based open-source examples. If you want to include your project in this list, please open an issue with a link to your repository.

* [CGRA-X-HEEP](https://github.com/esl-epfl/cgra_x_heep): A CGRA loosely coupled with X-HEEP.
* [F-HEEP](https://github.com/davidmallasen/F-HEEP): System integrating [fpu_ss](https://github.com/pulp-platform/fpu_ss) into X-HEEP via the eXtension interface and cv32e40px.
* [KALIPSO](https://github.com/vlsi-lab/ntt_intt_kyber) and [KRONOS](https://github.com/vlsi-lab/keccak_integration/tree/keccak_xheep): Loosely-coupled, post-quantum cryptography accelerators for NTT/INTT and Keccak hash function integrated into X-HEEP.

## Socsim-Generator: External Co-Simulation Flow for X-HEEP

X-HEEP natively supports Verilator-based simulation, where the SoC RTL is converted to C/C++ and executed as a single simulation process. In many development scenarios, however, peripherals or ISA extensions need to be validated before a full RTL implementation exists. Architectural models, algorithmic prototypes, or accelerator simulators may already exist in C++, Java, or Python and can be used to functionally validate the software stack, instruction encodings, and integration strategy. Integrating such models directly into RTL is often unnecessary at early stages and slows down iteration.

The [Socsim-Generator](https://github.com/specs-feup/socsim-generator) framework enables structured co-simulation between X-HEEP and an external simulator process. Using a JSON configuration, Socsim-Generator can:
- Generate the X-HEEP-side interface logic and communication code.
- Generate skeleton code for the external high-level simulator (in C++, Java or Python).
- Set up the underlying communication channel between X-HEEP and the simulator. Communication is cycle-accurate and in lock step, through a state-machine model the simulated peripheral must be compliant with.

The generated component is attached to X-HEEP either as a memory-mapped peripheral (OBI-based interface) or as a custom instruction extension. At runtime, accesses to the generated interface trigger DPI-C calls that forward transactions to an external process which models the peripheral, i.e., accelerator. The external simulator computes the response and returns data to the Verilated X-HEEP process, allowing the RISC-V software to interact with the model as if it were a hardware block. This makes it possible to validate register maps, protocols, instruction semantics, and software drivers without committing to RTL.

The approach has been validated for both OBI-based peripherals and custom instruction-based extensions. In the latter case, the flow was used to replicate the existing [bit-reversal custom instruction example](https://github.com/esl-epfl/xif_copro) provided in X-HEEP, using a generated external co-simulation interface, confirming correct integration through the instruction path. The framework supports attaching multiple external processes, each through its own interface.

Example JSON configuration:

```json
{
  "project_name": "bit_reverser",
  "paths": {
    "xheep_dir": "/home/usr/x-heep",
    "output_dir": "/home/usr/socsim-generator/examples"
  },
  "simulator_definitions": [
    {
      "interface": "obi",
      "identifier": "bit_reverser",
      "description": "A simple bit reverser",
      "class_name": "bit_reverser",
      "target_language": "cpp",
      "hardware_interface": {
        "memory_base_address": 6000,
        "memory_size_bytes": 100,
        "registers": [
          { "name": "src_address", "direction_to_simulator": "input", "type": "logic", "signed": false, "width": 32, "default_value": 0, "description": "" },
          { "name": "dst_address", "direction_to_simulator": "input", "type": "logic", "signed": false, "width": 32, "default_value": 0, "description": "" },
          { "name": "data_size", "direction_to_simulator": "input", "type": "logic", "signed": false, "width": 16, "default_value": 0, "description": "" }
        ]
      },
      "communication": {
        "host_address": "tcp://localhost:5556",
        "simulator_address": "tcp://*:5556",
        "send_timeout_ms": 5000,
        "recv_timeout_ms": 5000,
        "retries": 3
      }
    }
  ]
}
```