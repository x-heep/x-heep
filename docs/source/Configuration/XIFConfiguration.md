# CORE-V eXtension Interface (CV-X-IF) Configuration 

Most of the the cores available in X-HEEP support the CV-V-IF interface to offload instructions to a custom coprocessor. This interface is exposed in the top-level of `x_heep_system.sv` and `core_v_mini_mcu.sv`. Currently, the CV-V-IF is supported by the following cores:
- CV32E20
- CV32E40X
- CV32E40PX

```{warning}
CV32E20 only supports offloading two source operands. If your coprocessor requries 3 input operands (e.g., if it uses R4-type instructions), _you should rely on the CV32E40*X cores_. Support for 3 operands is going to be added in the near future. Note that, for testing purposes, `testharness.sv` allows CV32E20 as a valid choice when the FPU is enabled (together with the ZFINX RISC-V extension).
```

## Python configuration file

You can enable the CV-X-IF (disabled by default) and override its parameters (shown below) with the following syntax in your Python configuration file:

```python
from x_heep_gen.xif import CvXIf
...
xheep.set_xif(CvXIf(
    x_num_rs    = 2,
    x_id_width  = 4,
    x_mem_width = 32,
    x_rfr_width = 32,
    x_rfw_width = 32,
    x_misa      = 0x0,
    x_ecs_xs    = 0x0,
))
```

The CPU parameters are updated automatically to reflect the requested XIF configuration. Of course, be sure to match the XIF parameters expected by your coprocessor.

An example of a XIF-enable X-HEEP using the CV32E20 core is available in [configs/cv32e20_xif_fpu.py](https://github.com/x-heep/x-heep/blob/main/configs/cv32e20_xif_fpu.py) and can be built with:

```bash
make mcu-gen PYTHON_X_HEEP_CFG=configs/cv32e20_xif_fpu.py X_HEEP_CFG=configs/python_unsupported.hjson
```
