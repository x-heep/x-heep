# eXtending hardware

To extend X-HEEP with your own custom IPs, you first have to create a top-level repository that will contain both X-HEEP and your IP.

## Repository structure

The following is an example repository folder structure.

    BASE
    ├── hw
    │   ├── TOP
    │   │   └── top.sv
    │   └── vendor
    │       ├── your_copro
    │       ├── your_copro.vendor.hjson
    │       ├── esl_epfl_x_heep
    │       └── esl_epfl_x_heep.vendor.hjson
    ├── top.core
    ├── scripts
    │   └── sim
    │       ├── compile_remote_bitbang.sh
    │       └── compile_uart_dpi.sh
    ├── tb
    │   └── testharness.sv
    ├── util
    │   └── vendor.py
    ├── Makefile
    └── sw

## Adding a CV-X-IF coprocessor

We recomend using the [vendor](https://opentitan.org/book/util/doc/vendor.html) tool as [used inside X-HEEP](../GettingStarted/UnderstandingTools.md#vendor), although you could modify it to use git submodules.

- Create a new top-level repository (`BASE`) and vendorize both your `CV-X-IF` compliant coprocessor and X-HEEP. For X-HEEP, create inside your top-level repository's base directory (`BASE`) a `hw/vendor` directory containing a file named `esl_epfl_x_heep.vendor.hjson`:

<details>
    <summary>Example of esl_epfl_x_heep.vendor.hjson</summary>

```
// Copyright EPFL
// Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

{
  name: "esl_epfl_x_heep"
  target_dir: "esl_epfl_x_heep"

  upstream: {
    url: "https://github.com/x-heep/x-heep.git"
    rev: "main"
  }

  patch_dir: "patches/esl_epfl_x_heep"

  exclude_from_upstream: [
    ".github"
    "ci"
  ]
}

```
</details><br>

The `main` branch in `rev:` can be replaced with a specific commit. This is the recommended operation
to prevent accidental updates to an incompatible repository commit.

In a directory `BASE/util` add the [vendor Python script](https://github.com/lowRISC/opentitan/blob/master/util/vendor.py).

To vendorize or revendorize the X-HEEP repository inside a `BASE/hw/vendor/esl_epfl_x_heep/` folder run the following command from your `BASE`.
```
util/vendor.py --update hw/vendor/esl_epfl_x_heep.vendor.hjson
```

- Copy the `x-heep/hw/system/x_heep_system.sv` as your new top-level module. Then modify it as needed to include your coprocessor and connect it to the `core_v_mini_mcu` with the `XIF`. The `XIF` SystemVerilog interface must be instantiated in the top-level module, where X-HEEP and your co-processor are connected. See X-HEEP's testbench (`tb/testharness.sv`) as an example.
- Before building software remember to run `make mcu-gen CPU=cv32e40px`.

## Adding an accelerator on the bus

Documentation TBD. The start should be similar to a CV-X-IF coprocessor. You can look at the available [eXamples](./eXamples.md).

## Creating a simulation or synthesis flow

To add this new top-level module to the simulation/synthesis flow you can extend the [FuseSoC](https://fusesoc.readthedocs.io/en/stable/user/index.html) support of X-HEEP.

- Create a new `tb/testharness.sv` modifying the one in `x-heep/tb/testharness.sv` by adding your new top-level module.
- Create a new `scripts/sim` directory adapting the corresponding ones in `x-heep/scripts/sim`.
- Create a new `<your_toplevel_name>.core` FuseSoC file following this example for Modelsim simulation and adapting it to your particular needs:

<details>
  <summary>Example of .core</summary>

```
    CAPI=2:

    # Solderpad Hardware License, Version 2.1, see LICENSE for details.
    # SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

    name: "[YOUR_FUSESOC_IP_NAME]"
    description: "[YOUR_IP_DESCRIPTION]"

    filesets:
    files_rtl_generic:
        depend:
        - openhwgroup.org:systems:core-v-mini-mcu
        - x-heep:ip:pad_control
        - [YOUR_COPROCESSOR]
        files:
        - hw/[YOUR_TOPLEVEL_SV]
        - hw/vendor/esl-epfl_x-heep/hw/system/pad_ring.sv
        file_type: systemVerilogSource

    tb:
        depend:
        - x-heep::tb-utils
        files:
        - tb/testharness.sv   # Your modified testharness
        - hw/vendor/esl-epfl_x-heep/tb/tb_top.sv
        file_type: systemVerilogSource

    # Scripts for hooks
    pre_build_uartdpi:
        files:
        - scripts/sim/compile_uart_dpi.sh  # Your modified scripts
        file_type: user

    pre_build_remote_bitbang:
        files:
        - scripts/sim/compile_remote_bitbang.sh  # Your modified scripts
        file_type: user

    pre_patch_modelsim_Makefile:
        files:
        - hw/vendor/esl-epfl_x-heep/scripts/sim/modelsim/patch_modelsim_Makefile.py
        file_type: user

    parameters:
    JTAG_DPI:
        datatype: int
        paramtype: vlogparam
        default: 0
    USE_UPF:
      datatype: bool
      paramtype: vlogdefine
      description: |
        Enables simulation with UPF with Modelsim/VCS

    scripts:
    pre_build_remote_bitbang:
        cmd:
        - sh
        - ../../../scripts/sim/compile_remote_bitbang.sh
    pre_build_uartdpi:
        cmd:
        - sh
        - ../../../scripts/sim/compile_uart_dpi.sh
    pre_patch_modelsim_Makefile:
        cmd:
        - python
        - ../../../hw/vendor/esl-epfl_x-heep/scripts/sim/modelsim/patch_modelsim_Makefile.py

    targets:
    default: &default_target
        filesets:
        - files_rtl_generic

    sim:
        <<: *default_target
        default_tool: modelsim
        filesets_append:
        - tb
        - tool_modelsim? (pre_build_remote_bitbang)
        - tool_modelsim? (pre_build_uartdpi)
        - tool_modelsim? (pre_patch_modelsim_Makefile)
        toplevel:
        - tb_top
        hooks:
        pre_build:
            - tool_modelsim? (pre_build_uartdpi)
            - tool_modelsim? (pre_build_remote_bitbang)
            - tool_modelsim? (pre_patch_modelsim_Makefile) # this is required by Questa 2020 on
        parameters:
        - JTAG_DPI
        tools:
        modelsim:
            vlog_options:
            - -override_timescale 1ns/1ps
            - -suppress vlog-2583
            - -suppress vlog-2577
            - -pedanticerrors
            - -define MODELSIM
            vsim_options:
            - -sv_lib ../../../hw/vendor/esl-epfl_x-heep/hw/vendor/lowrisc_opentitan/hw/dv/dpi/uartdpi/uartdpi
            - -sv_lib ../../../hw/vendor/esl-epfl_x-heep/hw/vendor/pulp_platform_pulpissimo/rtl/tb/remote_bitbang/librbs
```

</details><br>
