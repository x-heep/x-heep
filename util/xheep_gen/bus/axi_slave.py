# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Luigi Giuffrida
# Description: AXI slave region on the bus (e.g. MEM, DEBUG_MODULE, EXT_SLAVE).


class AxiSlave:
    """
    A non-peripheral AXI slave on the bus (e.g. MEM, DEBUG_MODULE, EXT_SLAVE).

    Exposes the same name/address accessors as peripherals and peripheral
    domains so the address generator can treat every AXI slave uniformly. A
    slave is one crossbar port answering one contiguous address region.

    :param str name: The name of the slave.
    :param int base: The start address of the region.
    :param int size: The size of the region in bytes.
    """

    def __init__(self, name: str, base=None, size=None):
        if type(name) is not str or name == "":
            raise ValueError("BusSlave name should be a non-empty string")
        if base is not None and type(base) is not int:
            raise ValueError("BusSlave base should be a positive integer")
        if size is not None and type(size) is not int:
            raise ValueError("BusSlave size should be a strictly positive integer")
        self._name = name
        self._start_address = base
        self._length = size

    def get_name(self) -> str:
        """:return: the name of the slave."""
        return self._name

    def get_start_address(self) -> int:
        """:return: the start address of the slave."""
        return self._start_address

    def get_length(self) -> int:
        """:return: the size of the slave in bytes."""
        return self._length

    def set_start_address(self, base: int):
        """:param int base: The start address of the slave."""
        self._start_address = base

    def set_length(self, size: int):
        """:param int size: The size of the slave in bytes."""
        self._length = size
