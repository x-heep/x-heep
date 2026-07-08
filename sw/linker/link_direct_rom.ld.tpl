/* Copyright EPFL contributors.
 * Licensed under the Apache License, Version 2.0, see LICENSE for details.
 * SPDX-License-Identifier: Apache-2.0
 */

ENTRY(_start)

MEMORY
{
    rom  (rx)   : ORIGIN = 0x20010000, LENGTH = 0x00010000
% for i, section in enumerate(xheep.memory_ss().iter_linker_sections()):
    ram${i} (rwxai) : ORIGIN = ${f"{section.start:#08x}"}, LENGTH = ${f"{section.size:#08x}"}
% endfor
}

SECTIONS {

    PROVIDE(__boot_address = 0x20010000);

    __stack_size = DEFINED(__stack_size) ? __stack_size : 0x${stack_size};
    PROVIDE(__stack_size = __stack_size);
    __heap_size = DEFINED(__heap_size) ? __heap_size : 0x${heap_size};

    /* CPU reset vector is 0x20010000: _start must be the first instruction in ROM. */
    .init (ORIGIN(rom)):
    {
        KEEP (*(SORT_NONE(.init)))
        KEEP (*(.text.start))
    } >rom

    .text :
    {
        . = ALIGN(4);
        *(.text)
        *(.text*)
        . = ALIGN(4);
    } >rom

    .rodata :
    {
        *(.rodata)
        *(.rodata*)
        *(.srodata)
        *(.srodata*)
        . = ALIGN(4);
        _etext = .;
    } >rom

    /* Interrupt vector table: in ROM alongside the handlers it jumps to.
     * JAL range is ±1 MB; the whole ROM window is 64 KB so all targets are reachable.
     * mtvec is set to __vector_start | 1 (vectored mode) by crt0_rom.S.
     * CVE2 enforces 256-byte alignment on mtvec.BASE (zeros bits [7:2] on write),
     * so __vector_start must be 256-byte aligned or the vector dispatch is wrong. */
    .vectors : ALIGN(256)
    {
        PROVIDE(__vector_start = .);
        KEEP(*(.vectors));
    } >rom

    /* Initialised globals: initial values stored in ROM (LMA), copied to ram1 (VMA)
     * at startup by crt0_rom.S using _lma_data_start / _lma_data_end. */
    .data : ALIGN(256)
    {
        __data_start = .;
        _sidata = LOADADDR(.data);
        _lma_data_start = LOADADDR(.data);
        _sdata = .;
        _ram_start = .;
        . = ALIGN(4);
        __DATA_BEGIN__ = .;
        *(.data)
        *(.data*)
        __SDATA_BEGIN__ = .;
        *(.sdata)
        *(.sdata*)
    } >ram1 AT >rom

    . = ALIGN(4);
    _edata = .;

    .power_manager : ALIGN_WITH_INPUT
    {
        . = ALIGN(4);
        PROVIDE(__power_manager_start = .);
        . += 256;
    } >ram1 AT >rom

    _lma_data_end = _lma_data_start + SIZEOF(.data) + SIZEOF(.power_manager);
    _lma_vma_data_offset = _lma_data_start - __data_start;

    .bss : ALIGN_WITH_INPUT
    {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
        __BSS_END__ = .;
    } >ram1

    __global_pointer$ = MIN(__SDATA_BEGIN__ + 0x800,
                        MAX(__DATA_BEGIN__ + 0x800, __BSS_END__ - 0x800));

    _end = .;

    .heap :
    {
        PROVIDE(__heap_start = .);
        . = __heap_size;
        PROVIDE(__heap_end = .);
    } >ram1

    .stack : ALIGN(16)
    {
        PROVIDE(__stack_start = .);
        . = __stack_size;
        PROVIDE(_sp = .);
        PROVIDE(__stack_end = .);
        PROVIDE(__freertos_irq_stack_top = .);
    } >ram1

    _end_of_ram1_used = .;
    PROVIDE(__ram1_used_limit_plus_4 = . + 4);

    /* Extra memory banks — RAM only, no ROM image */
% for i, section in enumerate(xheep.memory_ss().iter_linker_sections()):
% if not section.name in ["code", "data"]:
    .${section.name} :
    {
        . = ALIGN(4);
        % for subsec_group in section.subsections:
        % if subsec_group.provide_start:
        PROVIDE(__${subsec_group.name}_start = .);
        % endif
        % for subsec_name in subsec_group.subsections_names:
        *(.${subsec_name})
        % endfor
        % if subsec_group.provide_end:
        PROVIDE(__${subsec_group.name}_end = .);
        % endif
        % endfor
        . = ALIGN(4);
    } >ram${i}
% endif
% endfor

    .stab          0 : { *(.stab) }
    .stabstr       0 : { *(.stabstr) }
    .debug          0 : { *(.debug) }
    .debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }
    .debug_abbrev   0 : { *(.debug_abbrev) }
    .debug_line     0 : { *(.debug_line .debug_line.* .debug_line_end) }
    .debug_frame    0 : { *(.debug_frame) }
    .debug_str      0 : { *(.debug_str) }
    .debug_loc      0 : { *(.debug_loc) }
    .debug_ranges   0 : { *(.debug_ranges) }
    .debug_macro    0 : { *(.debug_macro) }
    .gnu.attributes 0 : { KEEP (*(.gnu.attributes)) }
    /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu.lto_*) }
}
