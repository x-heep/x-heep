# Interrupts Configuration

The default interrupt configuration can be found in [configs/general.hjson](https://github.com/x-heep/x-heep/blob/main/configs/general.hjson) and [configs/general.py](https://github.com/x-heep/x-heep/blob/main/configs/general.py).

## Overall structure

Interrupts are represented by the {py:class}`interrupts.interrupts.Interrupts` class. The total number of PLIC interrupt sources is fixed to {py:attr}`interrupts.interrupts.Interrupts.PLIC_NUM_INTERRUPTS` (64) and must not be changed.

Each interrupt has:

* `name`: a unique identifier for the interrupt.
* `id`: the PLIC interrupt ID, in the range `[0, PLIC_NUM_INTERRUPTS)`.

Interrupt ID `0` is reserved and must always be named `null_intr`. It is tied to zero in hardware.

Unassigned IDs, from the first unused ID up to `63`, are automatically filled with external interrupts named `EXT_INTR_x`.

The generated hardware exposes the number of used interrupts through the `PLIC_USED_NINT` SystemVerilog parameter, and the number of available external interrupt lines through `NEXT_INT`:

```systemverilog
localparam PLIC_NINT = 64;
localparam PLIC_USED_NINT = <number of user-defined interrupts>;
localparam NEXT_INT = PLIC_NINT - PLIC_USED_NINT;
```

External interrupt lines can be driven from the top level through `intr_vector_ext_i`, as shown in the testbench:

```systemverilog
for (int i = 0; i < core_v_mini_mcu_pkg::NEXT_INT; i++) begin
  intr_vector_ext[i] = 1'b0;
end
intr_vector_ext[0] = memcopy_intr;
intr_vector_ext[1] = iffifo_int_o;
intr_vector_ext[2] = im2col_spc_done_int_o;
```

In software, the generated `core_v_mini_mcu.h` header defines a macro for each interrupt name, so applications can use identifiers such as `EXT_INTR_1` directly with the PLIC driver.

## Python configuration file

To configure interrupts in Python, create an `Interrupts` instance, add all internal interrupts with their IDs, and attach it to the system:

```python
from interrupts.interrupts import Interrupts

interrupts = Interrupts()
interrupts.add_interrupt("null_intr", 0)
interrupts.add_interrupt("uart_intr_tx_watermark", 1)
interrupts.add_interrupt("uart_intr_rx_watermark", 2)
# ... add remaining internal interrupts ...
system.set_interrupts(interrupts)
```

When {py:meth}`xheep.XHeep.build` is called, any unused IDs are automatically populated with `EXT_INTR_x` entries by {py:meth}`interrupts.interrupts.Interrupts.build`.

## HJSON configuration file

In an HJSON configuration file, interrupts are specified under the top-level `interrupts` object:

```{code} js
interrupts: {
    number: 64 // Do not change this number!
    list: {
        null_intr:               0
        uart_intr_tx_watermark:  1
        uart_intr_rx_watermark:  2
        // ... remaining interrupts ...
    }
}
```

The `number` field is validated against `PLIC_NUM_INTERRUPTS` and must remain `64`.
 