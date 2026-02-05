from .cell import Cell
from .pin import Pin
from .floorplan import Side, Orientation
from .pin import *

import copy
from typing import List


class Pad:

    name: str = ""
    iocell: Cell = None
    bondpad: Cell = None
    global_index: int = None
    side: Side = None
    side_index: float = None
    space: float = None
    offset: float = 0
    bp_space: float = 0
    orientation: Orientation = None
    iocell_center_to_ring_edge: float = None
    bondpad_center_to_ring_edge: float = None

    def __init__(self, global_index: int, pins: List[Pin] = None, attributes=None):
        """
        Constructor for Pad.

        :param global_index: Number locating the pads as they will be numbered on the chip. Only
            applies to non-physical pads. Physical pads can have global index 0. For non-physical
            pads, global_index goes from 1 to N.
        :param pins: The list of pins assigned to this pad.
        :param attributes: Additional attributes of the pad as key-value pairs.
        """

        self.global_index = global_index
        self.pins = [] if pins is None else pins
        if attributes is not None:
            for key, value in attributes.items():
                setattr(self, key, value)

    def build(self):
        if self.pins != []:
            # The pins assigned to this pad are sorted by priority.
            # Priority is an optional attribute and the highest priority will be used as main pin
            # (will be placed first on the list)
            self.pins = sorted(
                self.pins,
                key=lambda pin: (
                    pin.attributes.get("priority") or -self.pins.index(pin)
                ),
                reverse=True,
            )

            # Make the pad inherit the attributes of its main pin (the one with the highest priority)
            self.inherit_attributes()

    def is_muxed(self):
        """
        Returns True if the pad is multiplexed (i.e., has more than one pin assigned).
        """
        return len(self.pins) > 1

    def inherit_attributes(self):
        for key, value in vars(self.pins[0]).items():
            setattr(self, key, value)

    def copy(self):
        return copy.deepcopy(self)


class Physical(Pad):
    def __init__(self, name, iocell, bondpad, attributes={}):
        self.global_index = 0
        self.name = name
        self.iocell = iocell
        self.bondpad = bondpad
        self.pins = []
        self.attributes = attributes


class Corner(Physical):
    pass
