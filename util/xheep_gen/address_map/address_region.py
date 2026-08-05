# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): David Mallasén
# Description: Definition of an address region in the memory-mapped address map.


class AddressRegion:
    """
    A named region of the address map.

    :param str name: The name of the region.
    :param int start_address: The start address of the region.
    :param int length: The size in bytes of the region.
    """

    def __init__(
        self,
        name: str,
        start_address: int,
        length: int,
    ):
        self.name = name
        self.start_address = start_address
        self.length = length

    def get_name(self) -> str:
        """
        :return: The name of the region.
        :rtype: str
        """
        return self.name

    def get_start_address(self) -> int:
        """
        :return: The start address of the region.
        :rtype: int
        """
        return self.start_address

    def get_length(self) -> int:
        """
        :return: The length in bytes of the region.
        :rtype: int
        """
        return self.length

    def get_end_address(self) -> int:
        """
        :return: The end address of the region.
        :rtype: int
        """
        return self.start_address + self.length

    def validate(self):
        """
        Validate the region.

        Checks that the region has a start address and length.

        :raise RuntimeError: when the region is missing a start address or length.
        """
        if self.start_address is None:
            raise RuntimeError(
                f"[MCU-GEN - AddressRegion] ERROR: Region {self.name} is missing a start address"
            )
        if self.length is None:
            raise RuntimeError(
                f"[MCU-GEN - AddressRegion] ERROR: Region {self.name} is missing a length"
            )
