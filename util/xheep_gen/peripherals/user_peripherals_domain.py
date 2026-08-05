# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Pacsort17, marinPh, David Mallasén
# Description: User Peripherals (optional peripherals)

from .abstractions import UserPeripheral, PeripheralDomain

from .user_peripherals import PDM2PCM


class UserPeripheralDomain(PeripheralDomain):
    """
    Domain for user peripherals. All user peripherals must be added.
    """

    def __init__(self):
        """
        Initialize the user peripheral domain.
        """
        super().__init__(
            name="User",
        )

    def get_pdm2pcm(self):
        """
        Get the PDM2PCM peripheral. Assumes only one PDM2PCM peripheral is added. If multiple PDM2PCM peripherals are added, only the first added one will be returned.

        :return: The PDM2PCM peripheral.
        """
        for peripheral in self._peripherals:
            if isinstance(peripheral, PDM2PCM):
                return peripheral
        return None

    def add_peripheral(self, peripheral: UserPeripheral):
        """
        Add a peripheral to the domain if it is a UserPeripheral. If not, raise an error.

        :param UserPeripheral peripheral: The peripheral to add.
        """
        if not isinstance(peripheral, UserPeripheral):
            raise ValueError("Peripheral is not a UserPeripheral")
        self._peripherals.append(peripheral)

    def remove_peripheral(self, peripheral: UserPeripheral):
        """
        Remove a peripheral from the domain if it is a UserPeripheral.

        :param UserPeripheral peripheral: The peripheral to remove.
        """
        if peripheral not in self._peripherals:
            print(
                f"Warning : Peripheral {peripheral.get_name()} is not in the domain {self._name}"
            )
        self._peripherals.remove(peripheral)
