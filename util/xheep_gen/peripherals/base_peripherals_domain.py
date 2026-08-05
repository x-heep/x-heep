# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Pacsort17, marinPh, David Mallasén
# Description: Base Peripherals (mandatory, always-on peripherals)

from .abstractions import BasePeripheral, PeripheralDomain
from copy import deepcopy

from .base_peripherals import (
    SOC_ctrl,
    Bootrom,
    SPI_flash,
    SPI_memio,
    DMA,
    Power_manager,
    RV_timer_ao,
    Fast_intr_ctrl,
    Ext_peripheral,
)


class BasePeripheralDomain(PeripheralDomain):
    """
    Domain for base peripherals. All base peripherals must be added.
    """

    # List of all base peripherals names
    _default_base_peripherals = [
        SOC_ctrl(),
        Bootrom(),
        SPI_flash(),
        SPI_memio(),
        DMA(),
        Power_manager(),
        RV_timer_ao(),
        Fast_intr_ctrl(),
        Ext_peripheral(),
    ]

    def __init__(self):
        """
        Initialize the base peripheral domain.

        At the beginning, there are no base peripherals. All missing peripherals will be added during build().
        """
        super().__init__(
            name="Base",
        )

    def add_peripheral(self, peripheral: BasePeripheral):
        """
        Add a peripheral to the domain if it is a BasePeripheral. If not, raise an error.

        :param BasePeripheral peripheral: The peripheral to add.
        """
        if not isinstance(peripheral, BasePeripheral):
            raise ValueError("Peripheral is not a BasePeripheral")
        self._peripherals.append(peripheral)

    def remove_peripheral(self, peripheral: BasePeripheral):
        """
        Remove a peripheral from the domain if it is a BasePeripheral.

        :param BasePeripheral peripheral: The peripheral to remove.
        """
        if peripheral not in self._peripherals:
            print(
                f"Warning : Peripheral {peripheral.get_name()} is not in the domain {self._name}"
            )
        self._peripherals.remove(peripheral)

    def add_missing_peripherals(self):
        """
        Add missing peripherals to the domain.
        """
        # Add all default peripherals
        peripherals_to_add = [deepcopy(p) for p in self._default_base_peripherals]

        # Remove peripherals that are already in the domain to obtain the list of missing peripherals
        for peripheral in self._peripherals:
            for p in peripherals_to_add:
                if type(peripheral) == type(p):
                    peripherals_to_add.remove(p)
                    break

        # Add the missing peripherals
        for p in peripherals_to_add:
            self.add_peripheral(p)

    def get_all_dmas(self):
        """
        Get the DMA peripherals.

        :return: The DMA peripherals.
        :rtype: list[DMA]
        """
        dmas = []
        for p in self._peripherals:
            if isinstance(p, DMA):
                dmas.append(deepcopy(p))
        if len(dmas) == 0:
            raise ValueError("No DMA peripheral found")
        return dmas

    def get_dma(self):
        """
        Get the main DMA peripheral (the first appended DMA peripheral).

        :return: The DMA peripheral.
        :rtype: DMA
        """
        return self.get_all_dmas()[0]

    def get_power_manager(self):
        """
        Get the Power_manager peripheral.

        :return: The Power_manager peripheral.
        :rtype: Power_manager
        """
        for p in self._peripherals:
            if isinstance(p, Power_manager):
                return p

        raise ValueError("No Power_manager peripheral found")

    def validate(self, address_length: int):
        """
        Validate the base peripheral domain. Checks if all base peripherals are added, if they don't
        overlap and if their configuration paths are valid. Checks also if dmas are valid.

        :param int address_length: The length of the address space of the peripheral domain.
        """
        for dma in self.get_all_dmas():
            dma.validate()

        # Check if all base peripherals are added
        missing = []
        for default_peripheral in self._default_base_peripherals:
            added = False
            for peripheral in self._peripherals:
                if type(peripheral) == type(default_peripheral):
                    added = True
                    break
            if not added:
                missing.append(default_peripheral.get_name())

        if missing:
            raise RuntimeError(
                f"[MCU-GEN - BasePeripheralDomain] ERROR: Missing base peripherals in domain {self._name}: {', '.join(missing)}"
            )

        super().validate(address_length)
