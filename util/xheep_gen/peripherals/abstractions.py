# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Pacsort17, David Mallasén
# Description: Peripheral abstract classes.

from abc import (
    ABC,
)  # Used to define abstract classes that cannot be instantiated, only well defined subclasses can be instantiated.


class Peripheral(ABC):
    """
    Basic description of a peripheral. This class cannot be instantiated.

    :param str name: The name of the peripheral.
    :param int address: The virtual (in peripheral domain) memory address of the peripheral.
    :param int length: The size taken in memory by the peripheral
    """

    _name: str
    _address_offset: int = None
    _length: int = int("0x00010000", 16)  # default length of 64KB

    def __init__(
        self,
        offset=None,
        length=None,
        num_master_ports: int = 0,
    ):
        """
        Initialize the peripheral with the address range it occupies in its domain.

        The address range is defined relative to the start of the peripheral
        domain it belongs to. Every peripheral is reachable through its
        register interface, so this range identifies the portion of the domain
        assigned to it; no extra flag declares it.

        The address range may be given either directly or as an offset and a
        length. A range without a start address is assigned automatically during
        :meth:`PeripheralDomain.build`.

        :param int offset: The virtual (in peripheral domain) memory address of the peripheral. If None, the offset will be automatically computed during build function.
        :param int length: The size taken in memory by the peripheral. If None, the length will be automatically set to 64KB.
        :param int num_master_ports: Number of master ports. Zero when the peripheral does not master the bus.
        :raise ValueError: when both an address range and an offset or a length are given.
        """

        if type(offset) == int and offset >= 0x00000000:
            self._address_offset = offset
        else:
            self._address_offset = None

        if length is not None:
            self._length = length

        if type(num_master_ports) is not int:
            raise TypeError("Number of master ports should be of type int")
        if num_master_ports < 0:
            raise ValueError("Number of master ports should be positive")
        self._num_master_ports = num_master_ports

    def get_address(self):
        """
        :return: The virtual (in peripheral domain) memory address of the peripheral. If not set, return None.
        :rtype: int
        """
        return self._address_offset

    def set_address(self, address):
        """
        Set the virtual (in peripheral domain) memory address of the peripheral.
        """
        if address is None:
            self._address_offset = None
            return
        if type(address) is not int or address < 0:
            raise ValueError("Peripheral address should be a positive integer")
        self._address_offset = address

    def get_length(self):
        """
        :return: The length of the peripheral.
        :rtype: int
        """
        return self._length

    def get_name(self):
        """
        :return: The name of the peripheral.
        :rtype: str
        """
        return self._name

    def get_num_master_ports(self):
        """
        :return: Number of master ports.
        :rtype: int
        """
        return self._num_master_ports


class BasePeripheral(Peripheral, ABC):
    """
    Abstract class representing always-on peripherals. This class cannot be instantiated.
    """


class UserPeripheral(Peripheral, ABC):
    """
    Abstract class representing user-configurable peripherals. This class cannot be instantiated.
    """
