# X-HEEP-based eXamples

Here you can find a list of `X-HEEP` based open-source examples. If you want to include your project in this list, please open an issue with a link to your repository.

* [CGRA-X-HEEP](https://github.com/esl-epfl/cgra_x_heep): A CGRA loosely coupled with X-HEEP.
* [F-HEEP](https://github.com/davidmallasen/F-HEEP): System integrating [fpu_ss](https://github.com/pulp-platform/fpu_ss) into X-HEEP via the eXtension interface and cv32e40px.
* [KALIPSO](https://github.com/vlsi-lab/ntt_intt_kyber) and [KRONOS](https://github.com/vlsi-lab/keccak_integration/tree/keccak_xheep): Loosely-coupled, post-quantum cryptography accelerators for NTT/INTT and Keccak hash function integrated into X-HEEP.

## Socsim-Generator: Automating Inter-Process Communication with X-HEEP
X-HEEP simulations often require communication between the CPU and external accelerators or co-processors. Traditionally, this was done using Verilator’s [Direct Programming Interface (DPI)](https://verilator.org/guide/latest/connecting.html), which involves manually writing C code to send and receive data via Unix Domain Sockets, embedding this logic in a peripheral module, and customizing the accelerator’s interface. While functional, this approach is time-consuming and error-prone for each new accelerator. An example implementation of this approach can be seen [here](https://github.com/specs-feup/x-heep), where a CGRA peripheral is integrated into X-HEEP using DPI-based communication.

[Socsim-Generator](https://github.com/specs-feup/socsim-generator) simplifies and generalizes this workflow. It is a co-simulation framework that automates the integration of high-level simulators with X-HEEP, letting users focus on the accelerator’s behavior rather than low-level communication details. Using a JSON configuration, Socsim-Generator can:

- Generate the X-HEEP-side interface logic and communication code.
- Generate skeleton code for the external high-level simulator (in C++, Java or Python).
- Set up the underlying communication channel between X-HEEP and the simulator.

This means that adding a new peripheral or co-processor no longer requires manually writing DPI code or socket-handling logic. Users only define the interface and memory-mapped registers in JSON, and Socsim-Generator handles the rest.

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