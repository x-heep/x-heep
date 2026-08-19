# Debug Subsystem Configuration

The debug subsystem provides run-control debugging capabilities for X-HEEP. It is represented by the {py:class}`debug_ss.debug_ss.DebugSS` class.

## Default configuration

The default debug subsystem configuration can be found in [configs/general.py](https://github.com/x-heep/x-heep/blob/main/configs/general.py). A custom configuration can be created through the Python configuration approach.

```python
from debug_ss.debug_ss import DebugSS
...
system.set_debug_ss(DebugSS(has_spi_slave=1))
```

The debug subsystem must be included in the system's [address map](./AddressMap).

## Debug subsystem parameters

The debug subsystem currently exposes the following parameter:

* `has_spi_slave`: Whether the debug subsystem includes an SPI slave debug interface.
  * `0` (default): No SPI slave debug interface.
  * `1`: SPI slave debug interface is enabled.


The {py:class}`debug_ss.debug_ss.DebugSS` class can be instantiated with `has_spi_slave` directly, or the value can be changed later using {py:meth}`debug_ss.debug_ss.DebugSS.set_spi_slave`.

The configured debug subsystem is then passed to the `XHeep` system using `set_debug_ss()`.
