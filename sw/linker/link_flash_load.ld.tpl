/* Copyright EPFL contributors.
 * Licensed under the Apache License, Version 2.0, see LICENSE for details.
 * SPDX-License-Identifier: Apache-2.0
 */

ENTRY(_start)

MEMORY
{
<%flash_end = 0%>
% for i, section in enumerate(xheep.memory_ss().iter_linker_sections()):
    ram${i} (rwxai) : ORIGIN = ${f"{section.start:#08x}"}, LENGTH = ${f"{section.size:#08x}"}
    FLASH${i} (rx)  : ORIGIN = ${f"{section.start + int(flash_mem_start_address,16):#08x}"}, LENGTH = ${f"{section.size:#08x}"}
<%flash_end = section.end%>
% endfor
    FLASH_left (rx) : ORIGIN = ${f"{flash_end + int(flash_mem_start_address,16):#08x}"}, LENGTH = ${f"{int(flash_mem_size_address,16) - flash_end:#08x}"}
}



SECTIONS {

    /* we want a fixed entry point */
    PROVIDE(__boot_address = 0x180);

    /* stack and heap related settings */
    __stack_size = DEFINED(__stack_size) ? __stack_size : 0x${stack_size};
    PROVIDE(__stack_size = __stack_size);
    __heap_size = DEFINED(__heap_size) ? __heap_size : 0x${heap_size};

    /* interrupt vectors */
    .vectors (ORIGIN(ram0)):
    {
        PROVIDE(__vector_start = .);
        _lma_text_start = LOADADDR(.vectors);
        KEEP(*(.vectors));
        __VECTORS_AT = .;
    } >ram0 AT >FLASH0

    /* Fill memory up to __boot_address */
    .fill :
    {
        FILL(0xDEADBEEF);
        . = ORIGIN(ram0) + (__boot_address) - 1;
        BYTE(0xEE)
    } >ram0 AT >FLASH0

    /* crt0 init code */
    .init (__boot_address):
    {
        KEEP (*(SORT_NONE(.init)))
        KEEP (*(.text.start))
        KEEP (*(.text.w25q128jw_init_crt0))
        KEEP (*(.text.w25q128jw_sanity_checks))
        KEEP (*(.text.spi_write_word*))
        KEEP (*(.text.spi_wait_for_ready*))
        KEEP (*(.text.spi_create_command*))
        KEEP (*(.text.spi_set_command*))
        KEEP (*(.text.spi_set_rx_watermark*))
        KEEP (*(.text.spi_wait_for_rx_watermark*))
        KEEP (*(.text.spi_read_word*))
        KEEP (*(.text.memcpy))
        KEEP (*(.text.w25q128jw_read_standard)) /* as this function is used in the crt0, link it in the top, should be before 1024 Bytes loaded by the bootrom */
        KEEP (*(.text.w25q128jw_read_standard.*)) /* sometimes the function is renamed as  w25q128jw_read_standard.part */
        *(.xheep_init_data_crt0) /* this global variables are used in the crt0 */
        KEEP (*_bswapsi2*(.text)) /* this function is used in the w25q128jw_read_standard */
    } >ram0 AT >FLASH0

    /* The program code and other data goes into FLASH */
    .text : ALIGN_WITH_INPUT
    {
        . = ALIGN(4);
        __text_start = .; /* define a global symbol at data end; used by startup code in order to initialise the .data section in RAM */
        *(.text)           /* .text sections (code) */
        *(.text*)          /* .text* sections (code) */
        *(.rodata)         /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
        *(.srodata)        /* .rodata sections (constants, strings, etc.) */
        *(.srodata*)       /* .rodata* sections (constants, strings, etc.) */
        . = ALIGN(4);
        _etext = .;        /* define a global symbol at end of code */
    } >ram0 AT >FLASH0

    /* This is the initialized data section
    The program executes knowing that the data is in the RAM
    but the loader puts the initial values in the FLASH (inidata).
    It is one task of the startup to copy the initial values from FLASH to RAM. */
    .data : ALIGN(256)
    {
        __data_start = .; /* define a global symbol at data end; used by startup code in order to initialise the .data section in RAM */
        _sidata = LOADADDR(.data);
        _lma_data_start = LOADADDR(.data);
        _sdata = .;        /* create a global symbol at data start; used by startup code in order to initialise the .data section in RAM */
        _ram_start = .;    /* create a global symbol at ram start for garbage collector */
        . = ALIGN(4);
        __DATA_BEGIN__ = .;
        *(.data)           /* .data sections */
        *(.data*)          /* .data* sections */
        __SDATA_BEGIN__ = .;
        *(.sdata)           /* .sdata sections */
        *(.sdata*)          /* .sdata* sections */
    } >ram1 AT >FLASH1

    . = ALIGN(4);
    _edata = .;        /* define a global symbol at data end; used by startup code in order to initialise the .data section in RAM */

    .power_manager : ALIGN_WITH_INPUT
    {
        . = ALIGN(4);
       PROVIDE(__power_manager_start = .);
       . += 256;
    } >ram1 AT >FLASH1

    /* Uninitialized data section */
    .bss : ALIGN_WITH_INPUT
    {
        . = ALIGN(4);
        __bss_start = .;         /* define a global symbol at bss start; used by startup code */
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)

        . = ALIGN(4);
        __bss_end = .;         /* define a global symbol at bss end; used by startup code */
        __BSS_END__ = .;
    } >ram1 AT >FLASH1

    _lma_data_end = _lma_data_start + SIZEOF(.data) + SIZEOF(.power_manager) + SIZEOF(.bss);
    _lma_vma_data_offset = _lma_data_start - __data_start;

    _lma_text_end = _lma_text_start + SIZEOF(.vectors) + SIZEOF(.init) + SIZEOF(.text) + SIZEOF(.data) + SIZEOF(.power_manager) + SIZEOF(.bss);
    _lma_text_vma_offset = _lma_text_start - __vector_start;


    /* The compiler uses this to access data in the .sdata, .data, .sbss and .bss
     sections with fewer instructions (relaxation). This reduces code size. */
    __global_pointer$ = MIN(__SDATA_BEGIN__ + 0x800,
			    MAX(__DATA_BEGIN__ + 0x800, __BSS_END__ - 0x800));

    /* this is to define the start of the heap, and make sure we have a minimum size */
    .heap          :
    {
        PROVIDE(__heap_start = .);
        . = __heap_size;
        PROVIDE(__heap_end = .);
    } >ram1

    /* stack: we should consider putting this further to the top of the address
    space */
    .stack         : ALIGN(16) /* this is a requirement of the ABI(?) */
    {
       PROVIDE(__stack_start = .);
       . = __stack_size;
       PROVIDE(_sp = .);
       PROVIDE(__stack_end = .);
       PROVIDE(__freertos_irq_stack_top = .);
    } >ram1

    _end_of_ram1_used = .;
    PROVIDE(__ram1_used_limit_plus_4 = . + 4);

  % for i, section in enumerate(xheep.memory_ss().iter_linker_sections()):
  % if not section.name in ["code", "data"]:
    .${section.name} : ALIGN_WITH_INPUT
    {
        PROVIDE(__${section.name}_start = .);
        _lma_${section.name}_start = LOADADDR(.${section.name});
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
    } >ram${i} AT >FLASH${i}

   . = ALIGN(4);
  _ed${section.name} = .;
  _lma_${section.name}_end = _lma_${section.name}_start + SIZEOF(.${section.name});

  % endif
  % endfor

    .data_flash_only : ALIGN(256)
    {
        . = ALIGN(4);
        *(.xheep_data_flash_only)
        . = ALIGN(4);
    } >FLASH_left

}
