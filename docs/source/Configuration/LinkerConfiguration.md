# Linker Configuration

The linker configuration defines how the RAM banks created by the memory configuration are exposed to software.
Each linker section reserves a RAM address range and tells the generated linker script which input ELF sections
should be placed there.

The following rules always apply:

- Linker section names must be unique.
- After sorting by start address, the first two sections must be `code` and `data`.
- Sections must not overlap.
- A section must cover valid RAM addresses only. It cannot cross a hole between banks.

`code` and `data` are special sections. They do not only contain the `.text` and `.data` input sections: the
generated linker scripts also place the related runtime sections there.

## HJSON configuration file

In HJSON, linker sections can be created in two ways:

1. Automatically from a top-level `ram_banks` entry with `auto_section: auto`.
2. Manually through the `linker_sections` list.

Both mechanisms can be mixed in the same configuration.

### Automatically created sections

If a top-level `ram_banks` entry contains `auto_section: auto`, X-HEEP creates a linker section that exactly
matches that RAM bank group. This works for both continuous and interleaved bank groups.

For example, the following configuration creates an automatic linker section named `data_interleaved` on the
interleaved banks:

```{code} js
{
    bus_type: "NtoM"

    ram_banks: {
        code_and_data: {
            num: 2
            sizes: [32]
        }

        data_interleaved: {
            auto_section: auto
            type: interleaved
            num: 4
            size: 16
        }
    }

    linker_sections: [
        {
            name: code
            start: 0x00000000
            size: 0x0000E800
        }
        {
            name: data
            start: 0x0000E800
        }
    ]
}
```

This automatic section produces a custom linker output section named `.data_interleaved`.
You can place objects there from C or C++ with:

```{code} c
int32_t buffer[16 * 16] __attribute__((section(".data_interleaved")));
```

### Manually created sections

Manual sections are defined in the `linker_sections` list. Each entry must contain:

- `name`: linker section name.
- `start`: start address.

You can then choose one of the following:

- `size`: section size.
- `end`: end address.
- neither `size` nor `end`: the end is inferred automatically.

If the end is not specified, X-HEEP infers it from the start of the next linker section. If there is no following
section, the end is inferred from the end of the last RAM bank.

Example:

```{code} js
linker_sections: [
    {
        name: code
        start: 0x00000000
        size: 0x0000E800
    }
    {
        name: data
        start: 0x0000E800
    }
    {
        name: scratchpad
        start: 0x00018000
        end: 0x0001C000
    }
]
```

This creates a custom linker output section named `.scratchpad`:

```{code} c
uint8_t scratch[1024] __attribute__((section(".scratchpad")));
```

```{note}
In HJSON, a custom linker section named `foo` collects the input ELF section `.foo`.
If you want a linker section to collect a different input section name such as `.xheep_foo`, or several input
section names at once, use the Python configuration API described below.
```

## Python configuration file

The Python API gives full control over linker sections through `LinkerSection`.

```{code} python
from x_heep_gen.memory_ss.linker_section import LinkerSection
from x_heep_gen.memory_ss.linker_subsection import LinkerSubsection
```

Without extra arguments, a Python `LinkerSection("foo", ...)` behaves like the HJSON flow and collects the
input section `.foo`.

There are are two functions to add linker sections:

#### add_linker_section():

```{code} python
memory_ss.add_linker_section(LinkerSection("data", 0x0000E800, None))
memory_ss.add_linker_section(LinkerSection.by_size("code", 0x00000000, 0x0000E800))
```

The linker section fed to this function can be generated in two ways:
- `LinkerSection()`: needs `name`, `start` and optionally `end` addresses
- `LinkerSection.by_size()`: needs `name`, `start` and `size`

Background checks make sure that there isn't any overlap between sections.


### Grouping multiple input sections inside one linker section

This feature has been specifically developed for interleaved memory regions, with the goal of assigning multiple linker sections to the same interleaved bank.
However, it's possible to apply it to any ram bank.

To implement this, we use `add_linker_section_for_banks()`, which allows the creation of a linker section that spans an entire bank. 

Furthermore, it's possible to define a set of sub-sections (linker input sections) and to specify if we want to target an interleaved bank or not.

Since in `xheep_gen` interleaved banks are treated as _groups of banks_, if we want to target a specific group we need to provide their name.

For example, this will produce an interleaved group of 4 32kB banks, named *il_banks_group_0*:

```{code} Python
memory_ss.add_ram_banks_il(4, 32, "il_banks_group_0")
```

`add_linker_section_for_banks()` takes as inputs:
- `name`: name of the section
- `list[LinkerSubsections]`: optional list of subsection 
- `interleaved`: to target groups of interleaved banks
- `il_group_name`: name of the target group of interleaved banks

Without any subsections, to generate the previous *il_banks_group_0* we can use:

```{code} Python
memory_ss.add_linker_section_for_banks("data_interleaved", interleaved=True, il_group_name="il_banks_group_0")
```

And this will generate:

```{code} c
.data_interleaved :
{
  . = ALIGN(4);
  *(.data_interleaved)
  . = ALIGN(4);
} >ram2
```

If needed, it's possible to have multiple *sub-sections*, defined by the `LinkerSubsection` class. 

It has four important fields:

- `name`: logical name of the group.
- `subsections_names`: list of input ELF section names to collect, without the leading `.`.
- `provide_start`: when `True`, the linker script exports `__<name>_start`.
- `provide_end`: when `True`, the linker script exports `__<name>_end`.

The groups are emitted in the order in which they are listed.

### Example: interleaved coprocessor section

In this example, we need to have 2 sub-sections in an interleaved memory region, one for our coprocessor code, the other for its data.

```{code} python
from x_heep_gen.memory_ss.memory_ss import MemorySS
from x_heep_gen.memory_ss.linker_section import LinkerSection
from x_heep_gen.memory_ss.linker_subsection import LinkerSubsection

memory_ss = MemorySS()

memory_ss.add_ram_banks([32] * 2)
memory_ss.add_ram_banks_il(4, 32, "il_banks_group_0")

memory_ss.add_linker_section(LinkerSection.by_size("code", 0x00000000, 0x0000E800))
memory_ss.add_linker_section(LinkerSection("data", 0x0000E800, None))

coprocessor_subsection = LinkerSubsection(
    name="coprocessor",
    subsections_names=["coprocessor_code", "coprocessor_data"],
    provide_start=True,
    provide_end=True,
)

memory_ss.add_linker_section_for_banks(
    "data_interleaved",
    subsections=[coprocessor_subsection],
    interleaved=True,
    il_group_name="il_banks_group_0"
)
```

In software, you can then place objects into the two input sections:

```{code} c
uint32_t coprocessor_program[] __attribute__((section(".coprocessor_code")));
uint32_t coprocessor_buffer[256] __attribute__((section(".coprocessor_data")));

extern uint8_t __coprocessor_start[];
extern uint8_t __coprocessor_end[];
```

The generated linker section will look like this:

```{code} ld
  .data_interleaved :
  {
    . = ALIGN(4);
    PROVIDE(__coprocessor_start = .);
    *(.coprocessor_code)
    *(.coprocessor_data)
    PROVIDE(__coprocessor_end = .);
    . = ALIGN(4);
  } >ram2
```

```{note}
`LinkerSubsection` is currently a Python-configuration feature. The HJSON `linker_sections` parser does not accept a `subsections` field,
since we'll discontinue the HJSON system this feature will remain a Python exclusive.
```
