# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): David Mallasén
# Description: Definition of the memory-mapped address map and its regions.

from typing import Optional, List

from address_map.address_region import AddressRegion


class AddressMap:
    """
    An ordered collection of address regions.
    """

    # Total length of the 32-bit address map
    TOTAL_LENGTH = 0xFFFFFFFF + 1

    def __init__(self):
        self.regions: List[AddressRegion] = []

    def add_region(self, region: AddressRegion):
        """
        Add a region to the address map.

        :param AddressRegion region: The region to add.
        :raise TypeError: when region is not an instance of AddressRegion.
        """
        if not isinstance(region, AddressRegion):
            raise TypeError(
                "[MCU-GEN - AddressMap] ERROR: region should be an instance of AddressRegion"
            )
        self.regions.append(region)

    def get_regions(self) -> List[AddressRegion]:
        """
        :return: A copy of the list of regions in the address map.
        :rtype: list[AddressRegion]
        """
        return self.regions

    def get_region(self, name: str) -> Optional[AddressRegion]:
        """
        Get a copy of the region with the given name.

        :param str name: The name of the region to look for.
        :return: The region with the given name, or `None` if no such region exists.
        :rtype: AddressRegion
        """
        for r in self.regions:
            if r.get_name() == name:
                return r
        return None

    def validate(self):
        """
        Validate the address map.

        Validates the regions and checks that they do not overlap and that they fit within the total
        length of the map.

        :raise RuntimeError: when regions are missing a start address or length, overlap, or
            overflow the map.
        """
        if not self.regions:
            return

        sorted_regions = sorted(
            self.regions,
            key=lambda r: (r.get_start_address() is None, r.get_start_address()),
        )

        for region in sorted_regions:
            region.validate()

        for i in range(len(sorted_regions) - 1):
            current = sorted_regions[i]
            following = sorted_regions[i + 1]
            if current.get_end_address() > following.get_start_address():
                raise RuntimeError(
                    f"[AddressMap] ERROR: Region {current.get_name()} "
                    f"({hex(current.get_start_address())}-{hex(current.get_end_address())}) overlaps with "
                    f"{following.get_name()} (starts at {hex(following.get_start_address())})"
                )

        last = sorted_regions[-1]
        if last.get_end_address() > AddressMap.TOTAL_LENGTH:
            raise RuntimeError(
                f"[AddressMap] ERROR: Region {last.get_name()} overflows (ends at "
                f"{hex(last.get_end_address())}, map length is {hex(AddressMap.TOTAL_LENGTH)})"
            )
