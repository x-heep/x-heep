# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): David Mallasen
# Description: Generic (default) configuration for X-HEEP

from xheep import XHeep
from address_map.address_map import AddressMap
from address_map.address_region import AddressRegion
from cpu.cv32e20 import cv32e20
from bus_type import BusType
from debug_ss.debug_ss import DebugSS
from memory_ss.memory_ss import MemorySS
from memory_ss.linker_section import LinkerSection
from peripherals.base_peripherals import (
    SOC_ctrl,
    Bootrom,
    SPI_flash,
    W25Q128JW_Controller,
    DMA,
    Power_manager,
    RV_timer_ao,
    Fast_intr_ctrl,
    Ext_peripheral,
    Pad_control,
    GPIO_ao,
)

from peripherals.base_peripherals_domain import BasePeripheralDomain
from peripherals.user_peripherals_domain import UserPeripheralDomain

from peripherals.user_peripherals import (
    RV_plic,
    SPI_host,
    GPIO,
    I2C,
    RV_timer,
    SPI2,
    PDM2PCM,
    I2S,
    UART,
)

from linker_script.linker_script import LinkerScript


def config():
    system = XHeep(BusType.onetoM)
    system.set_cpu(cv32e20(rv32e=False, rv32m="RV32MSlow"))

    memory_ss = MemorySS()
    memory_ss.add_ram_banks([32] * 2)
    memory_ss.add_linker_section(LinkerSection.by_size("code", 0, 0x00000E800))
    memory_ss.add_linker_section(LinkerSection("data", 0x00000E800, None))
    system.set_memory_ss(memory_ss)

    system.set_linker_script_config(LinkerScript(stack_size=0x800, heap_size=0x800))

    system.set_debug_ss(DebugSS(has_spi_slave=1))

    address_map = AddressMap()
    address_map.add_region(
        AddressRegion("debug", start_address=0x10000000, length=0x00100000)
    )
    address_map.add_region(
        AddressRegion(
            "base_peripheral_domain", start_address=0x20000000, length=0x00100000
        )
    )
    address_map.add_region(
        AddressRegion(
            "user_peripheral_domain", start_address=0x30000000, length=0x00100000
        )
    )
    address_map.add_region(
        AddressRegion("flash_mem", start_address=0x40000000, length=0x01000000)
    )
    address_map.add_region(
        AddressRegion("serial_link", start_address=0x50000000, length=0x01000000)
    )
    address_map.add_region(
        AddressRegion("ext_slaves", start_address=0xF0000000, length=0x01000000)
    )
    system.set_address_map(address_map)

    # Peripheral domains initialization
    base_peripheral_domain = BasePeripheralDomain()
    user_peripheral_domain = UserPeripheralDomain()

    # Base peripherals. All base peripherals must be added.
    base_peripheral_domain.add_peripheral(SOC_ctrl(0x00000000))
    base_peripheral_domain.add_peripheral(Bootrom(0x00010000))
    base_peripheral_domain.add_peripheral(SPI_flash(0x00020000, 0x00008000))
    base_peripheral_domain.add_peripheral(
        W25Q128JW_Controller(0x00029000, 0x00007000, cache="no")
    )
    base_peripheral_domain.add_peripheral(
        DMA(
            address=0x30000,
            length=0x10000,
            num_channels=4,
            num_master_ports=2,
            num_channels_per_master_port=2,
        )
    )
    base_peripheral_domain.add_peripheral(Power_manager(0x00040000))
    base_peripheral_domain.add_peripheral(RV_timer_ao(0x00050000))
    base_peripheral_domain.add_peripheral(Fast_intr_ctrl(0x00060000))
    base_peripheral_domain.add_peripheral(Ext_peripheral(0x00070000))
    base_peripheral_domain.add_peripheral(Pad_control(0x00080000))
    base_peripheral_domain.add_peripheral(GPIO_ao(0x00090000))

    # User peripherals. All are optional.
    user_peripheral_domain.add_peripheral(RV_plic(0x00000000))
    user_peripheral_domain.add_peripheral(SPI_host(0x00010000))
    user_peripheral_domain.add_peripheral(GPIO(0x00020000))
    user_peripheral_domain.add_peripheral(I2C(0x00030000))
    user_peripheral_domain.add_peripheral(RV_timer(0x00040000))
    user_peripheral_domain.add_peripheral(SPI2(0x00050000))
    user_peripheral_domain.add_peripheral(I2S(0x00070000))
    user_peripheral_domain.add_peripheral(UART(0x00080000))

    # Add the peripheral domains to the system
    system.add_peripheral_domain(base_peripheral_domain)
    system.add_peripheral_domain(user_peripheral_domain)

    return system
