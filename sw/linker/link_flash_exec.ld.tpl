/* Copyright EPFL contributors.
 * Licensed under the Apache License, Version 2.0, see LICENSE for details.
 * SPDX-License-Identifier: Apache-2.0
 */

<%
    ram_start_address = xheep.memory_ss().ram_start_address()
    ram_size_address = xheep.memory_ss().ram_size_address()
%>

ENTRY(_start)

MEMORY
{
    FLASH (rx)      : ORIGIN = 0x${flash_mem_start_address}, LENGTH = 0x${flash_mem_size_address}
    RAM (xrw)       : ORIGIN = 0x${f'{ram_start_address+4:08X}'}, LENGTH = 0x${f'{ram_size_address-4:08X}'}
}

SECTIONS {

    /* we want a fixed entry point */
    PROVIDE(__boot_address = 0x40000180);

    /* stack and heap related settings */
    __stack_size = DEFINED(__stack_size) ? __stack_size : 0x${stack_size};
    PROVIDE(__stack_size = __stack_size);
    __heap_size = DEFINED(__heap_size) ? __heap_size : 0x${heap_size};

    /* interrupt vectors */
    .vectors (ORIGIN(FLASH)):
    {
      PROVIDE(__vector_start = .);
      KEEP(*(.vectors));
    } >FLASH

    /* crt0 init code */
    .init (__boot_address):
    {
        KEEP (*(SORT_NONE(.init)))
	KEEP (*(.text.start))
    } >FLASH

    /* The program code goes into FLASH */
    .text :
    {
        . = ALIGN(4);
        *(.text)           /* .text sections (code) */
        *(.text*)          /* .text* sections (code) */
        . = ALIGN(4);
    } >FLASH

    /* Read-only data lives in FLASH as a separate output section. */
    .rodata :
    {
        *(.rodata)         /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
        *(.srodata)        /* .rodata sections (constants, strings, etc.) */
        *(.srodata*)       /* .rodata* sections (constants, strings, etc.) */
        . = ALIGN(4);
        _etext = .;        /* define a global symbol at end of code-side content */
    } >FLASH

    /* This is the initialized data section
    The program executes knowing that the data is in the RAM
    but the loader puts the initial values in the FLASH (inidata).
    It is one task of the startup to copy the initial values from FLASH to RAM. */
    .data :
    {
        . = ALIGN(4);
        _sidata = LOADADDR(.data);
        _sdata = .;        /* create a global symbol at data start; used by startup code in order to initialise the .data section in RAM */
        _ram_start = .;    /* create a global symbol at ram start for garbage collector */
        . = ALIGN(4);
        __DATA_BEGIN__ = .;
        *(.data)           /* .data sections */
        *(.data*)          /* .data* sections */
        __SDATA_BEGIN__ = .;
        *(.sdata)           /* .sdata sections */
        *(.sdata*)          /* .sdata* sections */
        . = ALIGN(4);
        _edata = .;        /* define a global symbol at data end; used by startup code in order to initialise the .data section in RAM */
    } >RAM AT >FLASH

    _lma_vma_data_offset = 0x0;

    .power_manager : ALIGN(4096)
    {
       PROVIDE(__power_manager_start = .);
       . += 256;
    } >RAM

    /* Uninitialized data section */
    .bss :
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
    } >RAM

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
    } >RAM

    /* stack: we should consider putting this further to the top of the address
    space */
  .stack         : ALIGN(16) /* this is a requirement of the ABI(?) */
  {
   PROVIDE(__stack_start = .);
   . = __stack_size;
   PROVIDE(_sp = .);
   PROVIDE(__stack_end = .);
   PROVIDE(__freertos_irq_stack_top = .);
  } >RAM
}
