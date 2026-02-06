# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Juan Sapriza, David Mallasen
# Description: Floorplan definitions for X-HEEP padring generation.

from .dimension import Dimension
from enum import Enum


class FloorplanDimensions:
    """
    Container for the dimensions of the different elements involved in the floorplan.
    """

    def __init__(
        self,
        die_dimensions: Dimension,
        bondpad_margin: dict,
        iocell_margin: dict,
        core_margin: dict,
    ):
        """
        Constructor for FloorplanDimensions.

        :param die_dimensions:  Dimensions of the die.
        :param bondpad_margin:  dict {Side} of margins (float) from the bondpad edge to the die
            edge. For example: {Side.LEFT: 10, Side.BOTTOM: 20, Side.RIGHT: 10, Side.TOP: 20}.
        :param iocell_margin:   dict {Side} of margins (float) from the iocell edge to the bondpad
            edge. For example: {Side.LEFT: 10, Side.BOTTOM: 20, Side.RIGHT: 10, Side.TOP: 20}.
        :param core_margin:     dict {Side} of margins (float) from the core edge to the iocell
            edge. For example: {Side.LEFT: 10, Side.BOTTOM: 20, Side.RIGHT: 10, Side.TOP: 20}.
        """

        self.die_dimensions = die_dimensions
        self.bondpad_margin = bondpad_margin
        self.iocell_margin = iocell_margin
        self.core_margin = core_margin

        # Validate margins
        for margin, name in zip(
            [bondpad_margin, iocell_margin, core_margin],
            ["bondpad_margin", "iocell_margin", "core_margin"],
        ):
            if len(margin) != 4:
                raise ValueError(
                    f"{name} must be a dict of four elements corresponding to the sides: {list(Side)}."
                )

            for m in margin.values():
                if m < 0:
                    raise ValueError(f"All values in {name} must be non-negative.")


class Side(Enum):
    """
    Physical sides of the pad ring.
    """

    LEFT = "left"
    BOTTOM = "bottom"
    RIGHT = "right"
    TOP = "top"


class Orientation(Enum):
    """
    Physical orientation/rotation of pad cell.

    Values:
        R0: No rotation (0 degrees)
        R90: 90 degree rotation
        R180: 180 degree rotation
        R270: 270 degree rotation
        MX: Mirror around X axis
        MY: Mirror around Y axis
        MX90: Mirror X + 90 degree rotation
        MY90: Mirror Y + 90 degree rotation
    """

    R0 = "R0"
    R90 = "R90"
    R180 = "R180"
    R270 = "R270"
    MX = "MX"
    MY = "MY"
    MX90 = "MX90"
    MY90 = "MY90"


# Default cell orientation for each side of the pad ring
SIDE_DEFAULT_ROTATION = {
    Side.TOP: Orientation.R0,
    Side.RIGHT: Orientation.R270,
    Side.BOTTOM: Orientation.R180,
    Side.LEFT: Orientation.R90,
}
