
# Serial Link
[![SHL-0.51 license](https://img.shields.io/badge/license-SHL--0.51-green)](LICENSE)

The serial link is a simple all-digital Double-Data-Rate (DDR) link with a source-synchronous interface. The link is scalable and can be used for high-bandwidth low latency applications like Die2Die communication as well as lower demanding tasks like binary preloading. The link has an AXI4 interface and implements Network, Data Link and Physical layer. The serial link is part of the [PULP (Parallel Ultra-Low Power) Platform](https://pulp-platform.org/) and is being used in various chip tapeouts e.g. [Snitch based Systems](https://github.com/pulp-platform/snitch)

## Architecture Overview
The serial link implements the 3 lowest layers of the OSI reference model:
* **Network Layer:** AXI requests and the responses are serialized and translated to an AXI-Stream interface
* **Data Link Layer:** Splits the payload of the AXI stream into multiple packets which are distributed over the physical channels. A *Channel Allocator* reshuffles the packets and is able to recover defects of physical channels. It is able to apply back-pressure with a credit-based flow control mechanism. It also synchronizes the packets of multiple channels.
* **Physical Layer:** Parametrizable number of channels and wires per channel. Each TX channel forwards its own source-synchronous clock which is a divided clock of the system clock. The RX channels samples the data with the received clock and has a CDC to synchronize to the local system clock.

## License
The Serial Link is released under Solderpad v0.51 (SHL-0.51) see [`LICENSE`](LICENSE):

## Getting started
### Dependencies
The link uses [bender](https://github.com/pulp-platform/bender) to manage its dependencies and to automatically generate compilation scripts. Further `Python >= 3.8` is required with the packages listed in `requirements.txt`. Currently, we do not provide any open-source simulation setup. Internally, the Serial Link was tested using QuestaSim.

### Simulation
The Serial Link can be simulated in QuestaSim with the following steps:
```sh
# To compile the link, run the following command:
make all
# Run the simulation. This will start the simulation in batch mode.
make run
# To open it in the GUI mode, run the following command:
# This command will also add all interesting waves to the wave window.
make run GUI=true
```

## Configuration
The link can be parametrized with arbitrary AXI interfaces resp. structs (`axi_req_t`, `axi_rsp_t`). Further, the number of Channels number of Lanes per Channel is configurable in `serial_link_pkg.sv`.

### Single-Channel
For simple use cases with lower low bandwidth requirements (e.g. binary preloading), it is recommended to use a single-channel configuration. Single-channel configurations come with less overhead for channel synchronization and fault detection.

### Multi-Channel
For use cases that require a higher bandwidth (e.g. Die2Die communication), a multi-channel configuration is recommended. In multi-channel configurations, each channel has its own source-synchronous forwarded clock and the channels are synchronized on the receiver side again. Further, a channel allocator handles faulty channels by redistributing the packets to functional channels. The detection of faulty channels can be done entirely in SW with a special _Raw Mode_ that decouples the link from the AXI interface and allows full controllability and observability of independent channels.

### Configuration Registers
Single-channel and Multi-channels currently use different configuration register files because the multi-channel configuration requires additional registers for the channel allocator etc. The registers are generated with the [reggen](https://opentitan.org/book/util/reggen/index.html). The config files for single-channel (`serial_link_single_channel.hjson`) and multi-channel (`serial_link.hjson`) can be found in the `src/regs` folder and can be regenerated with the following command:

```
make update-regs
```
