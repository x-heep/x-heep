# CPU Configuration

The currently available CPUs can be found in `hw/core-v-mini-mcu/include/core_v_mini_mcu_pkg.sv.tpl` under `cpu_type_e` and are:
- cv32e20
- cv32e40p
- cv32e40x
- cv32e40px

The CPU used in X-HEEP can be selected and configured in three different ways: 
- Arguments in the make command: simple CPU selection only.
- Python configuration file: full CPU configuration capabilities (recommended).
- HJSON configuration file: limited CPU configuration.

## Arguments in the make command

You can set the CPU type directly in the make command using the `CPU` argument. For example:

```bash
make mcu-gen CPU=cv32e40p
```

This method has the highest priority and will override any other CPU configuration specified elsewhere.
However, you cannot specify any extra CPU parameters.

## Python configuration file

You can select the CPU in the Python configuration file used to generate the MCU. For example,
for the default configuration for the cv32e40p CPU:

```python
from x_heep_gen.cpu.cpu import CPU
...
xheep.set_cpu(CPU("cv32e40p"))
```

This uses the default configuration for the selected CPU. If a parameter is omitted, it is not
passed to the RTL and the core's internal default configuration is used. If you want to customize
the CPU configuration, you can import the specific CPU class and set the desired parameters. For
example, with the cv32e20 CPU, to enable the RV32E extension and set the RV32M extension to `RV32MSlow`:

```python
from x_heep_gen.cpu.cv32e20 import cv32e20
...
xheep.set_cpu(cv32e20(rv32e=True, rv32m="RV32MSlow"))
```

### cv32e20 CPU configuration

The `cv32e20` CPU supports the following optional parameters:
- `rv32e` (bool): Enable or disable the RV32E extension.
- `rv32m` (str): Set the RV32M extension configuration. Possible values are defined in the
  `rv32m_e` enumeral in the `hw/vendor/openhwgroup_cv32e20/rtl/cve2_pkg.sv` file.

`cv32e20` supports the CORE-V eXtension Interface (CV-X-IF) in case it is set with `xheep.set_xif()` (see [CORE-V eXtension Interface (CV-X-IF) Configuration](./XIFConfiguration)).

The following example sets the default configuration from the rtl found in `hw/core-v-mini-mcu/cve2_xif_wrapper.sv`:

```python
from x_heep_gen.cpu.cv32e20 import cv32e20
from x_heep_gen.xif import CvXIf
...
xheep.set_cpu(cv32e20(
    rv32e=False,
    rv32m="RV32MFast",
))

# Optionally enable the CV-X-IF
xheep.set_xif(CvXIf(
    x_num_rs    = 2,    # hardwired, do not change
    x_id_width  = 4,    # hardwired, do not change
    x_mem_width = 32,   # hardwired, do not change
    x_rfr_width = 32,   # hardwired, do not change
    x_rfw_width = 32,   # hardwired, do not change
    x_misa      = 0x0,  # hardwired, do not change
    x_ecs_xs    = 0x0,  # hardwired, do not change
))
```

```{warning}
All the XIF parameters are hardwired to their default values (shown above) in `cv32e20`, so be sure to match this X-XIF configuration when using this core. Modifying `x_num_rs` to 3 is allowed to ensure interface compatibility with Quadrilatero and the FPU subsystem in `testharness.sv`, though the core only offloads two source operands (i.e., R4-type instructions are not supported). Select the `cv32e40x` core if you need full X-IF configurability.
```

### cv32e40p CPU configuration

The `cv32e40p` CPU supports the following optional parameters:
- `fpu` (bool): Enable or disable the floating-point unit (FPU).
- `fpu_addmul_lat` (int): Floating-Point ADDition/MULtiplication lane pipeline registers number.
  Requires `fpu` to be enabled.
- `fpu_others_lat` (int): Floating-Point COMParison/CONVersion lanes pipeline registers number.
  Requires `fpu` to be enabled.
- `zfinx` (bool): Enable or disable the Zfinx extension (floating-point instructions using integer registers).
  Requires `fpu` to be enabled.
- `corev_pulp` (bool): Enable or disable CORE-V PULP-specific extensions.
- `num_mhpmcounters` (int): Number of machine hardware performance counters (MHPM counters).

The following example sets the default configuration from the rtl found in `hw/vendor/openhwgroup_cv32e40p/rtl/cv32e40p_top.sv`:

```python
from x_heep_gen.cpu.cv32e40p import cv32e40p
...
xheep.set_cpu(cv32e40p(
    fpu=False,
    fpu_addmul_lat=0,
    fpu_others_lat=0,
    zfinx=False,
    corev_pulp=False,
    num_mhpmcounters=1,
))
```

### cv32e40px CPU configuration

The `cv32e40px` CPU supports the following optional parameters:
- `fpu` (bool): Enable or disable the floating-point unit (FPU).
- `fpu_addmul_lat` (int): Floating-Point ADDition/MULtiplication lane pipeline registers number.  
  Requires `fpu` to be enabled.
- `fpu_others_lat` (int): Floating-Point COMParison/CONVersion lanes pipeline registers number.  
  Requires `fpu` to be enabled.
- `zfinx` (bool): Enable or disable the Zfinx extension (floating-point instructions using integer registers).  
  Requires `fpu` to be enabled.
- `corev_pulp` (bool): Enable or disable CORE-V PULP-specific extensions.
- `num_mhpmcounters` (int): Number of machine hardware performance counters (MHPM counters).

`cv32e40px` supports the CORE-V eXtension Interface (CV-X-IF) in case it is set with `xheep.set_xif()` (see [CORE-V eXtension Interface (CV-X-IF) Configuration](./XIFConfiguration)).

The following example sets the default configuration from the RTL found in
`hw/vendor/esl_epfl_cv32e40px/rtl/cv32e40px_xif_wrapper.sv`:

```python
from x_heep_gen.cpu.cv32e40px import cv32e40px
...
xheep.set_cpu(cv32e40px(
    fpu=False,
    fpu_addmul_lat=0,
    fpu_others_lat=0,
    zfinx=False,
    corev_pulp=False,
    num_mhpmcounters=1,
))

# Optionally enable the CV-X-IF
xheep.set_xif(CvXIf(
    x_num_rs    = 3,    # '2' or '3'
    x_id_width  = 4,    # hardwired, do not change
    x_mem_width = 32,   # hardwired, do not change
    x_rfr_width = 32,   # hardwired, do not change
    x_rfw_width = 32,   # hardwired, do not change
    x_misa      = 0x0,  # hardwired, do not change
    x_ecs_xs    = 0x0,  # hardwired, do not change
))
```

```{warning}
All the XIF parameters are hardwired to their default values (shown above) in `cv32e40px`. However, `x_num_rs` can be set to 2 as the wrapper adapts the interface. Select the `cv32e40x` core if you need full X-IF configurability.
```

### cv32e40x CPU configuration

The `cv32e40x` CPU supports the following optional parameters:
- `num_mhpmcounters` (int): Number of machine hardware performance counters (MHPM counters).

`cv32e40x` supports the CORE-V eXtension Interface (CV-X-IF) in case it is set with `xheep.set_xif()` (see [CORE-V eXtension Interface (CV-X-IF) Configuration](./XIFConfiguration)).

The following example sets the default configuration from the RTL found in
`hw/vendor/openhwgroup_cv32e40x/rtl/cv32e40x_core.sv`:

```python
from x_heep_gen.cpu.cv32e40x import cv32e40x
...
xheep.set_cpu(cv32e40x(
    num_mhpmcounters=1,
))

# Optionally enable the CV-X-IF
xheep.set_xif(CvXIf(
    x_num_rs    = 3,
    x_id_width  = 4,
    x_mem_width = 32,
    x_rfr_width = 32,
    x_rfw_width = 32,
    x_misa      = 0x0,
    x_ecs_xs    = 0x0,
))
```

## HJSON configuration file

You can select the CPU in the `.hjson` configuration file using the `cpu_type` field. For example:

```
cpu_type: cv32e40p
```

Furthermore, a limited set of CPU-specific configuration parameters from the ones described above
can be provided through the `cpu_features` field. The complete list is the following:

```
cpu_features: {
    fpu: false
    zfinx: false
    corev_pulp: false
    cve2_rv32e: false
    cve2_rv32m: "RV32MFast"
}
```

The available options depend on the selected CPU core, and are completely optional. No options (by
not having the `cpu_features` field), a single option, or multiple options can be provided.
