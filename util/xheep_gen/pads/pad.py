# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Juan Sapriza, David Mallasen
# Description: Pad definitions for X-HEEP padring generation.

from .cell import Cell
from .pin import Pin
from .floorplan import Side, Orientation
from .pin import *

import copy
from typing import List


class Pad:
    """
    Represents an element that goes into the padring. Can be a pad, but can also be a PRCUT or a
    CORNER cell, or anything.
    """

    def __init__(self, global_index: int, pins: List[Pin] = None):
        """
        Constructor for Pad.

        :param global_index: Number locating the pads as they will be numbered on the chip. Only
            applies to non-physical pads. Physical pads can have global index 0. For non-physical
            pads, global_index goes from 1 to N.
        :param pins: The list of pins assigned to this pad.
        """

        self.global_index = global_index
        self.pins = [] if pins is None else pins

        # Side of the chip that the pad was assigned to. Set by the user in the mapping
        # configuration. Assigned first in the pad ring when creating the pads.
        self.side: Side = None

        # Number locating the pad on its assigned side. This INCLUDES physical pads. Starts from 0.
        # Can be non-integer (e.g. a PRCUT can have side_index 7.5 to indicate that it is squished
        # between pad 7 and 8). Assigned first in the pad ring when creating the pads.
        self.side_index: float = None

        # Orientation of the pad on the physical layout. Assigned automatically in the pad ring when
        # creating the pads depending on the side.
        self.orientation: Orientation = None

        # The space in um from the edge of the previous pad in this ring. This is computed
        # automatically during the build process in the pad ring, unless hardcoded in advance.
        self.space: float = None

        # The offset in um from the start of the ring in which the bondpad is located. Is is used
        # to skip the corner iocell, which does not have a bondpad.
        # Only used during floorplanning.
        self.offset: float = None

        # The space in um from the edge of the ring that this pad belongs to, to the center of this
        # pad. This is computed automatically during the build process in the pad ring, but can be
        # hardcoded in advance in case you want a pad in a specific location in the padring. In the
        # case of the bondpads, they will use the iocell's center_to_ring_edge to align themselves
        # and compute their spacing
        self.iocell_center_to_ring_edge: float = None
        self.bondpad_center_to_ring_edge: float = None

        # Inherited from the main pin during build()
        self.name: str = ""
        self.attributes: dict = {}
        self.iocell: Cell = None
        self.bondpad: Cell = None

    def build(self):
        """
        Finalizes the pad by sorting its pins by priority and inheriting attributes from the main
        pin.
        """
        if self.pins:
            # The pins assigned a pad are sorted by priority.
            # Priority is an optional attribute and the highest priority will be used as main pin
            # (will be placed first on the list)
            self.pins = sorted(
                self.pins,
                key=lambda pin: (
                    pin.attributes.get("priority") or -self.pins.index(pin)
                ),
                reverse=True,
            )

            # Make the pad inherit some attributes of its main pin (the one with the highest priority)
            main_pin = self.pins[0]
            self.name = main_pin.name
            self.attributes = main_pin.attributes.copy()
            self.iocell = main_pin.iocell.copy()
            self.bondpad = main_pin.bondpad.copy()

    def is_muxed(self):
        """
        Returns True if the pad is multiplexed (i.e., has more than one pin assigned).
        """
        return len(self.pins) > 1

    def copy(self):
        return copy.deepcopy(self)


class Physical(Pad):
    def __init__(self, name, iocell, bondpad, attributes=None):
        super().__init__(global_index=None)
        self.name = name
        self.iocell = iocell
        self.bondpad = bondpad
        self.pins = []
        self.attributes = {} if attributes is None else attributes


class Corner(Physical):
    pass
